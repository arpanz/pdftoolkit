import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/color_schemes.dart';
import '../../core/providers/app_provider.dart';
import '../workspace/workspace_screen.dart' show ProPaywallSheet;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isPro = appProvider.isPro;
    final isDark = appProvider.isDarkMode;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final textPri = isDark
        ? AppColors.textPrimaryFor(context)
        : AppColors.textPrimaryLight;
    final textMut = isDark
        ? AppColors.textMutedFor(context)
        : AppColors.textMutedLight;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
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
                      'Preferences & account',
                      style: TextStyle(
                        color: textMut,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            // ── Divider ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Divider(
                  color: isDark
                      ? AppColors.borderFor(context)
                      : AppColors.borderLightMode,
                  height: 1,
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Pro status card
                  if (!isPro)
                    _ProCard(
                      onUpgrade: () => _showPaywall(context),
                      isDark: isDark,
                    ).animate().fadeIn().slideY(begin: 0.12)
                  else
                    _ProActiveCard(
                      isDark: isDark,
                    ).animate().fadeIn().slideY(begin: 0.12),

                  SizedBox(height: 32),

                  _SectionLabel(text: 'APPEARANCE', isDark: isDark),
                  SizedBox(height: 10),
                  _Card(
                    isDark: isDark,
                    children: [
                      _ToggleTile(
                        icon: isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'Dark Mode',
                        subtitle: isDark
                            ? 'Switch to light theme'
                            : 'Switch to dark theme',
                        value: isDark,
                        isDark: isDark,
                        onChanged: (_) => appProvider.toggleDarkMode(),
                      ),
                    ],
                  ).animate().fadeIn(delay: 80.ms),
                  SizedBox(height: 12),
                  _Card(
                    isDark: isDark,
                    children: [
                      _ThemeSelector(
                        isDark: isDark,
                        selectedTheme: appProvider.colorTheme,
                        onThemeSelected: (theme) {
                          appProvider.setColorTheme(theme);
                        },
                      ),
                    ],
                  ).animate().fadeIn(delay: 120.ms),

                  SizedBox(height: 28),
                  _SectionLabel(text: 'EXPLORE MORE APPS', isDark: isDark),
                  SizedBox(height: 10),
                  _Card(
                    isDark: isDark,
                    children: [
                      _LinkTile(
                        icon: Icons.receipt_long_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'Offline Invoice Maker',
                        subtitle: 'Create professional invoices',
                        isDark: isDark,
                        onTap: () => _url('https://play.google.com/store'),
                      ),
                      _Divider(isDark: isDark),
                      _LinkTile(
                        icon: Icons.qr_code_2_rounded,
                        iconColor: AppColors.primary,
                        title: 'Bulk QR Generator',
                        subtitle: 'Generate QR codes in bulk',
                        isDark: isDark,
                        onTap: () => _url('https://play.google.com/store'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 160.ms),

                  SizedBox(height: 28),
                  _SectionLabel(text: 'SUPPORT & INFO', isDark: isDark),
                  SizedBox(height: 10),
                  _Card(
                    isDark: isDark,
                    children: [
                      _LinkTile(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Rate BatchPDF',
                        subtitle: 'Love the app? Leave a review',
                        isDark: isDark,
                        onTap: () => _url('https://play.google.com/store'),
                      ),
                      _Divider(isDark: isDark),
                      _LinkTile(
                        icon: Icons.mail_outline_rounded,
                        iconColor: AppColors.accent,
                        title: 'Contact Support',
                        subtitle: 'Get help or send feedback',
                        isDark: isDark,
                        onTap: () => _url('mailto:support@batchpdf.app'),
                      ),
                      _Divider(isDark: isDark),
                      _LinkTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: isDark
                            ? AppColors.textMutedFor(context)
                            : AppColors.textMutedLight,
                        title: 'Privacy Policy',
                        subtitle: 'Your data never leaves your device',
                        isDark: isDark,
                        onTap: () => _url('https://batchpdf.app/privacy'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 240.ms),

                  SizedBox(height: 40),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🦀 ', style: TextStyle(fontSize: 14)),
                            Text(
                              'Rust Engine — 100% offline processing',
                              style: TextStyle(
                                color: textMut,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'BatchPDF  •  v1.0.0',
                          style: TextStyle(color: textMut, fontSize: 11),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 320.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ProPaywallSheet(),
    );
  }

  Future<void> _url(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: isDark
          ? AppColors.textMutedFor(context)
          : AppColors.textMutedLight,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
    ),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _Card({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isDark ? AppColors.cardFor(context) : AppColors.bgCardLight,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark
            ? AppColors.borderFor(context)
            : AppColors.borderLightMode,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(children: children),
  );
}

class _ThemeSelector extends StatelessWidget {
  final bool isDark;
  final ColorTheme selectedTheme;
  final ValueChanged<ColorTheme> onThemeSelected;

  const _ThemeSelector({
    required this.isDark,
    required this.selectedTheme,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textMut = isDark
        ? AppColors.textMutedFor(context)
        : AppColors.textMutedLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Color Theme',
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimaryFor(context)
                  : AppColors.textPrimaryLight,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Pick a palette for buttons, accents, and highlights.',
            style: TextStyle(color: textMut, fontSize: 12),
          ),
          SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ColorTheme.values.map((theme) {
              final scheme = AppColorSchemes.getScheme(theme);
              final isSelected = theme == selectedTheme;
              return _ThemeChip(
                scheme: scheme,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => onThemeSelected(theme),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final ColorSchemeData scheme;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.scheme,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? scheme.primaryGradient.first
        : (isDark ? AppColors.borderFor(context) : AppColors.borderLightMode);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          gradient: LinearGradient(colors: scheme.primaryGradient),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: scheme.primaryGradient.first.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(scheme.icon, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text(
              scheme.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) => Divider(
    color: isDark ? AppColors.borderFor(context) : AppColors.borderLightMode,
    height: 1,
    indent: 16,
    endIndent: 16,
  );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 18),
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
                      ? AppColors.textMutedFor(context)
                      : AppColors.textMutedLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 18),
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
                        ? AppColors.textMutedFor(context)
                        : AppColors.textMutedLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark
                ? AppColors.textMutedFor(context)
                : AppColors.textMutedLight,
            size: 18,
          ),
        ],
      ),
    ),
  );
}

class _ProCard extends StatelessWidget {
  final VoidCallback onUpgrade;
  final bool isDark;
  const _ProCard({required this.onUpgrade, required this.isDark});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onUpgrade,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.1),
            const Color(0xFFF97316).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Pro',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimaryFor(context)
                        : AppColors.textPrimaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'One-time · No subscription · No ads',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B), size: 20),
        ],
      ),
    ),
  );
}

class _ProActiveCard extends StatelessWidget {
  final bool isDark;
  const _ProActiveCard({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.verified_rounded,
            color: AppColors.success,
            size: 24,
          ),
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pro Active ✓',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Unlimited · no watermarks · no ads',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryFor(context)
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
