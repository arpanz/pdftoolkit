import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller;
  int _index = 0;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      title: 'Your PDF workbench.',
      subtitle:
          'Merge, split, sign and compress in one focused workspace built for speed.',
      badge: '01',
      icon: Icons.dashboard_customize_rounded,
      tone: Color(0xFF3B82F6),
    ),
    _OnboardingPageData(
      title: 'Everything stays local.',
      subtitle:
          'Files are processed on-device with the Rust engine. No upload, no waiting.',
      badge: '02',
      icon: Icons.lock_rounded,
      tone: Color(0xFF10B981),
    ),
    _OnboardingPageData(
      title: 'Built for daily flow.',
      subtitle:
          'Save output history, reuse files, and finish tasks in a couple of taps.',
      badge: '03',
      icon: Icons.bolt_rounded,
      tone: Color(0xFFF59E0B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _nextOrFinish() async {
    HapticFeedback.selectionClick();
    if (_index == _pages.length - 1) {
      widget.onDone();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.backgroundFor(context);
    final textPrimary = AppColors.textPrimaryFor(context);
    final textSecondary = AppColors.textSecondaryFor(context);
    final card = AppColors.cardFor(context);
    final border = AppColors.borderFor(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: 30,
              child: _AmbientBlob(
                color: _pages[_index].tone.withValues(
                  alpha: isDark ? 0.2 : 0.1,
                ),
                size: 180,
              ),
            ),
            Positioned(
              left: -50,
              bottom: 120,
              child: _AmbientBlob(
                color: AppColors.accent.withValues(alpha: isDark ? 0.14 : 0.08),
                size: 210,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'BatchPDF',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onDone,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemCount: _pages.length,
                      itemBuilder: (context, i) {
                        final page = _pages[i];
                        return _OnboardingPage(
                          page: page,
                          card: card,
                          border: border,
                          isDark: isDark,
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(_pages.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(right: 8),
                          width: active ? 30 : 10,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: active
                                ? _pages[_index].tone
                                : textSecondary.withValues(alpha: 0.35),
                          ),
                        );
                      }),
                      const Spacer(),
                      FilledButton(
                        onPressed: _nextOrFinish,
                        style: FilledButton.styleFrom(
                          backgroundColor: _pages[_index].tone,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          _index == _pages.length - 1 ? 'Start' : 'Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData page;
  final Color card;
  final Color border;
  final bool isDark;

  const _OnboardingPage({
    required this.page,
    required this.card,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryFor(context);
    final textSecondary = AppColors.textSecondaryFor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: page.tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: page.tone.withValues(alpha: 0.4)),
            ),
            child: Text(
              page.badge,
              style: TextStyle(
                color: page.tone,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(height: 14),
          Text(
            page.title,
            style: TextStyle(
              color: textPrimary,
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 12),
          Text(
            page.subtitle,
            style: TextStyle(
              color: textSecondary,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: border),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: _AmbientBlob(
                      color: page.tone.withValues(alpha: isDark ? 0.2 : 0.12),
                      size: 130,
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: 24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: page.tone.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: page.tone.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Center(
                        child: Icon(page.icon, color: page.tone, size: 72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color tone;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.tone,
  });
}
