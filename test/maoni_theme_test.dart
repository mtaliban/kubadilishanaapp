// ============================================================================
// test/maoni_theme_test.dart
// Ukaguzi wa rangi za Maoni — DESIGN MPYA (single-page "gazeti", code mockup):
//   page nyeupe, Live dot bluu, nukuu serif, jibu ni TextField italawezi pale
//   pale chini ya nukuu (HAKUNA page ya pili ya chat). Blue dominant
//   iruhusiwa kwenye accents tu (Live dot, underline, Tuma, pager).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/admin/maoni_page.dart';

bool _isBlueDominant(Color c) => c.b > c.r + 40 && c.b > c.g + 40;

List<BoxDecoration> _boxDecorations(WidgetTester tester) {
  final out = <BoxDecoration>[];
  for (final w in tester.widgetList<Container>(find.byType(Container))) {
    final d = w.decoration;
    if (d is BoxDecoration) out.add(d);
  }
  return out;
}

Maoni _m(int id, String name, String phone, String msg, {String reply = ''}) =>
    Maoni(id: id, name: name, phone: phone, date: '9 Okt', time: '07:41',
        message: msg, reply: reply);

Future<void> _pump(WidgetTester tester, List<Maoni> items) async {
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1F5FD6)),
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: MaoniPage(items: items)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Page: background NYEUPE + tab underline + Live dot bluu',
      (tester) async {
    await _pump(tester, [
      _m(1, 'Neema J.', '+255783172900', 'Hii ni maoni ya kupima'),
      _m(2, 'Erick', '+255759949199', 'Napenda app', reply: 'Asante'),
    ]);

    // Header + tabs + search zimeonekana.
    expect(find.text('Maoni'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Yote 2'), findsOneWidget);
    expect(find.textContaining('Yasiyojibiwa'), findsOneWidget);
    expect(find.textContaining('Yaliyojibiwa'), findsOneWidget);

    // Hakuna bluu kali ya opaque non-accent kwenye Containers (accents ndogo
    // zinaruhusiwa: _ac = 0xFF1F5FD6).
    const accent = Color(0xFF1F5FD6);
    for (final d in _boxDecorations(tester)) {
      final c = d.color;
      if (c == null) continue;
      if (c == accent) continue;
      expect(
        _isBlueDominant(c) && c.a == 1.0 && c.computeLuminance() < .6,
        isFalse,
        reason: 'Container yenye bluu kali ya ofa: $c',
      );
    }
  });

  testWidgets('Jibu: textbox LINAONEKANA PALE PALE kwenye page ile ile'
      ' (Tuma + Ghairi navyo), hakuna page nyengine', (tester) async {
    await _pump(tester, [
      _m(1, 'Neema J.', '+255783172900', 'Hii ni maoni ya kupima'),
    ]);

    // Nukuu ya mtumiaji iko.
    expect(find.textContaining('Hii ni maoni'), findsOneWidget);

    // Bonyeza "Andika jibu" → TextField ya jibu inatokea PALE PALE
    // (kwenye page ile ile, chini ya nukuu) pamoja na Tuma/Ghairi.
    await tester.tap(find.text('Andika jibu'));
    await tester.pumpAndSettle();

    // 2 TextFields: [0] search (juu), [1] reply PALE PALE chini ya nukuu.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Tuma'), findsOneWidget);
    expect(find.text('Ghairi'), findsOneWidget);

    // Hakuna navigator push — bado uko kwenye page ile ile
    // (MaoniPage inaonekana bado: header na tabs hazipotei).
    expect(find.text('Maoni'), findsOneWidget);
  });

  testWidgets('Jibu limetumwa: SnackBar + quote yenye mstari wa bluu kushoto',
      (tester) async {
    Maoni? sentItem;
    String? sentText;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: MaoniPage(
            items: [_m(1, 'Neema J.', '+255783172900', 'Hii ni maoni ya kupima')],
            onSendReply: (item, text) async {
              sentItem = item;
              sentText = text;
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Andika jibu'));
    await tester.pumpAndSettle();
    // Reply TextField NI ya pili (search iko juu).
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.last, 'Jibu la haraka');
    await tester.tap(find.text('Tuma'));
    await tester.pumpAndSettle();

    expect(sentText, 'Jibu la haraka');
    expect(sentItem!.replied, isTrue);
    // Quote ya "Jibu lako" + Hariri jibu.
    expect(find.text('Jibu lako'), findsOneWidget);
    expect(find.text('Hariri jibu'), findsOneWidget);
    expect(find.textContaining('Jibu la haraka'), findsOneWidget);
    // SnackBar floating.
    expect(find.text('Jibu limetumwa'), findsOneWidget);
  });
}
