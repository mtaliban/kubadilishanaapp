// ═══════════════════════════════════════════════════════════════════════════
// TOKEN YA PAMOJA — kadi za Takwimu ↔ Watumiaji
//
// Thamani hizi ni NAKALA KAMILI ya `_C` ya statistics_page.dart (Takwimu)
// BILA kubadilisha huo faili chochote:
//
//   • Border ya kadi  : _C.border  (0xFFD6E2F6, light) / _C.borderD (0xFF26324F, dark)
//                       — giza ni navy iliyokolea pia; unene ni 1.5 (Border.all
//                       kwenye hero na tiles za Takwimu).
//   • Background ya ukurasa : _C.jmBg (Colors.white, light) / _C.jmBgD
//                       (0xFF0F172A — "navy iliyokolea", dark).
//   • Rangi ya kadi   : _C.jmBg2 — ile ile (nyeupe / 0xFF0F172A), Takwimu
//                       hutofautisha giza kwa border tu.
//
// Watumiaji (WATUMIAJI TUMIA) ends with these; Takwimu inaendelea na _C yake
// isiyoguswa. Badilisha thamani hapa ndipo mbili ziendelee kulingana.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Unene wa border ya kadi — kama Takwimu (Border.all width: 1.5).
const double kSharedCardBorderWidth = 1.5;

const Color _kSharedBorderLight = Color(0xFFD6E2F6); // _C.border
const Color _kSharedBorderDark = Color(0xFF26324F); // _C.borderD
const Color _kSharedCardLight = Colors.white; // _C.jmBg / _C.jmBg2
const Color _kSharedCardDark = Color(0xFF0F172A); // _C.jmBgD (navy iliyokolea)

bool _isDark(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark;

/// Rangi ya border ya kadi (Takwimu ↔ Watumiaji).
Color sharedCardBorderOf(BuildContext c) =>
    _isDark(c) ? _kSharedBorderDark : _kSharedBorderLight;

/// Rangi ya BACKGROUND ya ukurasa (si ya kadi) — ile ile ya Takwimu.
Color sharedPageBgOf(BuildContext c) =>
    _isDark(c) ? _kSharedCardDark : _kSharedCardLight;

/// Rangi ya KADI (chips, search box, kadi za watumiaji) — ile ile ya Takwimu.
Color sharedCardColorOf(BuildContext c) =>
    _isDark(c) ? _kSharedCardDark : _kSharedCardLight;
