// ============================================================================
// test/drawer_overflow_test.dart
// Ukaguzi wa drawer (code ya kuchaguliwa — muundo wa gazeti, bluu pekee):
// font kubwa ya mfumo (textScaleFactor 2.0) ISIHARIBUI drawer (overflow) —
// drawer mwenyewe inafunga textScaler ≤ 1.0 ndani yake, kwa hivyo rows zote
// zibaki kwa ukubwa wao wa awali bila RenderFlex overflow.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/widgets/app_drawer.dart';

void _noopSelect(String label) {}
void _noop() {}

void main() {
  testWidgets('Drawer: font kubwa 2.0 haivunji drawer (textScaler ≤ 1.0)',
      (tester) async {
    // Simu yenye font kubwa ya mfumo (accessibility scale 2.0).
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        drawer: AppDrawer(
          selected: 'Takwimu',
          onSelect: _noopSelect,
          onLogout: _noop,
        ),
        body: SizedBox.shrink(),
      ),
    ));
    await tester.pump();
    final dynamic state = tester.state(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();

    // Drawer ionekane: kila kipengee chake kionekane.
    expect(find.text('Kubadilishana'), findsOneWidget);
    expect(find.text('Takwimu'), findsOneWidget);
    expect(find.text('Maoni na malalamiko'), findsOneWidget);
    expect(find.text('Wasifu wangu'), findsOneWidget);
    expect(find.text('Toka'), findsOneWidget);

    // Hakuna RenderFlex overflow — flutter_test inatupa exception ikiwa
    // widget tree imekatika; takeException lazima iwe null.
    expect(tester.takeException(), isNull,
        reason: 'Drawer inapaswa kubaki bila overflow hata font 2.0');
  });

  testWidgets('Drawer: nikibofya "Maoni na malalamiko", onSelect inapokea', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        drawer: AppDrawer(
          selected: 'Takwimu',
          onSelect: (label) => picked = label,
          onLogout: _noop,
        ),
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maoni na malalamiko'));
    await tester.pumpAndSettle();
    expect(picked, 'Maoni na malalamiko');
  });
}
