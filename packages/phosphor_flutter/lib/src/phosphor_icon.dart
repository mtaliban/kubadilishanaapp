// ══════════════════════════════════════════════════════════════════════════
// VENDORED + PATCHED — phosphor_flutter 2.1.0
//
// `PhosphorIcon` = `Icon` ya Flutter kwa icons za Phosphor.
// Branch ya Duotone imeondolewa kwa kuwa icons zinatengenezwa kama `IconData`
// halisi (tazama phosphor_icon_data.dart) na app inatumia Regular/Fill pekee.
// ══════════════════════════════════════════════════════════════════════════
library phosphor_flutter;

import 'package:flutter/material.dart';

class PhosphorIcon extends Icon {
  const PhosphorIcon(
    IconData icon, {
    Key? key,
    double? size,
    double? fill,
    double? weight,
    double? grade,
    double? opticalSize,
    Color? color,
    List<Shadow>? shadows,
    String? semanticLabel,
    TextDirection? textDirection,
  }) : super(
          icon,
          color: color,
          fill: fill,
          grade: grade,
          key: key,
          opticalSize: opticalSize,
          semanticLabel: semanticLabel,
          shadows: shadows,
          size: size,
          textDirection: textDirection,
          weight: weight,
        );
}
