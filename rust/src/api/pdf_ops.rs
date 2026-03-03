use std::collections::{BTreeMap, HashMap};
use std::fs;
use std::path::Path;
use std::time::Instant;

use anyhow::{anyhow, Result};
use flutter_rust_bridge::frb;
use lopdf::{Document, Object, ObjectId};

use super::types::{EncryptionInfo, FileInfo, PdfResult};

// ─── Helpers ────────────────────────────────────────────────────────────────

fn now_ms() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

fn ok(output_path: String, page_count: u32, start: Instant) -> PdfResult {
    PdfResult {
        success: true,
        output_path,
        error: None,
        page_count,
        processing_ms: start.elapsed().as_millis() as u64,
    }
}

fn ok_multi(output_paths: Vec<String>, page_count: u32, start: Instant) -> PdfResult {
    // For multi-output operations, join paths with '|' separator
    PdfResult {
        success: true,
        output_path: output_paths.join("|"),
        error: None,
        page_count,
        processing_ms: start.elapsed().as_millis() as u64,
    }
}

fn err(msg: String) -> PdfResult {
    PdfResult {
        success: false,
        output_path: String::new(),
        error: Some(msg),
        page_count: 0,
        processing_ms: 0,
    }
}

/// Remap all object IDs in `doc` so they start from `start_id`.
fn remap_ids(doc: &mut Document, start_id: u32) -> u32 {
    let old_ids: Vec<ObjectId> = doc.objects.keys().cloned().collect();
    let mut id_map: BTreeMap<ObjectId, ObjectId> = BTreeMap::new();
    let mut next = start_id;

    for old in &old_ids {
        let new_id = (next, 0u16);
        id_map.insert(*old, new_id);
        next += 1;
    }

    let mut new_objects: BTreeMap<ObjectId, Object> = BTreeMap::new();
    let old_ids: Vec<ObjectId> = doc.objects.keys().copied().collect();
    for old_id in old_ids {
        if let Some(obj) = doc.objects.remove(&old_id) {
            let new_id = id_map[&old_id];
            let remapped = remap_object(obj, &id_map);
            new_objects.insert(new_id, remapped);
        }
    }
    doc.objects = new_objects;
    remap_dict(&mut doc.trailer, &id_map);
    next
}

fn remap_object(obj: Object, map: &BTreeMap<ObjectId, ObjectId>) -> Object {
    match obj {
        Object::Reference(id) => {
            if let Some(&new_id) = map.get(&id) {
                Object::Reference(new_id)
            } else {
                Object::Reference(id)
            }
        }
        Object::Array(arr) => Object::Array(arr.into_iter().map(|o| remap_object(o, map)).collect()),
        Object::Dictionary(mut dict) => {
            remap_dict(&mut dict, map);
            Object::Dictionary(dict)
        }
        Object::Stream(mut stream) => {
            remap_dict(&mut stream.dict, map);
            Object::Stream(stream)
        }
        other => other,
    }
}

fn remap_dict(dict: &mut lopdf::Dictionary, map: &BTreeMap<ObjectId, ObjectId>) {
    for (_, val) in dict.iter_mut() {
        *val = remap_object(val.clone(), map);
    }
}

fn ensure_f1_in_resources_dict(res_dict: &mut lopdf::Dictionary, font_id: ObjectId) {
    match res_dict.get_mut(b"Font") {
        Ok(Object::Dictionary(font_dict)) => {
            font_dict.set("F1", Object::Reference(font_id));
        }
        _ => {
            let mut fonts = lopdf::Dictionary::new();
            fonts.set("F1", Object::Reference(font_id));
            res_dict.set("Font", Object::Dictionary(fonts));
        }
    }
}

// ─── Public API ─────────────────────────────────────────────────────────────

/// Merge multiple PDFs into one output file.
#[frb]
pub fn merge_pdfs(paths: Vec<String>, output_path: String, add_watermark: bool) -> PdfResult {
    let start = Instant::now();
    match merge_pdfs_inner(paths, &output_path, add_watermark) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e) => err(e.to_string()),
    }
}

fn merge_pdfs_inner(paths: Vec<String>, output_path: &str, add_watermark: bool) -> Result<u32> {
    if paths.is_empty() {
        return Err(anyhow!("No input files provided"));
    }

    let mut merged = Document::with_version("1.5");
    let mut pages_dict = lopdf::Dictionary::new();
    let mut page_ids: Vec<Object> = Vec::new();
    let mut next_id: u32 = 1;
    let mut total_pages: u32 = 0;

    let catalog_id: ObjectId = (next_id, 0);
    next_id += 1;
    let pages_id: ObjectId = (next_id, 0);
    next_id += 1;

    for path in &paths {
        let mut doc = Document::load(path).map_err(|e| anyhow!("Failed to load {}: {}", path, e))?;
        doc.decompress();

        next_id = remap_ids(&mut doc, next_id);

        let mut page_num_map: Vec<(u32, ObjectId)> = doc.get_pages().into_iter().collect();
        page_num_map.sort_by_key(|(num, _)| *num);
        let doc_page_ids: Vec<ObjectId> = page_num_map.into_iter().map(|(_, id)| id).collect();
        total_pages += doc_page_ids.len() as u32;

        for page_id in &doc_page_ids {
            let inherited_keys: &[&'static [u8]] = &[b"MediaBox", b"CropBox", b"Resources", b"Rotate"];

            let old_parent_id: Option<ObjectId> = doc
                .get_object(*page_id)
                .ok()
                .and_then(|o| o.as_dict().ok())
                .and_then(|d| d.get(b"Parent").ok())
                .and_then(|r| r.as_reference().ok());

            let mut inherited_values: Vec<(&'static [u8], Object)> = Vec::new();
            if let Some(parent_id) = old_parent_id {
                if let Ok(parent_obj) = doc.get_object(parent_id) {
                    if let Ok(parent_dict) = parent_obj.as_dict() {
                        for key in inherited_keys {
                            let page_has_key = doc
                                .get_object(*page_id)
                                .ok()
                                .and_then(|o| o.as_dict().ok())
                                .map(|d| d.has(*key))
                                .unwrap_or(false);
                            if !page_has_key {
                                if let Ok(val) = parent_dict.get(*key) {
                                    inherited_values.push((*key, val.clone()));
                                }
                            }
                        }
                    }
                }
            }

            if let Ok(page) = doc.get_object_mut(*page_id) {
                if let Ok(dict) = page.as_dict_mut() {
                    for (key, val) in inherited_values {
                        dict.set(key, val);
                    }
                    dict.set("Parent", Object::Reference(pages_id));
                }
            }
            page_ids.push(Object::Reference(*page_id));
        }

        for (id, obj) in doc.objects {
            merged.objects.insert(id, obj);
        }
    }

    pages_dict.set("Type", Object::Name(b"Pages".to_vec()));
    pages_dict.set("Kids", Object::Array(page_ids));
    pages_dict.set("Count", Object::Integer(total_pages as i64));
    merged.objects.insert(pages_id, Object::Dictionary(pages_dict));

    let mut catalog = lopdf::Dictionary::new();
    catalog.set("Type", Object::Name(b"Catalog".to_vec()));
    catalog.set("Pages", Object::Reference(pages_id));
    merged.objects.insert(catalog_id, Object::Dictionary(catalog));

    merged.trailer.set("Root", Object::Reference(catalog_id));
    merged.trailer.set("Size", Object::Integer((next_id + 1) as i64));

    if add_watermark {
        add_watermark_to_doc(&mut merged, pages_id)?;
    }

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    merged.save(output_path)?;
    Ok(total_pages)
}

/// Split a PDF: extract specific pages (1-indexed) into a new file.
#[frb]
pub fn split_pdf(input_path: String, pages: Vec<u32>, output_path: String, add_watermark: bool) -> PdfResult {
    let start = Instant::now();
    match split_pdf_inner(&input_path, &pages, &output_path, add_watermark) {
        Ok(count) => ok(output_path, count, start),
        Err(e) => err(e.to_string()),
    }
}

fn split_pdf_inner(input_path: &str, pages: &[u32], output_path: &str, add_watermark: bool) -> Result<u32> {
    let mut doc = Document::load(input_path)?;
    doc.decompress();

    let page_map: HashMap<ObjectId, u32> =
        doc.get_pages().into_iter().map(|(num, id)| (id, num)).collect();
    let max_page = page_map.len() as u32;

    for &p in pages {
        if p == 0 || p > max_page {
            return Err(anyhow!("Page {} out of range (1-{})", p, max_page));
        }
    }

    let keep_set: std::collections::HashSet<u32> = pages.iter().copied().collect();
    let mut pages_to_remove: Vec<u32> = page_map
        .values()
        .copied()
        .filter(|num| !keep_set.contains(num))
        .collect();
    pages_to_remove.sort_unstable_by(|a, b| b.cmp(a));

    for page_num in pages_to_remove {
        doc.delete_pages(&[page_num]);
    }

    if add_watermark {
        let pages_id = get_pages_id(&doc)?;
        add_watermark_to_doc(&mut doc, pages_id)?;
    }

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    doc.save(output_path)?;
    Ok(pages.len() as u32)
}

/// Protect a PDF with password encryption.
#[frb]
pub fn protect_pdf(input_path: String, password: String, output_path: String) -> PdfResult {
    let start = Instant::now();
    match protect_pdf_inner(&input_path, &password, &output_path) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e) => err(e.to_string()),
    }
}

fn protect_pdf_inner(_input_path: &str, _password: &str, _output_path: &str) -> Result<u32> {
    Err(anyhow!(
        "PDF password protection is not yet supported. \
         A spec-compliant RC4/AES encryption implementation is required."
    ))
}

/// Unlock (remove password from) a PDF.
#[frb]
pub fn unlock_pdf(input_path: String, password: String, output_path: String) -> PdfResult {
    let start = Instant::now();
    match unlock_pdf_inner(&input_path, &password, &output_path) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e) => err(e.to_string()),
    }
}

fn unlock_pdf_inner(input_path: &str, _password: &str, output_path: &str) -> Result<u32> {
    let mut doc = Document::load(input_path)
        .map_err(|e| anyhow!("Cannot open PDF (wrong password?): {}", e))?;
    let page_count = doc.get_pages().len() as u32;
    doc.trailer.remove(b"Encrypt");
    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    doc.save(output_path)?;
    Ok(page_count)
}

/// Convert images to a single PDF.
#[frb]
pub fn images_to_pdf(image_paths: Vec<String>, output_path: String, add_watermark: bool) -> PdfResult {
    let start = Instant::now();
    match images_to_pdf_inner(image_paths, &output_path, add_watermark) {
        Ok(count) => ok(output_path, count, start),
        Err(e) => err(e.to_string()),
    }
}

fn images_to_pdf_inner(image_paths: Vec<String>, output_path: &str, _add_watermark: bool) -> Result<u32> {
    use image::GenericImageView;

    if image_paths.is_empty() {
        return Err(anyhow!("No images provided"));
    }

    let mut doc = Document::with_version("1.5");
    let mut next_id: u32 = 1;

    let catalog_id: ObjectId = (next_id, 0);
    next_id += 1;
    let pages_id: ObjectId = (next_id, 0);
    next_id += 1;

    let mut page_ids: Vec<Object> = Vec::new();

    for img_path in &image_paths {
        let img = image::open(img_path)
            .map_err(|e| anyhow!("Cannot open image {}: {}", img_path, e))?;
        let (width, height) = img.dimensions();

        let rgb = img.to_rgb8();
        let mut jpeg_bytes: Vec<u8> = Vec::new();
        {
            use image::codecs::jpeg::JpegEncoder;
            let mut enc = JpegEncoder::new_with_quality(&mut jpeg_bytes, 90);
            enc.encode_image(&rgb)?;
        }

        let img_id: ObjectId = (next_id, 0);
        next_id += 1;
        let mut img_dict = lopdf::Dictionary::new();
        img_dict.set("Type", Object::Name(b"XObject".to_vec()));
        img_dict.set("Subtype", Object::Name(b"Image".to_vec()));
        img_dict.set("Width", Object::Integer(width as i64));
        img_dict.set("Height", Object::Integer(height as i64));
        img_dict.set("ColorSpace", Object::Name(b"DeviceRGB".to_vec()));
        img_dict.set("BitsPerComponent", Object::Integer(8));
        img_dict.set("Filter", Object::Name(b"DCTDecode".to_vec()));
        img_dict.set("Length", Object::Integer(jpeg_bytes.len() as i64));
        let img_stream = lopdf::Stream::new(img_dict, jpeg_bytes);
        doc.objects.insert(img_id, Object::Stream(img_stream));

        let res_id: ObjectId = (next_id, 0);
        next_id += 1;
        let mut xobject_dict = lopdf::Dictionary::new();
        xobject_dict.set("Im0", Object::Reference(img_id));
        let mut res_dict = lopdf::Dictionary::new();
        res_dict.set("XObject", Object::Dictionary(xobject_dict));
        doc.objects.insert(res_id, Object::Dictionary(res_dict));

        let (pw, ph) = fit_to_a4(width as f64, height as f64);
        let x_offset = (595.0 - pw) / 2.0;
        let y_offset = (842.0 - ph) / 2.0;
        let content = format!(
            "q\n{:.4} 0 0 {:.4} {:.4} {:.4} cm\n/Im0 Do\nQ\n",
            pw, ph, x_offset, y_offset
        );
        let content_bytes = content.into_bytes();
        let content_id: ObjectId = (next_id, 0);
        next_id += 1;
        let mut content_dict = lopdf::Dictionary::new();
        content_dict.set("Length", Object::Integer(content_bytes.len() as i64));
        let content_stream = lopdf::Stream::new(content_dict, content_bytes);
        doc.objects.insert(content_id, Object::Stream(content_stream));

        let page_id: ObjectId = (next_id, 0);
        next_id += 1;
        let mut page_dict = lopdf::Dictionary::new();
        page_dict.set("Type", Object::Name(b"Page".to_vec()));
        page_dict.set("Parent", Object::Reference(pages_id));
        page_dict.set(
            "MediaBox",
            Object::Array(vec![
                Object::Integer(0),
                Object::Integer(0),
                Object::Integer(595),
                Object::Integer(842),
            ]),
        );
        page_dict.set("Resources", Object::Reference(res_id));
        page_dict.set("Contents", Object::Reference(content_id));
        doc.objects.insert(page_id, Object::Dictionary(page_dict));
        page_ids.push(Object::Reference(page_id));
    }

    let count = page_ids.len() as u32;

    let mut pages_dict = lopdf::Dictionary::new();
    pages_dict.set("Type", Object::Name(b"Pages".to_vec()));
    pages_dict.set("Kids", Object::Array(page_ids));
    pages_dict.set("Count", Object::Integer(count as i64));
    doc.objects.insert(pages_id, Object::Dictionary(pages_dict));

    let mut catalog = lopdf::Dictionary::new();
    catalog.set("Type", Object::Name(b"Catalog".to_vec()));
    catalog.set("Pages", Object::Reference(pages_id));
    doc.objects.insert(catalog_id, Object::Dictionary(catalog));

    doc.trailer.set("Root", Object::Reference(catalog_id));
    doc.trailer.set("Size", Object::Integer((next_id + 1) as i64));

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    doc.save(output_path)?;
    Ok(count)
}

// ─── NEW: PDF to Images ──────────────────────────────────────────────────────

/// Convert each page of a PDF to a JPEG image.
/// Returns a PdfResult where output_path is '|'-joined list of image paths.
/// output_dir: directory to save images into.
/// dpi: rendering DPI (72 = screen, 150 = medium, 300 = print). 
/// Currently renders via a simple pixel-level approach using lopdf + image crate.
#[frb]
pub fn pdf_to_images(input_path: String, output_dir: String, dpi: u32) -> PdfResult {
    let start = Instant::now();
    match pdf_to_images_inner(&input_path, &output_dir, dpi) {
        Ok(paths) => {
            let count = paths.len() as u32;
            ok_multi(paths, count, start)
        }
        Err(e) => err(e.to_string()),
    }
}

fn pdf_to_images_inner(input_path: &str, output_dir: &str, dpi: u32) -> Result<Vec<String>> {
    let doc = Document::load(input_path)
        .map_err(|e| anyhow!("Failed to load PDF: {}", e))?;

    let pages = doc.get_pages();
    if pages.is_empty() {
        return Err(anyhow!("PDF has no pages"));
    }

    fs::create_dir_all(output_dir)?;

    let scale = dpi.max(72) as f64 / 72.0;
    let mut output_paths: Vec<String> = Vec::new();

    let mut page_nums: Vec<u32> = pages.keys().copied().collect();
    page_nums.sort();

    for page_num in page_nums {
        let page_id = pages[&page_num];

        // Get page dimensions from MediaBox
        let (page_w_pt, page_h_pt) = get_page_dimensions(&doc, page_id);

        // Convert points to pixels at target DPI
        let img_w = ((page_w_pt * scale) as u32).max(1);
        let img_h = ((page_h_pt * scale) as u32).max(1);

        // Create a white background image
        // Note: true PDF rendering (fonts, vectors) requires a full PDF renderer
        // (like pdfium). Here we extract embedded raster images and composite
        // them onto a white canvas. Text/vector content will not be rendered.
        // For production use, integrate pdfium_render or similar.
        let mut canvas = image::RgbImage::new(img_w, img_h);
        // Fill white
        for pixel in canvas.pixels_mut() {
            *pixel = image::Rgb([255u8, 255u8, 255u8]);
        }

        // Try to extract and composite any image XObjects from the page
        composite_page_images(&doc, page_id, &mut canvas, scale, page_h_pt)?;

        let out_path = Path::new(output_dir)
            .join(format!("page_{:04}.jpg", page_num));
        canvas
            .save_with_format(&out_path, image::ImageFormat::Jpeg)
            .map_err(|e| anyhow!("Failed to save page {}: {}", page_num, e))?;

        output_paths.push(out_path.to_string_lossy().into_owned());
    }

    Ok(output_paths)
}

fn get_page_dimensions(doc: &Document, page_id: ObjectId) -> (f64, f64) {
    // Try page dict first, then walk up to parent for inherited MediaBox
    let media_box = doc
        .get_object(page_id)
        .ok()
        .and_then(|o| o.as_dict().ok())
        .and_then(|d| {
            // Try direct MediaBox
            if let Ok(mb) = d.get(b"MediaBox") {
                return Some(mb.clone());
            }
            // Try via Parent
            if let Ok(parent_ref) = d.get(b"Parent").and_then(|r| r.as_reference()) {
                if let Ok(parent_obj) = doc.get_object(parent_ref) {
                    if let Ok(pd) = parent_obj.as_dict() {
                        if let Ok(mb) = pd.get(b"MediaBox") {
                            return Some(mb.clone());
                        }
                    }
                }
            }
            None
        });

    if let Some(Object::Array(arr)) = media_box {
        if arr.len() == 4 {
            let w = arr[2].as_float().unwrap_or(595.0) - arr[0].as_float().unwrap_or(0.0);
            let h = arr[3].as_float().unwrap_or(842.0) - arr[1].as_float().unwrap_or(0.0);
           return (w.abs() as f64, h.abs() as f64);
        }
    }
    // Default A4
    (595.0, 842.0)
}

fn composite_page_images(
    doc: &Document,
    page_id: ObjectId,
    canvas: &mut image::RgbImage,
    scale: f64,
    page_h_pt: f64,
) -> Result<()> {
    use image::GenericImage;

    let page_dict = match doc.get_object(page_id).ok().and_then(|o| o.as_dict().ok()) {
        Some(d) => d.clone(),
        None => return Ok(()),
    };

    // Get Resources -> XObject dict
    let xobj_dict: Option<lopdf::Dictionary> = get_xobject_dict(doc, &page_dict);
    let xobj_dict = match xobj_dict {
        Some(d) => d,
        None => return Ok(()),
    };

    // Parse content stream for image placement commands (cm matrix + Do)
    let content_bytes = get_page_content_bytes(doc, &page_dict);
    let placements = parse_image_placements(&content_bytes);

    for (xobj_name, matrix) in &placements {
        let name_bytes = xobj_name.as_bytes();
        let xobj_ref = match xobj_dict.get(name_bytes).ok().and_then(|o| o.as_reference().ok()) {
            Some(r) => r,
            None => continue,
        };

        let stream = match doc.get_object(xobj_ref) {
            Ok(Object::Stream(s)) => s.clone(),
            _ => continue,
        };

        // Only handle Image XObjects with DCTDecode (JPEG) or raw
        let subtype = stream.dict.get(b"Subtype").ok()
            .and_then(|o| o.as_name_str().ok())
            .unwrap_or("").to_string();
        if subtype != "Image" {
            continue;
        }

        let img_w_px = stream.dict.get(b"Width").ok().and_then(|o| o.as_i64().ok()).unwrap_or(0) as u32;
        let img_h_px = stream.dict.get(b"Height").ok().and_then(|o| o.as_i64().ok()).unwrap_or(0) as u32;
        if img_w_px == 0 || img_h_px == 0 {
            continue;
        }

        // Decode image bytes
        let decoded = match image::load_from_memory(&stream.content) {
            Ok(img) => img,
            Err(_) => continue,
        };
        let decoded = decoded.to_rgb8();

        // [a, b, c, d, e, f] — PDF CTM
        // For axis-aligned images: a=width_pt, d=height_pt, e=x_pt, f=y_pt
        let a = matrix[0];
        let d = matrix[3];
        let e = matrix[4];
        let f = matrix[5];

        // Convert PDF coords (origin bottom-left) to image coords (origin top-left)
        let dest_x = (e * scale) as i64;
        let dest_y = ((page_h_pt - f - d.abs()) * scale) as i64;
        let dest_w = ((a.abs()) * scale) as u32;
        let dest_h = ((d.abs()) * scale) as u32;

        if dest_w == 0 || dest_h == 0 {
            continue;
        }

        // Scale source image to destination size
        let scaled = image::imageops::resize(
            &decoded,
            dest_w,
            dest_h,
            image::imageops::FilterType::Lanczos3,
        );

        // Composite onto canvas (clip to canvas bounds)
        let canvas_w = canvas.width() as i64;
        let canvas_h = canvas.height() as i64;
        for py in 0..dest_h as i64 {
            for px in 0..dest_w as i64 {
                let cx = dest_x + px;
                let cy = dest_y + py;
                if cx >= 0 && cy >= 0 && cx < canvas_w && cy < canvas_h {
                    let pixel = scaled.get_pixel(px as u32, py as u32);
                    canvas.put_pixel(cx as u32, cy as u32, *pixel);
                }
            }
        }
    }

    Ok(())
}

fn get_xobject_dict(doc: &Document, page_dict: &lopdf::Dictionary) -> Option<lopdf::Dictionary> {
    let res = match page_dict.get(b"Resources").ok()? {
        Object::Dictionary(d) => d.clone(),
        Object::Reference(r) => {
            doc.get_object(*r).ok()?.as_dict().ok()?.clone()
        }
        _ => return None,
    };
    match res.get(b"XObject").ok()? {
        Object::Dictionary(d) => Some(d.clone()),
        Object::Reference(r) => {
            doc.get_object(*r).ok()?.as_dict().ok().map(|d| d.clone())
        }
        _ => None,
    }
}

fn get_page_content_bytes(doc: &Document, page_dict: &lopdf::Dictionary) -> Vec<u8> {
    let contents = match page_dict.get(b"Contents") {
        Ok(c) => c.clone(),
        Err(_) => return Vec::new(),
    };
    match contents {
        Object::Reference(r) => {
            doc.get_object(r).ok()
                .and_then(|o| if let Object::Stream(s) = o { Some(s.content.clone()) } else { None })
                .unwrap_or_default()
        }
        Object::Array(arr) => {
            arr.iter().flat_map(|o| {
                if let Ok(r) = o.as_reference() {
                    doc.get_object(r).ok()
                        .and_then(|obj| if let Object::Stream(s) = obj { Some(s.content.clone()) } else { None })
                        .unwrap_or_default()
                } else {
                    Vec::new()
                }
            }).collect()
        }
        _ => Vec::new(),
    }
}

/// Parse simple `a b c d e f cm /Name Do` sequences from content stream.
fn parse_image_placements(content: &[u8]) -> Vec<(String, [f64; 6])> {
    let text = String::from_utf8_lossy(content);
    let mut results = Vec::new();
    let mut current_matrix: Option<[f64; 6]> = None;

    for line in text.lines() {
        let tokens: Vec<&str> = line.split_whitespace().collect();
        if tokens.len() == 7 && tokens[6] == "cm" {
            let nums: Vec<f64> = tokens[..6].iter()
                .filter_map(|t| t.parse().ok())
                .collect();
            if nums.len() == 6 {
                current_matrix = Some([nums[0], nums[1], nums[2], nums[3], nums[4], nums[5]]);
            }
        } else if tokens.len() == 2 && tokens[1] == "Do" && tokens[0].starts_with('/') {
            if let Some(matrix) = current_matrix.take() {
                let name = tokens[0].trim_start_matches('/').to_string();
                results.push((name, matrix));
            }
        }
    }
    results
}

// ─── NEW: Compress PDF ───────────────────────────────────────────────────────

/// Compress a PDF by re-encoding JPEG images at lower quality and
/// removing metadata / unused objects.
/// quality: JPEG quality 1-100 (suggested: 60 for high compression, 80 for balanced)
#[frb]
pub fn compress_pdf(input_path: String, output_path: String, quality: u32) -> PdfResult {
    let start = Instant::now();
    match compress_pdf_inner(&input_path, &output_path, quality) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e) => err(e.to_string()),
    }
}

fn compress_pdf_inner(input_path: &str, output_path: &str, quality: u32) -> Result<u32> {
    let mut doc = Document::load(input_path)
        .map_err(|e| anyhow!("Failed to load PDF: {}", e))?;
    doc.decompress();

    let quality = quality.clamp(1, 100) as u8;
    let page_count = doc.get_pages().len() as u32;

    // Collect IDs of image streams to re-encode
    let image_ids: Vec<ObjectId> = doc.objects.iter()
        .filter_map(|(id, obj)| {
            if let Object::Stream(stream) = obj {
                let subtype = stream.dict.get(b"Subtype").ok()
                    .and_then(|o| o.as_name_str().ok())
                    .unwrap_or("");
                if subtype == "Image" {
                    return Some(*id);
                }
            }
            None
        })
        .collect();

    for img_id in image_ids {
        if let Some(Object::Stream(stream)) = doc.objects.get_mut(&img_id) {
            let w = stream.dict.get(b"Width").ok().and_then(|o| o.as_i64().ok()).unwrap_or(0) as u32;
            let h = stream.dict.get(b"Height").ok().and_then(|o| o.as_i64().ok()).unwrap_or(0) as u32;
            if w == 0 || h == 0 {
                continue;
            }

            // Try to decode whatever image data we have
            let decoded = match image::load_from_memory(&stream.content) {
                Ok(img) => img.to_rgb8(),
                Err(_) => continue, // skip if we can't decode (e.g. masks, CCITT)
            };

            // Re-encode at target quality
            let mut new_jpeg: Vec<u8> = Vec::new();
            {
                use image::codecs::jpeg::JpegEncoder;
                let mut enc = JpegEncoder::new_with_quality(&mut new_jpeg, quality);
                if enc.encode_image(&decoded).is_err() {
                    continue;
                }
            }

            // Only replace if we actually saved space
            if new_jpeg.len() < stream.content.len() {
                stream.content = new_jpeg;
                stream.dict.set("Filter", Object::Name(b"DCTDecode".to_vec()));
                stream.dict.set("Length", Object::Integer(stream.content.len() as i64));
            }
        }
    }

    // Remove metadata and info dict to save space
    doc.trailer.remove(b"Info");

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    doc.save(output_path)?;
    Ok(page_count)
}

// ─── NEW: Sign PDF ───────────────────────────────────────────────────────────

/// Add a visible text/image signature to a PDF page.
/// sig_image_path: optional path to a PNG/JPEG signature image; if empty, uses text.
/// signer_name: display name shown in signature.
/// page_number: 1-indexed page to place signature on.
/// x, y: position in points from bottom-left.
/// width, height: signature box dimensions in points.
#[frb]
pub fn sign_pdf(
    input_path: String,
    output_path: String,
    sig_image_path: String,
    signer_name: String,
    page_number: u32,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
) -> PdfResult {
    let start = Instant::now();
    match sign_pdf_inner(
        &input_path,
        &output_path,
        &sig_image_path,
        &signer_name,
        page_number,
        x, y, width, height,
    ) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e) => err(e.to_string()),
    }
}

fn sign_pdf_inner(
    input_path: &str,
    output_path: &str,
    sig_image_path: &str,
    signer_name: &str,
    page_number: u32,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
) -> Result<u32> {
    let mut doc = Document::load(input_path)
        .map_err(|e| anyhow!("Failed to load PDF: {}", e))?;
    doc.decompress();

    let page_count = doc.get_pages().len() as u32;
    if page_number == 0 || page_number > page_count {
        return Err(anyhow!("Page {} out of range (1-{})", page_number, page_count));
    }

    let pages = doc.get_pages();
    let page_id = *pages.get(&page_number)
        .ok_or_else(|| anyhow!("Page not found"))?;

    let next_base = doc.objects.keys().map(|id| id.0).max().unwrap_or(0) + 1;

    if !sig_image_path.is_empty() && Path::new(sig_image_path).exists() {
        // Image signature
        sign_with_image(&mut doc, page_id, sig_image_path, signer_name, x, y, width, height, next_base)?;
    } else {
        // Text signature fallback
        sign_with_text(&mut doc, page_id, signer_name, x, y, width, height, next_base)?;
    }

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    doc.save(output_path)?;
    Ok(page_count)
}

fn sign_with_image(
    doc: &mut Document,
    page_id: ObjectId,
    sig_image_path: &str,
    signer_name: &str,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    next_base: u32,
) -> Result<()> {
    use image::GenericImageView;

    let img = image::open(sig_image_path)
        .map_err(|e| anyhow!("Cannot open signature image: {}", e))?;
    let (iw, ih) = img.dimensions();
    let rgb = img.to_rgb8();
    let mut jpeg_bytes: Vec<u8> = Vec::new();
    {
        use image::codecs::jpeg::JpegEncoder;
        JpegEncoder::new_with_quality(&mut jpeg_bytes, 95).encode_image(&rgb)?;
    }

    let img_id: ObjectId = (next_base, 0);
    let mut img_dict = lopdf::Dictionary::new();
    img_dict.set("Type", Object::Name(b"XObject".to_vec()));
    img_dict.set("Subtype", Object::Name(b"Image".to_vec()));
    img_dict.set("Width", Object::Integer(iw as i64));
    img_dict.set("Height", Object::Integer(ih as i64));
    img_dict.set("ColorSpace", Object::Name(b"DeviceRGB".to_vec()));
    img_dict.set("BitsPerComponent", Object::Integer(8));
    img_dict.set("Filter", Object::Name(b"DCTDecode".to_vec()));
    img_dict.set("Length", Object::Integer(jpeg_bytes.len() as i64));
    doc.objects.insert(img_id, Object::Stream(lopdf::Stream::new(img_dict, jpeg_bytes)));

    // Content stream: draw image + signer label
    let ts = now_ms();
    let content = format!(
        "q\n{w:.2} 0 0 {h:.2} {x:.2} {y:.2} cm\n/SigImg Do\nQ\n\
         BT\n/F1 7 Tf\n{tx:.2} {ty:.2} Td\n0.4 0.4 0.4 rg\n(Signed by: {name}) Tj\nET\n",
        w = width, h = height, x = x, y = y,
        tx = x, ty = y - 10.0,
        name = signer_name,
    );
    let content_bytes = content.into_bytes();
    let content_id: ObjectId = (next_base + 1, 0);
    let mut cd = lopdf::Dictionary::new();
    cd.set("Length", Object::Integer(content_bytes.len() as i64));
    doc.objects.insert(content_id, Object::Stream(lopdf::Stream::new(cd, content_bytes)));

    // Font object
    let font_id: ObjectId = (next_base + 2, 0);
    let mut fd = lopdf::Dictionary::new();
    fd.set("Type", Object::Name(b"Font".to_vec()));
    fd.set("Subtype", Object::Name(b"Type1".to_vec()));
    fd.set("BaseFont", Object::Name(b"Helvetica".to_vec()));
    doc.objects.insert(font_id, Object::Dictionary(fd));

    inject_sig_resources(doc, page_id, img_id, Some("SigImg"), font_id, content_id)
}

fn sign_with_text(
    doc: &mut Document,
    page_id: ObjectId,
    signer_name: &str,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    next_base: u32,
) -> Result<()> {
    // Draw a rounded box + text
    let content = format!(
        // Box
        "q\n0.9 0.95 1.0 rg\n{x:.2} {y:.2} {w:.2} {h:.2} re\nf\n\
         0.2 0.4 0.8 RG\n1 w\n{x:.2} {y:.2} {w:.2} {h:.2} re\nS\nQ\n\
         BT\n/F1 9 Tf\n{tx:.2} {ty:.2} Td\n0.1 0.2 0.5 rg\n(Digitally Signed) Tj\n\
         0 -13 Td\n/F1 7 Tf\n0.3 0.3 0.3 rg\n({name}) Tj\n\
         0 -11 Td\n(Date: {ts}) Tj\nET\n",
        x = x, y = y, w = width, h = height,
        tx = x + 6.0, ty = y + height - 14.0,
        name = signer_name,
        ts = chrono::Utc::now().format("%Y-%m-%d"),
    );
    let content_bytes = content.into_bytes();
    let content_id: ObjectId = (next_base, 0);
    let mut cd = lopdf::Dictionary::new();
    cd.set("Length", Object::Integer(content_bytes.len() as i64));
    doc.objects.insert(content_id, Object::Stream(lopdf::Stream::new(cd, content_bytes)));

    let font_id: ObjectId = (next_base + 1, 0);
    let mut fd = lopdf::Dictionary::new();
    fd.set("Type", Object::Name(b"Font".to_vec()));
    fd.set("Subtype", Object::Name(b"Type1".to_vec()));
    fd.set("BaseFont", Object::Name(b"Helvetica".to_vec()));
    doc.objects.insert(font_id, Object::Dictionary(fd));

    inject_sig_resources(doc, page_id, (0, 0), None, font_id, content_id)
}

fn inject_sig_resources(
    doc: &mut Document,
    page_id: ObjectId,
    img_id: ObjectId,
    img_name: Option<&str>,
    font_id: ObjectId,
    content_id: ObjectId,
) -> Result<()> {
    // Handle Resources: could be inline dict or indirect reference
    let resources_clone = doc
        .get_object(page_id)
        .ok()
        .and_then(|o| o.as_dict().ok())
        .and_then(|d| d.get(b"Resources").ok().cloned());

    match resources_clone {
        Some(Object::Reference(res_id)) => {
            // Inline-mutate the referenced resource dict
            if let Ok(Object::Dictionary(res_dict)) = doc.get_object_mut(res_id) {
                ensure_f1_in_resources_dict(res_dict, font_id);
                if let Some(name) = img_name {
                    match res_dict.get_mut(b"XObject") {
                        Ok(Object::Dictionary(xobj)) => {
                            xobj.set(name, Object::Reference(img_id));
                        }
                        _ => {
                            let mut xobj = lopdf::Dictionary::new();
                            xobj.set(name, Object::Reference(img_id));
                            res_dict.set("XObject", Object::Dictionary(xobj));
                        }
                    }
                }
            }
        }
        _ => {
            // Build / merge inline resources on the page dict
            if let Ok(page) = doc.get_object_mut(page_id) {
                if let Ok(dict) = page.as_dict_mut() {
                    let mut res = lopdf::Dictionary::new();
                    let mut fonts = lopdf::Dictionary::new();
                    fonts.set("F1", Object::Reference(font_id));
                    res.set("Font", Object::Dictionary(fonts));
                    if let Some(name) = img_name {
                        let mut xobj = lopdf::Dictionary::new();
                        xobj.set(name, Object::Reference(img_id));
                        res.set("XObject", Object::Dictionary(xobj));
                    }
                    dict.set("Resources", Object::Dictionary(res));
                }
            }
        }
    }

    // Append content stream to page
    if let Ok(page) = doc.get_object_mut(page_id) {
        if let Ok(dict) = page.as_dict_mut() {
            let existing = dict.get(b"Contents").ok().cloned();
            match existing {
                Some(Object::Reference(eid)) => {
                    dict.set("Contents", Object::Array(vec![
                        Object::Reference(eid),
                        Object::Reference(content_id),
                    ]));
                }
                Some(Object::Array(mut arr)) => {
                    arr.push(Object::Reference(content_id));
                    dict.set("Contents", Object::Array(arr));
                }
                _ => {
                    dict.set("Contents", Object::Reference(content_id));
                }
            }
        }
    }
    Ok(())
}

// ─── NEW: DOCX/CSV/Excel → PDF ───────────────────────────────────────────────

/// Convert a plain-text file (DOCX exported as .txt, CSV, or raw text) to PDF.
/// For DOCX: caller should extract text content before calling (e.g. via docx_rs).
/// This function takes raw UTF-8 text lines and renders them as a paginated PDF.
/// font_size: point size (suggested 11-12).
#[frb]
pub fn text_to_pdf(
    text_content: String,
    output_path: String,
    title: String,
    font_size: f64,
) -> PdfResult {
    let start = Instant::now();
    match text_to_pdf_inner(&text_content, &output_path, &title, font_size) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e) => err(e.to_string()),
    }
}

fn text_to_pdf_inner(
    text_content: &str,
    output_path: &str,
    title: &str,
    font_size: f64,
) -> Result<u32> {
    let font_size = font_size.clamp(6.0, 36.0);
    let line_height = font_size * 1.4;
    // A4: 595 x 842 pts, margins: 50pt each side
    let margin = 50.0_f64;
    let page_w = 595.0_f64;
    let page_h = 842.0_f64;
    let usable_w = page_w - 2.0 * margin;
    let usable_h = page_h - 2.0 * margin;
    // Approximate chars per line at 0.6 * font_size avg char width
    let chars_per_line = ((usable_w / (font_size * 0.55)) as usize).max(20);
    let lines_per_page = ((usable_h / line_height) as usize).max(1);

    // Word-wrap all input lines
    let mut all_lines: Vec<String> = Vec::new();
    for input_line in text_content.lines() {
        if input_line.trim().is_empty() {
            all_lines.push(String::new());
            continue;
        }
        // Simple word-wrap
        let mut current = String::new();
        for word in input_line.split_whitespace() {
            if current.is_empty() {
                current = word.to_string();
            } else if current.len() + 1 + word.len() <= chars_per_line {
                current.push(' ');
                current.push_str(word);
            } else {
                all_lines.push(current.clone());
                current = word.to_string();
            }
        }
        if !current.is_empty() {
            all_lines.push(current);
        }
    }

    // Split into pages
    let pages_content: Vec<Vec<String>> = all_lines
        .chunks(lines_per_page)
        .map(|c| c.to_vec())
        .collect();

    let total_pages = pages_content.len().max(1) as u32;

    let mut doc = Document::with_version("1.5");
    let mut next_id: u32 = 1;

    let catalog_id: ObjectId = (next_id, 0);
    next_id += 1;
    let pages_id: ObjectId = (next_id, 0);
    next_id += 1;

    // Font
    let font_id: ObjectId = (next_id, 0);
    next_id += 1;
    let font_bold_id: ObjectId = (next_id, 0);
    next_id += 1;
    let mut fd = lopdf::Dictionary::new();
    fd.set("Type", Object::Name(b"Font".to_vec()));
    fd.set("Subtype", Object::Name(b"Type1".to_vec()));
    fd.set("BaseFont", Object::Name(b"Helvetica".to_vec()));
    fd.set("Encoding", Object::Name(b"WinAnsiEncoding".to_vec()));
    doc.objects.insert(font_id, Object::Dictionary(fd));

    let mut fdb = lopdf::Dictionary::new();
    fdb.set("Type", Object::Name(b"Font".to_vec()));
    fdb.set("Subtype", Object::Name(b"Type1".to_vec()));
    fdb.set("BaseFont", Object::Name(b"Helvetica-Bold".to_vec()));
    fdb.set("Encoding", Object::Name(b"WinAnsiEncoding".to_vec()));
    doc.objects.insert(font_bold_id, Object::Dictionary(fdb));

    // Shared Resources
    let res_id: ObjectId = (next_id, 0);
    next_id += 1;
    let mut fonts_dict = lopdf::Dictionary::new();
    fonts_dict.set("F1", Object::Reference(font_id));
    fonts_dict.set("F2", Object::Reference(font_bold_id));
    let mut res_dict = lopdf::Dictionary::new();
    res_dict.set("Font", Object::Dictionary(fonts_dict));
    doc.objects.insert(res_id, Object::Dictionary(res_dict));

    let mut page_ids: Vec<Object> = Vec::new();

    for (page_idx, page_lines) in pages_content.iter().enumerate() {
        let mut content_ops = String::new();

        // Title on first page
        if page_idx == 0 && !title.is_empty() {
            let safe_title = pdf_escape(title);
            content_ops.push_str(&format!(
                "BT\n/F2 {:.1} Tf\n{:.2} {:.2} Td\n0 0 0 rg\n({}) Tj\nET\n",
                font_size + 2.0,
                margin,
                page_h - margin,
                safe_title,
            ));
        }

        // Body text
        if !page_lines.is_empty() {
            content_ops.push_str(&format!(
                "BT\n/F1 {:.1} Tf\n{:.2} {:.2} Td\n{:.2} TL\n0.1 0.1 0.1 rg\n",
                font_size,
                margin,
                page_h - margin - (if page_idx == 0 && !title.is_empty() { font_size * 2.5 } else { 0.0 }),
                line_height,
            ));
            for line in page_lines {
                let safe = pdf_escape(line);
                content_ops.push_str(&format!("({}) '\n", safe));
            }
            content_ops.push_str("ET\n");
        }

        // Page number footer
        content_ops.push_str(&format!(
            "BT\n/F1 8 Tf\n{:.2} {:.2} Td\n0.5 0.5 0.5 rg\n(Page {} of {}) Tj\nET\n",
            page_w / 2.0 - 20.0,
            margin / 2.0,
            page_idx + 1,
            total_pages,
        ));

        let content_bytes = content_ops.into_bytes();
        let content_id: ObjectId = (next_id, 0);
        next_id += 1;
        let mut cd = lopdf::Dictionary::new();
        cd.set("Length", Object::Integer(content_bytes.len() as i64));
        doc.objects.insert(content_id, Object::Stream(lopdf::Stream::new(cd, content_bytes)));

        let page_id: ObjectId = (next_id, 0);
        next_id += 1;
        let mut pd = lopdf::Dictionary::new();
        pd.set("Type", Object::Name(b"Page".to_vec()));
        pd.set("Parent", Object::Reference(pages_id));
        pd.set("MediaBox", Object::Array(vec![
            Object::Integer(0), Object::Integer(0),
            Object::Integer(595), Object::Integer(842),
        ]));
        pd.set("Resources", Object::Reference(res_id));
        pd.set("Contents", Object::Reference(content_id));
        doc.objects.insert(page_id, Object::Dictionary(pd));
        page_ids.push(Object::Reference(page_id));
    }

    let mut pages_dict = lopdf::Dictionary::new();
    pages_dict.set("Type", Object::Name(b"Pages".to_vec()));
    pages_dict.set("Kids", Object::Array(page_ids));
    pages_dict.set("Count", Object::Integer(total_pages as i64));
    doc.objects.insert(pages_id, Object::Dictionary(pages_dict));

    let mut catalog = lopdf::Dictionary::new();
    catalog.set("Type", Object::Name(b"Catalog".to_vec()));
    catalog.set("Pages", Object::Reference(pages_id));
    doc.objects.insert(catalog_id, Object::Dictionary(catalog));

    doc.trailer.set("Root", Object::Reference(catalog_id));
    doc.trailer.set("Size", Object::Integer((next_id + 1) as i64));

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    doc.save(output_path)?;
    Ok(total_pages)
}

/// Escape special PDF string characters
fn pdf_escape(s: &str) -> String {
    s.chars()
        .filter(|c| c.is_ascii() && *c != '\x00')
        .map(|c| match c {
            '(' => "\\(".to_string(),
            ')' => "\\)".to_string(),
            '\\' => "\\\\".to_string(),
            other => other.to_string(),
        })
        .collect()
}

/// Get page count of a PDF.
#[frb]
pub fn get_pdf_page_count(path: String) -> u32 {
    Document::load(&path)
        .map(|d| d.get_pages().len() as u32)
        .unwrap_or(0)
}

/// Get file info.
#[frb]
pub fn get_file_info(path: String) -> FileInfo {
    let size_bytes = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
    let (page_count, is_encrypted) = Document::load(&path)
        .map(|d| (d.get_pages().len() as u32, d.is_encrypted()))
        .unwrap_or((0, false));
    FileInfo { path, size_bytes, page_count, is_encrypted }
}

/// Check if PDF is encrypted.
#[frb]
pub fn get_pdf_encryption_info(path: String) -> EncryptionInfo {
    let (is_encrypted, page_count) = Document::load(&path)
        .map(|d| (d.is_encrypted(), d.get_pages().len() as u32))
        .unwrap_or((false, 0));
    EncryptionInfo { is_encrypted, page_count }
}

// ─── Internal helpers ────────────────────────────────────────────────────────

fn fit_to_a4(w: f64, h: f64) -> (f64, f64) {
    let scale = (595.0_f64 / w).min(842.0_f64 / h);
    (w * scale, h * scale)
}

fn get_pages_id(doc: &Document) -> Result<ObjectId> {
    let catalog_id = doc.trailer.get(b"Root")
        .and_then(|o| o.as_reference())
        .map_err(|_| anyhow!("No Root in trailer"))?;
    let catalog = doc.get_object(catalog_id)
        .and_then(|o| o.as_dict())
        .map_err(|_| anyhow!("Cannot read catalog"))?;
    catalog.get(b"Pages")
        .and_then(|o| o.as_reference())
        .map_err(|_| anyhow!("No Pages in catalog"))
}

fn add_watermark_to_doc(doc: &mut Document, pages_id: ObjectId) -> Result<()> {
    let pages_obj = doc.get_object(pages_id)
        .map_err(|_| anyhow!("Cannot get pages"))?.clone();
    let kids = pages_obj.as_dict()
        .and_then(|d| d.get(b"Kids"))
        .and_then(|k| k.as_array())
        .map_err(|_| anyhow!("Cannot get kids"))?.clone();

    for kid_ref in kids {
        if let Ok(page_id) = kid_ref.as_reference() {
            add_watermark_to_page(doc, page_id)?;
        }
    }
    Ok(())
}

fn add_watermark_to_page(doc: &mut Document, page_id: ObjectId) -> Result<()> {
    let watermark_text = "Processed by BatchPDF";
    let content = format!(
        "BT\n/F1 8 Tf\n50 20 Td\n0.5 0.5 0.5 rg\n({}) Tj\nET\n",
        watermark_text
    );

    let font_id: ObjectId = {
        let next = doc.objects.keys().map(|id| id.0).max().unwrap_or(0) + 1;
        (next, 0)
    };
    let mut font_dict = lopdf::Dictionary::new();
    font_dict.set("Type", Object::Name(b"Font".to_vec()));
    font_dict.set("Subtype", Object::Name(b"Type1".to_vec()));
    font_dict.set("BaseFont", Object::Name(b"Helvetica".to_vec()));
    doc.objects.insert(font_id, Object::Dictionary(font_dict));

    let content_id: ObjectId = {
        let next = doc.objects.keys().map(|id| id.0).max().unwrap_or(0) + 1;
        (next, 0)
    };
    let content_bytes = content.into_bytes();
    let mut stream_dict = lopdf::Dictionary::new();
    stream_dict.set("Length", Object::Integer(content_bytes.len() as i64));
    doc.objects.insert(content_id, Object::Stream(lopdf::Stream::new(stream_dict, content_bytes)));

    // Bug #3 fix: handle both inline dict and indirect reference for Resources
    if let Ok(page) = doc.get_object_mut(page_id) {
        if let Ok(dict) = page.as_dict_mut() {
            match dict.get(b"Resources").ok().cloned() {
                Some(Object::Dictionary(mut res_dict)) => {
                    ensure_f1_in_resources_dict(&mut res_dict, font_id);
                    dict.set("Resources", Object::Dictionary(res_dict));
                }
                Some(Object::Reference(res_ref_id)) => {
                    // Do NOT overwrite the reference — mutate the referenced dict directly.
                    // We'll handle this after the page borrow is dropped.
                    let _ = res_ref_id; // handled below
                }
                _ => {
                    let mut res = lopdf::Dictionary::new();
                    let mut fonts = lopdf::Dictionary::new();
                    fonts.set("F1", Object::Reference(font_id));
                    res.set("Font", Object::Dictionary(fonts));
                    dict.set("Resources", Object::Dictionary(res));
                }
            }

            let existing_contents = dict.get(b"Contents").ok().cloned();
            match existing_contents {
                Some(Object::Reference(existing_id)) => {
                    dict.set("Contents", Object::Array(vec![
                        Object::Reference(existing_id),
                        Object::Reference(content_id),
                    ]));
                }
                Some(Object::Array(mut arr)) => {
                    arr.push(Object::Reference(content_id));
                    dict.set("Contents", Object::Array(arr));
                }
                _ => {
                    dict.set("Contents", Object::Reference(content_id));
                }
            }
        }
    }

    // Handle indirect Resources reference (after page borrow is released)
    let res_ref_id: Option<ObjectId> = doc
        .get_object(page_id).ok()
        .and_then(|o| o.as_dict().ok())
        .and_then(|d| d.get(b"Resources").ok().cloned())
        .and_then(|r| if let Object::Reference(id) = r { Some(id) } else { None });

    if let Some(rid) = res_ref_id {
        if let Ok(Object::Dictionary(res_dict)) = doc.get_object_mut(rid) {
            ensure_f1_in_resources_dict(res_dict, font_id);
        }
    }

    Ok(())
}
