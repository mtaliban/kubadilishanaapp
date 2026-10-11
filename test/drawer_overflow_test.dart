// ============================================================================
// test/drawer_overflow_test.dart
// Ukaguzi wa drawer: font kubwa ya mfumo (textScaleFactor 2.0) ISIHARIBUI
// drawer (overflow) — font-latch ya textScaler ≤ 1.0 (mockup) inapaswa
// kufanya rows zote zibaki kwa ukubwa wao wa awali bila RenderFlex overflow.
// Overflow yoyote kwenye widget tree inatupwa na flutter_test kama exception
// kwenye takeException — tunadai hakuna.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/widgets/app_drawer.dart';

void main() {
  testWidgets('Drawer: font kubwa 2.0 haivunji drawer (font-latch ≤ 1.0)',
      (tester) async {
    // Simu yenye font kubwa ya mfumo (accessibility scale 2.0).
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        drawer: AppDrawer(
          logo: Center(child: Text('ES')),
          userName: 'Hamisi Selemani Hamisi',
          current: NavItem.takwimu,
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
}

void _noopSelect(NavItem item) {}
void _noop() {}
