// ============================================================================
// test/register_stress_test.dart
// TESTING NGUMU — usajili: pembeni kali za uga (emoji, herufi maalum, nafasi
// tupu, namba fupi), ujumbe CHINI ya uga husika, auto-dismiss, na regression
// ya bug kuu: repo.submit ILIPUUZA matokeo ya API — sasa lazima itupe.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/screens/register_repo.dart';
import 'package:kubadilishanaapp/screens/register_screen.dart';
import 'package:kubadilishanaapp/widgets/app_toast.dart';

// ── Repo bandia — instantaneous API (hakuna mtandao kwenye tests) ────────────
class _StubRepo implements RegistrationRepository {
  @override
  Future<bool> isPhoneAvailable(String phone) async => true;
  @override
  Future<List<RegOption>> regions() async => [RegOption(id: '1', label: 'Mkoa')];
  @override
  Future<List<RegOption>> districts(RegOption region) async =>
      [RegOption(id: '11', label: 'Wilaya')];
  @override
  Future<List<RegOption>> schools(RegOption district) async =>
      [RegOption(id: '111', label: 'Shule')];
  @override
  Future<List<RegOption>> facilities(RegOption district) async =>
      [RegOption(id: '111', label: 'Kituo')];
  @override
  Future<List<RegOption>> referralHospitals(RegOption region) async =>
      [RegOption(id: '9', label: 'Hospitali')];
  @override
  Future<List<RegOption>> cadres() async =>
      [RegOption(id: 'DOC', label: 'Daktari')];
  @override
  Future<List<RegOption>> subjects(EduLevel level) async =>
      [RegOption(id: 'M1', label: 'Hisabati')];
  @override
  Future<void> submit(RegistrationData data) async {}
}

void main() {
  setUp(() {
    AppToast.current.value = null;
  });

  // Skrini ndefu — footer ('Endelea') ikonekane popote tests zinaipiga.
  Future<void> pumpApp(WidgetTester t, RegistrationRepository repo) async {
    await t.binding.setSurfaceSize(const Size(600, 2200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SafeArea(child: RegistrationFlowPage(repository: repo)),
      ),
    ));
  }

  Future<void> tapEndelea(WidgetTester t) async {
    await t.tap(find.text('Endelea'));
    await t.pump();
  }

  testWidgets('Endelea bila kujaza chochote — kila uga tupu una ujumbe WAKE '
      'chini yake (si tena "jina" pekee daima)', (t) async {
    await pumpApp(t, _StubRepo());
    await tapEndelea(t);
    await t.pumpAndSettle();

    expect(find.text('Jaza jina lako kamili.'), findsOneWidget);
    expect(find.text('Jaza namba ya simu (mf. 07xxxxxxxx).'), findsOneWidget);
    expect(
        find.text('Jaza namba ya WhatsApp (mf. 07xxxxxxxx).'), findsOneWidget);
  });

  testWidgets('Pembeni kali: emoji + herufi maalum + SQL-ish — app haivunjika '
      'na kosa linahama kutoka kwa jina kwenda namba', (t) async {
    await pumpApp(t, _StubRepo());

    const weird = '🚑🔥 Asha Mwinyi — (wa COVID.*\\n; DROP TABLE users;--';
    await t.enterText(find.byType(TextField).first, weird);
    await t.pump();
    await tapEndelea(t);
    await t.pumpAndSettle();

    // Jina sasa kipo — kosa lake limetoka; namba ndiyo yenye kosa wake
    expect(find.text('Jaza jina lako kamili.'), findsNothing);
    expect(find.text('Jaza namba ya simu (mf. 07xxxxxxxx).'), findsOneWidget);
  });

  testWidgets('Nafasi tupu ("   ") = jina lililoachwa wazi', (t) async {
    await pumpApp(t, _StubRepo());
    await t.enterText(find.byType(TextField).first, '   ');
    await tapEndelea(t);
    await t.pumpAndSettle();
    expect(find.text('Jaza jina lako kamili.'), findsOneWidget);
  });

  testWidgets('Namba fupi ("0712") — ujumbe wake wenye: "Namba ya simu si '
      'kamili."', (t) async {
    await pumpApp(t, _StubRepo());
    await t.enterText(find.byType(TextField).first, 'Asha Mwinyi');
    final fields = find.byType(TextField);
    await t.enterText(fields.at(1), '0712'); // simu fupi
    await t.pump();
    await tapEndelea(t);
    await t.pumpAndSettle();

    expect(find.text('Namba ya simu si kamili.'), findsOneWidget);
    expect(find.text('Jaza namba ya simu (mf. 07xxxxxxxx).'), findsNothing);
  });

  testWidgets('AUTO-DISMISS: makosa hutoka pekee yenyewe baada ya sekunde 5',
      (t) async {
    await pumpApp(t, _StubRepo());
    await tapEndelea(t);
    await t.pumpAndSettle();
    expect(find.text('Jaza jina lako kamili.'), findsOneWidget);

    await t.pump(const Duration(seconds: 5, milliseconds: 100));
    expect(find.text('Jaza jina lako kamili.'), findsNothing);
  });

  testWidgets('Mtumiaji anapoanza kurekebisha, kosa la uga husika linapotea '
      '(auto-clear on typing)', (t) async {
    await pumpApp(t, _StubRepo());
    await tapEndelea(t);
    await t.pumpAndSettle();
    expect(find.text('Jaza jina lako kamili.'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 'Asha Mwinyi');
    await t.pump();
    expect(find.text('Jaza jina lako kamili.'), findsNothing);
  });

  testWidgets('REGRESSION YA BUG KUU: RealRegistrationRepository.submit '
      'ikiwa API itafeli — lazima itupe RegisterException '
      '(zamani ilifanikiwa kimya kimy na akaunti haikuandikwa — '
      'ndiyo sababu watumiaji hawakuonekana kwenye orodha)',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final repo = RealRegistrationRepository();
    final data = RegistrationData(
      name: 'Mtumiaji 2025',
      phone: '0711000999',
      whatsapp: '0711000998',
      idara: 'Afya',
      region: RegOption(id: '1', label: 'Mkoa'),
      targets: const [],
      years: 'Mwaka 1',
    );

    // Mtandao HAUPATIKANI kwenye test — AuthProvider.register inarejesha
    // false → repo lazima itupe RegisterException.
    await expectLater(
      repo.submit(data),
      throwsA(isA<RegisterException>()),
    );
  });
}
