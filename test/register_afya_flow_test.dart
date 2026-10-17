// ============================================================================
// test/register_afya_flow_test.dart
// UHAKIKA WA MWENDO WA 'AFYA': ukibofya kadi 'Afya' na 'Endelea', hatua
// inayofuata ni WIZARA ('Wizara ya Afya' / 'TAMISEMI'), tena 'Endelea'
// inapeleka KADA ('Chagua kada au cheo chako chaji.') — LAZIMU WAonekane
// 'Msingi'/'Sekondari' (hatua hiyo ni ya Elimu pekee).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/register_screen.dart';
import 'helpers/register_stub_repo.dart';

void main() {
  Future<void> pumpApp(WidgetTester t, RegistrationRepository repo) async {
    await t.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SafeArea(child: RegistrationFlowPage(repository: repo)),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('Afya → Wizara → Kada (CHEO); Msingi/Sekondari HAYAONEKANI',
      (t) async {
    await pumpApp(t, stubRegistrationRepository);

    // Taarifa → Idara
    await t.enterText(find.byType(TextField).first, 'Asha Mwinyi');
    final fields = find.byType(TextField);
    await t.enterText(fields.at(1), '0712345678');
    await t.enterText(fields.at(2), '0712345678');
    await t.pump();
    await t.tap(find.text('Endelea'));
    await t.pumpAndSettle();

    // IDARA: kadi ya Afya — pinda text 'Afya' ya ndani ya kadi (mfuasi)
    final afya = find.widgetWithText(InkWell, 'Afya');
    await t.tap(afya.first);
    await t.pumpAndSettle();
    await t.tap(find.text('Endelea'));
    await t.pumpAndSettle();

    // WIZARA: tuliyo pelekanishwa — siyo Msingi/Sekondari
    expect(find.text('TAMISEMI'), findsWidgets,
        reason: 'Afya inapaswa kuingia hatua ya Wizara');
    expect(find.text('Wizara ya Afya'), findsWidgets);
    expect(find.text('Msingi'), findsNothing,
        reason: 'Msingi ni ya Elimu pekee');
    expect(find.text('Sekondari'), findsNothing,
        reason: 'Sekondari ni ya Elimu pekee');

    await t.tap(find.text('TAMISEMI'));
    await t.pumpAndSettle();
    await t.tap(find.text('Endelea'));
    await t.pumpAndSettle();

    // KADA: cheo cha Afya — labels ya Elimu hazipaswi kuonekana
    expect(find.textContaining('Cheo'), findsWidgets);
    expect(find.text('Masomo ya Sekondari'), findsNothing);
    expect(find.text('Masomo ya Msingi'), findsNothing);
  });
}
