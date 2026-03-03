import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isPro = appProvider.isPro;
    final isDark = appProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Pro card
          if (!isPro)
            _ProCard(
              onUpgrade: () => _showPaywall(context),
              isDark: isDark,
            ).animate().fadeIn().slideY(begin: 0.2),

          if (isPro) _ProActiveCard(isDark: isDark).animate().fadeIn().slideY(begin: 0.2),

          const SizedBox(height: 20),

          // Appearance
          _SectionHeader(title: 'APPEARANCE', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ToggleTile(
                icon: Icons.dark_mode_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Dark Mode',
                subtitle: 'Toggle app appearance',
                value: isDark,
                isDark: isDark,
                onChanged: (_) => appProvider.toggleDarkMode(),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 12),

          // Theme Selector
          _ThemeSelector().animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 20),

          // Business Tools (Cross-promo)
          _SectionHeader(title: 'BUSINESS TOOLS', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _LinkTile(
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF10B981),
                title: '🧾 Offline Invoice Maker',
                subtitle: 'Make professional invoices',
                isDark: isDark,
                onTap: () => _launchUrl('https://play.google.com/store'),
              ),
              Divider(
                color: isDark ? AppColors.border : AppColors.borderLightMode,
                height: 1,
              ),
              _LinkTile(
                icon: Icons.qr_code_2_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
                title: '🔲 Bulk QR Code Generator',
                subtitle: 'Generate bulk QR codes',
                isDark: isDark,
                onTap: () => _launchUrl('https://play.google.com/store'),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 20),

          // About
          _SectionHeader(title: 'ABOUT', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _LinkTile(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Rate BatchPDF',
                subtitle: 'Love the app? Leave a review!',
                isDark: isDark,
                onTap: () => _launchUrl('https://play.google.com/store'),
              ),
              Divider(
                color: isDark ? AppColors.border : AppColors.borderLightMode,
                height: 1,
              ),
              _LinkTile(
                icon: Icons.mail_rounded,
                iconColor: const Color(0xFF0D9488),
                title: 'Contact Developer',
                subtitle: 'Get help or send feedback',
                isDark: isDark,
                onTap: () => _launchUrl('mailto:support@batchpdf.app'),
              ),
              Divider(
                color: isDark ? AppColors.border : AppColors.borderLightMode,
                height: 1,
              ),
              _LinkTile(
                icon: Icons.privacy_tip_rounded,
                iconColor: isDark ? AppColors.textMuted : AppColors.textMutedLight,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                isDark: isDark,
                onTap: () => _launchUrl('https://batchpdf.app/privacy'),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 20),

          // App info
          Center(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.getThemeColors(appProvider.themeMode).primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'BatchPDF Pro',
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Version 1.0.0 • Powered by 🦀 Rust',
                  style: TextStyle(
                    color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _PaywallSheet(),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDark = appProvider.isDarkMode;
    final currentTheme = appProvider.themeMode;

    final themes = [
      _ThemeOption(
        mode: AppThemeMode.classicBlue,
        name: 'Classic Blue',
        colors: [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
      ),
      _ThemeOption(
        mode: AppThemeMode.amberTeal,
        name: 'Amber Teal',
        colors: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
      ),
      _ThemeOption(
        mode: AppThemeMode.lavenderMint,
        name: 'Lavender Mint',
        colors: [const Color(0xFFA78BFA), const Color(0xFF86EFAC)],
      ),
      _ThemeOption(
        mode: AppThemeMode.coralIndigo,
        name: 'Coral Indigo',
        colors: [const Color(0xFFFF6B9D), const Color(0xFF4F46E5)],
      ),
      _ThemeOption(
        mode: AppThemeMode.forestTerracotta,
        name: 'Forest Terra',
        colors: [const Color(0xFF059669), const Color(0xFFDC2626)],
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.borderLightMode,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Color Theme',
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              final isSelected = theme.mode == currentTheme;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  appProvider.setThemeMode(theme.mode);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.bgSurface
                        : AppColors.bgSurfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colors[0]
                          : (isDark
                              ? AppColors.border
                              : AppColors.borderLightMode),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: theme.colors),
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        theme.name,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colors[0]
                              : (isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLight),
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeOption {
  final AppThemeMode mode;
  final String name;
  final List<Color> colors;

  const _ThemeOption({
    required this.mode,
    required this.name,
    required this.colors,
  });
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;

  const _SettingsCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.borderLightMode,
        ),
      ),
      child: Column(children: children),
    );
  }
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textMuted
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.textMutedLight,
                      fontSize: 12,
                    ),
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
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  final VoidCallback onUpgrade;
  final bool isDark;

  const _ProCard({required this.onUpgrade, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E1E2E), const Color(0xFF252535)]
                : [
                    const Color(0xFFFFF7ED),
                    const Color(0xFFFFEDD5),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock Pro Workspace',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    '\$3.50 one-time • No subscription',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFF59E0B),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProActiveCard extends StatelessWidget {
  final bool isDark;

  const _ProActiveCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(isDark ? 0.1 : 0.15),
            AppColors.success.withOpacity(isDark ? 0.05 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.success, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pro Active ✓',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Unlimited access • No watermarks • No ads',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondary
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
}

class _PaywallSheet extends StatelessWidget {
  const _PaywallSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(28),
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
          const SizedBox(height: 20),
          Text(
            'Unlock Pro Workspace',
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
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
          const SizedBox(height: 28),
          _Feature(
            icon: Icons.all_inclusive_rounded,
            text: 'Unlimited file sizes',
            isDark: isDark,
          ),
          _Feature(
            icon: Icons.merge_type_rounded,
            text: 'Unlimited batch merging',
            isDark: isDark,
          ),
          _Feature(
            icon: Icons.branding_watermark_rounded,
            text: 'No watermarks on output',
            isDark: isDark,
          ),
          _Feature(
            icon: Icons.block_rounded,
            text: 'Remove all ads',
            isDark: isDark,
          ),
          const SizedBox(height: 28),
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
          const SizedBox(height: 12),
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

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _Feature({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
