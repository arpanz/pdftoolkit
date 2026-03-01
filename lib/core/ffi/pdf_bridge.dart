import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../rust/frb_generated.dart';
import '../models/pdf_file_model.dart';

/// Dart wrapper around the Rust PDF engine.
/// All heavy lifting is delegated to Rust via flutter_rust_bridge.
class PdfBridge {
  static const double _freeLimitMb = 5.0;
  static const int _freeMergeLimit = 3;

  /// Initialize the Rust library.
  static Future<void> init() async {
    await RustLib.init();
  }

  /// Returns the output directory for generated PDFs.
  static Future<String> get outputDir async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory(p.join(dir.path, 'BatchPDF'));
    if (!out.existsSync()) out.createSync(recursive: true);
    return out.path;
  }

  /// Generate a unique output filename.
  static Future<String> generateOutputPath(String prefix) async {
    final dir = await outputDir;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir, '${prefix}_$ts.pdf');
  }

  // ─── Validation ────────────────────────────────────────────────────────────

  static String? validateFileSizeForFree(List<String> paths) {
    for (final path in paths) {
      final size = File(path).lengthSync() / (1024 * 1024);
      if (size > _freeLimitMb) {
        return 'File "${p.basename(path)}" is ${size.toStringAsFixed(1)}MB. '
            'Free tier supports up to ${_freeLimitMb.toStringAsFixed(0)}MB. '
            'Upgrade to Pro for unlimited file sizes.';
      }
    }
    return null;
  }

  static String? validateMergeCountForFree(int count) {
    if (count > _freeMergeLimit) {
      return 'Free tier supports merging up to $_freeMergeLimit files. '
          'You selected $count files. Upgrade to Pro for unlimited merging.';
    }
    return null;
  }

  // ─── Operations ────────────────────────────────────────────────────────────

  /// Merge PDFs. Returns a [ProcessingResult].
  static Future<ProcessingResult> mergePdfsOp({
    required List<String> paths,
    required bool isPro,
  }) async {
    try {
      // Free tier checks
      if (!isPro) {
        final sizeError = validateFileSizeForFree(paths);
        if (sizeError != null) return ProcessingResult(success: false, error: sizeError);

        final countError = validateMergeCountForFree(paths.length);
        if (countError != null) return ProcessingResult(success: false, error: countError);
      }

      final outputPath = await generateOutputPath('merged');
      final result = await mergePdfs(
        paths: paths,
        outputPath: outputPath,
      );

      if (!result.success) {
        return ProcessingResult(success: false, error: result.error);
      }

      return ProcessingResult(
        success: true,
        outputPath: result.outputPath,
        pageCount: result.pageCount,
        processingMs: 0,
      );
    } catch (e) {
      return ProcessingResult(success: false, error: e.toString());
    }
  }

  /// Get page count of a PDF.
  static Future<int> getPageCount(String path) async {
    try {
      return await getPdfPageCount(path: path);
    } catch (_) {
      return 0;
    }
  }

  /// Check if PDF is encrypted.
  static Future<bool> isEncrypted(String path) async {
    try {
      final info = await getPdfEncryptionInfo(path: path);
      return info.isEncrypted;
    } catch (_) {
      return false;
    }
  }
}
