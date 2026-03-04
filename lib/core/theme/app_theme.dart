import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_schemes.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color accent = Color(0xFF06B6D4);
  static const List<Color> primaryGradient = [
    Color(0xFF3B82F6),
    Color(0xFF2563EB),
  ];

  // Dark surfaces
  static const Color bgDark = Color(0xFF0A0A0A);
  static const Color bgCard = Color(0xFF141414);
  static const Color bgCardElevated = Color(0xFF1C1C1C);
  static const Color bgSurface = Color(0xFF222222);

  // Light surfaces
  static const Color bgLight = Color(0xFFF9FAFB);
  static const Color bgCardLight = Color(0xFFFFFFFF);
  static const Color bgCardElevatedLight = Color(0xFFF3F4F6);
  static const Color bgSurfaceLight = Color(0xFFE5E7EB);

  // Dark text
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Light text
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textMutedLight = Color(0xFF9CA3AF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Borders
  static const Color border = Color(0xFF1F1F1F);
  static const Color borderLight = Color(0xFF2A2A2A);
  static const Color borderLightMode = Color(0xFFE5E7EB);
  static const Color borderLightModeStrong = Color(0xFFD1D5DB);

  static Color backgroundFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bgDark : bgLight;

  static Color cardFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bgCard : bgCardLight;

  static Color textPrimaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textPrimary
      : textPrimaryLight;

  static Color textSecondaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textSecondary
      : textSecondaryLight;

  static Color textMutedFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textMuted
      : textMutedLight;

  static Color borderFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? border
      : borderLightMode;
}

class AppTheme {
  static ThemeData darkTheme(ColorSchemeData scheme) {
    final primary = scheme.primaryGradient.first;
    final accent = scheme.accent;
    final error = scheme.error;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: AppColors.bgCard,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme:
          GoogleFonts.plusJakartaSansTextTheme(
            const TextTheme(
              displayLarge: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 32,
              ),
              displayMedium: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 28,
              ),
              headlineLarge: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 24,
              ),
              headlineMedium: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
              headlineSmall: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              titleLarge: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              titleMedium: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              bodyMedium: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 12),
              labelLarge: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ).copyWith(
            displayLarge: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 32,
            ),
            displayMedium: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 28,
            ),
            headlineLarge: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
            headlineMedium: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
            headlineSmall: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? primary : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.3)
              : AppColors.bgSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgCardElevated,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  static ThemeData lightTheme(ColorSchemeData scheme) {
    final primary = scheme.primaryGradient.first;
    final accent = scheme.accent;
    final error = scheme.error;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: AppColors.bgCardLight,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onError: Colors.white,
      ),
      textTheme:
          GoogleFonts.plusJakartaSansTextTheme(
            const TextTheme(
              displayLarge: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 32,
              ),
              displayMedium: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 28,
              ),
              headlineLarge: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 24,
              ),
              headlineMedium: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
              headlineSmall: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              titleLarge: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              titleMedium: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              bodyLarge: TextStyle(
                color: AppColors.textPrimaryLight,
                fontSize: 16,
              ),
              bodyMedium: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 14,
              ),
              bodySmall: TextStyle(
                color: AppColors.textMutedLight,
                fontSize: 12,
              ),
              labelLarge: TextStyle(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ).copyWith(
            displayLarge: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 32,
            ),
            displayMedium: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 28,
            ),
            headlineLarge: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
            headlineMedium: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
            headlineSmall: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCardLight,
        selectedItemColor: AppColors.textPrimaryLight,
        unselectedItemColor: AppColors.textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLightMode),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLightMode),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
        hintStyle: const TextStyle(color: AppColors.textMutedLight),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLightMode,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondaryLight),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : AppColors.textMutedLight,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.3)
              : AppColors.bgSurfaceLight,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgCardElevatedLight,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimaryLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondaryLight,
          fontSize: 14,
        ),
      ),
    );
  }
}
