import 'package:flutter/material.dart';

enum ColorTheme { classic }

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
      accent: Color(0xFF06B6D4),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      icon: Icons.water_drop_rounded,
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
