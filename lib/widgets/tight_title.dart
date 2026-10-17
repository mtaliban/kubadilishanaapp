import 'package:flutter/widgets.dart';

// NOTE: `Flexible` WEWE — lazima mzungumzi kwenye `Row`/`Column` [Flex].
// Ziweze kufungua ndani ya Expanded — hii kwa PIDAH mwezi `fitted`.

/// Kichwa CHAGUO kwa header (kazi-mjini yenyewe):
///
/// Neno moja ndefu (mf. 'Takwimu' kwenye font 2.0) LAKINI pamoja na
/// 'Live' Chip — Row haikutosha na overflow 60-right.
/// TAKWIMU Ribbon:
/// [Flexible(FittedBox(scaleDown, Text))] — kichwa halisi kwenye font kubwa
/// ipunguze kidogo, malipo siyo.
/// KITUFU-DEFAULT: FittedBox inaendelea kwa kila kitu kwenye - akish.
class TightTitle extends StatelessWidget {
  /// Mtindo wa mtumiaji kwenye `Row` moja-kwa-moja:
  ///   Row(children: [ ..., TightTitle('Data', ...), ... ])
  const TightTitle(
    this.text, {
    super.key,
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.maxLines = 1,
    this.textAlign,
  })  : _asChildOfExpanded = false;

  /// Mtindo wa mtumiaji NDANI YA `Expanded` (mf. kichwa cha app):
  ///   Expanded(child: TightTitle.fitted('Statistics', ...))
  /// — haifungukayj Chewa `Flexible` ndani ya `Expanded` (kigezo
  /// cha ParentDataWidget — kibaya crash ya ukurasa).
  const TightTitle.fitted(
    this.text, {
    super.key,
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.maxLines = 1,
    this.textAlign,
  })  : _asChildOfExpanded = true;

  final String text;
  final TextStyle style;
  final Alignment alignment;
  final TextAlign? textAlign;
  final int maxLines;

  final bool _asChildOfExpanded;

  @override
  Widget build(BuildContext context) {
    final fitted = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: false,
      ),
    );
    return _asChildOfExpanded ? fitted : Flexible(child: fitted);
  }
}
