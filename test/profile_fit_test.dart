import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kubadilishanaapp/screens/admin/admin_profile_page.dart';

void main() {
  testWidgets('Hifadhi + Ghairi zote zinaonekana kwenye 360px (screen ndogo)', (tester) async {
    // Rafu ndogo kama simu ya mtumiaji (360 logical px)
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminProfilePage(
          fullName: 'Hamisi S',
          phone: '+255763795801',
          onSave: (a, b, c, d) async => true,
        ),
      ),
    ));
    // Bonyeza Hariri (pencil ya Tabler) → action bar inatokea
    await tester.tap(find.byIcon(TablerIcons.pencil, skipOffstage: false).last);
    await tester.pumpAndSettle();

    final ghairi = tester.getRect(find.text('Ghairi'));
    final hifadhi = tester.getRect(find.text('Hifadhi'));
    // Zote mbili zinaonekana ndani ya viewport 360 na HIFADHI NI KULIA
    expect(hifadhi.right, lessThanOrEqualTo(360), reason: 'HIFADHI IMEJITOKEA NJE-KULIA');
    expect(hifadhi.left, greaterThan(ghairi.right), reason: 'Hifadhi iwe kulia ya Ghairi');
    expect(ghairi.left, greaterThanOrEqualTo(0));
  });
}
