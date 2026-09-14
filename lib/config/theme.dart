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

  // ── Design tokens za kisasa (web parity) ─────────────────────────────
  static const Color blue50 = Color(0xFFEFF6FF);   // brand-blue-50
  static const Color blue100 = Color(0xFFDBEAFE);  // brand-blue-100
  static const Color blue200 = Color(0xFFBFDBFE);  // brand-blue-200
  static const Color blue500 = Color(0xFF3B82F6);  // brand-blue-500
  static const Color blue700 = Color(0xFF1D4ED8);  // brand-blue-700
  static const Color navy = Color(0xFF172554);     // brand-navy (header ya kisomi)
  static const Color grey50 = Color(0xFFF9FAFB);   // brand-grey-50
  static const Color grey100 = Color(0xFFF3F4F6);  // brand-grey-100
  static const Color grey300 = Color(0xFFD1D5DB);  // brand-grey-300
  static const Color grey700 = Color(0xFF374151);  // brand-grey-700

  /// Kivuli laini (shadow-soft) — kinaonekana kwenye Android na iOS.
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowCard = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
  ];

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
    // Grey-50 badala ya nyeupe tupu — cards nyeupe zinajitokeza (haipauki).
    scaffoldBackgroundColor: AppColors.bg,
    // AppBar NYEUPE yenye title nyeusi — kama web (na kama screens za
    // my_matches/announcements zilivyoanza). Inafanana na web ambayo haina
    // bar ya rangi juu; ina mstari mwembamba chini.
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      shape: Border(bottom: BorderSide(color: AppColors.borderLight)),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: false,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textLight),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.grey700,
        minimumSize: const Size(0, 46),
        side: const BorderSide(color: AppColors.grey300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.grey700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight, thickness: 1, space: 1,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    ),
  );
}
