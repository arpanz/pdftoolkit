import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_provider.dart';
import '../merge/merge_screen.dart';
import '../split/split_screen.dart';
import '../protect/protect_screen.dart';
import '../protect/unlock_screen.dart';
import '../protect/image_to_pdf_screen.dart';
import '../pdf_to_images/pdf_to_images_screen.dart';
import '../compress/compress_screen.dart';
import '../sign/sign_screen.dart';
import '../convert/convert_screen.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isPro = provider.isPro;
    final isDark = provider.isDarkMode;
    final bg  = isDark ? AppColors.bgDark  : AppColors.bgLight;
    final textPri  = isDark ? AppColors.textPrimary   : AppColors.textPrimaryLight;
    final textSec  = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final textMut  = isDark ? AppColors.textMuted     : AppColors.textMutedLight;
    final cardCol  = isDark ? AppColors.bgCard        : AppColors.bgCardLight;
    final borderCol= isDark ? AppColors.border        : AppColors.borderLightMode;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BatchPDF',
                            style: TextStyle(
                              color: textPri,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'PDF tools, offline & fast.',
                            style: TextStyle(
                              color: textMut,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // dark/light toggle
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.read<AppProvider>().toggleDarkMode();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cardCol,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderCol),
                        ),
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: textSec,
                          size: 18,
                        ),
                      ),
                    ),

                    if (!isPro) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _showProPaywall(context),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.35),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded,
                                  color: Color(0xFFF59E0B), size: 15),
                              SizedBox(width: 5),
                              Text(
                                'PRO',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            // ── Divider ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Divider(color: borderCol, thickness: 1, height: 1),
              ),
            ),

            // ── Tools list ──────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  _SectionLabel(label: 'Organise', isDark: isDark),
                  _ToolRow(
                    icon: Icons.merge_rounded,
                    title: 'Merge PDFs',
                    description: 'Combine multiple files into one',
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                    onTap: () => _push(context, const MergeScreen()),
                  ),
                  _ToolRow(
                    icon: Icons.content_cut_rounded,
                    title: 'Split PDF',
                    description: 'Extract specific page ranges',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    onTap: () => _push(context, const SplitScreen()),
                  ),

                  _SectionLabel(label: 'Security', isDark: isDark),
                  _ToolRow(
                    icon: Icons.lock_rounded,
                    title: 'Protect',
                    description: 'Encrypt with AES password',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    onTap: () => _push(context, const ProtectScreen()),
                  ),
                  _ToolRow(
                    icon: Icons.lock_open_rounded,
                    title: 'Unlock',
                    description: 'Remove existing password',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () => _push(context, const UnlockScreen()),
                  ),

                  _SectionLabel(label: 'Convert', isDark: isDark),
                  _ToolRow(
                    icon: Icons.image_rounded,
                    title: 'Images → PDF',
                    description: 'Turn gallery photos into a PDF',
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                    onTap: () => _push(context, const ImageToPdfScreen()),
                  ),
                  _ToolRow(
                    icon: Icons.burst_mode_rounded,
                    title: 'PDF → Images',
                    description: 'Export every page as JPEG',
                    color: const Color(0xFF06B6D4),
                    isDark: isDark,
                    onTap: () => _push(context, const PdfToImagesScreen()),
                  ),
                  _ToolRow(
                    icon: Icons.upload_file_rounded,
                    title: 'File → PDF',
                    description: 'DOCX, CSV, XLSX to PDF',
                    color: const Color(0xFF84CC16),
                    isDark: isDark,
                    onTap: () => _push(context, const ConvertScreen()),
                  ),

                  _SectionLabel(label: 'Enhance', isDark: isDark),
                  _ToolRow(
                    icon: Icons.compress_rounded,
                    title: 'Compress',
                    description: 'Shrink file size without loss',
                    color: const Color(0xFFF97316),
                    isDark: isDark,
                    onTap: () => _push(context, const CompressScreen()),
                  ),
                  _ToolRow(
                    icon: Icons.draw_rounded,
                    title: 'Sign PDF',
                    description: 'Add your visible signature',
                    color: const Color(0xFFEC4899),
                    isDark: isDark,
                    onTap: () => _push(context, const SignScreen()),
                  ),

                  const SizedBox(height: 16),

                  // ── Rust badge ─────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🦀', style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            'Powered by Rust — processes locally',
                            style: TextStyle(
                              color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showProPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ProPaywallSheet(),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

// ── Tool row ───────────────────────────────────────────────────────────────
class _ToolRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ToolRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends State<_ToolRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textPri = widget.isDark ? AppColors.textPrimary   : AppColors.textPrimaryLight;
    final textSec = widget.isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              // icon dot
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: TextStyle(
                        color: textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.isDark ? AppColors.textMuted : AppColors.textMutedLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pro paywall ────────────────────────────────────────────────────────────
class _ProPaywallSheet extends StatelessWidget {
  const _ProPaywallSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.bgCard      : AppColors.bgCardLight;
    final border = isDark ? AppColors.border      : AppColors.borderLightMode;
    final textPri= isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final textSec= isDark ? AppColors.textSecondary: AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Unlock Pro', style: TextStyle(color: textPri, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 6),
          Text('One-time · No subscription · No hidden fees.', style: TextStyle(color: textSec, fontSize: 14)),
          const SizedBox(height: 28),
          _PayFeature(text: 'Unlimited file sizes', isDark: isDark),
          _PayFeature(text: 'Unlimited batch merging', isDark: isDark),
          _PayFeature(text: 'No watermarks on output', isDark: isDark),
          _PayFeature(text: 'Remove all ads', isDark: isDark),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () {
              context.read<AppProvider>().unlockPro();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🎉 Pro unlocked!')),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'Get Pro  —  \$3.50 / ₹295',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Maybe later', style: TextStyle(color: textSec, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayFeature extends StatelessWidget {
  final String text;
  final bool isDark;
  const _PayFeature({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
