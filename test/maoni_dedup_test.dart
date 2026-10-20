// ============================================================================
// test/maoni_dedup_test.dart
// DEDUP ya Maoni — "maneno yanajirudia" (kasoro halisi):
// app ya user inatuma subject = herufi 60 za kwanza za ujumbe mwenyewe —
// kadi ilionyesha maneno YALE YALE mara mbili ("Okay\nOkay").
// Zinakagua: subject mwenzo wa ujumbe / ndani ya ujumbe / case tofauti —
// moja tu inaonyeshwa, bila kuharibu maoni HALISI yenye subject alikuya.
// Zinatumia maoniFromFeedbackForTest (@visibleForTesting kwenye maoni_page).
// ============================================================================
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/admin/maoni_page.dart';

void main() {
  group('Maoni DEDUP — subject/message hazijirudii', () {
    test('subject == ujumbe → ujumbe moja tu', () {
      final m = maoniFromFeedbackForTest({
        'subject': 'Okay kasoro',
        'message': 'Okay kasoro',
      }, 1);
      expect(m.text, 'Okay kasoro');
    });

    test('subject ni MWANZO (prefix) wa ujumbe → ujumbe moja tu', () {
      final m = maoniFromFeedbackForTest({
        'subject': 'Okay kasoro ya malipo',
        'message': 'Okay kasoro ya malipo yangu yamekataa',
      }, 1);
      expect(m.text, 'Okay kasoro ya malipo yangu yamekataa');
    });

    test('subject prefix na vitone ("...") ya truncation → moja tu', () {
      final m = maoniFromFeedbackForTest({
        'subject': 'Okay kasoro ya malipo...',
        'message': 'Okay kasoro ya malipo yangu yamekataa',
      }, 1);
      expect(m.text, 'Okay kasoro ya malipo yangu yamekataa');
    });

    test('CASE TOFAUTI ("okay" vs "OKAY") — bado hakuna kurudia', () {
      final m = maoniFromFeedbackForTest({
        'subject': 'okay kasoro ya malipo',
        'message': 'OKAY kasoro ya malipo yangu yamekataa',
      }, 1);
      expect(m.text, 'OKAY kasoro ya malipo yangu yamekataa');
    });

    test('subject ndani ya MWANZO wa ujumbe hata kama si herufi ya kwanza '
        '(ujumbe unaanza na maneno mengine) → MOJA tu', () {
      final m = maoniFromFeedbackForTest({
        'subject': 'kasoro ya malipo',
        'message': 'Hii ni kasoro ya malipo kubwa kwenye app',
      }, 1);
      // subject iko NDANI ya ujumbe — ujumbe tu (usifute contents halisi).
      expect(m.text, 'Hii ni kasoro ya malipo kubwa kwenye app');
    });

    // TABIA MPYA (kasoro ya picha: "Mimi mgeni wadau..." ulijirudia mara mbili
    // kwenye kadi): ujumbe wa mtumiaji uonyeshwe MARA MOJA TU — message pekee
    // (subject kama prefix wake hupuuzwa kabisa; kwa kadi zilizokwisha jibiwa
    // admin huonyesha ujumbe WOTE kwa "Soma zaidi", esuba ya kichwa haihitajiki).
    test('maoni HALISI: subject yoyote — ujumbe (message) moja tu', () {
      final m = maoniFromFeedbackForTest({
        'subject': 'Malipo yangu',
        'message': 'Changia langu limekataliwa kwa kosa la mtandao',
      }, 1);
      expect(m.text, 'Changia langu limekataliwa kwa kosa la mtandao');
    });

    test('subject=ellipsis ("Mimi mgeni wadau…") + message kamili → message tu', () {
      final m = maoniFromFeedbackForTest({
        'subject': 'Mimi mgeni wadau. Je kwani kuna utaratibu wa kulipia naona n\u2026',
        'message':
            'Mimi mgeni wadau. Je kwani kuna utaratibu wa kulipia naona nimeandikiwa hajalipa',
      }, 1);
      expect(m.text,
          'Mimi mgeni wadau. Je kwani kuna utaratibu wa kulipia naona nimeandikiwa hajalipa');
    });

    test('subject tupu, message tu → message tu', () {
      final m = maoniFromFeedbackForTest({
        'subject': '',
        'message': 'Sawaa',
      }, 1);
      expect(m.text, 'Sawaa');
    });

    test('ujumbe tupu → "(tupu)" (hakuna kadi tupu)', () {
      final m = maoniFromFeedbackForTest({
        'subject': '',
        'message': '',
      }, 1);
      expect(m.text, '(tupu)');
    });
  });
}
