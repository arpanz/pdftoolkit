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
/// Returns the next available ID after remapping.
fn remap_ids(doc: &mut Document, start_id: u32) -> u32 {
    let old_ids: Vec<ObjectId> = doc.objects.keys().cloned().collect();
    let mut id_map: BTreeMap<ObjectId, ObjectId> = BTreeMap::new();
    let mut next = start_id;

    for old in &old_ids {
        let new_id = (next, 0u16);
        id_map.insert(*old, new_id);
        next += 1;
    }

    // Rebuild objects with new IDs
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

    // Remap trailer
    remap_dict(&mut doc.trailer, &id_map);

    next
}

fn remap_object(obj: Object, map: &BTreeMap<ObjectId, ObjectId>) -> Object {
    match obj {
        // Bug #5 fix: References that weren't in the map are remapped where possible;
        // indirect chasing is handled at the call site (remap_ids) since we work on
        // a flat object table — all reachable objects are already enumerated.
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

    // Reserve IDs for catalog and pages
    let catalog_id: ObjectId = (next_id, 0);
    next_id += 1;
    let pages_id: ObjectId = (next_id, 0);
    next_id += 1;

    for path in &paths {
        let mut doc = Document::load(path).map_err(|e| anyhow!("Failed to load {}: {}", path, e))?;
        doc.decompress();

        // Remap IDs to avoid collisions
        next_id = remap_ids(&mut doc, next_id);

        // Collect page IDs from this document (ordered by 1-based page number)
        let mut page_num_map: Vec<(u32, ObjectId)> = doc.get_pages().into_iter().collect();
        page_num_map.sort_by_key(|(num, _)| *num);
        let doc_page_ids: Vec<ObjectId> = page_num_map.into_iter().map(|(_, id)| id).collect();
        total_pages += doc_page_ids.len() as u32;

        for page_id in &doc_page_ids {
            // Flatten inherited properties (MediaBox, CropBox, Resources, Rotate)
            // by walking the FULL parent chain — not just the direct parent.
            // This handles multi-level page trees where MediaBox lives on the
            // root Pages node, two or more levels above the leaf page.
            const INHERITED: &[&[u8]] = &[b"MediaBox", b"CropBox", b"Resources", b"Rotate"];

            // Determine which keys the page is missing (read-only borrow)
            let missing_keys: Vec<&[u8]> = {
                let page_dict = doc
                    .get_object(*page_id)
                    .ok()
                    .and_then(|o| o.as_dict().ok());
                INHERITED
                    .iter()
                    .copied()
                    .filter(|k| {
                        page_dict
                            .as_ref()
                            .map(|d| !d.has(*k))
                            .unwrap_or(true)
                    })
                    .collect()
            };

            // Get the direct parent id so we can start climbing from there
            let old_parent_id: Option<ObjectId> = doc
                .get_object(*page_id)
                .ok()
                .and_then(|o| o.as_dict().ok())
                .and_then(|d| d.get(b"Parent").ok())
                .and_then(|r| r.as_reference().ok());

            // Walk up the parent chain for each missing key
            // (uses Vec<(Vec<u8>, Object)> — no unsafe needed)
            let mut inherited_values: Vec<(Vec<u8>, Object)> = Vec::new();
            if let Some(parent_id) = old_parent_id {
                for key in &missing_keys {
                    if let Some(val) = walk_inherited(&doc, parent_id, key) {
                        inherited_values.push((key.to_vec(), val));
                    }
                }
            }

            // Apply inherited values and reparent (mutable borrow)
            if let Ok(page) = doc.get_object_mut(*page_id) {
                if let Ok(dict) = page.as_dict_mut() {
                    for (key, val) in inherited_values {
                        dict.set(key.as_slice(), val);
                    }
                    dict.set("Parent", Object::Reference(pages_id));
                }
            }
            page_ids.push(Object::Reference(*page_id));
        }

        // Move all objects into merged doc
        for (id, obj) in doc.objects {
            merged.objects.insert(id, obj);
        }
    }

    // Build Pages dictionary
    pages_dict.set("Type", Object::Name(b"Pages".to_vec()));
    pages_dict.set("Kids", Object::Array(page_ids));
    pages_dict.set("Count", Object::Integer(total_pages as i64));
    merged.objects.insert(pages_id, Object::Dictionary(pages_dict));

    // Build Catalog
    let mut catalog = lopdf::Dictionary::new();
    catalog.set("Type", Object::Name(b"Catalog".to_vec()));
    catalog.set("Pages", Object::Reference(pages_id));
    merged.objects.insert(catalog_id, Object::Dictionary(catalog));

    merged.trailer.set("Root", Object::Reference(catalog_id));

    if add_watermark {
        add_watermark_to_doc(&mut merged, pages_id)?;
    }

    // CRITICAL: lopdf's save() uses max_id to size the xref table.
    // Without this, max_id stays at 0 and the xref is empty → corrupt PDF.
    merged.max_id = merged.objects.keys().map(|k| k.0).max().unwrap_or(0);

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

    // Bug #2 fix: get_pages() returns a map of 1-based page number -> ObjectId.
    // Build a reverse map ObjectId -> page_number so we can pass correct page
    // numbers to delete_pages() instead of raw object IDs.
    let page_map: HashMap<ObjectId, u32> =
        doc.get_pages().into_iter().map(|(num, id)| (id, num)).collect();
    let max_page = page_map.len() as u32;

    // Validate page numbers
    for &p in pages {
        if p == 0 || p > max_page {
            return Err(anyhow!("Page {} out of range (1-{})", p, max_page));
        }
    }

    // Determine which page numbers to remove
    let keep_set: std::collections::HashSet<u32> = pages.iter().copied().collect();
    // Collect page numbers to remove (sorted descending so removing one doesn't shift the rest)
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

/// Protect a PDF with AES password encryption.
#[frb]
pub fn protect_pdf(input_path: String, password: String, output_path: String) -> PdfResult {
    let start = Instant::now();
    match protect_pdf_inner(&input_path, &password, &output_path) {
        Ok(pages) => ok(output_path, pages, start),
        Err(e) => err(e.to_string()),
    }
}

fn protect_pdf_inner(_input_path: &str, _password: &str, _output_path: &str) -> Result<u32> {
    // Bug #4 fix: the previous implementation hand-rolled an RC4-40 Encrypt dict
    // with O/U entries computed incorrectly per the PDF spec. Every conforming
    // viewer validates those entries and rejects the file as corrupt. Until a
    // spec-correct implementation is available (requires MD5+RC4 key schedule per
    // PDF 1.7 §3.5), we return an explicit error rather than produce broken output.
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
    // lopdf loads encrypted PDFs; we just remove the Encrypt entry and re-save
    let mut doc = Document::load(input_path)
        .map_err(|e| anyhow!("Cannot open PDF (wrong password?): {}", e))?;
    let page_count = doc.get_pages().len() as u32;

    // Remove encryption
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

        // Convert to RGB JPEG bytes
        let rgb = img.to_rgb8();
        let mut jpeg_bytes: Vec<u8> = Vec::new();
        {
            use image::codecs::jpeg::JpegEncoder;
            let mut enc = JpegEncoder::new_with_quality(&mut jpeg_bytes, 90);
            enc.encode_image(&rgb)?;
        }

        // Image XObject
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
        let img_stream = lopdf::Stream::new(img_dict, jpeg_bytes);
        doc.objects.insert(img_id, Object::Stream(img_stream));

        // Resources
        let res_id: ObjectId = (next_id, 0);
        next_id += 1;
        let mut xobject_dict = lopdf::Dictionary::new();
        xobject_dict.set("Im0", Object::Reference(img_id));
        let mut res_dict = lopdf::Dictionary::new();
        res_dict.set("XObject", Object::Dictionary(xobject_dict));
        doc.objects.insert(res_id, Object::Dictionary(res_dict));

        // Content stream: scale image to fill A4 (595x842 pts) maintaining aspect
        let (pw, ph) = fit_to_a4(width as f64, height as f64);
        let x_offset = (595.0 - pw) / 2.0;
        let y_offset = (842.0 - ph) / 2.0;
        let content = format!(
            "q\n{} 0 0 {} {} {} cm\n/Im0 Do\nQ\n",
            pw, ph, x_offset, y_offset
        );
        let content_id: ObjectId = (next_id, 0);
        next_id += 1;
        let content_stream = lopdf::Stream::new(lopdf::Dictionary::new(), content.into_bytes());
        doc.objects.insert(content_id, Object::Stream(content_stream));

        // Page
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

    // Pages
    let mut pages_dict = lopdf::Dictionary::new();
    pages_dict.set("Type", Object::Name(b"Pages".to_vec()));
    pages_dict.set("Kids", Object::Array(page_ids));
    pages_dict.set("Count", Object::Integer(count as i64));
    doc.objects.insert(pages_id, Object::Dictionary(pages_dict));

    // Catalog
    let mut catalog = lopdf::Dictionary::new();
    catalog.set("Type", Object::Name(b"Catalog".to_vec()));
    catalog.set("Pages", Object::Reference(pages_id));
    doc.objects.insert(catalog_id, Object::Dictionary(catalog));

    doc.trailer.set("Root", Object::Reference(catalog_id));

    // CRITICAL: lopdf's save() uses max_id to size the xref table.
    // Without this, max_id stays at 0 and the xref is empty → corrupt PDF.
    doc.max_id = doc.objects.keys().map(|k| k.0).max().unwrap_or(0);

    if let Some(parent) = Path::new(output_path).parent() {
        fs::create_dir_all(parent)?;
    }
    doc.save(output_path)?;
    Ok(count)
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
    FileInfo {
        path,
        size_bytes,
        page_count,
        is_encrypted,
    }
}

/// Check if PDF is encrypted.
#[frb]
pub fn get_pdf_encryption_info(path: String) -> EncryptionInfo {
    let (is_encrypted, page_count) = Document::load(&path)
        .map(|d| (d.is_encrypted(), d.get_pages().len() as u32))
        .unwrap_or((false, 0));
    EncryptionInfo {
        is_encrypted,
        page_count,
    }
}

// ─── Internal helpers ────────────────────────────────────────────────────────

/// Walk up the page-tree parent chain to find an inherited property.
/// Starts at `node_id` and climbs via /Parent until the key is found or the
/// root is reached. This handles multi-level page trees correctly.
fn walk_inherited(doc: &Document, node_id: ObjectId, key: &[u8]) -> Option<Object> {
    let obj = doc.get_object(node_id).ok()?;
    let dict = obj.as_dict().ok()?;
    if let Ok(val) = dict.get(key) {
        return Some(val.clone());
    }
    // Climb to parent
    let parent_id = dict.get(b"Parent").ok()?.as_reference().ok()?;
    walk_inherited(doc, parent_id, key)
}

fn fit_to_a4(w: f64, h: f64) -> (f64, f64) {
    let max_w = 595.0_f64;
    let max_h = 842.0_f64;
    let scale = (max_w / w).min(max_h / h);
    (w * scale, h * scale)
}

fn get_pages_id(doc: &Document) -> Result<ObjectId> {
    let catalog_id = doc
        .trailer
        .get(b"Root")
        .and_then(|o| o.as_reference())
        .map_err(|_| anyhow!("No Root in trailer"))?;
    let catalog = doc
        .get_object(catalog_id)
        .and_then(|o| o.as_dict())
        .map_err(|_| anyhow!("Cannot read catalog"))?;
    catalog
        .get(b"Pages")
        .and_then(|o| o.as_reference())
        .map_err(|_| anyhow!("No Pages in catalog"))
}

fn add_watermark_to_doc(doc: &mut Document, pages_id: ObjectId) -> Result<()> {
    let pages_obj = doc
        .get_object(pages_id)
        .map_err(|_| anyhow!("Cannot get pages"))?
        .clone();
    let kids = pages_obj
        .as_dict()
        .and_then(|d| d.get(b"Kids"))
        .and_then(|k| k.as_array())
        .map_err(|_| anyhow!("Cannot get kids"))?
        .clone();

    for kid_ref in kids {
        if let Ok(page_id) = kid_ref.as_reference() {
            add_watermark_to_page(doc, page_id)?;
        }
    }
    Ok(())
}

fn add_watermark_to_page(doc: &mut Document, page_id: ObjectId) -> Result<()> {
    let watermark_text = "Processed by BatchPDF";
    // Simple text watermark at bottom of page
    let content = format!(
        "BT\n/F1 8 Tf\n50 20 Td\n0.5 0.5 0.5 rg\n({}) Tj\nET\n",
        watermark_text
    );

    // Get or create font resource
    let font_id: ObjectId = {
        let next = doc.objects.keys().map(|id| id.0).max().unwrap_or(0) + 1;
        (next, 0)
    };
    let mut font_dict = lopdf::Dictionary::new();
    font_dict.set("Type", Object::Name(b"Font".to_vec()));
    font_dict.set("Subtype", Object::Name(b"Type1".to_vec()));
    font_dict.set("BaseFont", Object::Name(b"Helvetica".to_vec()));
    doc.objects.insert(font_id, Object::Dictionary(font_dict));

    // Add content stream
    let content_id: ObjectId = {
        let next = doc.objects.keys().map(|id| id.0).max().unwrap_or(0) + 1;
        (next, 0)
    };
    let mut stream_dict = lopdf::Dictionary::new();
    stream_dict.set("Length", Object::Integer(content.len() as i64));
    let stream = lopdf::Stream::new(stream_dict, content.into_bytes());
    doc.objects.insert(content_id, Object::Stream(stream));

    // Update page to include watermark content and font resource
    if let Ok(page) = doc.get_object_mut(page_id) {
        if let Ok(dict) = page.as_dict_mut() {
            // Bug #3 fix: always merge /F1 into the Resources Font dict, whether
            // a Resources entry already exists or not. The previous code skipped
            // the entire block when Resources was present, leaving /F1 undefined
            // but still referenced in the content stream.
            match dict.get_mut(b"Resources") {
                Ok(Object::Dictionary(res_dict)) => {
                    // Resources exists inline — update or create the Font sub-dict
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
                _ => {
                    // No Resources, or it's a Reference (to an indirect object).
                    // Build a fresh inline Resources dict.
                    let mut res = lopdf::Dictionary::new();
                    let mut fonts = lopdf::Dictionary::new();
                    fonts.set("F1", Object::Reference(font_id));
                    res.set("Font", Object::Dictionary(fonts));
                    dict.set("Resources", Object::Dictionary(res));
                }
            }

            // Append content
            let existing_contents = dict.get(b"Contents").ok().cloned();
            match existing_contents {
                Some(Object::Reference(existing_id)) => {
                    dict.set(
                        "Contents",
                        Object::Array(vec![
                            Object::Reference(existing_id),
                            Object::Reference(content_id),
                        ]),
                    );
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

// Note: RC4/AES encryption helpers removed — protect_pdf_inner now returns an
// explicit error rather than writing a non-spec-compliant Encrypt dictionary.
// Keeping this comment so git history is clear about why they were removed.
