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
import 'package:pdftoolkit/src/rust/api/pdf_ops.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  String? _selectedFile;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.first.path != null) {
      setState(() => _selectedFile = result.files.first.path);
    }
  }

  Future<void> _unlock() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file first.')),
      );
      return;
    }

    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the PDF password.')),
      );
      return;
    }

    final appProvider = context.read<AppProvider>();
    final isPro = appProvider.isPro;

    if (!isPro) {
      final size = File(_selectedFile!).lengthSync() / (1024 * 1024);
      if (size > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File is ${size.toStringAsFixed(1)}MB. Free tier supports up to 5MB.',
            ),
          ),
        );
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
          title: 'Unlocking PDF via Rust Engine...',
          subtitle: 'Removing password protection',
        ),
      );
    }

    try {
      final outputPath = await PdfBridge.generateOutputPath('unlocked');
      final result = await unlockPdf(
        inputPath: _selectedFile!,
        password: password,
        outputPath: outputPath,
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
          operation: PdfOperation.unlock,
          createdAt: DateTime.now(),
          processingMs: result.processingMs.toInt(),
        );
        await appProvider.addFile(model);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SuccessScreen(
                outputPath: result.outputPath,
                pageCount: result.pageCount,
                processingMs: result.processingMs.toInt(),
                operationLabel: 'Unlock',
                onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${result.error ?? "Wrong password or not encrypted"}',
              ),
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
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Unlock PDF'),
        backgroundColor: AppColors.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withOpacity(0.1),
                    const Color(0xFFD97706).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lock_open_rounded,
                    color: Color(0xFFF59E0B),
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remove Password Protection',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Enter the current password to unlock',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.2),

            const SizedBox(height: 24),

            // File picker
            const Text(
              'SELECT ENCRYPTED FILE',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedFile != null
                        ? AppColors.primary.withOpacity(0.5)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _selectedFile != null
                            ? AppColors.error.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _selectedFile != null
                            ? Icons.picture_as_pdf_rounded
                            : Icons.upload_file_rounded,
                        color: _selectedFile != null
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFile != null
                            ? p.basename(_selectedFile!)
                            : 'Tap to select encrypted PDF',
                        style: TextStyle(
                          color: _selectedFile != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: _selectedFile != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      _selectedFile != null
                          ? Icons.swap_horiz_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // Password field
            const Text(
              'CURRENT PASSWORD',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter current password',
                prefixIcon: const Icon(
                  Icons.key_rounded,
                  color: Color(0xFFF59E0B),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 32),

            GradientButton(
              label: 'Unlock PDF',
              icon: Icons.lock_open_rounded,
              onPressed: _isProcessing ? null : _unlock,
              isLoading: _isProcessing,
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}
