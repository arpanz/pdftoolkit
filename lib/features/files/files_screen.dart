import 'package:flutter/material.dart';
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
    final files = context.watch<AppProvider>().files;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Local Files'),
        backgroundColor: AppColors.bgDark,
        actions: [
          if (files.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => context.read<AppProvider>().refresh(),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: files.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: files.length,
              itemBuilder: (context, index) {
                return _FileCard(
                      file: files[index],
                      onDelete: () => _confirmDelete(context, files[index]),
                      onOpen: () => OpenFilex.open(files[index].path),
                    )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 30 * index))
                    .slideX(begin: 0.1);
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, PdfFileModel file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete File?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently delete "${file.name}" from your device.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppProvider>().deleteFile(file.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: AppColors.primary,
              size: 48,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          const Text(
            'No Files Yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 8),
          const Text(
            'Files you process will appear here.\nGo to Workspace to get started.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final PdfFileModel file;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _FileCard({
    required this.file,
    required this.onDelete,
    required this.onOpen,
  });

  Color get _operationColor {
    switch (file.operation) {
      case PdfOperation.merge:
        return AppColors.primary;
      case PdfOperation.split:
        return const Color(0xFF8B5CF6);
      case PdfOperation.protect:
        return const Color(0xFF10B981);
      case PdfOperation.unlock:
        return const Color(0xFFF59E0B);
      case PdfOperation.imageToPdf:
        return const Color(0xFFEF4444);
      case PdfOperation.compress:
        // TODO: Handle this case.
        throw UnimplementedError();
      case PdfOperation.sign:
        // TODO: Handle this case.
        throw UnimplementedError();
      case PdfOperation.convert:
        // TODO: Handle this case.
        throw UnimplementedError();
      case PdfOperation.pdfToImages:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(file.createdAt);

    return Dismissible(
      key: ValueKey(file.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => context.read<AppProvider>().deleteFile(file.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_rounded, color: AppColors.error),
            const SizedBox(height: 4),
            const Text(
              'Delete',
              style: TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // PDF icon with operation color
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _operationColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: _operationColor,
                      size: 26,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // File details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Operation badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _operationColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${file.operation.icon} ${file.operation.label}',
                            style: TextStyle(
                              color: _operationColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          file.formattedSize,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${file.pageCount}p',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    color: AppColors.primary,
                    onPressed: onOpen,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: AppColors.textMuted,
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
