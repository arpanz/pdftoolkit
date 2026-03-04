import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_provider.dart';
import '../../core/models/pdf_file_model.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final files = provider.files;
    final isDark = provider.isDarkMode;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final textPri = isDark
        ? AppColors.textPrimaryFor(context)
        : AppColors.textPrimaryLight;
    final textMut = isDark
        ? AppColors.textMutedFor(context)
        : AppColors.textMutedLight;
    final borderCol = isDark
        ? AppColors.borderFor(context)
        : AppColors.borderLightMode;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Files',
                          style: TextStyle(
                            color: textPri,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          files.isEmpty
                              ? 'No processed files yet'
                              : '${files.length} file${files.length == 1 ? '' : 's'} · swipe left to delete',
                          style: TextStyle(
                            color: textMut,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (files.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.read<AppProvider>().refresh();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardFor(context)
                              : AppColors.bgCardLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderCol),
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: textMut,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),

            // ── Divider ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Divider(color: borderCol, height: 1),
            ),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: files.isEmpty
                  ? _EmptyState(isDark: isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: files.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _FileCard(
                          file: files[index],
                          isDark: isDark,
                          onDelete: () =>
                              _confirmDelete(context, files[index], isDark),
                          onOpen: () => OpenFilex.open(files[index].path),
                        ).animate().fadeIn(
                          delay: Duration(milliseconds: 30 * index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PdfFileModel file, bool isDark) {
    final textPri = isDark
        ? AppColors.textPrimaryFor(context)
        : AppColors.textPrimaryLight;
    final textSec = isDark
        ? AppColors.textSecondaryFor(context)
        : AppColors.textSecondaryLight;
    final bg = isDark ? AppColors.cardFor(context) : AppColors.bgCardLight;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete file?',
          style: TextStyle(
            color: textPri,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '"${file.name}" will be permanently removed.',
          style: TextStyle(color: textSec, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppColors.textMutedFor(context)
                    : AppColors.textMutedLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppProvider>().deleteFile(file.id);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPri = isDark
        ? AppColors.textPrimaryFor(context)
        : AppColors.textPrimaryLight;
    final textSec = isDark
        ? AppColors.textSecondaryFor(context)
        : AppColors.textSecondaryLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                Icons.folder_open_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            SizedBox(height: 24),
            Text(
              'Nothing here yet',
              style: TextStyle(
                color: textPri,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(delay: 150.ms),
            SizedBox(height: 10),
            Text(
              'Files you process with any tool will\nappear here automatically.',
              style: TextStyle(color: textSec, fontSize: 14, height: 1.65),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Go to Tools to get started',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 250.ms),
          ],
        ),
      ),
    );
  }
}

// ── File card ──────────────────────────────────────────────────────────────────
class _FileCard extends StatelessWidget {
  final PdfFileModel file;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _FileCard({
    required this.file,
    required this.isDark,
    required this.onDelete,
    required this.onOpen,
  });

  Color get _opColor {
    switch (file.operation) {
      case PdfOperation.merge:
        return const Color(0xFF3B82F6);
      case PdfOperation.split:
        return const Color(0xFF8B5CF6);
      case PdfOperation.protect:
        return const Color(0xFF10B981);
      case PdfOperation.unlock:
        return const Color(0xFFF59E0B);
      case PdfOperation.imageToPdf:
        return const Color(0xFFEF4444);
      case PdfOperation.compress:
        return const Color(0xFFF97316);
      case PdfOperation.sign:
        return const Color(0xFFEC4899);
      case PdfOperation.convert:
        return const Color(0xFF84CC16);
      case PdfOperation.pdfToImages:
        return const Color(0xFF06B6D4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardCol = isDark ? AppColors.cardFor(context) : AppColors.bgCardLight;
    final borderCol = isDark
        ? AppColors.borderFor(context)
        : AppColors.borderLightMode;
    final textPri = isDark
        ? AppColors.textPrimaryFor(context)
        : AppColors.textPrimaryLight;
    final textMut = isDark
        ? AppColors.textMutedFor(context)
        : AppColors.textMutedLight;
    final dateStr = DateFormat('MMM d  ·  h:mm a').format(file.createdAt);

    return Dismissible(
      key: ValueKey(file.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => context.read<AppProvider>().deleteFile(file.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 22,
            ),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _opColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: _opColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(
                        color: textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _opColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${file.operation.icon} ${file.operation.label}',
                            style: TextStyle(
                              color: _opColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${file.formattedSize}  ·  ${file.pageCount}p',
                          style: TextStyle(color: textMut, fontSize: 11),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(color: textMut, fontSize: 11),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8),
              // Open icon
              Icon(Icons.open_in_new_rounded, color: textMut, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
