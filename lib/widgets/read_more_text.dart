/// ReadMoreText — maandishi marefu (maoni/malamiko/-jibu) yanakatwa kuwa vikima
/// [collapsedLines], na kitufe cha "Soma zaidi" kinazifungua (Punguza kuirudisha).
/// Maandishi mafupi onywesho bila kitufe (no toggle).
library;

import 'package:flutter/material.dart';

class ReadMoreText extends StatefulWidget {
  const ReadMoreText(
    this.text, {
    super.key,
    required this.style,
    this.collapsedLines = 6,
  });

  final String text;
  final TextStyle style;
  final int collapsedLines;

  @override
  State<ReadMoreText> createState() => _ReadMoreTextState();
}

class _ReadMoreTextState extends State<ReadMoreText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final text = widget.text;
    // Maandishi mafupi: onyesha bila kitufe ya Soma zaidi.
    // ~45 herufi kwa mstari wastani (font 15–17); vikima 6 → ~270 herufi.
    final isLong = text.length > widget.collapsedLines * 45;
    if (!isLong) return Text(text, style: style);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: style,
          maxLines: _expanded ? null : widget.collapsedLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _expanded ? 'Punguza' : 'Soma zaidi',
              style: style.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: (style.fontSize ?? 14) - 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
