// ============================================================================
// test/forgot_number_flow_test.dart
// Mtiririko wa "Sahau namba?" (ukurasa mmoja):
//   - validation ya jina (lazima maneno 2+)
//   - tafuta kwa jina kupitia /auth/lookup-by-name (FakeApiAdapter)
//   - matokeo yanatokea CHINI ya fomu (bila kuhamia ukurasa mwingine)
//   - hakuna matokeo → kadi ya matokeo tupu
//   - "Tafuta tena" inafuta matokeo na kufuta field
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/forgot_number_screen.dart';
import 'package:kubadilishanaapp/services/api_service.dart';

import 'helpers/fake_api.dart';
import 'helpers/responsive_pump.dart';

void main() {
  setUpAll(() async {
    await bootTestEnv(routes: {
      '/auth/lookup-by-name': {
        'users': [
          {
            'full_name': 'Amani Selemani',
            'phone_primary': '+255763795805',
            'category': 'education',
            'cadre_display': 'Mwalimu',
            'is_verified': true,
          },
        ],
      },
    });
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SahauNambaScreen()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('validation — jina moja tu inaonyesha kosa', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani');
    await tester.tap(find.text('Tafuta'));
    await tester.pumpAndSettle();

    expect(find.text('Weka jina la kwanza na la mwisho.'), findsOneWidget);
    // Matokeo hayajaonekana bado.
    expect(find.text('Matokeo'), findsNothing);
  });

  testWidgets('tafuta kwa jina — matokeo yanatokea chini ya fomu',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump(); // frame ya loading
    await tester.pump(const Duration(milliseconds: 400)); // API + AnimatedSize
    await tester.pump(const Duration(
        milliseconds: 400)); // Scrollable.ensureVisible frame

    // Ukurasa UNAENDELIA hapa hapa — hakuna screen mpya iliyopushwa.
    expect(find.byType(SahauNambaScreen), findsOneWidget);
    expect(find.text('Matokeo'), findsOneWidget);
    expect(find.text('1 imepatikana'), findsOneWidget);
    expect(find.text('Nakili namba yako.'), findsOneWidget);
    // Namba imeformatiwa: +255 763 795 805
    expect(find.text('+255 763 795 805'), findsOneWidget);
    // Idara kutoka cadre_display
    expect(find.text('Mwalimu'), findsOneWidget);
    expect(find.text('Tafuta tena'), findsOneWidget);
  });

  testWidgets('"Tafuta tena" inafuta matokeo na kufuta field', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Matokeo'), findsOneWidget);

    // 'Tafuta tena' iko chini ya kadi — vilete kwenye screen kwanza
    // (viewport ya test ni 800x600, kitufe kinaweza kuwa nje ya screen).
    await tester.ensureVisible(find.text('Tafuta tena'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tafuta tena'));
    await tester.pumpAndSettle();

    expect(find.text('Matokeo'), findsNothing);
    final ctrl =
        tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(ctrl, isEmpty);
  });

  testWidgets('hakuna matokeo — kadi ya matokeo tupu inaonyeshwa',
      (tester) async {
    // Badilisha adapter kuwa na majibu yasiyo na users (mwisho wa faili —
    // mabadiliko ya singleton adapter yanaathiri tests zilizofuata).
    final api = ApiService();
    ApiService.dioForTest(api).httpClientAdapter =
        FakeApiAdapter(routes: {'/auth/lookup-by-name': {'users': []}});

    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Matokeo'), findsOneWidget);
    expect(find.text('0 imepatikana'), findsOneWidget);
    expect(find.text('Hatukupata namba kwa jina hilo.'), findsOneWidget);
  });
}
