// ============================================================================
// test/services_stress_test.dart
// TESTING NGUMU — huduma za app chini ya mshtuko:
//   • AppToast         — tosti 200 (storm), dupe-repeat, timer hakuna leak
//   • OfflineQueue     — vitendo 100, aina isiyojulikana, roundtrip diski
//   • CachedRepository — syncAll: kurasa zenye MARADUFU + maxItems cap
//   • AppCache         — funguo 5000 (write/read timing)
//   • PageSkeleton     — mistari 300 @ 320x640 (hakuna overflow)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/services/cached_repository.dart';
import 'package:kubadilishanaapp/services/offline_queue.dart';
import 'package:kubadilishanaapp/widgets/app_toast.dart';
import 'package:kubadilishanaapp/widgets/page_skeleton.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppCache().clear();
  });

  group('AppToast — tosti-storm na timer', () {
    testWidgets('tosti 200 zilizotumwa kwa upesi — ile ya MWISHO tu inaishi',
        (t) async {
      AppToast.current.value = null;
      final host = MaterialApp(
        home: Scaffold(body: ToastHost(child: const SizedBox.expand())),
      );
      await t.pumpWidget(host);

      for (var i = 0; i < 200; i++) {
        AppToast.show('Tosti #$i', duration: const Duration(seconds: 3));
      }
      await t.pump();

      // Mwisho tu anabaki (kipenyo cha juu — sio kile cha kwanza wala wote)
      expect(find.byType(ToastHost), findsOneWidget);
      expect(AppToast.current.value?.text, 'Tosti #199');

      // Timer ya tosti ya mwisho — ulisubiri ikome (hakuna timer inayobaki
      // mwishoni mwa test — Flutter test inakataza).
      await t.pump(const Duration(seconds: 4));
      expect(AppToast.current.value, isNull);
    });

    testWidgets('DUPE-REPEAT: ujumbe uleule hauwahi kuisha muda mfupi — '
        'kila kurudia inaandaa muda upya (hakuna tosti inayotokea ghafla)',
        (t) async {
      AppToast.current.value = null;
      AppToast.show('Hakuna mtandao', duration: const Duration(seconds: 4));
      await t.pump(const Duration(seconds: 3));
      expect(AppToast.current.value?.text, 'Hakuna mtandao');

      // Ujumbe uleule kwa wakati wa kurudi mtandaoni — timer INYAANDIKA UPYA
      AppToast.show('Hakuna mtandao', duration: const Duration(seconds: 4));
      await t.pump(const Duration(seconds: 3)); // jumla 6 — zingatia EXPIRED
      expect(AppToast.current.value?.text, 'Hakuna mtandao');

      // (6 + 4 = 10) — sasa kweli imekwisha
      await t.pump(const Duration(seconds: 4));
      expect(AppToast.current.value, isNull);
    });
  });

  group('OfflineQueue — mshtuko wa vitendo', () {
    test('vitendo 100 kwenye foleni + roundtrip diski (serialize/deserialize)',
        () async {
      final q = OfflineQueue();
      await q.load();
      expect(q.actions, isEmpty);

      for (var i = 0; i < 100; i++) {
        await q.enqueue(
          type: 'approve_payment',
          payload: {'order_id': 'OID-$i', 'note': 'Angalizo $i'},
          displayText: 'Thibitisha malipo $i',
        );
      }
      expect(q.actions.length, 100);
      expect(q.pendingCount, 100);

      // Rejea kwa diski — load() inapaswa kupata zote 100
      final q2 = OfflineQueue();
      await q2.load();
      expect(q2.actions.length, 100);
      expect(q2.actions.first.payload['order_id'], 'OID-0');
    });

    test('AINA ISIYOJULIKANA — inaanguka kwa heshima (status=failed + ujumbe '
        'wa kirafiki), HAISIMAMISHE foleni nzima', () async {
      final q = OfflineQueue();
      await q.load();

      await q.enqueue(
          type: 'approve_payment',
          payload: {'order_id': 'ok-1'},
          displayText: 'A');
      await q.enqueue(
          type: 'sea_monster', // aina isiyojulikana kabisa
          payload: {},
          displayText: 'B');

      await q.processAll();

      final a = q.actions.firstWhere((x) => x.type == 'approve_payment');
      final b = q.actions.firstWhere((x) => x.type == 'sea_monster');
      // Mtandao hapo test — ApiService inashindwa — lakini status NI WKU
      // (failed au sent, sio kutanua exception, wala foleni kutanua)
      expect(a.status, isNot(QueueStatus.processing));
      expect(b.status, QueueStatus.failed);
      expect(b.error, isNotNull);
    });

    test('retryFailed — zilizoshindwa zinarudi kwenye foleni kwa pending',
        () async {
      final q = OfflineQueue();
      // Singleton — tests zingine zimeachia vitendo kwenye diski: safisha
      // foleni ile yote (tabia halisi: load() inarejesha diski kwa restart).
      await q.load();
      for (final a in q.actions.toList()) {
        await q.remove(a.id);
      }
      expect(q.actions, isEmpty);

      await q.enqueue(
          type: 'sea_monster', payload: {}, displayText: 'X');
      await q.processAll();
      expect(q.failedCount, 1);

      // retryFailed() inaweka pending kisha inaita processAll() NDANI YAKE —
      // kitendo hutumwa (hapa mtandao haupati) → huanguka tena: failed=1,
      // pending=0. Kwa uzito: HAIKAFI wala kutoroka kutoka kwenye foleni.
      await q.retryFailed();
      expect(q.failedCount, 1);
      expect(q.pendingCount, 0);
    });
  });

  group('CachedRepository.syncAll — chini ya API mbaya', () {
    test('kurasa zenye MARADUFU — dedupe guard inazuia data mara mbili',
        () async {
      // Server isiotumia `skip` — inarudisha UKURASA ULEULE mara kwa mara:
      // bila dedupe, diski ingejaa maradufu BILA mwisho (dead-loop).
      final page = List.generate(200, (i) => {'_id': '$i', 'n': i});
      var calls = 0;
      await CachedRepository().syncAll(
        'stress:dedupe',
        fetchPage: (limit, skip) async {
          calls++;
          return page; // daima ile ile!
        },
      );
      final stored = CachedRepository().readOrNull<dynamic>('stress:dedupe');
      expect(stored.length, 200); // Maradufu ZOTE zimekataliwa
      expect(calls, lessThanOrEqualTo(5),
          reason: 'Dead-loop inavunjwa haraka (ukurasa uleule)');
    });

    test('maxItems cap — server yenye ukurasa usioisha HAISIDHARAU kumbukumbu',
        () async {
      final page =
          List.generate(200, (i) => {'id': 'x-$i', 'w': 'x' * 100});
      await CachedRepository().syncAll(
        'stress:cap',
        fetchPage: (limit, skip) async =>
            [{'_id': 'unique-$skip', 'v': skip}]..addAll(page),
        maxItems: 1000,
      );
      final stored = CachedRepository().readOrNull<dynamic>('stress:cap');
      expect(stored.length, lessThanOrEqualTo(1000));
    });

    test('onProgress — wito kwa kila ukurasa unapoandikwa (diskee kwa skrini)',
        () async {
      var ticks = 0;
      await CachedRepository().syncAll(
        'stress:progress',
        fetchPage: (limit, skip) async =>
            List.generate(50, (i) => {'_id': 'p$skip-$i'}),
        onProgress: (_) => ticks++,
      );
      expect(ticks, greaterThanOrEqualTo(1));
    });
  });

  test('AppCache — funguo 5000: write/read chini ya 2s (SPA kubwa inapumaana)',
      () async {
    final sw = Stopwatch()..start();
    final cache = AppCache();
    for (var i = 0; i < 5000; i++) {
      cache.set('key:$i', {'v': 'x$i'});
    }
    for (var i = 0; i < 5000; i++) {
      expect(cache.getStale('key:$i')?['v'], 'x$i');
    }
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
  });

  testWidgets('PageSkeleton rows=300 @ 320x640 — HAKUNA overflow (kanuni ya '
      'viewport ndogo zaidi)', (t) async {
    await t.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final itemCount = 300;
    final list = ListView.builder(
      itemCount: itemCount,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.person),
        title: Text('Mtumiaji Namba Ya Sitaha Ya Kwanza Tena $i'),
        subtitle: const Text('Kada ya nia ya muda observing wa sekavi sana — '
            'maelezo marefu sana yaliyopikwa kwa ziada ya kuwa ya juu'),
        trailing: Text('Mkoa $i'),
      ),
    );

    final sw = Stopwatch()..start();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: list)));
    final build1 = sw.elapsed;

    // Perf: menukuu ya kwanza la orodha-1000 hasikaidi 3s (CI polepole)
    expect(build1, lessThan(const Duration(seconds: 3)));

    // Skeleton mbano — viewport ndogo inavumiliwa
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PageSkeleton(rows: 300, scrollable: false),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
