import 'package:flutter/material.dart';

/// Tema web Banco Los Andes — header celeste, fondo claro.
class WebTheme {
  static const brandCyan = Color(0xFF00C1F9);
  static const brandCyanLight = Color(0xFF89D9FF);
  static const brandCyanDark = Color(0xFF0097C7);
  static const headerGradientStart = Color(0xFF0097C7);
  static const headerGradientEnd = Color(0xFF00C1F9);
  static const pageBackground = Color(0xFFF0F4F8);
  static const cardBackground = Colors.white;
  static const textPrimary = Color(0xFF0D1C2D);
  static const textSecondary = Color(0xFF5C6B7A);
  static const accent = brandCyan;
  static const navActive = brandCyanDark;
  static const navInactive = Color(0xFF6B7280);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandCyan,
      brightness: Brightness.light,
      surface: pageBackground,
      primary: brandCyanDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pageBackground,
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandCyanDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: brandCyan, width: 2),
        ),
      ),
    );
  }

  static const headerGradient = LinearGradient(
    colors: [headerGradientStart, headerGradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static BoxDecoration cardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: borderColor ?? Colors.black.withValues(alpha: 0.06),
      ),
      boxShadow: [
        BoxShadow(
          color: brandCyanDark.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
