// ============================================================================
// test/maoni_theme_test.dart
// Ukaguzi wa rangi za Maoni (inbox + chat) — BACKGROUND NYEUPE KABISA kama
// WhatsApp: inbox nyeupe, chat nyeupe, incoming bubble nyeupe (kivuli tu),
// outgoing beige safi (E7E1D6), quote tint hazina bluu kali.
// Inatumia InMemoryMaoniRepository.demo() na kunakagua Container decorations
// halisi kwenye widget tree.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/admin/maoni_pages.dart';

bool _isBlueDominant(Color c) => c.b > c.r + 40 && c.b > c.g + 40;

/// Kusanya Container zote zenye BoxDecoration yenye rangi.
List<BoxDecoration> _boxDecorations(WidgetTester tester) {
  final out = <BoxDecoration>[];
  for (final w in tester.widgetList<Container>(find.byType(Container))) {
    final d = w.decoration;
    if (d is BoxDecoration) out.add(d);
  }
  return out;
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MaoniInboxPage(repo: InMemoryMaoniRepository.demo()),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openChat(WidgetTester tester) async {
  await _pump(tester);
  final row = find.textContaining('Godwin').first;
  expect(row, findsOneWidget, reason: 'Mazungumzo ya demo yanapaswa kuonekana');
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Inbox: background NYEUPE (Container mweupe) + hakuna bluu kali',
      (tester) async {
    await _pump(tester);
    expect(find.text('Maoni'), findsOneWidget);

    final decos = _boxDecorations(tester);
    expect(
      decos.any((d) => d.color == Colors.white),
      isTrue,
      reason: 'Inbox inapaswa kuwa na Container background nyeupe',
    );
    // Hakuna bluu kali (opaque, blue-dominant) kwenye inbox yote.
    for (final d in decos) {
      final c = d.color;
      if (c == null) continue;
      expect(
        _isBlueDominant(c) && c.a == 1.0 && c.computeLuminance() < .8,
        isFalse,
        reason: 'Inbox ina Container yenye bluu kali: $c',
      );
    }
  });

  testWidgets('Chat: incoming bubble NI NYEUPE + hakuna bluu kali',
      (tester) async {
    await _openChat(tester);

    // Chat inaonyesha jumbe za mtumiaji ("sawa").
    expect(find.textContaining('sawa'), findsWidgets);

    final decos = _boxDecorations(tester);
    // Incoming bubble (WhatsApp) = Container nyeupe yenye border.
    expect(
      decos.any((d) =>
          d.color == Colors.white &&
          d.border != null &&
          d.borderRadius != null),
      isTrue,
      reason: 'Bubble ya inayoingia inapaswa kuwa NYEUPE yenye mstari',
    );
    for (final d in decos) {
      final c = d.color;
      if (c == null) continue;
      expect(
        _isBlueDominant(c) && c.a == 1.0 && c.computeLuminance() < .8,
        isFalse,
        reason: 'Chat ina Container yenye bluu kali: $c',
      );
    }
  });

  testWidgets('Chat: outgoing bubble ni beige (E7E1D6 range), siyo bluu',
      (tester) async {
    await _openChat(tester);

    final beige = decosAfter(tester);
    expect(
      beige.any((c) {
        // beige: r>g>b, luminance kati ya .7 na .95
        final lum = c.computeLuminance();
        return c.r > c.g && c.g > c.b && lum > .7 && lum < .95 && c.a == 1.0;
      }),
      isTrue,
      reason: 'Bubble ya outgoing inapaswa kuwa beige (sent ya WhatsApp)',
    );
  });

  testWidgets('Filter wa inbox: chip haijawi bluu kali', (tester) async {
    await _pump(tester);
    final chipLabel = find.textContaining('Hayajajibiwa');
    expect(chipLabel, findsOneWidget);

    for (final w in tester.widgetList<Container>(
        find.ancestor(of: chipLabel, matching: find.byType(Container)))) {
      final d = w.decoration;
      if (d is BoxDecoration && d.color != null && d.borderRadius != null) {
        final c = d.color!;
        expect(
          _isBlueDominant(c) && c.a == 1.0 && c.computeLuminance() < .8,
          isFalse,
          reason: 'Chip ina bluu kali: $c',
        );
      }
    }
  });
}

List<Color> decosAfter(WidgetTester tester) {
  final colors = <Color>[];
  for (final w in tester.widgetList<Container>(find.byType(Container))) {
    final d = w.decoration;
    if (d is BoxDecoration && d.color != null) colors.add(d.color!);
  }
  return colors;
}
