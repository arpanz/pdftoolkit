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

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  String? _selectedPath;
  bool _isProcessing = false;
  double _fontSize = 11.0;

  String? get _fileType {
    if (_selectedPath == null) return null;
    return p.extension(_selectedPath!).toLowerCase();
  }

  String get _fileTypeLabel {
    switch (_fileType) {
      case '.docx':
        return 'Word Document';
      case '.csv':
        return 'CSV Spreadsheet';
      case '.xlsx':
      case '.xls':
        return 'Excel Spreadsheet';
      case '.txt':
        return 'Plain Text';
      default:
        return 'Text File';
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv', 'docx', 'xlsx', 'xls'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedPath = result.files.single.path);
    }
  }

  Future<String> _extractTextContent(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.txt' || ext == '.csv') {
      // Plain text / CSV: read directly
      return await File(filePath).readAsString();
    } else if (ext == '.docx') {
      // DOCX: extract raw text from XML inside the zip
      // docx files are ZIP archives containing word/document.xml
      try {
        final bytes = await File(filePath).readAsBytes();
        // Simple extraction: find text between <w:t> tags
        final content = String.fromCharCodes(bytes);
        final regex = RegExp(r'<w:t[^>]*>([^<]*)<\/w:t>');
        final matches = regex.allMatches(content);
        return matches.map((m) => m.group(1) ?? '').join(' ');
      } catch (_) {
        return 'Could not extract text from DOCX. Convert to .txt first for best results.';
      }
    } else if (ext == '.xlsx' || ext == '.xls') {
      // XLSX: extract shared strings from XML
      try {
        final bytes = await File(filePath).readAsBytes();
        final content = String.fromCharCodes(bytes);
        final regex = RegExp(r'<si><t>([^<]*)<\/t><\/si>');
        final matches = regex.allMatches(content);
        return matches.map((m) => m.group(1) ?? '').join('\t');
      } catch (_) {
        return 'Could not extract text from XLSX. Convert to CSV first for best results.';
      }
    }
    return await File(filePath).readAsString();
  }

  Future<void> _convert() async {
    if (_selectedPath == null) return;
    setState(() => _isProcessing = true);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.7),
        builder: (_) => ProcessingDialog(
          title: 'Converting $_fileTypeLabel...',
          subtitle: 'Rendering text as paginated PDF',
        ),
      );
    }

    try {
      final textContent = await _extractTextContent(_selectedPath!);
      final outputPath = await PdfBridge.generateOutputPath('converted');
      final title = p.basenameWithoutExtension(_selectedPath!);

      final result = await textToPdf(
        textContent: textContent,
        outputPath: outputPath,
        title: title,
        fontSize: _fontSize,
      );

      if (mounted) Navigator.of(context).pop();

      if (result.success) {
        final model = PdfFileModel(
          id: const Uuid().v4(),
          path: result.outputPath,
          name: p.basename(result.outputPath),
          sizeBytes: File(result.outputPath).lengthSync(),
          pageCount: result.pageCount,
          operation: PdfOperation.convert,
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
                operationLabel: 'Convert ($_fileTypeLabel)',
                onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${result.error ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Convert to PDF'),
        backgroundColor: AppColors.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Supported formats chips
            Wrap(
              spacing: 8,
              children: [
                _FormatChip(label: 'TXT', color: const Color(0xFF3B82F6)),
                _FormatChip(label: 'CSV', color: const Color(0xFF10B981)),
                _FormatChip(label: 'DOCX', color: const Color(0xFF8B5CF6)),
                _FormatChip(label: 'XLSX', color: const Color(0xFFF59E0B)),
              ],
            ).animate().fadeIn(),
            const SizedBox(height: 20),

            // File picker
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedPath != null
                        ? AppColors.primary.withOpacity(0.5)
                        : AppColors.border,
                  ),
                ),
                child: _selectedPath == null
                    ? Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.upload_file_rounded,
                                color: Color(0xFF8B5CF6), size: 32),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap to select a file',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'TXT, CSV, DOCX, or XLSX',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                (_fileType ?? '.txt').toUpperCase().replaceFirst('.', ''),
                                style: const TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.basename(_selectedPath!),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _fileTypeLabel,
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success),
                        ],
                      ),
              ),
            ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.2),

            const SizedBox(height: 24),

            // Font size
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FONT SIZE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${_fontSize.toStringAsFixed(0)}pt',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: AppColors.border,
                trackHeight: 4,
              ),
              child: Slider(
                value: _fontSize,
                min: 8,
                max: 16,
                divisions: 8,
                label: '${_fontSize.toStringAsFixed(0)}pt',
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF8B5CF6), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DOCX/XLSX: plain text is extracted. For layout-accurate conversion, export to PDF via Word/Excel first.',
                      style:
                          TextStyle(color: Color(0xFF8B5CF6), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms),

            const Spacer(),

            GradientButton(
              label: 'Convert to PDF',
              icon: Icons.picture_as_pdf_rounded,
              onPressed: (_selectedPath == null || _isProcessing) ? null : _convert,
              isLoading: _isProcessing,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _FormatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
