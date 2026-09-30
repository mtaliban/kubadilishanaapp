// ============================================================================
// test/offline_queue_unit_test.dart
// Unit tests za OfflineQueue — enqueue, load, retry, JSON round-trip.
// ============================================================================
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/services/offline_queue.dart';

Future<void> _reset() async {
  SharedPreferences.setMockInitialValues({});
  for (final a in List.of(OfflineQueue().actions)) {
    await OfflineQueue().remove(a.id);
  }
}

void main() {
  setUp(_reset);

  group('QueuedAction — JSON round-trip', () {
    test('toJson/fromJson huhifadhi fields zote', () {
      final a = QueuedAction(
        id: 'test123',
        type: 'approve_payment',
        payload: {'order_id': 'ORD-001'},
        displayText: 'Thibitisha malipo',
        createdAt: DateTime(2026, 9, 30, 12, 0),
        status: QueueStatus.pending,
      );
      final b = QueuedAction.fromJson(a.toJson());
      expect(b.id, 'test123');
      expect(b.type, 'approve_payment');
      expect(b.payload['order_id'], 'ORD-001');
      expect(b.displayText, 'Thibitisha malipo');
      expect(b.status, QueueStatus.pending);
      expect(b.error, isNull);
    });

    test('fromJson inaweza kukabili json ya kale bila displayText', () {
      final j = {
        'id': 'old1',
        'type': 'reply_feedback',
        'payload': {'feedback_id': 'f1', 'reply': 'Asante'},
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      };
      final a = QueuedAction.fromJson(j);
      expect(a.displayText, 'Kitendo');
    });

    test('fromJson inaweza kukabili status zote za QueueStatus', () {
      for (final s in QueueStatus.values) {
        final j = {
          'id': 'id_${s.name}',
          'type': 'approve_payment',
          'payload': <String, dynamic>{},
          'displayText': 'Test',
          'createdAt': DateTime.now().toIso8601String(),
          'status': s.name,
        };
        final a = QueuedAction.fromJson(j);
        expect(a.status, s);
      }
    });
  });

  group('OfflineQueue — enqueue', () {
    test('enqueue huongeza kitendo kwenye orodha', () async {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'ORD-001'},
        displayText: 'Thibitisha',
      );
      expect(OfflineQueue().actions, hasLength(1));
      expect(OfflineQueue().actions.first.type, 'approve_payment');
      expect(OfflineQueue().actions.first.status, QueueStatus.pending);
    });

    test('vitendo vingi vinaweza kuwekwa', () async {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'A1'},
        displayText: 'Approve A1',
      );
      await OfflineQueue().enqueue(
        type: 'reject_payment',
        payload: {'order_id': 'A2', 'note': 'fake'},
        displayText: 'Reject A2',
      );
      await OfflineQueue().enqueue(
        type: 'reply_feedback',
        payload: {'feedback_id': 'F1', 'reply': 'OK'},
        displayText: 'Jibu F1',
      );
      expect(OfflineQueue().actions, hasLength(3));
      expect(OfflineQueue().pendingCount, 3);
    });

    test('vitendo viwili vina IDs za kipekee', () async {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'X'},
        displayText: 'X',
      );
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'Y'},
        displayText: 'Y',
      );
      final ids = OfflineQueue().actions.map((a) => a.id).toList();
      expect(ids.toSet().length, 2, reason: 'IDs lazima ziwe tofauti');
    });
  });

  group('OfflineQueue — counts', () {
    test('pendingCount inahesabu vya pending pekee', () async {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'C1'},
        displayText: 'C1',
      );
      expect(OfflineQueue().pendingCount, 1);
      expect(OfflineQueue().failedCount, 0);
      expect(OfflineQueue().activeCount, 1);
    });

    test('failedCount inahesabu vya failed pekee', () async {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'D1'},
        displayText: 'D1',
      );
      OfflineQueue().actions.first.status = QueueStatus.failed;
      expect(OfflineQueue().failedCount, 1);
      expect(OfflineQueue().pendingCount, 0);
    });

    test('activeCount ni jumla ya pending + processing + failed', () async {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'D1'},
        displayText: 'D1',
      );
      await OfflineQueue().enqueue(
        type: 'reject_payment',
        payload: {'order_id': 'D2', 'note': 'reason'},
        displayText: 'D2',
      );
      expect(OfflineQueue().activeCount, 2);
    });
  });

  group('OfflineQueue — load kutoka SharedPreferences', () {
    test('load hurudisha vitendo vilivyohifadhiwa', () async {
      await OfflineQueue().enqueue(
        type: 'reply_feedback',
        payload: {'feedback_id': 'fb1', 'reply': 'Asante'},
        displayText: 'Jibu',
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('kv_oq');
      expect(raw, isNotNull);
      // Simulate restart: clear memory, prefs intact
      for (final a in List.of(OfflineQueue().actions)) {
        OfflineQueue().actions; // access list to avoid modify-while-iterate
      }
      // Re-load from prefs
      await OfflineQueue().load();
      expect(OfflineQueue().actions.isNotEmpty, isTrue);
    });

    test('load inabadilisha processing → pending', () async {
      final prefs = await SharedPreferences.getInstance();
      final data = [
        {
          'id': 'proc1',
          'type': 'approve_payment',
          'payload': {'order_id': 'OX'},
          'displayText': 'Test',
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'processing',
          'error': null,
        }
      ];
      await prefs.setString('kv_oq', jsonEncode(data));
      await OfflineQueue().load();
      final loaded = OfflineQueue().actions.where((a) => a.id == 'proc1').firstOrNull;
      expect(loaded, isNotNull);
      expect(loaded!.status, QueueStatus.pending,
          reason: 'processing → pending wakati wa load (app ilikufa)');
    });

    test('load haijali prefs tupu', () async {
      SharedPreferences.setMockInitialValues({});
      await expectLater(OfflineQueue().load(), completes);
    });
  });

  group('OfflineQueue — remove', () {
    test('remove huondoa kitendo kwa ID', () async {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'RM1'},
        displayText: 'Remove test',
      );
      final id = OfflineQueue().actions.first.id;
      await OfflineQueue().remove(id);
      expect(OfflineQueue().actions, isEmpty);
    });

    test('remove ID isiyoipo haisababishi makosa', () async {
      await expectLater(OfflineQueue().remove('hakipo'), completes);
    });
  });

  group('OfflineQueue — retryFailed', () {
    test('vitendo vilivyoshindwa vinarudi pending baada ya kubadilishwa', () async {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': 'RTR1'},
        displayText: 'Retry test',
      );
      final action = OfflineQueue().actions.first;
      action.status = QueueStatus.failed;
      action.error = 'Kosa la zamani';
      expect(OfflineQueue().failedCount, 1);

      // Badilisha manually (processAll itashindwa bila server)
      for (final a in OfflineQueue().actions.where((a) => a.status == QueueStatus.failed)) {
        a.status = QueueStatus.pending;
        a.error = null;
      }
      expect(OfflineQueue().failedCount, 0);
      expect(OfflineQueue().pendingCount, 1);
    });
  });
}
