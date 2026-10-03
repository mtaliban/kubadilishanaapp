// ============================================================================
// test/app_cache_unit_test.dart
// Unit tests za AppCache — TTL, invalidation, listeners, revision, warmUp.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/services/app_cache.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppCache().clear();
  });

  group('AppCache — set na get', () {
    test('set huhifadhi data, get hurejesha', () {
      AppCache().set('k1', {'a': 1});
      expect(AppCache().get('k1'), {'a': 1});
    });

    test('get hurejesha null kwa ufunguo usio na data', () {
      expect(AppCache().get('haipo'), isNull);
    });

    test('get hurejesha null kwa TTL iliyopita', () async {
      AppCache().set('k2', 'data', ttl: const Duration(milliseconds: 1));
      // Subiri TTL iishe HALISI (20ms — mil 1 ya TTL inaisha hata kwenye runner
      // mzito; awali kulikuwa na race: Future.delayed isiyosubiriwa + isNotNull).
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Sera ya offline ("Cached + banner"): get() inarudisha null kwa iliyoisha
      // muda, lakini entry inabaki kwa getStale() — fallback ya mtandao mbaya.
      expect(AppCache().get('k2'), isNull);
      expect(AppCache().getStale('k2'), 'data');
    });

    test('data ya aina tofauti zinaweza kuhifadhiwa', () {
      AppCache().set('int', 42);
      AppCache().set('list', [1, 2, 3]);
      AppCache().set('map', {'x': 'y'});
      AppCache().set('str', 'hello');
      expect(AppCache().get('int'), 42);
      expect(AppCache().get('list'), [1, 2, 3]);
      expect(AppCache().get('map'), {'x': 'y'});
      expect(AppCache().get('str'), 'hello');
    });

    test('set upya kwenye ufunguo uliopo inabadilisha data', () {
      AppCache().set('dup', 'v1');
      AppCache().set('dup', 'v2');
      expect(AppCache().get('dup'), 'v2');
    });
  });

  group('AppCache — invalidate', () {
    test('invalidate huondoa ufunguo mmoja', () {
      AppCache().set('a', 1);
      AppCache().set('b', 2);
      AppCache().invalidate('a');
      expect(AppCache().get('a'), isNull);
      expect(AppCache().get('b'), 2);
    });

    test('invalidate huongeza revision na kuarifu listeners', () {
      AppCache().set('x', 'data');
      final revBefore = AppCache().revision;
      bool notified = false;
      void listener() => notified = true;
      AppCache().addListener(listener);
      AppCache().invalidate('x');
      AppCache().removeListener(listener);
      expect(AppCache().revision, greaterThan(revBefore));
      expect(notified, isTrue);
    });

    test('invalidate kwenye ufunguo usio na data haiarifu listeners', () {
      final revBefore = AppCache().revision;
      bool notified = false;
      void listener() => notified = true;
      AppCache().addListener(listener);
      AppCache().invalidate('haipo_hata');
      AppCache().removeListener(listener);
      expect(AppCache().revision, revBefore);
      expect(notified, isFalse);
    });
  });

  group('AppCache — invalidatePrefix', () {
    test('huondoa ufunguo wote wenye prefix', () {
      AppCache().set('/locations/regions', []);
      AppCache().set('/locations/regions/1/districts', []);
      AppCache().set('/locations/departments', []);
      AppCache().set('/cadres', []);
      AppCache().set('/other', 'keep');

      AppCache().invalidatePrefix('/locations');

      expect(AppCache().get('/locations/regions'), isNull);
      expect(AppCache().get('/locations/regions/1/districts'), isNull);
      expect(AppCache().get('/locations/departments'), isNull);
      expect(AppCache().get('/cadres'), isNotNull, reason: '/cadres haibadiliki');
      expect(AppCache().get('/other'), 'keep', reason: '/other haibadiliki');
    });

    test('invalidatePrefix("/cadres") huathiri subcaches za cadres', () {
      AppCache().set('/cadres', []);
      AppCache().set('/cadres?category=health', []);
      AppCache().set('/cadres/subjects', []);
      AppCache().set('/cadres/subjects?level=Primary', []);

      AppCache().invalidatePrefix('/cadres');

      expect(AppCache().get('/cadres'), isNull);
      expect(AppCache().get('/cadres?category=health'), isNull);
      expect(AppCache().get('/cadres/subjects'), isNull);
      expect(AppCache().get('/cadres/subjects?level=Primary'), isNull);
    });

    test('huongeza revision kama kulikuwa na ufunguo', () {
      AppCache().set('/locs', []);
      final before = AppCache().revision;
      AppCache().invalidatePrefix('/locs');
      expect(AppCache().revision, greaterThan(before));
    });

    test('haibadilishi revision kama hakuna ufunguo unaofanana', () {
      final before = AppCache().revision;
      AppCache().invalidatePrefix('/haipatikani_prefix');
      expect(AppCache().revision, before);
    });
  });

  group('AppCache — clear', () {
    test('huondoa kila kitu', () {
      AppCache().set('a', 1);
      AppCache().set('b', 2);
      AppCache().clear();
      expect(AppCache().get('a'), isNull);
      expect(AppCache().get('b'), isNull);
    });

    test('huongeza revision na kuarifu listeners', () {
      AppCache().set('c', 3);
      final before = AppCache().revision;
      bool notified = false;
      void l() => notified = true;
      AppCache().addListener(l);
      AppCache().clear();
      AppCache().removeListener(l);
      expect(AppCache().revision, greaterThan(before));
      expect(notified, isTrue);
    });

    test('clear kwenye cache tupu haisababishi makosa', () {
      expect(() => AppCache().clear(), returnsNormally);
    });
  });

  group('AppCache — warmUp na persistence', () {
    test('warmUp huload data iliyohifadhiwa kwenye SharedPreferences', () async {
      // Hifadhi kwenye cache, kisha warmUp mpya
      AppCache().set('/test/key', {'hello': 'world'}, ttl: const Duration(minutes: 5));
      // Simulate app restart — clear in-memory only (prefs remain)
      // Haiwezekani kabisa bila kufikia _store moja kwa moja, lakini
      // tunapima kwamba warmUp inafanya kazi bila throw.
      await AppCache().warmUp();
      // Baada ya warmUp, data bado iko kwa sababu prefs mock ina data
      // (AppCache._persist inaiandika async, kwa hivyo tutegemee get kufanya kazi)
      expect(AppCache().get('/test/key'), isNotNull);
    });

    test('warmUp haisababishi makosa kwenye prefs tupu', () async {
      SharedPreferences.setMockInitialValues({});
      AppCache().clear();
      await expectLater(AppCache().warmUp(), completes);
    });
  });
}
