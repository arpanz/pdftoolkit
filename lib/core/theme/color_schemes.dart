import 'package:flutter/material.dart';

enum ColorTheme { classic, lavender, amber, coral, forest, chrome }

class ColorSchemeData {
  final String name;
  final String description;
  final List<Color> primaryGradient;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final IconData icon;

  const ColorSchemeData({
    required this.name,
    required this.description,
    required this.primaryGradient,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.icon,
  });
}

class AppColorSchemes {
  static const Map<ColorTheme, ColorSchemeData> schemes = {
    ColorTheme.classic: ColorSchemeData(
      name: 'Classic Blue',
      description: 'Original professional blue',
      primaryGradient: [Color(0xFF3B82F6), Color(0xFF2563EB)],
      accent: Color(0xFF8B5CF6),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      icon: Icons.water_drop_rounded,
    ),

    ColorTheme.lavender: ColorSchemeData(
      name: 'Digital Lavender',
      description: 'Calm tech vibe',
      primaryGradient: [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
      accent: Color(0xFF86EFAC),
      success: Color(0xFF86EFAC),
      warning: Color(0xFFFCD34D),
      error: Color(0xFFFB7185),
      icon: Icons.spa_rounded,
    ),

    ColorTheme.amber: ColorSchemeData(
      name: 'Burnished Amber',
      description: 'Premium & bold',
      primaryGradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      accent: Color(0xFF0D9488),
      success: Color(0xFF0D9488),
      warning: Color(0xFFFCD34D),
      error: Color(0xFFDC2626),
      icon: Icons.local_fire_department_rounded,
    ),

    ColorTheme.coral: ColorSchemeData(
      name: 'Electric Coral',
      description: 'Energetic & modern',
      primaryGradient: [Color(0xFFFF6B9D), Color(0xFFEC4899)],
      accent: Color(0xFF4F46E5),
      success: Color(0xFF14B8A6),
      warning: Color(0xFFFBBF24),
      error: Color(0xFFF43F5E),
      icon: Icons.flash_on_rounded,
    ),

    ColorTheme.forest: ColorSchemeData(
      name: 'Forest Green',
      description: 'Earthy premium',
      primaryGradient: [Color(0xFF059669), Color(0xFF047857)],
      accent: Color(0xFFDC2626),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFDC2626),
      icon: Icons.forest_rounded,
    ),

    ColorTheme.chrome: ColorSchemeData(
      name: 'Liquid Chrome',
      description: 'Futuristic',
      primaryGradient: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      accent: Color(0xFFEC4899),
      success: Color(0xFF06B6D4),
      warning: Color(0xFFFBBF24),
      error: Color(0xFFF43F5E),
      icon: Icons.auto_awesome_rounded,
    ),
  };

  static ColorSchemeData getScheme(ColorTheme theme) {
    return schemes[theme]!;
  }

  static Color getPrimary(ColorTheme theme) {
    return schemes[theme]!.primaryGradient[0];
  }

  static List<Color> getGradient(ColorTheme theme) {
    return schemes[theme]!.primaryGradient;
  }
}
