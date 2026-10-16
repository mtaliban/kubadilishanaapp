// ============================================================================
// test/paged_cache_test.dart
// SCREEN >>> CACHE >>> BASI — kila ukurasa wa orodha una funguo yake ya diski:
//   • pagedKey() inatofautisha ukurasa + vichujio
//   • write() inaandika PAPO HAPO (sync) na inaarifu listeners
//   • ukurasa uliowahi kutembelewa unasomwa KUTOKA DISKI (offline) —
//     Next/Ifuatayo haitaki mtandao kwa kurasa ulizofunguliwa awali.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/services/cached_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppCache().clear();
  });

  group('pagedKey — funguo za ukurasa', () {
    test('bila vichujio: base@p<n>', () {
      expect(CachedRepository.pagedKey('page:admin/users', 0),
          'page:admin/users@p0');
      expect(CachedRepository.pagedKey('page:admin/users', 3),
          'page:admin/users@p3');
    });

    test('na vichujio: funguo tofauti kwa vichujio tofauti', () {
      final a = CachedRepository.pagedKey('page:admin/users', 0, filterHint: 'q=ana');
      final b = CachedRepository.pagedKey('page:admin/users', 0, filterHint: 'q=juma');
      expect(a, isNot(equals(b)));
      // Vichujio vile vile + ukurasa vile vile → funguo ile ile (stable).
      expect(
          CachedRepository.pagedKey('page:admin/users', 0, filterHint: 'q=ana'),
          equals(a));
    });
  });

  group('write — andika diski PAPO HAPO', () {
    test('inahifadhi data (inasomwa baadaye — hata "stale")', () {
      final repo = CachedRepository();
      repo.write('page:admin/users@p0', {'users': [], 'total': 0});
      expect(
          repo.readOrNull<dynamic>('page:admin/users@p0'), {'users': [], 'total': 0});
    });

    test('null hairuhusiwi — hakuna data tupu kwenye diski', () {
      CachedRepository().write('page:z', null);
      expect(CachedRepository().readOrNull<dynamic>('page:z'), isNull);
    });

    test('inaongeza revision + inaarifu listeners', () {
      final repo = CachedRepository();
      var notified = 0;
      repo.addListener(() => notified++);
      final rev0 = repo.revision;
      repo.write('page:users@p1', {'users': [1]});
      expect(notified, greaterThan(0));
      expect(repo.revision, greaterThan(rev0));
      repo.removeListener(() {});
    });

    test('inaweka updatedAt (bango la "data ya HH:mm" listaonekana --:--)',
        () {
      CachedRepository().write('page:users@p2', {'users': []});
      expect(CachedRepository().updatedAt('page:users@p2'), isNotNull);
    });
  });

  group('SCREEN >>> CACHE >>> BASI — offline Next/Ifuatayo', () {
    test('ukurasa uliowahi kutembelewa unasomwa kutoka diski bila mtandao',
        () async {
      final repo = CachedRepository();
      // Mfano: ukurasa 2 ulifunguliwa wakati wa mtandao → diski.
      final key2 = CachedRepository.pagedKey('page:admin/users', 1);
      repo.write(key2, {'users': [{'full_name': 'Asha'}], 'total': 100});

      // Mtandao ukizima (API haitumiki kabisa kwenye read hii),
      // skrini ya ukurasa 2 inaweza kupata data yake PAPO HAPO:
      final cached = repo.readOrNull<dynamic>(key2);
      expect(cached, isNotNull);
      expect((cached as Map)['users'].first['full_name'], 'Asha');
    });

    test('ungua ukurasa uliotembelewa BWAWA (fresh-data path — kwa mtandao)',
        () async {
      final repo = CachedRepository();
      final key0 = CachedRepository.pagedKey('page:admin/users', 0);
      repo.write(key0, {'users': [1, 2]});
      ;

      // Ili mtumiaji aone data mpya ya ukurasa mpya, write() inaambukiza
      // setData mpya kwenye funguo kwa value mpya:
      repo.write(key0, {'users': [1, 2, 3]});
      final updated = repo.readOrNull<dynamic>(key0) as Map;
      expect(updated['users'].length, 3);
    });
  });

  group('syncAll — FULL-SYNC (pages ZOTE kwa diski)', () {
    test('inapakia kurasa zote (skip loop) kisha inaandika diski MOJO',
        () async {
      final repo = CachedRepository();
      final key = 'page:f/editors@p';
      final faked = <String, Map<String, dynamic>>{};
      final fakes = List.generate(950, (i) => {'_id': '$i', 'name': 'u$i'});
      faked[key] = {'users': fakes};

      final progress = <int>[];
      await repo.syncAll(key,
          limit: 200,
          fetchPage: (limit, skip) async => <String, dynamic>{
                'users': fakes.sublist(
                    skip, (skip + limit).clamp(0, fakes.length)),
              },
          pack: (all) => {'users': all, 'total': all.length},
          onProgress: (soFar) => progress.add(soFar.length));

      final packed = repo.readOrNull<dynamic>(key) as Map;
      expect(packed['total'], 950);
      expect((packed['users'] as List).length, 950);
      expect(progress.last, greaterThanOrEqualTo(950));
    });

    test('fetchPage yenye kosa (API pekee) — diski inabaki salama',
        () async {
      final repo = CachedRepository();
      repo.write('page:f/x@p', {'users': [1]});
      await repo.syncAll('page:f/x@p',
          fetchPage: (limit, skip) async => throw Exception('mtandao'));
      // Diski HAIBADILIKI (kanuni ya offline-first):
      final data = repo.readOrNull<dynamic>('page:f/x@p') as Map;
      expect(data['users'], [1]);
    });

    test('inamaliza kurasa mpya hituni (dedup kwa id)', () async {
      final repo = CachedRepository();
      final key = 'page:dedup';
      final page0 = List.generate(50, (i) => {'_id': '$i'});
      await repo.syncAll(key,
          limit: 50,
          maxItems: 300,
          // Server inarudisha ukurasa ULE ULE kila skip (hakuna skip effect):
          fetchPage: (limit, skip) async => page0,
          pack: (all) => {'users': all});
      final packed = repo.readOrNull<dynamic>(key) as Map;
      // Hakuna marudio ya mitihani ule ule — verification ya dedup:
      expect((packed['users'] as List).length, 50);
    });
  });
}
