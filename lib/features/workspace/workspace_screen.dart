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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            snap: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                AppColors.bgDark,
                                AppColors.bgCard.withOpacity(0.5),
                                AppColors.bgDark,
                              ]
                            : [
                                AppColors.bgLight,
                                AppColors.bgCardLight.withOpacity(0.5),
                                AppColors.bgLight,
                              ],
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -60,
                    left: -60,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'BatchPDF',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLight,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: AppColors.primaryGradient,
                    ).createShader(bounds),
                    child: const Text(
                      'Professional PDF Tools',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Theme toggle
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.read<AppProvider>().toggleDarkMode();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12, top: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.border
                          : AppColors.borderLightMode,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return RotationTransition(
                        turns: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      key: ValueKey(isDark),
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms).scale(delay: 100.ms),
              if (!isPro)
                GestureDetector(
                  onTap: () => _showProPaywall(context),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16, top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'PRO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: 'PDF TOOLS', isDark: isDark),
                const SizedBox(height: 16),
                _ToolsGrid(isDark: isDark),
                const SizedBox(height: 24),
                _CrossPromoBanner(isDark: isDark),
                const SizedBox(height: 24),
                if (!isPro)
                  _FreeTierCard(
                    onUpgrade: () => _showProPaywall(context),
                    isDark: isDark,
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ToolsGrid extends StatelessWidget {
  final bool isDark;
  const _ToolsGrid({required this.isDark});

  @override
  Widget build(BuildContext context) {
    const tools = [
      _ToolCard(
        icon: Icons.merge_type_rounded,
        title: 'Merge',
        subtitle: 'Combine multiple PDFs',
        gradient: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        route: 'merge',
      ),
      _ToolCard(
        icon: Icons.content_cut_rounded,
        title: 'Split',
        subtitle: 'Extract page ranges',
        gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        route: 'split',
      ),
      _ToolCard(
        icon: Icons.lock_rounded,
        title: 'Protect',
        subtitle: 'Add AES password',
        gradient: [Color(0xFF10B981), Color(0xFF059669)],
        route: 'protect',
      ),
      _ToolCard(
        icon: Icons.lock_open_rounded,
        title: 'Unlock',
        subtitle: 'Remove password',
        gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
        route: 'unlock',
      ),
      _ToolCard(
        icon: Icons.image_rounded,
        title: 'Image → PDF',
        subtitle: 'Convert gallery images',
        gradient: [Color(0xFFEF4444), Color(0xFFDC2626)],
        route: 'image_to_pdf',
      ),
      _ToolCard(
        icon: Icons.burst_mode_rounded,
        title: 'PDF → Images',
        subtitle: 'Export pages as JPEG',
        gradient: [Color(0xFF06B6D4), Color(0xFF0891B2)],
        route: 'pdf_to_images',
      ),
      _ToolCard(
        icon: Icons.compress_rounded,
        title: 'Compress',
        subtitle: 'Reduce PDF file size',
        gradient: [Color(0xFFF97316), Color(0xFFEA580C)],
        route: 'compress',
      ),
      _ToolCard(
        icon: Icons.draw_rounded,
        title: 'Sign PDF',
        subtitle: 'Add visible signature',
        gradient: [Color(0xFFEC4899), Color(0xFFDB2777)],
        route: 'sign',
      ),
      _ToolCard(
        icon: Icons.upload_file_rounded,
        title: 'Convert',
        subtitle: 'DOCX / CSV / XLSX → PDF',
        gradient: [Color(0xFF84CC16), Color(0xFF65A30D)],
        route: 'convert',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.25,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        return tools[index]
            .animate()
            .fadeIn(delay: Duration(milliseconds: 50 * index))
            .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOut);
      },
    );
  }
}

class _ToolCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final String route;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.route,
  });

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _isPressed = false;

  void _navigate(BuildContext context) {
    Widget screen;
    switch (widget.route) {
      case 'merge':
        screen = const MergeScreen();
        break;
      case 'split':
        screen = const SplitScreen();
        break;
      case 'protect':
        screen = const ProtectScreen();
        break;
      case 'unlock':
        screen = const UnlockScreen();
        break;
      case 'image_to_pdf':
        screen = const ImageToPdfScreen();
        break;
      case 'pdf_to_images':
        screen = const PdfToImagesScreen();
        break;
      case 'compress':
        screen = const CompressScreen();
        break;
      case 'sign':
        screen = const SignScreen();
        break;
      case 'convert':
        screen = const ConvertScreen();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _navigate(context);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.border : AppColors.borderLightMode,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.gradient[0].withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: widget.gradient[0].withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 24),
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.textMutedLight,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrossPromoBanner extends StatelessWidget {
  final bool isDark;
  const _CrossPromoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.borderLightMode,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need to bill a client?',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Try our Offline Invoice Maker →',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
            size: 14,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

class _FreeTierCard extends StatelessWidget {
  final VoidCallback onUpgrade;
  final bool isDark;
  const _FreeTierCard({required this.onUpgrade, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.1),
            const Color(0xFFEF4444).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Free Tier Limits',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _LimitRow(
            icon: Icons.merge_type_rounded,
            text: 'Max 3 files per merge',
          ),
          const SizedBox(height: 6),
          const _LimitRow(
            icon: Icons.storage_rounded,
            text: 'Max 5MB per file',
          ),
          const SizedBox(height: 6),
          const _LimitRow(
            icon: Icons.branding_watermark_rounded,
            text: 'Watermark on output',
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  '⚡ Unlock Pro — \$3.50 One-Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}

class _LimitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _LimitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProPaywallSheet extends StatelessWidget {
  const _ProPaywallSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.border : AppColors.borderLightMode,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Unlock Pro Workspace',
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.textPrimaryLight,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'One-time purchase. No subscription.',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          const _ProFeature(
            icon: Icons.all_inclusive_rounded,
            text: 'Unlimited file sizes',
          ),
          const _ProFeature(
            icon: Icons.merge_type_rounded,
            text: 'Unlimited batch merging',
          ),
          const _ProFeature(
            icon: Icons.branding_watermark_rounded,
            text: 'No watermarks',
          ),
          const _ProFeature(icon: Icons.block_rounded, text: 'Remove all ads'),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              context.read<AppProvider>().unlockPro();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 Pro unlocked! Enjoy unlimited access.'),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '⚡ Get Pro — \$3.50 / ₹295',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe later',
              style: TextStyle(
                color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.success, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.textPrimaryLight,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
