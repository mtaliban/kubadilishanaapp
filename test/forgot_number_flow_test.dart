// ============================================================================
// test/forgot_number_flow_test.dart
// Mtiririko wa "Umesahau namba?" (skrini mbili: fomu → matokeo):
//   - validation ya jina (lazima maneno 2+)
//   - tafuta → push NambaImepatikanaScreen yenye namba + jina + kada
//   - "Tafuta tena" → inarudisha SahauNambaScreen, field inafutwa
//   - "Ingia →" → inarudisha namba kwa login (Navigator.pop(context, phone))
//   - hakuna matokeo → "Hatukupata" inaonyeshwa kwenye SahauNambaScreen
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
    // Haijapeleka kwenye skrini ya matokeo
    expect(find.text('Namba imepatikana'), findsNothing);
  });

  testWidgets('tafuta kwa jina — NambaImepatikanaScreen inaonyeshwa',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump(); // loading frame
    await tester.pump(const Duration(milliseconds: 400)); // API response
    await tester.pumpAndSettle(); // navigation animation

    // Skrini mpya imepushwa — "Namba imepatikana" inaonekana
    expect(find.text('Namba imepatikana'), findsOneWidget);
    expect(find.text('Hii ndiyo namba uliyojisajili nayo.'), findsOneWidget);
    // Namba imeformatiwa
    expect(find.text('+255 763 795 805'), findsOneWidget);
    // Kada kutoka cadre_display
    expect(find.text('Mwalimu'), findsOneWidget);
    // Kitufe cha Tafuta tena kipo
    expect(find.text('Tafuta tena'), findsOneWidget);
    // Kitufe cha Ingia kipo
    expect(find.text('Ingia'), findsOneWidget);
  });

  testWidgets('"Tafuta tena" inarudisha fomu na kufuta field', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Namba imepatikana'), findsOneWidget);

    // Rudi nyuma kwa "Tafuta tena"
    await tester.tap(find.text('Tafuta tena'));
    await tester.pumpAndSettle();

    // Skrini ya fomu inarudi — "Namba imepatikana" haitakiwi tena
    expect(find.text('Namba imepatikana'), findsNothing);
    // Field imefutwa
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('"Ingia" inarudisha namba kwa caller (login screen)',
      (tester) async {
    String? poppedPhone;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () async {
            poppedPhone = await Navigator.of(ctx).push<String>(
              MaterialPageRoute(
                  builder: (_) => const SahauNambaScreen()),
            );
          },
          child: const Text('Fungua'),
        ),
      ),
    ));

    await tester.tap(find.text('Fungua'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Namba imepatikana'), findsOneWidget);

    await tester.tap(find.text('Ingia'));
    await tester.pumpAndSettle();

    // Namba ilirudi kwa caller bila kuongezwa nafasi
    expect(poppedPhone, isNotNull);
    expect(poppedPhone, startsWith('+255'));
  });

  testWidgets('hakuna matokeo — "Hatukupata" inaonyeshwa kwenye fomu',
      (tester) async {
    final api = ApiService();
    ApiService.dioForTest(api).httpClientAdapter =
        FakeApiAdapter(routes: {'/auth/lookup-by-name': {'users': []}});

    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Amani Selemani');
    await tester.tap(find.text('Tafuta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Hakuna navigation — kadi ya "Hatukupata" inaonyeshwa ndani ya fomu
    expect(find.text('Hatukupata'), findsOneWidget);
    expect(find.text('Hatukupata namba kwa jina hilo.'), findsOneWidget);
    expect(find.text('Namba imepatikana'), findsNothing);
  });
}
