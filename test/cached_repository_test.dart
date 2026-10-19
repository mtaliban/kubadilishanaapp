// ============================================================================
// test/cached_repository_test.dart
// CachedRepository — diski-kwanza, updatedAt, refresh nyuma ya pazia,
// kosa la API halibadiliki skrini, request dedup.
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

  group('CachedRepository — read (diski pekee)', () {
    test('readOrNull inarejesha null kama hakuna data kwenye diski', () {
      expect(CachedRepository().readOrNull<dynamic>('page:x'), isNull);
    });

    test('read inatupa NoCachedData kama hakuna data kabisa', () {
      expect(() => CachedRepository().read<dynamic>('page:x'),
          throwsA(isA<NoCachedData>()));
    });

    test('read inasoma data iliyohifadhiwa (AppCache.getStale)', () {
      AppCache().set('page:x', {'a': 1});
      expect(CachedRepository().readOrNull<dynamic>('page:x'), {'a': 1});
    });
  });

  group('CachedRepository — refresh (nyuma ya pazia)', () {
    test('ikifaulu: inaandika diski + inahifadhi updatedAt + inaarifu', () async {
      final repo = CachedRepository();
      var notified = 0;
      repo.addListener(() => notified++);

      await repo.refresh('page:y', () async => {'ok': true});

      expect(repo.readOrNull<dynamic>('page:y'), {'ok': true});
      expect(repo.updatedAt('page:y'), isNotNull);
      expect(notified, 1);
    });

    test('ikishindwa (API inatupa): hakibadilishi diski wala skrini',
        () async {
      final repo = CachedRepository();
      AppCache().set('page:z', {'old': true}, ttl: const Duration(days: 1));
      var notified = 0;
      repo.addListener(() => notified++);
      final revBefore = repo.revision;

      await repo.refresh('page:z', () async => throw Exception('offline'));

      // Data ya zamani inabaki — hakuna kitu kimebadilika.
      expect(repo.readOrNull<dynamic>('page:z'), {'old': true});
      expect(repo.revision, revBefore);
      expect(notified, 0);
    });

    test('mwaliwa wa pili aliyejiuja WAKATI fetch inaendelea anapata FRESH',
        () async {
      // KANUNI MPYA (kasoro ya "badge inaonyesha kitu mpya, orodha HAIONSHEKI"):
      // Ombi la KALE (lililoanza kwanza) lilirejesha data ya KABLA ya tukio —
      // yule aliyeingia JUU lake hupata fetch FRESH (data ya BAADA ya tukio).
      final repo = CachedRepository();
      var calls = 0;
      Future<dynamic> fetch() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return {'n': calls};
      }

      await Future.wait([
        repo.refresh('page:d', fetch),
        repo.refresh('page:d', fetch),
      ]);

      expect(calls, 2);
      expect(repo.readOrNull<dynamic>('page:d'), {'n': 2});
    });

    test('fetch inayorejesha null haiandiki diski', () async {
      final repo = CachedRepository();
      await repo.refresh('page:null', () async => null);
      expect(repo.readOrNull<dynamic>('page:null'), isNull);
    });
  });

  group('CachedRepository — updatedAt', () {
    test('updatedAt inarejesha null kama hakuna data', () {
      expect(CachedRepository().updatedAt('page:e'), isNull);
    });

    test('baada ya refresh, updatedAt ipo', () async {
      final repo = CachedRepository();
      await repo.refresh('page:f', () async => 'data');
      expect(repo.updatedAt('page:f'), isNotNull);
    });
  });

  group('CachedRepository — loadPage (ukurasa mzima)', () {
    test('diski kwanza, kisha refresh: apply inaitwa mara 2', () async {
      final repo = CachedRepository();
      repo.clearAll();
      AppCache().set('page:L', {'disco': true}, ttl: const Duration(days: 1));
      repo.warmUp();

      final applied = <dynamic>[];
      await repo.loadPage('page:L', () async => {'fetched': true},
          (data) async => applied.add(data));

      // Mara 1 = diski, mara 2 = API (revision imebadilika).
      expect(applied.length, 2);
      expect(applied[0], {'disco': true});
      expect(applied[1], {'fetched': true});
    });

    test('offline: diski tu — apply mara 1, skrini haibadiliki', () async {
      final repo = CachedRepository();
      repo.clearAll();
      AppCache().set('page:O', {'disco': true}, ttl: const Duration(days: 1));

      final applied = <dynamic>[];
      await repo.loadPage(
          'page:O', () async => throw Exception('offline'),
          (data) async => applied.add(data));

      expect(applied.length, 1);
      expect(applied[0], {'disco': true});
    });

    test('bila diski + API imeshindwa: apply mara 1 (null — NoCachedData',
        () async {
      final repo = CachedRepository();
      repo.clearAll();

      final applied = <dynamic>[];
      await repo.loadPage(
          'page:N', () async => throw Exception('offline'),
          (data) async => applied.add(data));

      expect(applied.length, 1);
      expect(applied[0], isNull); // ukurasa unaonyesha NoCachedDataWidget
    });
  });
}
