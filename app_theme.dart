import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF071A31);
  static const navySoft = Color(0xFF102B4A);
  static const purple = Color(0xFF5B35D5);
  static const purpleDark = Color(0xFF4524B8);
  static const lavender = Color(0xFFF0ECFF);
  static const teal = Color(0xFF26B99A);
  static const orange = Color(0xFFF6A43B);
  static const background = Color(0xFFF7F7FB);
  static const cardBorder = Color(0xFFE8E7EF);
}

class AppTheme {
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      brightness: brightness,
      primary: AppColors.purple,
      secondary: AppColors.teal,
      surface: brightness == Brightness.light ? Colors.white : const Color(0xFF151721),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? AppColors.background
          : const Color(0xFF0E1017),
      fontFamilyFallback: const ['Vazirmatn', 'Tahoma', 'Arial'],
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.light ? Colors.white : const Color(0xFF171A24),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: brightness == Brightness.light
                ? AppColors.cardBorder
                : Colors.white.withValues(alpha: .08),
          ),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      dividerColor: scheme.outlineVariant.withValues(alpha: .6),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xFFF9F9FC)
            : const Color(0xFF20232D),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: brightness == Brightness.light ? Colors.white : const Color(0xFF141720),
        indicatorColor: AppColors.lavender,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.purple : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.purple : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide.none,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
