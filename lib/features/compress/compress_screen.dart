import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_provider.dart';
import '../../core/models/pdf_file_model.dart';
import '../../core/ffi/pdf_bridge.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/processing_dialog.dart';
import '../../shared/widgets/success_screen.dart';
import 'package:pdftoolkit/src/rust/api/pdf_ops.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  String? _selectedPath;
  int _quality = 70;
  bool _isProcessing = false;

  String get _qualityLabel {
    if (_quality >= 85) return 'Low Compression';
    if (_quality >= 65) return 'Balanced';
    if (_quality >= 45) return 'High Compression';
    return 'Maximum Compression';
  }

  Color get _qualityColor {
    if (_quality >= 85) return const Color(0xFF10B981);
    if (_quality >= 65) return const Color(0xFF3B82F6);
    if (_quality >= 45) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedPath = result.files.single.path);
    }
  }

  Future<void> _compress() async {
    if (_selectedPath == null) return;
    setState(() => _isProcessing = true);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (_) => const ProcessingDialog(
          title: 'Compressing PDF...',
          subtitle: 'Re-encoding images at target quality',
        ),
      );
    }

    try {
      final outputPath = await PdfBridge.generateOutputPath('compressed');
      final result = await compressPdf(
        inputPath: _selectedPath!,
        outputPath: outputPath,
        quality: _quality,
      );

      if (mounted) Navigator.of(context).pop();

      if (result.success) {
        final originalSize = File(_selectedPath!).lengthSync();
        final newSize = File(result.outputPath).lengthSync();
        final savings = ((1 - newSize / originalSize) * 100).clamp(0.0, 100.0);

        final model = PdfFileModel(
          id: const Uuid().v4(),
          path: result.outputPath,
          name: p.basename(result.outputPath),
          sizeBytes: newSize,
          pageCount: result.pageCount,
          operation: PdfOperation.compress,
          createdAt: DateTime.now(),
          processingMs: result.processingMs,
        );
        await context.read<AppProvider>().addFile(model);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SuccessScreen(
                outputPath: result.outputPath,
                pageCount: result.pageCount,
                processingMs: result.processingMs,
                operationLabel:
                    'Compress (${savings.toStringAsFixed(0)}% saved)',
                onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
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
        title: Text('Compress PDF'),
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
            // File picker
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
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.compress_rounded,
                              color: Color(0xFF3B82F6),
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
                            'Images inside the PDF will be re-encoded',
                            style: TextStyle(
                              color: AppColors.textMutedFor(context),
                              fontSize: 12,
                            ),
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

            SizedBox(height: 28),

            // Quality slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'IMAGE QUALITY',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _qualityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _qualityLabel,
                    style: TextStyle(
                      color: _qualityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _qualityColor,
                thumbColor: _qualityColor,
                inactiveTrackColor: AppColors.borderFor(context),
                overlayColor: _qualityColor.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _quality.toDouble(),
                min: 20,
                max: 95,
                divisions: 15,
                label: '$_quality%',
                onChanged: (v) => setState(() => _quality = v.round()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Max Compress',
                  style: TextStyle(
                    color: AppColors.textMutedFor(context),
                    fontSize: 10,
                  ),
                ),
                Text(
                  'Quality: $_quality%',
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 11,
                  ),
                ),
                Text(
                  'Best Quality',
                  style: TextStyle(
                    color: AppColors.textMutedFor(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF3B82F6),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Compression works on JPEG/PNG images embedded in the PDF. Text-only PDFs may not reduce in size.',
                      style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms),

            const Spacer(),

            GradientButton(
              label: 'Compress PDF',
              icon: Icons.compress_rounded,
              onPressed: (_selectedPath == null || _isProcessing)
                  ? null
                  : _compress,
              isLoading: _isProcessing,
            ).animate().fadeIn(delay: 200.ms),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
