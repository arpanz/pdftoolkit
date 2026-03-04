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

// ── Tool data model ──────────────────────────────────────────────────────────
class _Tool {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Widget Function() screenBuilder;
  final bool isPro;

  const _Tool({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.screenBuilder,
    this.isPro = false,
  });
}

const List<_ToolSection> _sections = [
  _ToolSection(
    label: 'Organise',
    tools: [
      _Tool(
        icon: Icons.merge_rounded,
        title: 'Merge',
        description: 'Combine PDFs',
        color: Color(0xFF3B82F6),
        screenBuilder: MergeScreen.new,
      ),
      _Tool(
        icon: Icons.content_cut_rounded,
        title: 'Split',
        description: 'Extract pages',
        color: Color(0xFF8B5CF6),
        screenBuilder: SplitScreen.new,
      ),
    ],
  ),
  _ToolSection(
    label: 'Security',
    tools: [
      _Tool(
        icon: Icons.lock_rounded,
        title: 'Protect',
        description: 'AES encrypt',
        color: Color(0xFF10B981),
        screenBuilder: ProtectScreen.new,
      ),
      _Tool(
        icon: Icons.lock_open_rounded,
        title: 'Unlock',
        description: 'Remove password',
        color: Color(0xFFF59E0B),
        screenBuilder: UnlockScreen.new,
      ),
    ],
  ),
  _ToolSection(
    label: 'Convert',
    tools: [
      _Tool(
        icon: Icons.image_rounded,
        title: 'Images→PDF',
        description: 'Photos to PDF',
        color: Color(0xFFEF4444),
        screenBuilder: ImageToPdfScreen.new,
      ),
      _Tool(
        icon: Icons.burst_mode_rounded,
        title: 'PDF→Images',
        description: 'Pages as JPEG',
        color: Color(0xFF06B6D4),
        screenBuilder: PdfToImagesScreen.new,
      ),
      _Tool(
        icon: Icons.upload_file_rounded,
        title: 'File→PDF',
        description: 'DOCX / XLSX',
        color: Color(0xFF84CC16),
        screenBuilder: ConvertScreen.new,
        isPro: true,
      ),
    ],
  ),
  _ToolSection(
    label: 'Enhance',
    tools: [
      _Tool(
        icon: Icons.compress_rounded,
        title: 'Compress',
        description: 'Shrink size',
        color: Color(0xFFF97316),
        screenBuilder: CompressScreen.new,
      ),
      _Tool(
        icon: Icons.draw_rounded,
        title: 'Sign',
        description: 'Add signature',
        color: Color(0xFFEC4899),
        screenBuilder: SignScreen.new,
      ),
    ],
  ),
];

class _ToolSection {
  final String label;
  final List<_Tool> tools;
  const _ToolSection({required this.label, required this.tools});
}

// ── Screen ───────────────────────────────────────────────────────────────────
class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isPro = provider.isPro;
    final isDark = provider.isDarkMode;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final textPri = isDark
        ? AppColors.textPrimaryFor(context)
        : AppColors.textPrimaryLight;
    final textSec = isDark
        ? AppColors.textSecondaryFor(context)
        : AppColors.textSecondaryLight;
    final textMut = isDark
        ? AppColors.textMutedFor(context)
        : AppColors.textMutedLight;
    final cardCol = isDark ? AppColors.cardFor(context) : AppColors.bgCardLight;
    final borderCol = isDark
        ? AppColors.borderFor(context)
        : AppColors.borderLightMode;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App icon badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.primaryGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BatchPDF',
                                style: TextStyle(
                                  color: textPri,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  height: 1,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Offline · Private · Powered by Rust 🦀',
                                style: TextStyle(
                                  color: textMut,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Theme toggle
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
                              isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              color: textSec,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Pro banner (contextual, not header badge) ────
                    if (!isPro) ...[
                      SizedBox(height: 20),
                      _ProBanner(onTap: () => _showProPaywall(context)),
                    ],

                    if (isPro) ...[
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.success,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Pro Active — unlimited & no watermarks',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms),
            ),

            // ── Section divider ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Divider(color: borderCol, thickness: 1, height: 1),
              ),
            ),

            // ── Tools grid by section ─────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final section = _sections[index];
                  return _SectionBlock(
                    section: section,
                    isDark: isDark,
                    isPro: isPro,
                    onProToolTap: () => _showProPaywall(context),
                    onToolTap: (tool) => _push(context, tool.screenBuilder()),
                  ).animate().fadeIn(
                    delay: Duration(milliseconds: 80 * index),
                    duration: 300.ms,
                  );
                }, childCount: _sections.length),
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
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ProPaywallSheet(),
    );
  }
}

// ── Pro banner strip ─────────────────────────────────────────────────────────
class _ProBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ProBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF59E0B).withValues(alpha: 0.12),
              const Color(0xFFF97316).withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFF59E0B),
              size: 18,
            ),
            SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Unlock Pro — \$3.50 one-time, no subscription',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFF59E0B),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section block with 2-col grid ─────────────────────────────────────────────
class _SectionBlock extends StatelessWidget {
  final _ToolSection section;
  final bool isDark;
  final bool isPro;
  final VoidCallback onProToolTap;
  final void Function(_Tool tool) onToolTap;

  const _SectionBlock({
    required this.section,
    required this.isDark,
    required this.isPro,
    required this.onProToolTap,
    required this.onToolTap,
  });

  @override
  Widget build(BuildContext context) {
    final textMut = isDark
        ? AppColors.textMutedFor(context)
        : AppColors.textMutedLight;
    final tools = section.tools;

    // Build rows of 2
    final rows = <Widget>[];
    for (int i = 0; i < tools.length; i += 2) {
      final first = tools[i];
      final second = i + 1 < tools.length ? tools[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(
              child: _ToolCard(
                tool: first,
                isDark: isDark,
                isLocked: first.isPro && !isPro,
                onTap: (first.isPro && !isPro)
                    ? onProToolTap
                    : () => onToolTap(first),
              ),
            ),
            SizedBox(width: 12),
            if (second != null)
              Expanded(
                child: _ToolCard(
                  tool: second,
                  isDark: isDark,
                  isLocked: second.isPro && !isPro,
                  onTap: (second.isPro && !isPro)
                      ? onProToolTap
                      : () => onToolTap(second),
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < tools.length) rows.add(SizedBox(height: 12));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Text(
            section.label.toUpperCase(),
            style: TextStyle(
              color: textMut,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(height: 14),
          ...rows,
        ],
      ),
    );
  }
}

// ── Tool card ─────────────────────────────────────────────────────────────────
class _ToolCard extends StatefulWidget {
  final _Tool tool;
  final bool isDark;
  final bool isLocked;
  final VoidCallback onTap;

  const _ToolCard({
    required this.tool,
    required this.isDark,
    required this.isLocked,
    required this.onTap,
  });

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cardCol = widget.isDark
        ? AppColors.cardFor(context)
        : AppColors.bgCardLight;
    final borderCol = widget.isDark
        ? AppColors.borderFor(context)
        : AppColors.borderLightMode;
    final textPri = widget.isDark
        ? AppColors.textPrimaryFor(context)
        : AppColors.textPrimaryLight;
    final textSec = widget.isDark
        ? AppColors.textSecondaryFor(context)
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.tool.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.tool.icon,
                      color: widget.isLocked
                          ? widget.tool.color.withValues(alpha: 0.4)
                          : widget.tool.color,
                      size: 20,
                    ),
                  ),
                  if (widget.isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'PRO',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 14),
              Text(
                widget.tool.title,
                style: TextStyle(
                  color: widget.isLocked ? textSec : textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                widget.tool.description,
                style: TextStyle(
                  color: textSec,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pro paywall sheet (shared) ────────────────────────────────────────────────
class ProPaywallSheet extends StatelessWidget {
  const ProPaywallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardFor(context) : AppColors.bgCardLight;
    final border = isDark
        ? AppColors.borderFor(context)
        : AppColors.borderLightMode;
    final textPri = isDark
        ? AppColors.textPrimaryFor(context)
        : AppColors.textPrimaryLight;
    final textSec = isDark
        ? AppColors.textSecondaryFor(context)
        : AppColors.textSecondaryLight;

    // Locale-aware price string
    final locale =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final priceLabel = (locale == 'IN') ? '₹295 one-time' : '\$3.50 one-time';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 28),

          // Icon + headline
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFF59E0B),
                  size: 26,
                ),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BatchPDF Pro',
                    style: TextStyle(
                      color: textPri,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    'One-time · No subscription · No hidden fees',
                    style: TextStyle(color: textSec, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 28),

          _ProFeatureRow(
            icon: Icons.all_inclusive_rounded,
            color: AppColors.primary,
            title: 'Unlimited file sizes',
            subtitle: 'Free tier capped at 20 MB per file',
            isDark: isDark,
          ),
          SizedBox(height: 16),
          _ProFeatureRow(
            icon: Icons.layers_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Unlimited batch merging',
            subtitle: 'Free tier limited to 3 files per merge',
            isDark: isDark,
          ),
          SizedBox(height: 16),
          _ProFeatureRow(
            icon: Icons.water_drop_outlined,
            color: const Color(0xFF06B6D4),
            title: 'No watermarks on output',
            subtitle: 'Clean, professional PDFs every time',
            isDark: isDark,
          ),
          SizedBox(height: 16),
          _ProFeatureRow(
            icon: Icons.upload_file_rounded,
            color: const Color(0xFF84CC16),
            title: 'File → PDF conversion',
            subtitle: 'DOCX, XLSX, CSV support unlocked',
            isDark: isDark,
          ),

          SizedBox(height: 32),

          // CTA button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              context.read<AppProvider>().unlockPro();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🎉 Pro unlocked! Enjoy unlimited tools.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Get Pro — $priceLabel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe later',
                style: TextStyle(color: textSec, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isDark;
  const _ProFeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryFor(context)
                      : AppColors.textPrimaryLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryFor(context)
                      : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
