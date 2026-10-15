/// PageSkeleton — KIJIVU (skeleton) pekee, KAMWE spinner.
///
/// KANUNI YA APP: hakuna duara linalozunguka kwa ukurasa wowote — hata mbano
/// wa kwanza baada ya install. Wakati data bado haijafika (mtumiaji mgeni,
/// mtandao mbaya), ukurasa unaonyesha kurasa tupu za kijivu vinavyoonyesha
/// maumbo ya data inayokuja — mtumiaji anaanza kutumia app mara moja.
///
/// § inatumika na kurusa ZOTE (user + admin) kwa hali "haijapakuliwa":
///   PageSkeleton(rows: 6)   — badala ya Center(CircularProgressIndicator)
///   PageSkeleton(rows: 2)   — kwa maeneo madogo (kadi/chips)
library;

import 'package:flutter/material.dart';

class PageSkeleton extends StatelessWidget {
  const PageSkeleton({
    super.key,
    this.rows = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.scrollable = true,
  });

  /// Idadi ya kadi-bandaluli (skeleton rows).
  final int rows;

  final EdgeInsets padding;

  /// Ukurasa mrefu (ListView) au maeneo madogo (Column ndani ya Stack).
  final bool scrollable;

  Color _base(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF16202F)
          : const Color(0xFFF0F4F9);

  Color _line(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color(0xFF253244)
      : const Color(0xFFE2E9F2);

  Color _chip(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color(0xFF1D2A3C)
      : const Color(0xFFE9EFF6);

  Widget _skelRow(BuildContext context) {
    final base = _base(context);
    final line = _line(context);

    // Muundo wima PEKEE — mistari ya `widthFactor` (≤ parent) — HAUWEZI
    // kufanya overflow hata viewport ndogo zaidi (320×640 kwenye tests).
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, height: 12, color: line),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.6,
          child: Container(height: 10, color: line),
        ),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.85,
          child: Container(height: 10, color: line),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) _skelRow(context),
        ],
      ),
    );
    if (!scrollable) return body;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: body,
    );
  }
}
