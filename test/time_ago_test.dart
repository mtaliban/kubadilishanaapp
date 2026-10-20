// ============================================================================
// test/time_ago_test.dart
// Helper ya muda uliopita (lib/widgets/time_ago.dart) — kanuni za WhatsApp:
//   'Sasa hivi' (<1 dak), 'dak X' (<saa 1), 'saa X' (<saa 24), 'Jana'
//   (<saa 48), 'siku X' (<siku 30), halafu 'd Mon' (zamani zaidi).
// Pure unit tests — hakuna widgets, wakati LAZIMA uwe fixed {at: …}.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/widgets/time_ago.dart';

DateTime _ref() => DateTime(2026, 10, 20, 14, 0); // 20 Okt 2026, 14:00 (fixed)

DateTime _iso(int minutesAgo) => _ref().subtract(Duration(minutes: minutesAgo));

void main() {
  group('timeAgoShortFromDateTime — fixed clock', () {
    test('sekunde chache → "Sasa hivi"', () {
      expect(timeAgoShortFromDateTime(_iso(0), at: _ref()), 'Sasa hivi');
      // 59 sekunde = 0 dakika kamili (int truncation) → "Sasa hivi".
      expect(timeAgoShortFromDateTime(_ref().subtract(const Duration(seconds: 59)), at: _ref()), 'Sasa hivi');
    });

    test('mbele-o-mbele (future) → "Sasa hivi" (salama, hakuna koroma)', () {
      expect(
        timeAgoShortFromDateTime(_ref().add(const Duration(hours: 5)),
            at: _ref()),
        'Sasa hivi',
      );
    });

    test('dakika < 60 → "dak X"', () {
      expect(timeAgoShortFromDateTime(_iso(1), at: _ref()), 'dak 1');
      expect(timeAgoShortFromDateTime(_iso(7), at: _ref()), 'dak 7');
      expect(timeAgoShortFromDateTime(_iso(59), at: _ref()), 'dak 59');
    });

    test('saa < 24 → "saa X"', () {
      expect(timeAgoShortFromDateTime(_iso(60), at: _ref()), 'saa 1');
      expect(timeAgoShortFromDateTime(_iso(144), at: _ref()), 'saa 2'); // 2h24m
      expect(timeAgoShortFromDateTime(_iso(23 * 60 + 59), at: _ref()), 'saa 23');
    });

    test('saa < 48 → "Jana"', () {
      expect(timeAgoShortFromDateTime(_iso(24 * 60), at: _ref()), 'Jana');
      expect(timeAgoShortFromDateTime(_iso(47 * 60 + 59), at: _ref()), 'Jana');
    });

    test('siku < 30 → "siku X"', () {
      expect(timeAgoShortFromDateTime(_iso(48 * 60), at: _ref()), 'siku 2');
      expect(timeAgoShortFromDateTime(_iso(29 * 24 * 60), at: _ref()), 'siku 29');
    });

    test('zaidi ya siku 30 → "d Mon" (siku + mwezi kwa Kiswahili)', () {
      expect(timeAgoShortFromDateTime(_iso(30 * 24 * 60), at: _ref()), '20 Sep');
      expect(timeAgoShortFromDateTime(
        DateTime(2026, 2, 3),
        at: _ref(),
      ), '3 Feb');
    });

    test('ISO tupu / mbaya → "" (UI inaonyesha kinachofaa, hakuna crash)', () {
      expect(timeAgoShort(''), '');
      expect(timeAgoShort('siyo-tarehe'), '');
    });

    test('timeAgoShort — ISO halisi (UTC + local) inapita', () {
      // 20:00 UTC = 23:00 EAT (UTC+3) — saa 15 kabla ya ref.
      expect(
        timeAgoShortFromDateTime(
          DateTime.parse('2026-10-20T11:00:00Z'),
          at: DateTime.parse('2026-10-20T14:00:00Z'),
        ),
        'saa 3',
      );
    });
  });
}
