import 'package:flutter/material.dart';
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
    final isPro  = appProvider.isPro;
    final isDark = appProvider.isDarkMode;
    final bg     = isDark ? AppColors.bgDark      : AppColors.bgLight;
    final textMut= isDark ? AppColors.textMuted   : AppColors.textMutedLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          'Settings',
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (!isPro)
            _ProCard(onUpgrade: () => _showPaywall(context), isDark: isDark)
                .animate().fadeIn().slideY(begin: 0.15),
          if (isPro)
            _ProActiveCard(isDark: isDark)
                .animate().fadeIn().slideY(begin: 0.15),

          const SizedBox(height: 28),
          _Label(text: 'APPEARANCE', isDark: isDark),
          const SizedBox(height: 8),
          _Card(
            isDark: isDark,
            children: [
              _ToggleTile(
                icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Dark Mode',
                subtitle: 'Switch app appearance',
                value: isDark,
                isDark: isDark,
                onChanged: (_) => appProvider.toggleDarkMode(),
              ),
            ],
          ).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 24),
          _Label(text: 'BUSINESS TOOLS', isDark: isDark),
          const SizedBox(height: 8),
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

          const SizedBox(height: 24),
          _Label(text: 'ABOUT', isDark: isDark),
          const SizedBox(height: 8),
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
                title: 'Contact',
                subtitle: 'Get help or send feedback',
                isDark: isDark,
                onTap: () => _url('mailto:support@batchpdf.app'),
              ),
              _Divider(isDark: isDark),
              _LinkTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: isDark ? AppColors.textMuted : AppColors.textMutedLight,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                isDark: isDark,
                onTap: () => _url('https://batchpdf.app/privacy'),
              ),
            ],
          ).animate().fadeIn(delay: 240.ms),

          const SizedBox(height: 36),
          Center(
            child: Text(
              'BatchPDF  •  v1.0.0  •  🦀 Rust Engine',
              style: TextStyle(color: textMut, fontSize: 11),
            ),
          ).animate().fadeIn(delay: 320.ms),
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

  Future<void> _url(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Label({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
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
      color: isDark ? AppColors.bgCard : AppColors.bgCardLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? AppColors.border : AppColors.borderLightMode,
      ),
    ),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
    color: isDark ? AppColors.border : AppColors.borderLightMode,
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
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.value, required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontSize: 14, fontWeight: FontWeight.w600,
                )),
              Text(subtitle,
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
                  fontSize: 12,
                )),
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
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                    fontSize: 14, fontWeight: FontWeight.w600,
                  )),
                Text(subtitle,
                  style: TextStyle(
                    color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
                    fontSize: 12,
                  )),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFF59E0B), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unlock Pro',
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                    fontSize: 15, fontWeight: FontWeight.w700,
                  )),
                const Text('\$3.50 one-time · no subscription',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B), size: 18),
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
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.success.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.success.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.verified_rounded, color: AppColors.success, size: 28),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pro Active',
              style: TextStyle(color: AppColors.success, fontSize: 15, fontWeight: FontWeight.w700)),
            Text('Unlimited · no watermarks · no ads',
              style: TextStyle(
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                fontSize: 12,
              )),
          ],
        ),
      ],
    ),
  );
}

class _PaywallSheet extends StatelessWidget {
  const _PaywallSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg  = isDark ? AppColors.bgCard      : AppColors.bgCardLight;
    final border = isDark ? AppColors.border   : AppColors.borderLightMode;
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
                color: border, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Unlock Pro',
            style: TextStyle(color: textPri, fontSize: 26,
                fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 6),
          Text('One-time · No subscription · No hidden fees.',
            style: TextStyle(color: textSec, fontSize: 14)),
          const SizedBox(height: 28),
          _Feat(text: 'Unlimited file sizes', isDark: isDark),
          _Feat(text: 'Unlimited batch merging', isDark: isDark),
          _Feat(text: 'No watermarks on output', isDark: isDark),
          _Feat(text: 'Remove all ads', isDark: isDark),
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
                child: Text('Get Pro  —  \$3.50 / ₹295',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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

class _Feat extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Feat({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Icon(Icons.check_rounded, color: AppColors.success, size: 18),
        const SizedBox(width: 12),
        Text(text,
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            fontSize: 14,
          )),
      ],
    ),
  );
}
