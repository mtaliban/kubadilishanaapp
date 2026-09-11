// Kubadilishana app theme — colors, typography, spacing.
import 'package:flutter/material.dart';

class AppColors {
  // Brand — exact Tailwind grey palette matching the website
  static const Color primary = Color(0xFF1E40AF);      // brand-blue (#1E40AF)
  static const Color primaryDark = Color(0xFF1D4ED8);  // brand-blue-700
  static const Color primaryLight = Color(0xFFEFF6FF); // brand-blue-50
  static const Color accent = Color(0xFF3B82F6);       // blue-500

  // Backgrounds
  static const Color bg = Color(0xFFF9FAFB);           // brand-grey-50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFFF3F4F6);  // brand-grey-100

  // Text
  static const Color textPrimary = Color(0xFF111827);  // brand-grey-900
  static const Color textSecondary = Color(0xFF6B7280);// brand-grey-500
  static const Color textLight = Color(0xFF9CA3AF);    // brand-grey-400

  // Status
  static const Color success = Color(0xFF22C55E);      // green-500
  static const Color warning = Color(0xFFF59E0B);      // amber-500
  static const Color error = Color(0xFFDC2626);        // brand-red
  static const Color info = Color(0xFF3B82F6);         // blue-500

  // Borders
  static const Color border = Color(0xFFE5E7EB);      // brand-grey-200
  static const Color borderLight = Color(0xFFF3F4F6); // brand-grey-100

  // Category
  static const Color education = Color(0xFF1E40AF);   // brand-blue
  static const Color health = Color(0xFFDC2626);      // brand-red
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    ),
  );
}
