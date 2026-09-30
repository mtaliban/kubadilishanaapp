// ============================================================================
// test/forgot_number_flow_test.dart
// Mtiririko wa "Sahau namba?" (kadi moja inabadilika):
//   - validation ya jina (lazima maneno 2+)
//   - tafuta kwa jina → kadi inabadilika "Namba imepatikana" (AnimatedSwitcher)
//   - namba + jina + kada zinaonyeshwa kwenye kadi ile ile
//   - hakuna matokeo → kadi inabadilika "Hatukupata"
//   - "Tafuta tena" inafuta matokeo na kufuta field (kadi inarudi search)
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
    // Kadi ya matokeo haijabadilika — bado iko kwenye hali ya search.
    expect(find.text('Namba imepatikana'), findsNothing);
  });

  testWidgets('tafuta kwa jina — kadi inabadilika na kuonyesha namba',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump(); // frame ya loading
    await tester.pump(const Duration(milliseconds: 400)); // API + AnimatedSwitcher
    await tester.pump(const Duration(milliseconds: 400)); // AnimatedSize

    // Ukurasa UNAENDELIA hapa hapa — hakuna screen mpya iliyopushwa.
    expect(find.byType(SahauNambaScreen), findsOneWidget);
    // Kadi ile ile inabadilika kuwa "Namba imepatikana"
    expect(find.text('Namba imepatikana'), findsOneWidget);
    expect(find.text('Hii ndiyo namba uliyojisajili nayo.'), findsOneWidget);
    // Namba imeformatiwa: +255 763 795 805
    expect(find.text('+255 763 795 805'), findsOneWidget);
    // Kada kutoka cadre_display
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
    expect(find.text('Namba imepatikana'), findsOneWidget);

    // 'Tafuta tena' iko ndani ya kadi — vilete kwenye screen kwanza
    await tester.ensureVisible(find.text('Tafuta tena'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tafuta tena'));
    await tester.pumpAndSettle();

    // Kadi inarudi hali ya search — "Namba imepatikana" haipo tena
    expect(find.text('Namba imepatikana'), findsNothing);
    final ctrl =
        tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(ctrl, isEmpty);
  });

  testWidgets('hakuna matokeo — kadi inabadilika "Hatukupata"',
      (tester) async {
    // Badilisha adapter kuwa na majibu yasiyo na users
    final api = ApiService();
    ApiService.dioForTest(api).httpClientAdapter =
        FakeApiAdapter(routes: {'/auth/lookup-by-name': {'users': []}});

    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Kadi inabadilika kuwa "Hatukupata" (si "Namba imepatikana")
    expect(find.text('Hatukupata'), findsOneWidget);
    expect(find.text('Hatukupata namba kwa jina hilo.'), findsOneWidget);
  });
}
