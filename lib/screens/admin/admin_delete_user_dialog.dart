import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Dirisha dogo la mraba la kuthibitisha kufuta.
/// Inarudisha true mtumiaji akibonyeza "Futa".
///
/// Mfano:
///   final ok = await showDeleteUserDialog(context, name: 'Benedictor Makono');
///   if (ok) { /* futa kwenye API */ }
Future<bool> showDeleteUserDialog(BuildContext context, {required String name}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => _DeleteDialog(name: name),
  );
  return res ?? false;
}

class _DeleteDialog extends StatelessWidget {
  final String name;
  const _DeleteDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF181D26) : Colors.white;
    final text = dark ? const Color(0xFFEEF1F6) : const Color(0xFF111827);
    final muted = dark ? const Color(0xFFA8B1C1) : const Color(0xFF5B6475);
    final soft = dark ? const Color(0xFF212833) : const Color(0xFFF1F3F7);
    final red = dark ? const Color(0xFFFF8A8A) : const Color(0xFFC62828);
    final redBg = dark ? const Color(0xFF3A1D1F) : const Color(0xFFFDECEC);

    Widget btn(String label, Color fg, Color bg, bool value) => Expanded(
          child: SizedBox(
            height: 30,
            child: TextButton(
              onPressed: () => Navigator.pop(context, value),
              style: TextButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: fg,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
              child: Text(label),
            ),
          ),
        );

    return Dialog(
      backgroundColor: card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 250,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: redBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(TablerIcons.trash, size: 20, color: red),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: TextStyle(color: text, fontSize: 15),
                  children: [
                    const TextSpan(text: 'Futa '),
                    TextSpan(
                        text: name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const TextSpan(text: '?'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text('Haiwezi kutenduliwa',
                  style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 14),
              Row(
                children: [
                  btn('Ghairi', muted, soft, false),
                  const SizedBox(width: 6),
                  btn('Futa', red, redBg, true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
