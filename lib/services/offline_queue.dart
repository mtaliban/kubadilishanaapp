/// Foleni ya vitendo vya admin vilivyofanyika bila mtandao.
///
/// Vitendo (approve/reject malipo, jibu maoni) vinahifadhiwa kwenye
/// SharedPreferences ya simu. Mtandao ukiingia, vitendo vyote hutumwa
/// kwa mpangilio, kisha hutolewa foleni.
///
/// HAZIGUSI MongoDB — zinatumwa tu kwa server kama HTTP request kawaida
/// wakati mtandao unarudi.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'admin_badge_service.dart';

enum QueueStatus { pending, processing, sent, failed }

// ─── Kitendo kimoja ───────────────────────────────────────────────────────────

class QueuedAction {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final String displayText; // maandishi ya binadamu ("Thibitisha malipo")
  final DateTime createdAt;
  QueueStatus status;
  String? error;

  QueuedAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.displayText,
    required this.createdAt,
    this.status = QueueStatus.pending,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'payload': payload,
    'displayText': displayText,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name, 'error': error,
  };

  factory QueuedAction.fromJson(Map<String, dynamic> j) => QueuedAction(
    id: j['id'] as String,
    type: j['type'] as String,
    payload: Map<String, dynamic>.from(j['payload'] as Map),
    displayText: (j['displayText'] as String?) ?? 'Kitendo',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    status: QueueStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => QueueStatus.pending,
    ),
    error: j['error'] as String?,
  );
}

// ─── Huduma ya foleni ─────────────────────────────────────────────────────────

class OfflineQueue extends ChangeNotifier {
  static final OfflineQueue _i = OfflineQueue._();
  factory OfflineQueue() => _i;
  OfflineQueue._();

  static const _kKey = 'kv_oq';
  final List<QueuedAction> _actions = [];
  bool _processing = false;

  List<QueuedAction> get actions => List.unmodifiable(_actions);
  int get pendingCount    => _actions.where((a) => a.status == QueueStatus.pending).length;
  int get processingCount => _actions.where((a) => a.status == QueueStatus.processing).length;
  int get failedCount     => _actions.where((a) => a.status == QueueStatus.failed).length;
  int get activeCount     => pendingCount + processingCount + failedCount;

  // ── Pakia kutoka SharedPreferences (startup) ──────────────────────────────

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _actions.clear();
      for (final item in list) {
        final a = QueuedAction.fromJson(item as Map<String, dynamic>);
        // "processing" iliyokatizwa (app ilifungwa) → rudisha kuwa pending
        if (a.status == QueueStatus.processing) a.status = QueueStatus.pending;
        if (a.status != QueueStatus.sent) _actions.add(a);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── Weka kitendo foleni ───────────────────────────────────────────────────

  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
    required String displayText,
  }) async {
    final a = QueuedAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}',
      type: type,
      payload: payload,
      displayText: displayText,
      createdAt: DateTime.now(),
    );
    _actions.add(a);
    await _save();
    notifyListeners();
  }

  // ── Chapua vitendo vyote vilivyosubiri ────────────────────────────────────

  Future<void> processAll() async {
    if (_processing) return;
    final pending = _actions.where((a) => a.status == QueueStatus.pending).toList();
    if (pending.isEmpty) return;

    _processing = true;
    for (final action in pending) {
      action.status = QueueStatus.processing;
      notifyListeners();
      try {
        await _execute(action);
        action.status = QueueStatus.sent;
      } catch (e) {
        action.status = QueueStatus.failed;
        action.error = _friendly(e.toString());
      }
      notifyListeners();
    }
    _processing = false;
    await _save();

    // Ondoa vilivyotumwa baada ya sekunde 3 (vilikuwa vikionekana ✅ kidogo)
    final hasSent = _actions.any((a) => a.status == QueueStatus.sent);
    if (hasSent) {
      await Future.delayed(const Duration(seconds: 3));
      _actions.removeWhere((a) => a.status == QueueStatus.sent);
      await _save();
      notifyListeners();
    }

    AdminBadgeService().refresh();
  }

  // ── Jaribu tena vilivyoshindwa ────────────────────────────────────────────

  Future<void> retryFailed() async {
    for (final a in _actions.where((a) => a.status == QueueStatus.failed)) {
      a.status = QueueStatus.pending;
      a.error = null;
    }
    notifyListeners();
    await processAll();
  }

  // ── Ondoa kitendo (mkono) ────────────────────────────────────────────────

  Future<void> remove(String id) async {
    _actions.removeWhere((a) => a.id == id);
    await _save();
    notifyListeners();
  }

  // ── Hifadhi ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _actions
          .where((a) => a.status != QueueStatus.sent)
          .map((a) => a.toJson())
          .toList();
      await prefs.setString(_kKey, jsonEncode(data));
    } catch (_) {}
  }

  // ── Tekeleza kitendo kimoja ───────────────────────────────────────────────

  Future<void> _execute(QueuedAction a) async {
    switch (a.type) {
      case 'approve_payment':
        await ApiService().adminApproveDonation(
          a.payload['order_id'] as String,
          note: a.payload['note'] as String?,
        );
      case 'reject_payment':
        await ApiService().adminRejectDonation(
          a.payload['order_id'] as String,
          note: a.payload['note'] as String?,
        );
      case 'reply_feedback':
        await ApiService().adminReplyFeedback(
          a.payload['feedback_id'] as String,
          a.payload['reply'] as String,
        );
      default:
        throw Exception('Aina haijulikani: ${a.type}');
    }
  }

  static String _friendly(String e) {
    if (e.contains('401')) return 'Ruhusa imekataliwa';
    if (e.contains('404')) return 'Kipengele hakipatikani';
    if (e.contains('500')) return 'Kosa la server';
    if (e.contains('SocketException') || e.contains('Connection')) return 'Mtandao umekatika';
    return 'Kosa — jaribu tena';
  }
}
