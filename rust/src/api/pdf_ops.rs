use std::collections::{BTreeMap, HashMap};
use std::fs;
use std::path::Path;
use std::time::Instant;

use anyhow::{anyhow, Result};
use flutter_rust_bridge::frb;
use lopdf::{Document, Object, ObjectId};
use lopdf::content::Operation;

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

fn save_document(doc: &mut Document, path: &str) -> anyhow::Result<()> {
    doc.max_id = doc.objects.keys().map(|k| k.0).max().unwrap_or(0);
    doc.save(path).map_err(|e| anyhow!("Failed to save PDF: {}", e))?;
    Ok(())
}

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
    save_document(&mut merged, output_path)?;
    Ok(total_pages)
}

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
    save_document(&mut doc, output_path)?;
    Ok(pages.len() as u32)
}

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
    save_document(&mut doc, output_path)?;
    Ok(page_count)
}

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
    save_document(&mut doc, output_path)?;
    Ok(count)
}

// ─── PDF to Images ───────────────────────────────────────────────────────────

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
    let mut doc = Document::load(input_path)
        .map_err(|e| anyhow!("Failed to load PDF: {}", e))?;
    let _ = doc.decompress();

    let pages = doc.get_pages();
    if pages.is_empty() {
        return Err(anyhow!("PDF has no pages"));
    }

    fs::create_dir_all(output_dir)?;

    let scale = dpi.max(72) as f64 / 72.0;
    let mut output_paths: Vec<String> = Vec::new();
    let mut page_nums: Vec<u32> = pages.keys().copied().collect();
    page_nums.sort();

    let mut any_raster_found = false;

    for page_num in page_nums {
        let page_id = pages[&page_num];

        let (page_w_pt, page_h_pt) = get_page_dimensions(&doc, page_id);
        let img_w = ((page_w_pt * scale) as u32).max(1);
        let img_h = ((page_h_pt * scale) as u32).max(1);

        // PERF FIX 1: use from_pixel for O(1) white fill instead of pixel loop
        let mut canvas = image::RgbImage::from_pixel(img_w, img_h, image::Rgb([255u8, 255u8, 255u8]));

        let placed = composite_page_images(&doc, page_id, &mut canvas, scale, page_h_pt)?;
        if placed > 0 {
            any_raster_found = true;
        }

        let out_path = Path::new(output_dir).join(format!("page_{:04}.jpg", page_num));
        canvas
            .save_with_format(&out_path, image::ImageFormat::Jpeg)
            .map_err(|e| anyhow!("Failed to save page {}: {}", page_num, e))?;

        output_paths.push(out_path.to_string_lossy().into_owned());
    }

    if !any_raster_found {
        return Err(anyhow!(
            "No extractable images found. This PDF likely contains only text/vector content."
        ));
    }

    Ok(output_paths)
}

fn get_page_dimensions(doc: &Document, page_id: ObjectId) -> (f64, f64) {
    let media_box = doc
        .get_object(page_id)
        .ok()
        .and_then(|o| o.as_dict().ok())
        .and_then(|d| {
            if let Ok(mb) = d.get(b"MediaBox") {
                return Some(mb.clone());
            }
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
    (595.0, 842.0)
}

fn composite_page_images(
    doc: &Document,
    page_id: ObjectId,
    canvas: &mut image::RgbImage,
    scale: f64,
    page_h_pt: f64,
) -> Result<usize> {
    use image::imageops;

    let page_dict = match doc.get_object(page_id).ok().and_then(|o| o.as_dict().ok()) {
        Some(d) => d.clone(),
        None => return Ok(0),
    };

    let xobj_dict = match get_xobject_dict_inherited(doc, page_id, &page_dict) {
        Some(d) => d,
        None => return Ok(0),
    };

    let content = match doc.get_and_decode_page_content(page_id) {
        Ok(c) => c,
        Err(_) => return Ok(0),
    };

    let mut current_matrix: Option<[f64; 6]> = None;
    let mut placements: Vec<(Vec<u8>, [f64; 6])> = Vec::new();

    for Operation { operator, operands } in content.operations {
        match operator.as_str() {
            "cm" => {
                if operands.len() == 6 {
                    if let Some(m) = operands_to_matrix(&operands) {
                        current_matrix = Some(m);
                    }
                }
            }
            "Do" => {
                if operands.len() == 1 {
                    if let (Some(m), Object::Name(name)) = (current_matrix.take(), &operands[0]) {
                        placements.push((name.clone(), m));
                    }
                }
            }
            _ => {}
        }
    }

    let mut placed_count = 0usize;

    for (name, matrix) in placements {
        let xobj_ref = match xobj_dict.get(&name).ok().and_then(|o| o.as_reference().ok()) {
            Some(r) => r,
            None => continue,
        };

        let stream = match doc.get_object(xobj_ref) {
            Ok(Object::Stream(s)) => s.clone(),
            _ => continue,
        };

        let subtype = stream.dict.get(b"Subtype").ok()
            .and_then(|o| o.as_name_str().ok())
            .unwrap_or("");
        if subtype != "Image" {
            continue;
        }

        let filter_name = stream.dict.get(b"Filter").ok()
            .and_then(|o| o.as_name_str().ok())
            .unwrap_or("");

        let img_bytes = if filter_name == "DCTDecode" {
            stream.content.clone()
        } else {
            stream.decompressed_content().unwrap_or_else(|_| stream.content.clone())
        };

        let decoded = match image::load_from_memory(&img_bytes) {
            Ok(img) => img.to_rgb8(),
            Err(_) => continue,
        };

        let a = matrix[0];
        let d = matrix[3];
        let e = matrix[4];
        let f = matrix[5];

        let dest_x = (e * scale) as i64;
        let dest_y = ((page_h_pt - f - d.abs()) * scale) as i64;
        let dest_w = (a.abs() * scale) as u32;
        let dest_h = (d.abs() * scale) as u32;

        if dest_w == 0 || dest_h == 0 {
            continue;
        }

        // PERF FIX 2: Triangle is ~4x faster than Lanczos3 with negligible quality loss
        let scaled = imageops::resize(
            &decoded,
            dest_w,
            dest_h,
            imageops::FilterType::Triangle,
        );

        // PERF FIX 3: overlay does a bulk memcpy-style blit instead of per-pixel put_pixel loop
        imageops::overlay(canvas, &scaled, dest_x, dest_y);

        placed_count += 1;
    }

    Ok(placed_count)
}

fn operands_to_matrix(ops: &[Object]) -> Option<[f64; 6]> {
    let mut nums: Vec<f64> = Vec::with_capacity(6);
    for o in ops {
        let v = match o {
            Object::Integer(i) => *i as f64,
            Object::Real(r) => *r as f64,
            _ => return None,
        };
        nums.push(v);
    }
    if nums.len() != 6 {
        return None;
    }
    Some([nums[0], nums[1], nums[2], nums[3], nums[4], nums[5]])
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

fn get_xobject_dict_inherited(
    doc: &Document,
    page_id: ObjectId,
    page_dict: &lopdf::Dictionary,
) -> Option<lopdf::Dictionary> {
    if let Some(d) = get_xobject_dict(doc, page_dict) {
        return Some(d);
    }
    let mut current = Some(page_id);
    for _ in 0..8 {
        let cid = current?;
        let dict = doc.get_object(cid).ok()?.as_dict().ok()?.clone();
        if let Some(d) = get_xobject_dict(doc, &dict) {
            return Some(d);
        }
        current = dict.get(b"Parent").ok().and_then(|o| o.as_reference().ok());
    }
    None
}

// ─── Compress PDF ──────────────────────────────────────────────────────────────

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

            let decoded = match image::load_from_memory(&stream.content) {
                Ok(img) => img.to_rgb8(),
                Err(_) => continue,
            };

            let mut new_jpeg: Vec<u8> = Vec::new();
            {
                use image::codecs::jpeg::JpegEncoder;
                let mut enc = JpegEncoder::new_with_quality(&mut new_jpeg, quality);
                if enc.encode_image(&decoded).is_err() {
                    continue;
                }
            }

            if new_jpeg.len() < stream.content.len() {
                stream.content = new_jpeg;
                stream.dict.set("Filter", Object::Name(b"DCTDecode".to_vec()));
                stream.dict.set("Length", Object::Integer(stream.content.len() as i64));
            }
        }
    }

    doc.trailer.remove(b"Info");

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    save_document(&mut doc, output_path)?;
    Ok(page_count)
}

// ─── Sign PDF ──────────────────────────────────────────────────────────────────

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
        sign_with_image(&mut doc, page_id, sig_image_path, signer_name, x, y, width, height, next_base)?;
    } else {
        sign_with_text(&mut doc, page_id, signer_name, x, y, width, height, next_base)?;
    }

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    save_document(&mut doc, output_path)?;
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

    // FIX: pdf_escape signer_name to avoid PDF syntax corruption; remove unused ts
    let safe_name = pdf_escape(signer_name);
    let content = format!(
        "q\n{w:.2} 0 0 {h:.2} {x:.2} {y:.2} cm\n/SigImg Do\nQ\n\
         BT\n/F1 7 Tf\n{tx:.2} {ty:.2} Td\n0.4 0.4 0.4 rg\n(Signed by: {name}) Tj\nET\n",
        w = width, h = height, x = x, y = y,
        tx = x, ty = y - 10.0,
        name = safe_name,
    );
    let content_bytes = content.into_bytes();
    let content_id: ObjectId = (next_base + 1, 0);
    let mut cd = lopdf::Dictionary::new();
    cd.set("Length", Object::Integer(content_bytes.len() as i64));
    doc.objects.insert(content_id, Object::Stream(lopdf::Stream::new(cd, content_bytes)));

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
    let content = format!(
        "q\n0.9 0.95 1.0 rg\n{x:.2} {y:.2} {w:.2} {h:.2} re\nf\n\
         0.2 0.4 0.8 RG\n1 w\n{x:.2} {y:.2} {w:.2} {h:.2} re\nS\nQ\n\
         BT\n/F1 9 Tf\n{tx:.2} {ty:.2} Td\n0.1 0.2 0.5 rg\n(Digitally Signed) Tj\n\
         0 -13 Td\n/F1 7 Tf\n0.3 0.3 0.3 rg\n({name}) Tj\n\
         0 -11 Td\n(Date: {ts}) Tj\nET\n",
        x = x, y = y, w = width, h = height,
        tx = x + 6.0, ty = y + height - 14.0,
        name = pdf_escape(signer_name),
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
    let resources_clone = doc
        .get_object(page_id)
        .ok()
        .and_then(|o| o.as_dict().ok())
        .and_then(|d| d.get(b"Resources").ok().cloned());

    match resources_clone {
        Some(Object::Reference(res_id)) => {
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

// ─── DOCX/CSV/Excel → PDF ────────────────────────────────────────────────────

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
    let margin = 50.0_f64;
    let page_w = 595.0_f64;
    let page_h = 842.0_f64;
    let usable_w = page_w - 2.0 * margin;
    let usable_h = page_h - 2.0 * margin;
    let chars_per_line = ((usable_w / (font_size * 0.55)) as usize).max(20);
    let lines_per_page = ((usable_h / line_height) as usize).max(1);

    let mut all_lines: Vec<String> = Vec::new();
    for input_line in text_content.lines() {
        if input_line.trim().is_empty() {
            all_lines.push(String::new());
            continue;
        }
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
    save_document(&mut doc, output_path)?;
    Ok(total_pages)
}

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

#[frb]
pub fn get_pdf_page_count(path: String) -> u32 {
    Document::load(&path)
        .map(|d| d.get_pages().len() as u32)
        .unwrap_or(0)
}

#[frb]
pub fn get_file_info(path: String) -> FileInfo {
    let size_bytes = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
    let (page_count, is_encrypted) = Document::load(&path)
        .map(|d| (d.get_pages().len() as u32, d.is_encrypted()))
        .unwrap_or((0, false));
    FileInfo { path, size_bytes, page_count, is_encrypted }
}

#[frb]
pub fn get_pdf_encryption_info(path: String) -> EncryptionInfo {
    let (is_encrypted, page_count) = Document::load(&path)
        .map(|d| (d.is_encrypted(), d.get_pages().len() as u32))
        .unwrap_or((false, 0));
    EncryptionInfo { is_encrypted, page_count }
}

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

    if let Ok(page) = doc.get_object_mut(page_id) {
        if let Ok(dict) = page.as_dict_mut() {
            match dict.get(b"Resources").ok().cloned() {
                Some(Object::Dictionary(mut res_dict)) => {
                    ensure_f1_in_resources_dict(&mut res_dict, font_id);
                    dict.set("Resources", Object::Dictionary(res_dict));
                }
                Some(Object::Reference(res_ref_id)) => {
                    let _ = res_ref_id;
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

// ─── Shared office-format helpers ────────────────────────────────────────────

/// Push current page content, reset y to top.
fn office_next_page(pages: &mut Vec<String>, cur: &mut String, y: &mut f64) {
    pages.push(std::mem::take(cur));
    *y = 842.0 - 60.0;
}

/// Escape a string for use inside a PDF literal string `( ... )`.
fn pdf_escape_latin(s: &str) -> String {
    s.chars()
        .map(|c| {
            let cp = c as u32;
            if cp > 0xff { '?' } else { c }
        })
        .filter(|c| *c != '\x00')
        .map(|c| match c {
            '(' => "\\(".to_string(),
            ')' => "\\)".to_string(),
            '\\' => "\\\\".to_string(),
            other => other.to_string(),
        })
        .collect()
}

/// Build a minimal 2-font lopdf Document from a list of per-page content streams.
fn build_office_pdf(
    pages_content: Vec<String>,
    page_w: i64,
    page_h: i64,
    extra_resources: Option<lopdf::Dictionary>, // merged into every page's Resources
) -> Result<Document> {
    let mut doc = Document::with_version("1.5");
    let mut nid: u32 = 1;

    let catalog_id: ObjectId = (nid, 0); nid += 1;
    let pages_id:   ObjectId = (nid, 0); nid += 1;
    let font_id:    ObjectId = (nid, 0); nid += 1;
    let font_bold_id: ObjectId = (nid, 0); nid += 1;

    let mut fd = lopdf::Dictionary::new();
    fd.set("Type",     Object::Name(b"Font".to_vec()));
    fd.set("Subtype",  Object::Name(b"Type1".to_vec()));
    fd.set("BaseFont", Object::Name(b"Helvetica".to_vec()));
    fd.set("Encoding", Object::Name(b"WinAnsiEncoding".to_vec()));
    doc.objects.insert(font_id, Object::Dictionary(fd));

    let mut fdb = lopdf::Dictionary::new();
    fdb.set("Type",     Object::Name(b"Font".to_vec()));
    fdb.set("Subtype",  Object::Name(b"Type1".to_vec()));
    fdb.set("BaseFont", Object::Name(b"Helvetica-Bold".to_vec()));
    fdb.set("Encoding", Object::Name(b"WinAnsiEncoding".to_vec()));
    doc.objects.insert(font_bold_id, Object::Dictionary(fdb));

    let mut page_ids: Vec<Object> = Vec::new();

    for content_str in pages_content {
        let content_bytes = content_str.into_bytes();
        let content_id: ObjectId = (nid, 0); nid += 1;
        let mut cd = lopdf::Dictionary::new();
        cd.set("Length", Object::Integer(content_bytes.len() as i64));
        doc.objects.insert(content_id, Object::Stream(lopdf::Stream::new(cd, content_bytes)));

        let res_id: ObjectId = (nid, 0); nid += 1;
        let mut fonts_d = lopdf::Dictionary::new();
        fonts_d.set("F1", Object::Reference(font_id));
        fonts_d.set("F2", Object::Reference(font_bold_id));
        let mut res_d = lopdf::Dictionary::new();
        res_d.set("Font", Object::Dictionary(fonts_d));
        if let Some(ref extra) = extra_resources {
            for (k, v) in extra.iter() {
                res_d.set(k.clone(), v.clone());
            }
        }
        doc.objects.insert(res_id, Object::Dictionary(res_d));

        let page_id: ObjectId = (nid, 0); nid += 1;
        let mut pd = lopdf::Dictionary::new();
        pd.set("Type",   Object::Name(b"Page".to_vec()));
        pd.set("Parent", Object::Reference(pages_id));
        pd.set("MediaBox", Object::Array(vec![
            Object::Integer(0), Object::Integer(0),
            Object::Integer(page_w), Object::Integer(page_h),
        ]));
        pd.set("Resources", Object::Reference(res_id));
        pd.set("Contents",  Object::Reference(content_id));
        doc.objects.insert(page_id, Object::Dictionary(pd));
        page_ids.push(Object::Reference(page_id));
    }

    let count = page_ids.len() as i64;
    let mut pages_dict = lopdf::Dictionary::new();
    pages_dict.set("Type",  Object::Name(b"Pages".to_vec()));
    pages_dict.set("Kids",  Object::Array(page_ids));
    pages_dict.set("Count", Object::Integer(count));
    doc.objects.insert(pages_id, Object::Dictionary(pages_dict));

    let mut catalog = lopdf::Dictionary::new();
    catalog.set("Type",  Object::Name(b"Catalog".to_vec()));
    catalog.set("Pages", Object::Reference(pages_id));
    doc.objects.insert(catalog_id, Object::Dictionary(catalog));

    doc.trailer.set("Root", Object::Reference(catalog_id));
    doc.trailer.set("Size", Object::Integer((nid + 1) as i64));
    Ok(doc)
}

// ─── DOCX → PDF ──────────────────────────────────────────────────────────────

#[frb]
pub fn docx_to_pdf(input_path: String, output_path: String) -> PdfResult {
    let start = Instant::now();
    match docx_to_pdf_inner(&input_path, &output_path) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e)    => err(e.to_string()),
    }
}

fn docx_to_pdf_inner(input_path: &str, output_path: &str) -> Result<u32> {
    use quick_xml::events::Event;
    use quick_xml::Reader;
    use std::io::Read;

    // ── Read document.xml from the zip ───────────────────────────────────
    let file = fs::File::open(input_path)?;
    let mut archive = zip::ZipArchive::new(file)?;
    let xml = {
        let mut entry = archive
            .by_name("word/document.xml")
            .map_err(|_| anyhow!("word/document.xml not found in DOCX"))?;
        let mut s = String::new();
        entry.read_to_string(&mut s)?;
        s
    };

    // ── Parse OOXML into block list ───────────────────────────────────────
    #[derive(Clone)] struct DocRun  { text: String, bold: bool }
    #[derive(Clone)] struct DocPara { runs: Vec<DocRun>, heading: u8 }
    #[derive(Clone)] struct DocRow  { cells: Vec<String> }
    enum DocBlock { Para(DocPara), Table(Vec<DocRow>) }

    let mut blocks: Vec<DocBlock> = Vec::new();
    let (mut in_body, mut in_tbl, mut in_tr, mut in_tc) = (false, false, false, false);
    let (mut in_p, mut in_r, mut in_ppr, mut in_rpr, mut in_t) = (false,false,false,false,false);
    let (mut cur_heading, mut cur_bold) = (0u8, false);
    let mut cur_run  = String::new();
    let mut cur_runs: Vec<DocRun> = Vec::new();
    let mut cur_cell = String::new();
    let mut cur_row:   Vec<String>  = Vec::new();
    let mut cur_table: Vec<DocRow>  = Vec::new();

    let mut reader = Reader::from_str(&xml);
    let mut buf = Vec::new();

    loop {
        let event = reader.read_event_into(&mut buf).unwrap_or(Event::Eof);
        match event {
            Event::Eof => break,
            Event::Start(ref e) | Event::Empty(ref e) => {
                let loc = e.name().local_name();
                let loc = loc.as_ref();
                match loc {
                    b"body"   => in_body = true,
                    b"tbl"    if in_body && !in_tbl => { in_tbl = true; cur_table.clear(); }
                    b"tr"     if in_tbl  => { in_tr = true; cur_row.clear(); }
                    b"tc"     if in_tr   => { in_tc = true; cur_cell.clear(); }
                    b"p"      if in_body => {
                        in_p = true; cur_runs.clear(); cur_heading = 0;
                    }
                    b"pPr"    if in_p    => in_ppr = true,
                    b"pStyle" if in_ppr  => {
                        if let Some(v) = e.attributes().filter_map(|a| a.ok())
                            .find(|a| a.key.local_name().as_ref() == b"val")
                            .map(|a| String::from_utf8_lossy(&a.value).to_lowercase())
                        {
                            if v.starts_with("heading") {
                                cur_heading = v.trim_start_matches("heading")
                                    .trim().parse::<u8>().unwrap_or(1).min(6);
                            }
                        }
                    }
                    b"r"   if in_p   => { in_r = true; cur_run.clear(); cur_bold = cur_heading > 0; }
                    b"rPr" if in_r   => in_rpr = true,
                    b"b"   if in_rpr => cur_bold = true,
                    b"t"   if in_r   => in_t = true,
                    b"br"  if in_r   => cur_run.push('\n'),
                    _ => {}
                }
            }
            Event::End(ref e) => {
                let loc = e.name().local_name();
                let loc = loc.as_ref();
                match loc {
                    b"body" => in_body = false,
                    b"tbl"  => {
                        blocks.push(DocBlock::Table(std::mem::take(&mut cur_table)));
                        in_tbl = false;
                    }
                    b"tr"   => {
                        cur_table.push(DocRow { cells: std::mem::take(&mut cur_row) });
                        in_tr = false;
                    }
                    b"tc"   => {
                        cur_row.push(std::mem::take(&mut cur_cell));
                        in_tc = false;
                    }
                    b"p"    => {
                        let runs = std::mem::take(&mut cur_runs);
                        if in_tc {
                            let t: String = runs.iter().map(|r| r.text.as_str()).collect::<Vec<_>>().join(" ");
                            if !cur_cell.is_empty() { cur_cell.push(' '); }
                            cur_cell.push_str(t.trim());
                        } else if in_body {
                            blocks.push(DocBlock::Para(DocPara { runs, heading: cur_heading }));
                        }
                        in_p = false; in_ppr = false;
                    }
                    b"pPr" => in_ppr = false,
                    b"r"   => {
                        let t = std::mem::take(&mut cur_run);
                        cur_runs.push(DocRun { text: t, bold: cur_bold });
                        in_r = false; in_rpr = false;
                    }
                    b"rPr" => in_rpr = false,
                    b"t"   => in_t = false,
                    _ => {}
                }
            }
            Event::Text(ref e) => {
                if in_t && in_r {
                    cur_run.push_str(&e.unescape().unwrap_or_default());
                }
            }
            _ => {}
        }
        buf.clear();
    }

    // ── Lay out blocks onto pages ─────────────────────────────────────────
    const PW: f64 = 595.0;
    const PH: f64 = 842.0;
    const M:  f64 = 60.0;
    const UW: f64 = PW - 2.0 * M;
    const HEADING_FS: [f64; 6] = [22.0, 18.0, 15.0, 13.0, 12.0, 11.5];
    const NORMAL_FS:  f64 = 11.0;
    const CELL_FS:    f64 = 9.0;
    const CELL_PAD:   f64 = 3.5;

    let mut pages: Vec<String> = Vec::new();
    let mut cur   = String::new();
    let mut y     = PH - M;

    for block in &blocks {
        match block {
            DocBlock::Para(para) => {
                let (fs, hbold) = if para.heading > 0 {
                    (HEADING_FS[(para.heading as usize).saturating_sub(1).min(5)], true)
                } else {
                    (NORMAL_FS, false)
                };
                let lh = fs * 1.4;
                let is_bold = hbold
                    || para.runs.first().map(|r| r.bold).unwrap_or(false);
                let font = if is_bold { "F2" } else { "F1" };
                let full: String = para.runs.iter().map(|r| r.text.as_str()).collect::<Vec<_>>().join(" ");
                if full.trim().is_empty() {
                    y -= lh * 0.4;
                    continue;
                }
                let cpl = ((UW / (fs * 0.55)) as usize).max(10);
                let mut line_buf = String::new();
                for word in full.split_whitespace() {
                    if line_buf.is_empty() {
                        line_buf.push_str(word);
                    } else if line_buf.len() + 1 + word.len() <= cpl {
                        line_buf.push(' ');
                        line_buf.push_str(word);
                    } else {
                        if y - lh < M { office_next_page(&mut pages, &mut cur, &mut y); }
                        y -= lh;
                        cur.push_str(&format!("BT\n/{} {:.1} Tf\n{:.2} {:.2} Td\n({}) Tj\nET\n",
                            font, fs, M, y, pdf_escape_latin(&line_buf)));
                        line_buf.clear();
                        line_buf.push_str(word);
                    }
                }
                if !line_buf.is_empty() {
                    if y - lh < M { office_next_page(&mut pages, &mut cur, &mut y); }
                    y -= lh;
                    cur.push_str(&format!("BT\n/{} {:.1} Tf\n{:.2} {:.2} Td\n({}) Tj\nET\n",
                        font, fs, M, y, pdf_escape_latin(&line_buf)));
                }
                y -= 3.0; // paragraph spacing
            }

            DocBlock::Table(rows) => {
                if rows.is_empty() { continue; }
                let ncols = rows.iter().map(|r| r.cells.len()).max().unwrap_or(0);
                if ncols == 0 { continue; }
                let col_w = UW / ncols as f64;
                let cell_lh = CELL_FS * 1.4;
                let row_h = cell_lh + 2.0 * CELL_PAD;

                // Draw each row
                for row in rows {
                    if y - row_h < M { office_next_page(&mut pages, &mut cur, &mut y); }
                    let row_top = y;
                    // Grid rect for this row
                    cur.push_str(&format!("q\n0.5 w\n0 0 0 RG\n{:.2} {:.2} {:.2} {:.2} re S\nQ\n",
                        M, row_top - row_h, UW, row_h));
                    // Vertical dividers
                    cur.push_str("q\n0.5 w\n0 0 0 RG\n");
                    for ci in 1..ncols {
                        let cx = M + ci as f64 * col_w;
                        cur.push_str(&format!("{:.2} {:.2} m\n{:.2} {:.2} l\nS\n",
                            cx, row_top, cx, row_top - row_h));
                    }
                    cur.push_str("Q\n");
                    // Cell text
                    let text_y = row_top - CELL_PAD - cell_lh;
                    for (ci, cell) in row.cells.iter().enumerate() {
                        if ci >= ncols { break; }
                        let available_chars = ((col_w - 2.0 * CELL_PAD) / (CELL_FS * 0.55)) as usize;
                        let display = if cell.len() > available_chars && available_chars > 3 {
                            format!("{}…", &cell[..available_chars.saturating_sub(1)])
                        } else {
                            cell.clone()
                        };
                        let cx = M + ci as f64 * col_w + CELL_PAD;
                        cur.push_str(&format!("BT\n/F1 {:.1} Tf\n{:.2} {:.2} Td\n({}) Tj\nET\n",
                            CELL_FS, cx, text_y, pdf_escape_latin(&display)));
                    }
                    y -= row_h;
                }
                y -= 6.0;
            }
        }
    }

    if !cur.is_empty() { pages.push(cur); }
    if pages.is_empty() { pages.push(String::new()); }

    let count = pages.len() as u32;
    let mut doc = build_office_pdf(pages, 595, 842, None)?;
    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    save_document(&mut doc, output_path)?;
    Ok(count)
}

// ─── XLSX → PDF ──────────────────────────────────────────────────────────────

#[frb]
pub fn xlsx_to_pdf(input_path: String, output_path: String) -> PdfResult {
    let start = Instant::now();
    match xlsx_to_pdf_inner(&input_path, &output_path) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e)    => err(e.to_string()),
    }
}

fn xlsx_to_pdf_inner(input_path: &str, output_path: &str) -> Result<u32> {
    use quick_xml::events::Event;
    use quick_xml::Reader;
    use std::io::Read;

    let file = fs::File::open(input_path)?;
    let mut archive = zip::ZipArchive::new(file)?;

    // ── Shared strings ────────────────────────────────────────────────────
    let shared_strings: Vec<String> = {
        let mut ss: Vec<String> = Vec::new();
        if let Ok(mut entry) = archive.by_name("xl/sharedStrings.xml") {
            let mut xml = String::new();
            entry.read_to_string(&mut xml)?;
            let mut reader = Reader::from_str(&xml);
            let mut buf = Vec::new();
            let mut in_t = false;
            let mut cur  = String::new();
            loop {
                let ev = reader.read_event_into(&mut buf).unwrap_or(Event::Eof);
                match ev {
                    Event::Eof => break,
                    Event::Start(ref e) | Event::Empty(ref e)
                        if e.name().local_name().as_ref() == b"t" => { in_t = true; cur.clear(); }
                    Event::End(ref e)
                        if e.name().local_name().as_ref() == b"t" => {
                            ss.push(std::mem::take(&mut cur));
                            in_t = false;
                        }
                    Event::Text(ref e) if in_t => {
                        cur.push_str(&e.unescape().unwrap_or_default());
                    }
                    _ => {}
                }
                buf.clear();
            }
        }
        ss
    };

    // ── Sheet names (list sheets to find active ones) ─────────────────────
    // We'll read all sheet*.xml files found in xl/worksheets/
    let sheet_names: Vec<String> = {
        let mut names: Vec<String> = Vec::new();
        for i in 0..archive.len() {
            if let Ok(f) = archive.by_index(i) {
                let n = f.name().to_string();
                if n.starts_with("xl/worksheets/sheet") && n.ends_with(".xml") {
                    names.push(n);
                }
            }
        }
        names.sort();
        names
    };

    if sheet_names.is_empty() {
        return Err(anyhow!("No worksheets found in XLSX"));
    }

    // ── Parse all sheets into rows ────────────────────────────────────────
    // col_ref like "A1" → col index (0-based)
    fn col_index(cell_ref: &str) -> usize {
        let mut idx = 0usize;
        for c in cell_ref.chars() {
            if c.is_ascii_alphabetic() {
                idx = idx * 26 + (c.to_ascii_uppercase() as usize - 'A' as usize + 1);
            } else { break; }
        }
        idx.saturating_sub(1)
    }

    // Each sheet → rows of cells (Vec<Vec<String>>)
    let mut all_sheets: Vec<(String, Vec<Vec<String>>)> = Vec::new();

    for sheet_path in &sheet_names {
        let xml = {
            let mut entry = archive.by_name(sheet_path)?;
            let mut s = String::new();
            entry.read_to_string(&mut s)?;
            s
        };
        let sheet_label = sheet_path
            .trim_start_matches("xl/worksheets/")
            .trim_end_matches(".xml")
            .to_string();

        let mut rows: Vec<Vec<String>> = Vec::new();
        let mut cur_row_idx = 0usize;
        let mut cur_row: Vec<(usize, String)> = Vec::new(); // (col_idx, value)
        let mut in_row   = false;
        let mut in_cell  = false;
        let mut in_v     = false;
        let mut cell_type = String::new();
        let mut cell_ref  = String::new();
        let mut cell_val  = String::new();

        let mut reader = Reader::from_str(&xml);
        let mut buf = Vec::new();
        loop {
            let ev = reader.read_event_into(&mut buf).unwrap_or(Event::Eof);
            match ev {
                Event::Eof => break,
                Event::Start(ref e) | Event::Empty(ref e) => {
                    let loc = e.name().local_name();
                    let loc = loc.as_ref();
                    match loc {
                        b"row" => {
                            in_row = true;
                            cur_row.clear();
                            cur_row_idx = e.attributes().filter_map(|a| a.ok())
                                .find(|a| a.key.local_name().as_ref() == b"r")
                                .and_then(|a| String::from_utf8_lossy(&a.value).parse::<usize>().ok())
                                .unwrap_or(rows.len() + 1)
                                .saturating_sub(1);
                        }
                        b"c" if in_row => {
                            in_cell = true;
                            cell_val.clear();
                            cell_type = e.attributes().filter_map(|a| a.ok())
                                .find(|a| a.key.local_name().as_ref() == b"t")
                                .map(|a| String::from_utf8_lossy(&a.value).to_string())
                                .unwrap_or_default();
                            cell_ref = e.attributes().filter_map(|a| a.ok())
                                .find(|a| a.key.local_name().as_ref() == b"r")
                                .map(|a| String::from_utf8_lossy(&a.value).to_string())
                                .unwrap_or_default();
                        }
                        b"v" | b"t" if in_cell => { in_v = true; cell_val.clear(); }
                        _ => {}
                    }
                }
                Event::End(ref e) => {
                    let loc = e.name().local_name();
                    let loc = loc.as_ref();
                    match loc {
                        b"row" => {
                            // Expand sparse row to dense
                            let max_col = cur_row.iter().map(|(ci, _)| *ci).max().unwrap_or(0);
                            let mut dense: Vec<String> = vec![String::new(); max_col + 1];
                            for (ci, val) in std::mem::take(&mut cur_row) {
                                if ci < dense.len() { dense[ci] = val; }
                            }
                            // Ensure rows vector is large enough
                            while rows.len() <= cur_row_idx { rows.push(Vec::new()); }
                            rows[cur_row_idx] = dense;
                            in_row = false;
                        }
                        b"c" if in_cell => {
                            let value = if cell_type == "s" {
                                let idx = cell_val.trim().parse::<usize>().unwrap_or(usize::MAX);
                                if idx < shared_strings.len() { shared_strings[idx].clone() } else { String::new() }
                            } else if cell_type == "b" {
                                if cell_val.trim() == "1" { "TRUE".to_string() } else { "FALSE".to_string() }
                            } else {
                                cell_val.trim().to_string()
                            };
                            let ci = col_index(&cell_ref);
                            cur_row.push((ci, value));
                            in_cell = false;
                            in_v = false;
                        }
                        b"v" | b"t" => in_v = false,
                        _ => {}
                    }
                }
                Event::Text(ref e) if in_v => {
                    cell_val.push_str(&e.unescape().unwrap_or_default());
                }
                _ => {}
            }
            buf.clear();
        }
        // Trim trailing empty rows
        while rows.last().map(|r: &Vec<String>| r.iter().all(|c| c.is_empty())).unwrap_or(false) {
            rows.pop();
        }
        if !rows.is_empty() {
            all_sheets.push((sheet_label, rows));
        }
    }

    if all_sheets.is_empty() {
        return Err(anyhow!("XLSX had no readable data."));
    }

    // ── Render sheets to PDF pages ────────────────────────────────────────
    const PW: f64 = 842.0; // landscape A4
    const PH: f64 = 595.0;
    const M:  f64 = 40.0;
    const UW: f64 = PW - 2.0 * M;
    const HEADER_FS: f64 = 13.0;
    const CELL_FS:   f64 = 8.5;
    const CELL_PAD:  f64 = 3.0;
    const ROW_H:     f64 = CELL_FS * 1.4 + 2.0 * CELL_PAD;

    let mut pages: Vec<String> = Vec::new();
    let mut cur   = String::new();
    let mut y     = PH - M;

    for (sheet_name, rows) in &all_sheets {
        // Sheet header
        if y < PH - M + 1.0 && y < M + HEADER_FS * 2.0 + ROW_H {
            office_next_page(&mut pages, &mut cur, &mut y);
        }
        y -= HEADER_FS * 1.4;
        cur.push_str(&format!("BT\n/F2 {:.1} Tf\n{:.2} {:.2} Td\n({}) Tj\nET\n",
            HEADER_FS, M, y, pdf_escape_latin(sheet_name)));
        y -= 6.0;

        if rows.is_empty() { continue; }
        let ncols = rows.iter().map(|r| r.len()).max().unwrap_or(0);
        if ncols == 0 { continue; }

        // Auto-size columns: max content length, capped
        let mut col_max_len: Vec<usize> = vec![3; ncols];
        for row in rows {
            for (ci, cell) in row.iter().enumerate() {
                if ci < ncols {
                    col_max_len[ci] = col_max_len[ci].max(cell.len().min(30));
                }
            }
        }
        let total_chars: usize = col_max_len.iter().sum::<usize>().max(1);
        let col_widths: Vec<f64> = col_max_len.iter()
            .map(|&l| (l as f64 / total_chars as f64 * UW).max(20.0))
            .collect();
        // Normalize so sum == UW
        let w_sum: f64 = col_widths.iter().sum();
        let col_widths: Vec<f64> = col_widths.iter().map(|&w| w * UW / w_sum).collect();

        for (ri, row) in rows.iter().enumerate() {
            if y - ROW_H < M {
                office_next_page(&mut pages, &mut cur, &mut y);
            }
            let row_top = y;
            let text_y  = row_top - CELL_PAD - CELL_FS * 1.2;
            let font    = if ri == 0 { "F2" } else { "F1" };

            // Row rect
            cur.push_str(&format!("q\n0.5 w\n0 0 0 RG\n{:.2} {:.2} {:.2} {:.2} re S\nQ\n",
                M, row_top - ROW_H, UW, ROW_H));

            // Vertical dividers
            cur.push_str("q\n0.5 w\n0 0 0 RG\n");
            let mut cx = M;
            for ci in 0..ncols.saturating_sub(1) {
                cx += col_widths[ci];
                cur.push_str(&format!("{:.2} {:.2} m\n{:.2} {:.2} l\nS\n",
                    cx, row_top, cx, row_top - ROW_H));
            }
            cur.push_str("Q\n");

            // Cell text
            let mut cx = M;
            for ci in 0..ncols {
                let cell = row.get(ci).map(|s| s.as_str()).unwrap_or("");
                if !cell.is_empty() {
                    let avail = ((col_widths[ci] - 2.0 * CELL_PAD) / (CELL_FS * 0.55)) as usize;
                    let display = if cell.len() > avail && avail > 3 {
                        format!("{}…", &cell[..avail.saturating_sub(1)])
                    } else {
                        cell.to_string()
                    };
                    cur.push_str(&format!("BT\n/{} {:.1} Tf\n{:.2} {:.2} Td\n({}) Tj\nET\n",
                        font, CELL_FS, cx + CELL_PAD, text_y, pdf_escape_latin(&display)));
                }
                cx += col_widths[ci];
            }
            y -= ROW_H;
        }
        y -= 12.0; // spacing between sheets
    }

    if !cur.is_empty() { pages.push(cur); }
    if pages.is_empty() { pages.push(String::new()); }

    let count = pages.len() as u32;
    // landscape A4: pass 842×595
    let mut doc = build_office_pdf(pages, 842, 595, None)?;
    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    save_document(&mut doc, output_path)?;
    Ok(count)
}

// ─── PPTX → PDF ──────────────────────────────────────────────────────────────

#[frb]
pub fn pptx_to_pdf(input_path: String, output_path: String) -> PdfResult {
    let start = Instant::now();
    match pptx_to_pdf_inner(&input_path, &output_path) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e)    => err(e.to_string()),
    }
}

fn pptx_to_pdf_inner(input_path: &str, output_path: &str) -> Result<u32> {
    use quick_xml::events::Event;
    use quick_xml::Reader;
    use std::io::Read;
    use image::GenericImageView;

    // Landscape A4
    const PW: f64 = 842.0;
    const PH: f64 = 595.0;

    // Standard PPTX slide in EMU → points (1 pt = 12700 EMU)
    const SLIDE_W_PT: f64 = 720.0; // 9144000 / 12700
    const SLIDE_H_PT: f64 = 540.0; // 6858000 / 12700

    // Scale to fit landscape A4, keep aspect ratio
    let scale = (PW / SLIDE_W_PT).min(PH / SLIDE_H_PT);
    let rendered_w = SLIDE_W_PT * scale;
    let rendered_h = SLIDE_H_PT * scale;
    let x_off = (PW - rendered_w) / 2.0;
    let y_off  = (PH - rendered_h) / 2.0;

    let emu_to_pt = |v: i64| v as f64 / 12700.0;

    // PPTX y is from top; PDF y is from bottom
    let pptx_y_to_pdf = |pptx_y_pt: f64| -> f64 {
        y_off + rendered_h - pptx_y_pt * scale
    };
    // x stays same direction
    let pptx_x_to_pdf = |pptx_x_pt: f64| -> f64 {
        x_off + pptx_x_pt * scale
    };

    // ── Collect slide file names & rels ──────────────────────────────────
    let file = fs::File::open(input_path)?;
    let mut archive = zip::ZipArchive::new(file)?;

    let mut slide_paths: Vec<String> = (0..archive.len())
        .filter_map(|i| archive.by_index(i).ok().map(|f| f.name().to_string()))
        .filter(|n| {
            let re = regex_slide_name(n);
            re
        })
        .collect();
    slide_paths.sort_by_key(|s| slide_number_from_path(s));

    if slide_paths.is_empty() {
        return Err(anyhow!("No slides found in PPTX"));
    }

    // ── Parse each slide ─────────────────────────────────────────────────
    struct PptxShape {
        x: f64, y: f64, cx: f64, cy: f64,
        text_runs: Vec<(String, f64, bool)>, // (text, font_pt, bold)
        img_r_id: Option<String>,
    }

    struct PptxSlide {
        shapes: Vec<PptxShape>,
    }

    // Parse rels for a slide → rId → media path
    fn read_slide_rels(archive: &mut zip::ZipArchive<fs::File>, slide_path: &str)
        -> HashMap<String, String>
    {
        let mut map = HashMap::new();
        // rels file is at ppt/slides/_rels/<filename>.rels
        let parts: Vec<&str> = slide_path.rsplitn(2, '/').collect();
        if parts.len() < 2 { return map; }
        let rels_path = format!("{}/_rels/{}.rels", parts[1], parts[0]);
        if let Ok(mut entry) = archive.by_name(&rels_path) {
            let mut xml = String::new();
            if entry.read_to_string(&mut xml).is_ok() {
                let mut reader = Reader::from_str(Box::leak(xml.into_boxed_str()) as &str);
                let mut buf = Vec::new();
                loop {
                    match reader.read_event_into(&mut buf).unwrap_or(Event::Eof) {
                        Event::Eof => break,
                        Event::Start(ref e) | Event::Empty(ref e)
                            if e.name().local_name().as_ref() == b"Relationship" =>
                        {
                            let mut rid    = String::new();
                            let mut target = String::new();
                            let mut rtype  = String::new();
                            for attr in e.attributes().filter_map(|a| a.ok()) {
                                let k = attr.key.local_name();
                                match k.as_ref() {
                                    b"Id"     => rid    = String::from_utf8_lossy(&attr.value).to_string(),
                                    b"Target" => target = String::from_utf8_lossy(&attr.value).to_string(),
                                    b"Type"   => rtype  = String::from_utf8_lossy(&attr.value).to_string(),
                                    _ => {}
                                }
                            }
                            if rtype.ends_with("/image") && !rid.is_empty() {
                                // Resolve relative target
                                let resolved = if target.starts_with("../") {
                                    format!("ppt/{}", target.trim_start_matches("../"))
                                } else if target.starts_with('/') {
                                    target.trim_start_matches('/').to_string()
                                } else {
                                    format!("ppt/slides/{}", target)
                                };
                                map.insert(rid, resolved);
                            }
                        }
                        _ => {}
                    }
                    buf.clear();
                }
            }
        }
        map
    }

    let mut all_slides: Vec<(PptxSlide, HashMap<String,String>)> = Vec::new();

    for sp in &slide_paths {
        let xml = {
            let mut entry = archive.by_name(sp)?;
            let mut s = String::new();
            entry.read_to_string(&mut s)?;
            s
        };
        let rels = read_slide_rels(&mut archive, sp);

        let mut shapes: Vec<PptxShape> = Vec::new();
        let mut in_sp      = false;
        let mut in_sppr    = false;
        let mut in_xfrm    = false;
        let mut in_txbody  = false;
        let mut in_para    = false;
        let mut in_run     = false;
        let mut in_rpr     = false;
        let mut in_t       = false;
        let mut in_blipfill = false;

        let mut cur_x   = 0i64;
        let mut cur_y   = 0i64;
        let mut cur_cx  = 0i64;
        let mut cur_cy  = 0i64;
        let mut cur_fs  = 1800i64; // half-points in PPTX (1800 = 18pt)
        let mut cur_bold = false;
        let mut cur_run_text = String::new();
        let mut cur_para_runs: Vec<(String, f64, bool)> = Vec::new();
        let mut cur_shape_runs: Vec<(String, f64, bool)> = Vec::new();
        let mut cur_img_rid: Option<String> = None;

        let mut reader2 = Reader::from_str(&xml);
        let mut buf = Vec::new();

        loop {
            let ev = reader2.read_event_into(&mut buf).unwrap_or(Event::Eof);
            match ev {
                Event::Eof => break,
                Event::Start(ref e) | Event::Empty(ref e) => {
                    let loc = e.name().local_name();
                    let loc = loc.as_ref();
                    match loc {
                        b"sp" | b"pic" => {
                            in_sp = true;
                            cur_x = 0; cur_y = 0; cur_cx = 0; cur_cy = 0;
                            cur_shape_runs.clear();
                            cur_img_rid = None;
                        }
                        b"spPr" | b"nvSpPr" if in_sp => in_sppr = true,
                        b"xfrm"  if in_sp  => in_xfrm = true,
                        b"off"   if in_xfrm => {
                            cur_x = attr_i64(e, b"x");
                            cur_y = attr_i64(e, b"y");
                        }
                        b"ext"   if in_xfrm => {
                            cur_cx = attr_i64(e, b"cx");
                            cur_cy = attr_i64(e, b"cy");
                        }
                        b"txBody" if in_sp => in_txbody = true,
                        b"p"      if in_txbody => {
                            in_para = true;
                            cur_para_runs.clear();
                        }
                        b"r"   if in_para => {
                            in_run = true;
                            cur_run_text.clear();
                            cur_bold = false;
                            cur_fs = 1800;
                        }
                        b"rPr" if in_run  => {
                            in_rpr = true;
                            cur_bold = e.attributes().filter_map(|a| a.ok())
                                .find(|a| a.key.local_name().as_ref() == b"b")
                                .map(|a| a.value.as_ref() != b"0")
                                .unwrap_or(false);
                            cur_fs = attr_i64(e, b"sz").max(600); // fallback 600 = 6pt
                        }
                        b"t" if in_run  => { in_t = true; cur_run_text.clear(); }
                        b"br" if in_para => {
                            cur_para_runs.push(("\n".to_string(), cur_fs as f64 / 100.0, false));
                        }
                        b"blipFill" if in_sp => in_blipfill = true,
                        b"blip" if in_blipfill => {
                            // r:embed attribute
                            if let Some(rid) = e.attributes().filter_map(|a| a.ok())
                                .find(|a| a.key.local_name().as_ref() == b"embed")
                                .map(|a| String::from_utf8_lossy(&a.value).to_string())
                            {
                                cur_img_rid = Some(rid);
                            }
                        }
                        _ => {}
                    }
                }
                Event::End(ref e) => {
                    let loc = e.name().local_name();
                    let loc = loc.as_ref();
                    match loc {
                        b"sp" | b"pic" if in_sp => {
                            shapes.push(PptxShape {
                                x:  emu_to_pt(cur_x),
                                y:  emu_to_pt(cur_y),
                                cx: emu_to_pt(cur_cx),
                                cy: emu_to_pt(cur_cy),
                                text_runs: std::mem::take(&mut cur_shape_runs),
                                img_r_id: cur_img_rid.take(),
                            });
                            in_sp = false; in_sppr = false; in_xfrm = false;
                            in_txbody = false; in_blipfill = false;
                        }
                        b"spPr" | b"nvSpPr" => in_sppr = false,
                        b"xfrm"  => in_xfrm = false,
                        b"txBody"=> in_txbody = false,
                        b"p" if in_para => {
                            cur_shape_runs.extend(std::mem::take(&mut cur_para_runs));
                            // Paragraph break between shapes' paragraphs
                            if !cur_shape_runs.is_empty() {
                                cur_shape_runs.push(("\n".to_string(), 0.0, false));
                            }
                            in_para = false;
                        }
                        b"r" if in_run => {
                            let t = std::mem::take(&mut cur_run_text);
                            if !t.is_empty() {
                                let fpt = (cur_fs as f64 / 100.0).clamp(6.0, 48.0);
                                cur_para_runs.push((t, fpt, cur_bold));
                            }
                            in_run = false; in_rpr = false;
                        }
                        b"rPr"    => in_rpr = false,
                        b"t"      => in_t = false,
                        b"blipFill" => in_blipfill = false,
                        _ => {}
                    }
                }
                Event::Text(ref e) if in_t => {
                    cur_run_text.push_str(&e.unescape().unwrap_or_default());
                }
                _ => {}
            }
            buf.clear();
        }
        all_slides.push((PptxSlide { shapes }, rels));
    }

    // ── Render slides → PDF ───────────────────────────────────────────────
    let mut doc = Document::with_version("1.5");
    let mut nid: u32 = 1;

    let catalog_id: ObjectId = (nid, 0); nid += 1;
    let pages_id:   ObjectId = (nid, 0); nid += 1;
    let font_id:    ObjectId = (nid, 0); nid += 1;
    let font_bold_id: ObjectId = (nid, 0); nid += 1;

    {
        let mut fd = lopdf::Dictionary::new();
        fd.set("Type",     Object::Name(b"Font".to_vec()));
        fd.set("Subtype",  Object::Name(b"Type1".to_vec()));
        fd.set("BaseFont", Object::Name(b"Helvetica".to_vec()));
        fd.set("Encoding", Object::Name(b"WinAnsiEncoding".to_vec()));
        doc.objects.insert(font_id, Object::Dictionary(fd));
        let mut fdb = lopdf::Dictionary::new();
        fdb.set("Type",     Object::Name(b"Font".to_vec()));
        fdb.set("Subtype",  Object::Name(b"Type1".to_vec()));
        fdb.set("BaseFont", Object::Name(b"Helvetica-Bold".to_vec()));
        fdb.set("Encoding", Object::Name(b"WinAnsiEncoding".to_vec()));
        doc.objects.insert(font_bold_id, Object::Dictionary(fdb));
    }

    let mut page_ids: Vec<Object> = Vec::new();

    for (slide, rels) in &all_slides {
        let mut content = String::new();
        let mut xobjects_d = lopdf::Dictionary::new();

        // Slide background (light grey)
        content.push_str(&format!(
            "q\n0.97 0.97 0.97 rg\n{:.2} {:.2} {:.2} {:.2} re\nf\nQ\n",
            x_off, y_off, rendered_w, rendered_h));

        // Border
        content.push_str(&format!(
            "q\n0.7 0.7 0.7 RG\n0.5 w\n{:.2} {:.2} {:.2} {:.2} re\nS\nQ\n",
            x_off, y_off, rendered_w, rendered_h));

        // Sort shapes: images first, then text on top
        for shape in &slide.shapes {
            let pdf_x  = pptx_x_to_pdf(shape.x);
            let pdf_yt = pptx_y_to_pdf(shape.y);         // top of shape in PDF coords
            let pdf_yb = pptx_y_to_pdf(shape.y + shape.cy); // bottom
            let w_pdf  = shape.cx * scale;
            let h_pdf  = (pdf_yt - pdf_yb).abs();

            // ── Embed image if present ────────────────────────────
            if let Some(ref rid) = shape.img_r_id {
                if let Some(media_path) = rels.get(rid) {
                    if let Ok(mut entry) = archive.by_name(media_path) {
                        let mut img_bytes: Vec<u8> = Vec::new();
                        if entry.read_to_end(&mut img_bytes).is_ok() {
                            if let Ok(img) = image::load_from_memory(&img_bytes) {
                                let (iw, ih) = img.dimensions();
                                let rgb = img.to_rgb8();
                                let mut jpeg: Vec<u8> = Vec::new();
                                if image::codecs::jpeg::JpegEncoder::new_with_quality(&mut jpeg, 85)
                                    .encode_image(&rgb).is_ok()
                                {
                                    let img_id: ObjectId = (nid, 0); nid += 1;
                                    let im_name = format!("Im{}", nid);
                                    let mut imd = lopdf::Dictionary::new();
                                    imd.set("Type",             Object::Name(b"XObject".to_vec()));
                                    imd.set("Subtype",          Object::Name(b"Image".to_vec()));
                                    imd.set("Width",            Object::Integer(iw as i64));
                                    imd.set("Height",           Object::Integer(ih as i64));
                                    imd.set("ColorSpace",       Object::Name(b"DeviceRGB".to_vec()));
                                    imd.set("BitsPerComponent", Object::Integer(8));
                                    imd.set("Filter",           Object::Name(b"DCTDecode".to_vec()));
                                    imd.set("Length",           Object::Integer(jpeg.len() as i64));
                                    doc.objects.insert(img_id, Object::Stream(lopdf::Stream::new(imd, jpeg)));
                                    xobjects_d.set(im_name.as_bytes().to_vec(), Object::Reference(img_id));

                                    let bot_y = pdf_yb.min(pdf_yt);
                                    content.push_str(&format!(
                                        "q\n{:.4} 0 0 {:.4} {:.4} {:.4} cm\n/{} Do\nQ\n",
                                        w_pdf, h_pdf, pdf_x, bot_y, im_name));
                                }
                            }
                        }
                    }
                }
            }

            // ── Render text runs ──────────────────────────────────
            if !shape.text_runs.is_empty() {
                // Collect non-empty text
                let all_text: String = shape.text_runs.iter()
                    .map(|(t, _, _)| t.as_str())
                    .collect::<Vec<_>>()
                    .join("");
                if all_text.trim().is_empty() { continue; }

                // Determine dominant font size
                let dom_fs = shape.text_runs.iter()
                    .filter(|(t, fs, _)| *fs > 0.0 && !t.trim().is_empty())
                    .map(|(_, fs, _)| *fs)
                    .fold(0.0f64, f64::max)
                    .clamp(6.0, 48.0);
                let fs = if dom_fs < 1.0 { 12.0 } else { dom_fs * scale };
                let is_bold = shape.text_runs.iter().any(|(_, _, b)| *b);

                // Wrap text to fit shape width
                let char_w = fs * 0.55;
                let avail_chars = ((w_pdf / char_w) as usize).max(5);
                let font_key = if is_bold { "F2" } else { "F1" };
                let lh = fs * 1.2;

                let mut text_y = pdf_yt - fs * 0.2;
                let text_x = pdf_x + 2.0 * scale;

                let mut line_buf = String::new();
                let combined: String = shape.text_runs.iter()
                    .flat_map(|(t, _, _)| t.chars())
                    .collect();

                for word in combined.split_whitespace() {
                    if word == "\n" {
                        if !line_buf.is_empty() {
                            if text_y > y_off {
                                content.push_str(&format!(
                                    "BT\n/{} {:.2} Tf\n{:.2} {:.2} Td\n({}) Tj\nET\n",
                                    font_key, fs, text_x, text_y,
                                    pdf_escape_latin(&line_buf)));
                            }
                            line_buf.clear();
                        }
                        text_y -= lh;
                        continue;
                    }
                    if line_buf.is_empty() {
                        line_buf.push_str(word);
                    } else if line_buf.len() + 1 + word.len() <= avail_chars {
                        line_buf.push(' ');
                        line_buf.push_str(word);
                    } else {
                        if text_y > y_off {
                            content.push_str(&format!(
                                "BT\n/{} {:.2} Tf\n{:.2} {:.2} Td\n({}) Tj\nET\n",
                                font_key, fs, text_x, text_y,
                                pdf_escape_latin(&line_buf)));
                        }
                        line_buf.clear();
                        line_buf.push_str(word);
                        text_y -= lh;
                    }
                }
                if !line_buf.is_empty() && text_y > y_off {
                    content.push_str(&format!(
                        "BT\n/{} {:.2} Tf\n{:.2} {:.2} Td\n({}) Tj\nET\n",
                        font_key, fs, text_x, text_y,
                        pdf_escape_latin(&line_buf)));
                }
            }
        }

        // ── Build page ────────────────────────────────────────────────────
        let content_bytes = content.into_bytes();
        let content_id: ObjectId = (nid, 0); nid += 1;
        let mut cd = lopdf::Dictionary::new();
        cd.set("Length", Object::Integer(content_bytes.len() as i64));
        doc.objects.insert(content_id, Object::Stream(lopdf::Stream::new(cd, content_bytes)));

        let res_id: ObjectId = (nid, 0); nid += 1;
        let mut fonts_d = lopdf::Dictionary::new();
        fonts_d.set("F1", Object::Reference(font_id));
        fonts_d.set("F2", Object::Reference(font_bold_id));
        let mut res_d = lopdf::Dictionary::new();
        res_d.set("Font", Object::Dictionary(fonts_d));
        if xobjects_d.len() > 0 {
            res_d.set("XObject", Object::Dictionary(xobjects_d));
        }
        doc.objects.insert(res_id, Object::Dictionary(res_d));

        let page_id: ObjectId = (nid, 0); nid += 1;
        let mut pd = lopdf::Dictionary::new();
        pd.set("Type",   Object::Name(b"Page".to_vec()));
        pd.set("Parent", Object::Reference(pages_id));
        pd.set("MediaBox", Object::Array(vec![
            Object::Integer(0), Object::Integer(0),
            Object::Integer(842), Object::Integer(595),
        ]));
        pd.set("Resources", Object::Reference(res_id));
        pd.set("Contents",  Object::Reference(content_id));
        doc.objects.insert(page_id, Object::Dictionary(pd));
        page_ids.push(Object::Reference(page_id));
    }

    let count = page_ids.len() as u32;
    let mut pages_dict = lopdf::Dictionary::new();
    pages_dict.set("Type",  Object::Name(b"Pages".to_vec()));
    pages_dict.set("Kids",  Object::Array(page_ids));
    pages_dict.set("Count", Object::Integer(count as i64));
    doc.objects.insert(pages_id, Object::Dictionary(pages_dict));

    let mut catalog = lopdf::Dictionary::new();
    catalog.set("Type",  Object::Name(b"Catalog".to_vec()));
    catalog.set("Pages", Object::Reference(pages_id));
    doc.objects.insert(catalog_id, Object::Dictionary(catalog));
    doc.trailer.set("Root", Object::Reference(catalog_id));
    doc.trailer.set("Size", Object::Integer((nid + 1) as i64));

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    save_document(&mut doc, output_path)?;
    Ok(count)
}

fn regex_slide_name(s: &str) -> bool {
    // Matches "ppt/slides/slide<N>.xml"
    if !s.starts_with("ppt/slides/slide") { return false; }
    if !s.ends_with(".xml") { return false; }
    let mid = &s["ppt/slides/slide".len()..s.len() - 4];
    !mid.is_empty() && mid.chars().all(|c| c.is_ascii_digit())
}

fn slide_number_from_path(s: &str) -> u32 {
    let mid = s.trim_start_matches("ppt/slides/slide").trim_end_matches(".xml");
    mid.parse().unwrap_or(0)
}

/// Extract an i64 attribute value from a quick-xml BytesStart element.
fn attr_i64(e: &quick_xml::events::BytesStart<'_>, key: &[u8]) -> i64 {
    e.attributes().filter_map(|a| a.ok())
        .find(|a| a.key.local_name().as_ref() == key)
        .and_then(|a| String::from_utf8_lossy(&a.value).parse::<i64>().ok())
        .unwrap_or(0)
}
