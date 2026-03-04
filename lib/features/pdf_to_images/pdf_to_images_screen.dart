import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/processing_dialog.dart';
import 'package:pdftoolkit/src/rust/api/pdf_ops.dart';

class PdfToImagesScreen extends StatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> {
  String? _selectedPath;
  int _dpi = 150;
  bool _isProcessing = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedPath = result.files.single.path);
    }
  }

  Future<void> _convert() async {
    if (_selectedPath == null) return;
    setState(() => _isProcessing = true);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (_) => const ProcessingDialog(
          title: 'Converting Pages to Images...',
          subtitle: 'Extracting each page via Rust engine',
        ),
      );
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final outDir = p.join(
        dir.path,
        'BatchPDF',
        'images_${DateTime.now().millisecondsSinceEpoch}',
      );

      final result = await pdfToImages(
        inputPath: _selectedPath!,
        outputDir: outDir,
        dpi: _dpi,
      );

      if (mounted) Navigator.of(context).pop();

      if (result.success) {
        final imagePaths = result.outputPath
            .split('|')
            .where((s) => s.isNotEmpty)
            .toList();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ImageResultScreen(
                imagePaths: imagePaths,
                processingMs: result.processingMs,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result.error ?? "Unknown error"}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: Text('PDF → Images'),
        backgroundColor: AppColors.backgroundFor(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File picker card
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardFor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedPath != null
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.borderFor(context),
                  ),
                ),
                child: _selectedPath == null
                    ? Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tap to select a PDF',
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Each page will be exported as a JPEG image',
                            style: TextStyle(
                              color: AppColors.textMutedFor(context),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: AppColors.error,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.basename(_selectedPath!),
                                  style: TextStyle(
                                    color: AppColors.textPrimaryFor(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(File(_selectedPath!).lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                        ],
                      ),
              ),
            ).animate().fadeIn().slideY(begin: 0.2),

            SizedBox(height: 24),

            // DPI selector
            Text(
              'OUTPUT QUALITY',
              style: TextStyle(
                color: AppColors.textSecondaryFor(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                _DpiChip(
                  label: '72 DPI',
                  sublabel: 'Screen',
                  value: 72,
                  selected: _dpi == 72,
                  onTap: () => setState(() => _dpi = 72),
                ),
                SizedBox(width: 8),
                _DpiChip(
                  label: '150 DPI',
                  sublabel: 'Balanced',
                  value: 150,
                  selected: _dpi == 150,
                  onTap: () => setState(() => _dpi = 150),
                ),
                SizedBox(width: 8),
                _DpiChip(
                  label: '300 DPI',
                  sublabel: 'Print',
                  value: 300,
                  selected: _dpi == 300,
                  onTap: () => setState(() => _dpi = 300),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms),

            // Note about rendering
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Raster images embedded in the PDF are extracted. Text/vector content renders as white background.',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms),

            const Spacer(),

            GradientButton(
              label: 'Convert to Images',
              icon: Icons.image_rounded,
              onPressed: (_selectedPath == null || _isProcessing)
                  ? null
                  : _convert,
              isLoading: _isProcessing,
            ).animate().fadeIn(delay: 200.ms),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DpiChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _DpiChip({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.cardFor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.borderFor(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textPrimaryFor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: AppColors.textMutedFor(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageResultScreen extends StatelessWidget {
  final List<String> imagePaths;
  final int processingMs;

  const _ImageResultScreen({
    required this.imagePaths,
    required this.processingMs,
  });

  Future<void> _saveAsZip(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final zipPath = p.join(
        dir.path,
        'BatchPDF',
        'pages_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      for (final imgPath in imagePaths) {
        encoder.addFile(File(imgPath));
      }
      encoder.close();
      await Share.shareXFiles([XFile(zipPath)], text: 'PDF pages as ZIP');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _shareAll(BuildContext context) async {
    final xFiles = imagePaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(xFiles, text: 'PDF pages as images');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: Text('${imagePaths.length} Pages Exported'),
        backgroundColor: AppColors.backgroundFor(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _saveAsZip(context),
            icon: Icon(Icons.archive_rounded, size: 16),
            label: Text('Save ZIP'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.cardFor(context),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.photo_library_rounded,
                  label: '${imagePaths.length} images',
                ),
                SizedBox(width: 12),
                _StatChip(
                  icon: Icons.timer_rounded,
                  label: processingMs < 1000
                      ? '${processingMs}ms'
                      : '${(processingMs / 1000).toStringAsFixed(1)}s',
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _shareAll(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.share_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Share All',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Grid of images
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemCount: imagePaths.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () async {
                    await Share.shareXFiles([
                      XFile(imagePaths[index]),
                    ], text: 'Page ${index + 1}');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardFor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderFor(context)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(imagePaths[index]),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(
                                'Page ${index + 1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(
                  delay: Duration(milliseconds: 40 * index),
                  duration: 300.ms,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 14),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondaryFor(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
