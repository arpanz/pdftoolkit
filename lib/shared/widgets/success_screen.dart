import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import 'gradient_button.dart';

class SuccessScreen extends StatelessWidget {
  final String outputPath;
  final int pageCount;
  final int processingMs;
  final String operationLabel;
  final VoidCallback onDone;

  const SuccessScreen({
    super.key,
    required this.outputPath,
    required this.pageCount,
    required this.processingMs,
    required this.operationLabel,
    required this.onDone,
  });

  String get _processingTime {
    if (processingMs < 1000) return '${processingMs}ms';
    return '${(processingMs / 1000).toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryFor(context);
    final textSecondary = AppColors.textSecondaryFor(context);
    final card = AppColors.cardFor(context);
    final border = AppColors.borderFor(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.15),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 52,
                    ),
                  )
                  .animate()
                  .scale(
                    begin: const Offset(0, 0),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(),
              SizedBox(height: 28),
              Text(
                '$operationLabel Complete!',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
              SizedBox(height: 12),
              Text(
                p.basename(outputPath),
                style: TextStyle(color: textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(delay: 300.ms),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatChip(
                    icon: Icons.description_outlined,
                    label: '$pageCount pages',
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.bolt_rounded,
                    label: _processingTime,
                    color: AppColors.accent,
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
              SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Text(
                  'Processed by Rust Engine in $_processingTime',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => OpenFilex.open(outputPath),
                      icon: Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text('Open PDF'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: 'Share',
                      icon: Icons.share_rounded,
                      onPressed: () => Share.shareXFiles([XFile(outputPath)]),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),
              SizedBox(height: 12),
              TextButton(
                onPressed: onDone,
                child: Text(
                  'Back to Workspace',
                  style: TextStyle(color: textSecondary),
                ),
              ).animate().fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
