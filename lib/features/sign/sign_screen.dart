import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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

class SignScreen extends StatefulWidget {
  const SignScreen({super.key});

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  String? _pdfPath;
  String? _sigImagePath;
  final _nameController = TextEditingController();
  int _pageNumber = 1;
  int _totalPages = 0;
  bool _isProcessing = false;

  // Signature placement (points from bottom-left, A4 595x842)
  double _sigX = 50;
  double _sigY = 50;
  double _sigW = 180;
  double _sigH = 60;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final pageCount = await getPdfPageCount(path: path);
      setState(() {
        _pdfPath = path;
        _totalPages = pageCount;
        _pageNumber = 1;
      });
    }
  }

  Future<void> _pickSignatureImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _sigImagePath = image.path);
    }
  }

  Future<void> _sign() async {
    if (_pdfPath == null) return;
    final signerName = _nameController.text.trim();

    setState(() => _isProcessing = true);
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (_) => const ProcessingDialog(
          title: 'Signing PDF...',
          subtitle: 'Placing signature via Rust engine',
        ),
      );
    }

    try {
      final outputPath = await PdfBridge.generateOutputPath('signed');
      final result = await signPdf(
        inputPath: _pdfPath!,
        outputPath: outputPath,
        sigImagePath: _sigImagePath ?? '',
        signerName: signerName.isEmpty ? 'Signed' : signerName,
        pageNumber: _pageNumber,
        x: _sigX,
        y: _sigY,
        width: _sigW,
        height: _sigH,
      );

      if (mounted) Navigator.of(context).pop();

      if (result.success) {
        final model = PdfFileModel(
          id: const Uuid().v4(),
          path: result.outputPath,
          name: p.basename(result.outputPath),
          sizeBytes: File(result.outputPath).lengthSync(),
          pageCount: result.pageCount,
          operation: PdfOperation.sign,
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
                operationLabel: 'Sign',
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
        title: Text('Sign PDF'),
        backgroundColor: AppColors.backgroundFor(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PDF picker
            _SectionLabel(text: 'DOCUMENT'),
            SizedBox(height: 8),
            GestureDetector(
              onTap: _pickPdf,
              child: _FileCard(
                path: _pdfPath,
                emptyIcon: Icons.picture_as_pdf_rounded,
                emptyLabel: 'Select PDF to sign',
              ),
            ).animate().fadeIn().slideY(begin: 0.2),

            SizedBox(height: 24),

            // Signature source
            _SectionLabel(text: 'SIGNATURE'),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickSignatureImage,
                    child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.cardFor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _sigImagePath != null
                              ? AppColors.success.withValues(alpha: 0.5)
                              : AppColors.borderFor(context),
                        ),
                      ),
                      child: _sigImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(_sigImagePath!),
                                fit: BoxFit.contain,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Upload Signature Image',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryFor(context),
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Column(
                  children: [
                    Text(
                      'OR',
                      style: TextStyle(
                        color: AppColors.textMutedFor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 90,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cardFor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            _sigImagePath == null &&
                                _nameController.text.isNotEmpty
                            ? AppColors.success.withValues(alpha: 0.5)
                            : AppColors.borderFor(context),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Text Signature',
                          style: TextStyle(
                            color: AppColors.textMutedFor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          style: TextStyle(
                            color: AppColors.textPrimaryFor(context),
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Your name',
                            hintStyle: TextStyle(
                              color: AppColors.textMutedFor(context),
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms),

            SizedBox(height: 24),

            // Page number
            if (_totalPages > 0) ...[
              _SectionLabel(text: 'PAGE NUMBER'),
              SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _pageNumber > 1
                        ? () => setState(() => _pageNumber--)
                        : null,
                    icon: Icon(Icons.remove_circle_outline_rounded),
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardFor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderFor(context)),
                      ),
                      child: Text(
                        'Page $_pageNumber of $_totalPages',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _pageNumber < _totalPages
                        ? () => setState(() => _pageNumber++)
                        : null,
                    icon: Icon(Icons.add_circle_outline_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ).animate().fadeIn(delay: 150.ms),
              SizedBox(height: 24),
            ],

            // Position controls
            _SectionLabel(text: 'PLACEMENT (POINTS FROM BOTTOM-LEFT)'),
            SizedBox(height: 10),
            Row(
              children: [
                _NumberField(
                  label: 'X',
                  value: _sigX,
                  onChanged: (v) => setState(() => _sigX = v),
                ),
                SizedBox(width: 8),
                _NumberField(
                  label: 'Y',
                  value: _sigY,
                  onChanged: (v) => setState(() => _sigY = v),
                ),
                SizedBox(width: 8),
                _NumberField(
                  label: 'W',
                  value: _sigW,
                  onChanged: (v) => setState(() => _sigW = v),
                ),
                SizedBox(width: 8),
                _NumberField(
                  label: 'H',
                  value: _sigH,
                  onChanged: (v) => setState(() => _sigH = v),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),

            SizedBox(height: 32),

            GradientButton(
              label: 'Sign PDF',
              icon: Icons.draw_rounded,
              onPressed: (_pdfPath == null || _isProcessing) ? null : _sign,
              isLoading: _isProcessing,
            ).animate().fadeIn(delay: 250.ms),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondaryFor(context),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final String? path;
  final IconData emptyIcon;
  final String emptyLabel;

  const _FileCard({
    required this.path,
    required this.emptyIcon,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: path != null
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.borderFor(context),
        ),
      ),
      child: path == null
          ? Row(
              children: [
                Icon(
                  emptyIcon,
                  color: AppColors.textMutedFor(context),
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  emptyLabel,
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 13,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.error,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.basename(path!),
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${(File(path!).lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
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
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMutedFor(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          TextFormField(
            initialValue: value.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              filled: true,
              fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderFor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderFor(context)),
              ),
            ),
            onChanged: (v) {
              final d = double.tryParse(v);
              if (d != null) onChanged(d);
            },
          ),
        ],
      ),
    );
  }
}
