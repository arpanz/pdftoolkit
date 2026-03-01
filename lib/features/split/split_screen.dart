import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_provider.dart';
import '../../core/models/pdf_file_model.dart';
import '../../core/ffi/pdf_bridge.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/processing_dialog.dart';
import '../../shared/widgets/success_screen.dart';
import '../../rust/frb_generated.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _selectedFile;
  int _totalPages = 0;
  final TextEditingController _rangeController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.first.path != null) {
      final path = result.files.first.path!;
      setState(() {
        _selectedFile = path;
        _totalPages = 0;
      });
      // Get page count
      final count = await PdfBridge.getPageCount(path);
      if (mounted) setState(() => _totalPages = count);
    }
  }

  List<int>? _parsePageRange(String input) {
    final pages = <int>{};
    final parts = input.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final range = trimmed.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0].trim());
          final end = int.tryParse(range[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              pages.add(i);
            }
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        final page = int.tryParse(trimmed);
        if (page != null) {
          pages.add(page);
        } else {
          return null;
        }
      }
    }
    return pages.toList()..sort();
  }

  Future<void> _split() async {
    if (_selectedFile == null) return;

    final rangeText = _rangeController.text.trim();
    if (rangeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a page range (e.g., 1-5, 9)')),
      );
      return;
    }

    final pages = _parsePageRange(rangeText);
    if (pages == null || pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid page range format. Use: 1-5, 9')),
      );
      return;
    }

    if (_totalPages > 0) {
      for (final page in pages) {
        if (page < 1 || page > _totalPages) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Page $page is out of range (1-$_totalPages)')),
          );
          return;
        }
      }
    }

    final appProvider = context.read<AppProvider>();
    final isPro = appProvider.isPro;

    if (!isPro) {
      final size = File(_selectedFile!).lengthSync() / (1024 * 1024);
      if (size > 5) {
        _showUpgradeDialog('File is ${size.toStringAsFixed(1)}MB. Free tier supports up to 5MB.');
        return;
      }
    }

    setState(() => _isProcessing = true);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.7),
        builder: (_) => const ProcessingDialog(
          title: 'Splitting PDF via Rust Engine...',
          subtitle: 'Extracting your pages at native speed',
        ),
      );
    }

    try {
      final outputPath = await PdfBridge.generateOutputPath('split');
      final result = await splitPdf(
        inputPath: _selectedFile!,
        pages: pages,
        outputPath: outputPath,
        addWatermark: !isPro,
      );

      if (mounted) Navigator.of(context).pop();

      if (result.success) {
        final fileSize = File(result.outputPath).lengthSync();
        final model = PdfFileModel(
          id: const Uuid().v4(),
          path: result.outputPath,
          name: p.basename(result.outputPath),
          sizeBytes: fileSize,
          pageCount: result.pageCount,
          operation: PdfOperation.split,
          createdAt: DateTime.now(),
          processingMs: result.processingMs,
        );
        await appProvider.addFile(model);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SuccessScreen(
                outputPath: result.outputPath,
                pageCount: result.pageCount,
                processingMs: result.processingMs,
                operationLabel: 'Split',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showUpgradeDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Upgrade to Pro', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppProvider>().unlockPro();
            },
            child: const Text('Upgrade — \$3.50'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Split PDF'),
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
            // File picker card
            _FilePicker(
              selectedFile: _selectedFile,
              totalPages: _totalPages,
              onPick: _pickFile,
            ).animate().fadeIn().slideY(begin: 0.2),

            const SizedBox(height: 24),

            // Page range input
            if (_selectedFile != null) ...[
              const Text(
                'PAGE RANGE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rangeController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g., 1-5, 9, 12-15',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.content_cut_rounded, color: AppColors.primary),
                  helperText: _totalPages > 0
                      ? 'This PDF has $_totalPages pages'
                      : null,
                  helperStyle: const TextStyle(color: AppColors.textMuted),
                ),
                keyboardType: TextInputType.text,
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 12),

              // Quick range chips
              if (_totalPages > 0)
                Wrap(
                  spacing: 8,
                  children: [
                    _RangeChip(
                      label: 'First half',
                      onTap: () => _rangeController.text = '1-${(_totalPages / 2).floor()}',
                    ),
                    _RangeChip(
                      label: 'Second half',
                      onTap: () => _rangeController.text =
                          '${(_totalPages / 2).floor() + 1}-$_totalPages',
                    ),
                    _RangeChip(
                      label: 'All pages',
                      onTap: () => _rangeController.text = '1-$_totalPages',
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms),
            ],

            const Spacer(),

            if (_selectedFile != null)
              GradientButton(
                label: 'Split PDF',
                icon: Icons.content_cut_rounded,
                onPressed: _isProcessing ? null : _split,
                isLoading: _isProcessing,
              ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FilePicker extends StatelessWidget {
  final String? selectedFile;
  final int totalPages;
  final VoidCallback onPick;

  const _FilePicker({
    required this.selectedFile,
    required this.totalPages,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedFile != null ? AppColors.primary.withOpacity(0.5) : AppColors.border,
          ),
        ),
        child: selectedFile == null
            ? Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.upload_file_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select PDF File',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Tap to browse your files',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.basename(selectedFile!),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          totalPages > 0 ? '$totalPages pages' : 'Loading...',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                ],
              ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RangeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
