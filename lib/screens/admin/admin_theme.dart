// admin_theme.dart
// Palette halisi ya admin — inabadilisha rangi ngumu (hardcoded light) kwenye
// pages zote za admin na mfumo mmoja wa theme: kila helper inapokea context,
// inarudisha rangi ya light au dark kwa `Theme.of(context).brightness`.
//
// Dark tokens ni ILE ILE ya pages zilizofanya kazi vizuri (Matangazo,
// Maoni, Wenzao): bg 0xFF0F172A, card 0xFF1E293B, border 0xFF2A3240,
// text 0xFFE7ECF8, muted 0xFF9AA8C7, bluu 0xFF7AA7FF.
//
// Matumizi: import kwenye admin page, kisha badilisha `Colors.white` na
// `Ad.card(context)`, `Color(0xFFF3F4F6)` → `Ad.tile(context)`,
// `Color(0xFFEFF6FF)` → `Ad.blueSoft(context)`, `Color(0xFF111827)` /
// `Color(0xFF243049)` → `Ad.ink(context)`, `Color(0xFF6B7280)` /
// `Color(0xFF7A8496)` → `Ad.muted(context)`, `Color(0xFFE5E7EB)` /
// `Color(0xFFE3E7EE)` → `Ad.border(context)`.

import 'package:flutter/material.dart';

class Ad {
  Ad._();

  // ── LIGHT (hali ya mwanga — rangi ileile zilizokuwa hardcoded) ────────────
  static const _card = Colors.white;
  static const _pageBg = Color(0xFFF8FAFC);
  static const _tile = Color(0xFFF3F4F6);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _ink = Color(0xFF111827);
  static const _inkStrong = Color(0xFF243049);
  static const _muted = Color(0xFF6B7280);
  static const _muted2 = Color(0xFF7A8496);
  static const _border = Color(0xFFE5E7EB);
  static const _borderStrong = Color(0xFFD1D5DB);
  static const _blue = Color(0xFF1E40AF);
  static const _danger = Color(0xFFD92D20);
  static const _dangerBg = Color(0xFFFEF2F2);
  static const _success = Color(0xFF15803D);
  static const _successBg = Color(0xFFECFDF5);
  static const _warning = Color(0xFFC2410C);
  static const _warningBg = Color(0xFFFFF7ED);

  // ── DARK (tokens za Matangazo/Maoni — hali ya giza) ──────────────────────
  static const _cardD = Color(0xFF1E293B);
  static const _pageBgD = Color(0xFF0F172A);
  static const _tileD = Color(0xFF212833);
  static const _blueSoftD = Color(0xFF1C2A44);
  static const _inkD = Color(0xFFE7ECF8);
  static const _mutedD = Color(0xFF9AA8C7);
  static const _muted2D = Color(0xFF8B99B4);
  static const _borderD = Color(0xFF2A3240);
  static const _borderStrongD = Color(0xFF334155);
  static const _blueD = Color(0xFF7AA7FF);
  static const _dangerD = Color(0xFFF87171);
  static const _dangerBgD = Color(0xFF3A1D1B);
  static const _successD = Color(0xFF86EFAC);
  static const _successBgD = Color(0xFF14532D);
  static const _warningD = Color(0xFFFBBF24);
  static const _warningBgD = Color(0xFF3A2C14);

  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  // ── Helpers ──────────────────────────────────────────────────────────────
  static Color card(BuildContext c)     => isDark(c) ? _cardD : _card;
  static Color pageBg(BuildContext c)   => isDark(c) ? _pageBgD : _pageBg;
  static Color tile(BuildContext c)     => isDark(c) ? _tileD : _tile;
  static Color blueSoft(BuildContext c) => isDark(c) ? _blueSoftD : _blueSoft;
  static Color ink(BuildContext c)      => isDark(c) ? _inkD : _ink;
  static Color inkStrong(BuildContext c)=> isDark(c) ? _inkD : _inkStrong;
  static Color muted(BuildContext c)    => isDark(c) ? _mutedD : _muted;
  static Color muted2(BuildContext c)   => isDark(c) ? _muted2D : _muted2;
  static Color border(BuildContext c)   => isDark(c) ? _borderD : _border;
  static Color borderStrong(BuildContext c) =>
      isDark(c) ? _borderStrongD : _borderStrong;
  static Color blue(BuildContext c)     => isDark(c) ? _blueD : _blue;
  static Color danger(BuildContext c)   => isDark(c) ? _dangerD : _danger;
  static Color dangerBg(BuildContext c) => isDark(c) ? _dangerBgD : _dangerBg;
  static Color success(BuildContext c)  => isDark(c) ? _successD : _success;
  static Color successBg(BuildContext c)=> isDark(c) ? _successBgD : _successBg;
  static Color warning(BuildContext c)  => isDark(c) ? _warningD : _warning;
  static Color warningBg(BuildContext c)=> isDark(c) ? _warningBgD : _warningBg;

  /// Helper ya jumla: `Ad.of(context, lightColor, darkColor)`.
  static Color of(BuildContext c, Color light, Color dark) =>
      isDark(c) ? dark : light;
}
