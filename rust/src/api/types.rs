use flutter_rust_bridge::frb;

#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone)]
pub struct PdfResult {
    pub success: bool,
    pub output_path: String,
    pub error: Option<String>,
    pub page_count: u32,
    pub processing_ms: u64,
}

#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone)]
pub struct FileInfo {
    pub path: String,
    pub size_bytes: u64,
    pub page_count: u32,
    pub is_encrypted: bool,
}

#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone)]
pub struct EncryptionInfo {
    pub is_encrypted: bool,
    pub page_count: u32,
}
