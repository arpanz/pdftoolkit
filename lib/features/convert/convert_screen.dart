import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:archive/archive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_provider.dart';
import '../../core/models/pdf_file_model.dart';
import '../../core/ffi/pdf_bridge.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/processing_dialog.dart';
import '../../shared/widgets/success_screen.dart';
import 'package:pdftoolkit/src/rust/api/pdf_ops.dart';

// ─── Format config ────────────────────────────────────────────────────────────

enum ConvertFormat { txt, csv, docx, xlsx, pptx }

extension ConvertFormatX on ConvertFormat {
  String get label {
    switch (this) {
      case ConvertFormat.txt:  return 'Plain Text';
      case ConvertFormat.csv:  return 'CSV Spreadsheet';
      case ConvertFormat.docx: return 'Word Document';
      case ConvertFormat.xlsx: return 'Excel Spreadsheet';
      case ConvertFormat.pptx: return 'PowerPoint';
    }
  }

  String get ext {
    switch (this) {
      case ConvertFormat.txt:  return 'txt';
      case ConvertFormat.csv:  return 'csv';
      case ConvertFormat.docx: return 'docx';
      case ConvertFormat.xlsx: return 'xlsx';
      case ConvertFormat.pptx: return 'pptx';
    }
  }

  List<String> get allowedExtensions {
    switch (this) {
      case ConvertFormat.txt:  return ['txt'];
      case ConvertFormat.csv:  return ['csv'];
      case ConvertFormat.docx: return ['docx', 'doc'];
      case ConvertFormat.xlsx: return ['xlsx', 'xls'];
      case ConvertFormat.pptx: return ['pptx', 'ppt'];
    }
  }

  Color get color {
    switch (this) {
      case ConvertFormat.txt:  return const Color(0xFF3B82F6);
      case ConvertFormat.csv:  return const Color(0xFF10B981);
      case ConvertFormat.docx: return const Color(0xFF8B5CF6);
      case ConvertFormat.xlsx: return const Color(0xFFF59E0B);
      case ConvertFormat.pptx: return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case ConvertFormat.txt:  return Icons.text_snippet_rounded;
      case ConvertFormat.csv:  return Icons.table_chart_rounded;
      case ConvertFormat.docx: return Icons.description_rounded;
      case ConvertFormat.xlsx: return Icons.grid_on_rounded;
      case ConvertFormat.pptx: return Icons.slideshow_rounded;
    }
  }

  String get hint {
    switch (this) {
      case ConvertFormat.txt:  return 'Plain text converted with wrapping & pagination';
      case ConvertFormat.csv:  return 'Rows formatted as a table in the PDF';
      case ConvertFormat.docx: return 'Text is extracted; complex layouts are simplified';
      case ConvertFormat.xlsx: return 'Cell data extracted; export CSV for full fidelity';
      case ConvertFormat.pptx: return 'Each slide becomes one PDF page';
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ConvertScreen extends StatefulWidget {
  final ConvertFormat format;
  const ConvertScreen({super.key, required this.format});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  String? _selectedPath;
  bool _isProcessing = false;
  double _fontSize = 11.0;

  ConvertFormat get _fmt => widget.format;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _fmt.allowedExtensions,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedPath = result.files.single.path);
    }
  }

  // ── Text extraction ──────────────────────────────────────────────────────

  Future<String> _extractText(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();

    if (ext == '.txt') return File(filePath).readAsString();

    if (ext == '.csv') {
      final raw = await File(filePath).readAsString();
      // Format CSV as aligned columns separated by  |  for text_to_pdf
      final lines = raw.split('\n');
      return lines
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.split(',').map((c) => c.trim()).join('  |  '))
          .join('\n');
    }

    if (ext == '.xls' || ext == '.ppt') {
      return '${ext.toUpperCase().replaceFirst(".", "")} format is not supported. '
          'Please save as ${ext == ".xls" ? "XLSX" : "PPTX"} or export to PDF directly.';
    }

    final bytes = await File(filePath).readAsBytes();

    String readZip(List<int> zipBytes, String entryPath) {
      final archive = ZipDecoder().decodeBytes(zipBytes, verify: false);
      final file = archive.files.firstWhere(
        (f) => f.name == entryPath,
        orElse: () => ArchiveFile.noCompress('', 0, []),
      );
      if (file.name.isEmpty) return '';
      final data = file.content;
      return data is List<int> ? utf8.decode(data, allowMalformed: true) : data.toString();
    }

    String xmlEntities(String s) => s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    if (ext == '.docx') {
      try {
        var xml = readZip(bytes, 'word/document.xml');
        if (xml.isEmpty) return 'Could not read DOCX (document.xml missing).';
        xml = xml
            .replaceAll(RegExp(r'<w:br\s*/?>'), '\n')
            .replaceAll(RegExp(r'<w:tab\s*/?>'), '\t')
            .replaceAll(RegExp(r'</w:p>'), '\n');
        final matches = RegExp(r'<w:t[^>]*>([^<]*)</w:t>').allMatches(xml);
        final text = matches.map((m) => xmlEntities(m.group(1) ?? '')).join(' ');
        final cleaned = text.replaceAll(RegExp(r' {2,}'), ' ').trim();
        return cleaned.isEmpty ? 'DOCX had no readable text.' : cleaned;
      } catch (e) {
        return 'Could not extract text from DOCX: $e';
      }
    }

    if (ext == '.xlsx') {
      try {
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);

        // Read shared strings
        final ssFile = archive.files.firstWhere(
          (f) => f.name == 'xl/sharedStrings.xml',
          orElse: () => ArchiveFile.noCompress('', 0, []),
        );
        List<String> sharedStrings = [];
        if (ssFile.name.isNotEmpty) {
          final ssXml = utf8.decode(ssFile.content as List<int>, allowMalformed: true);
          sharedStrings = RegExp(r'<t[^>]*>([^<]*)</t>')
              .allMatches(ssXml)
              .map((m) => xmlEntities(m.group(1) ?? ''))
              .toList();
        }

        // Read first sheet
        final sheetFile = archive.files.firstWhere(
          (f) => f.name == 'xl/worksheets/sheet1.xml',
          orElse: () => ArchiveFile.noCompress('', 0, []),
        );
        if (sheetFile.name.isEmpty) return 'Could not read XLSX (sheet1.xml missing).';
        final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);

        final rowRegex = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true);
        final cellRegex = RegExp(r'<c[^>]*t="s"[^>]*><v>(\d+)</v></c>|<c[^>]*><v>([^<]*)</v></c>', dotAll: true);

        final lines = <String>[];
        for (final rowMatch in rowRegex.allMatches(sheetXml)) {
          final rowContent = rowMatch.group(1) ?? '';
          final cells = <String>[];
          for (final cellMatch in cellRegex.allMatches(rowContent)) {
            if (cellMatch.group(1) != null) {
              // shared string index
              final idx = int.tryParse(cellMatch.group(1)!) ?? -1;
              cells.add(idx >= 0 && idx < sharedStrings.length ? sharedStrings[idx] : '');
            } else {
              cells.add(cellMatch.group(2) ?? '');
            }
          }
          if (cells.any((c) => c.isNotEmpty)) {
            lines.add(cells.join('  |  '));
          }
        }
        return lines.isEmpty ? 'XLSX had no readable data.' : lines.join('\n');
      } catch (e) {
        return 'Could not extract data from XLSX: $e';
      }
    }

    if (ext == '.pptx') {
      try {
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        final slideFiles = archive.files
            .where((f) => RegExp(r'ppt/slides/slide\d+\.xml').hasMatch(f.name))
            .toList()
          ..sort((a, b) {
            final ai = int.tryParse(RegExp(r'slide(\d+)\.xml').firstMatch(a.name)?.group(1) ?? '0') ?? 0;
            final bi = int.tryParse(RegExp(r'slide(\d+)\.xml').firstMatch(b.name)?.group(1) ?? '0') ?? 0;
            return ai.compareTo(bi);
          });

        if (slideFiles.isEmpty) return 'No slides found in PPTX.';

        final slideTexts = <String>[];
        for (int i = 0; i < slideFiles.length; i++) {
          final xml = utf8.decode(slideFiles[i].content as List<int>, allowMalformed: true);
          final matches = RegExp(r'<a:t>([^<]*)</a:t>').allMatches(xml);
          final texts = matches
              .map((m) => xmlEntities(m.group(1) ?? '').trim())
              .where((t) => t.isNotEmpty)
              .toList();
          if (texts.isNotEmpty) {
            slideTexts.add('--- Slide ${i + 1} ---\n${texts.join(' ')}')
          } else {
            slideTexts.add('--- Slide ${i + 1} ---\n[No text content]');
          }
        }
        return slideTexts.join('\n\n');
      } catch (e) {
        return 'Could not extract text from PPTX: $e';
      }
    }

    return File(filePath).readAsString();
  }

  // ── Convert action ───────────────────────────────────────────────────────

  Future<void> _convert() async {
    if (_selectedPath == null) return;
    setState(() => _isProcessing = true);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (_) => ProcessingDialog(
          title: 'Converting ${_fmt.label}...',
          subtitle: _fmt == ConvertFormat.pptx
              ? 'Extracting slide content'
              : 'Rendering as paginated PDF',
        ),
      );
    }

    try {
      final textContent = await _extractText(_selectedPath!);
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
                operationLabel: '${_fmt.label} → PDF',
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = _fmt.color;

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      appBar: AppBar(
        title: Text('${_fmt.label} → PDF'),
        backgroundColor: AppColors.backgroundFor(context),
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
            // Format badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_fmt.icon, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _fmt.ext.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 20),

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
                        ? color.withValues(alpha: 0.5)
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
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_fmt.icon, color: color, size: 32),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to select a ${_fmt.ext.toUpperCase()} file',
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fmt.allowedExtensions.map((e) => e.toUpperCase()).join(', '),
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
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(_fmt.icon, color: color, size: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
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
                                  _fmt.label,
                                  style: TextStyle(
                                    color: AppColors.textMutedFor(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.check_circle_rounded, color: AppColors.success),
                        ],
                      ),
              ),
            ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.2),

            const SizedBox(height: 24),

            // Font size (not relevant for PPTX but still useful)
            if (_fmt != ConvertFormat.pptx) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FONT SIZE',
                    style: TextStyle(
                      color: AppColors.textSecondaryFor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${_fontSize.toStringAsFixed(0)}pt',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  thumbColor: color,
                  inactiveTrackColor: AppColors.borderFor(context),
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
            ],

            // Hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fmt.hint,
                      style: TextStyle(color: color, fontSize: 11),
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
