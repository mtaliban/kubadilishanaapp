import 'package:flutter_test/flutter_test.dart';
import 'package:kubadilishanaapp/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KubadilishanaApp());
    expect(find.text('Kubadilishana'), findsOneWidget);
  });
}
