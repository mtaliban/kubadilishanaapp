/// Admin badge service — counts za kazi zinazosubiri admin (kama WhatsApp):
///   • Malipo: payments zilizo "verifying" (zinasubiri uidhinishaji)
///   • Maoni:  feedback zisizojibiwa (hakuna reply)
///   • Matangazo: hakuna count ya API — tangazo jipya linapoad mina bump ya WS
///
/// Inapoll count APIs kila sekunde 45 + inasikiliza WS events za papo hapo.
/// Namba inaonekana kwenye bottom nav ya admin kwenye kila menyu husika.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'websocket_service.dart';

class AdminBadgeService extends ChangeNotifier {
  static final AdminBadgeService _i = AdminBadgeService._();
  factory AdminBadgeService() => _i;
  AdminBadgeService._();

  int payments = 0; // zinasubiri uidhinishaji (verifying)
  int feedback = 0; // zisizojibiwa
  int announcements = 0; // matangazo mapya (bump ya WS tu)

  Timer? _pollTimer;
  bool _wsBound = false;

  void start() {
    refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) => refresh());
    if (!_wsBound) {
      _wsBound = true;
      WebSocketService().onAny(_onWs);
    }
  }

  void stop() {
    _pollTimer?.cancel();
    if (_wsBound) {
      WebSocketService().offAny(_onWs);
      _wsBound = false;
    }
  }

  void _onWs(Map<String, dynamic> event) {
    final type = (event['event'] ?? event['type'])?.toString() ?? '';
    switch (type) {
      case 'payment.submitted':
      case 'payment.message':
        bumpPayments();
      case 'feedback.new':
        bumpFeedback();
      case 'announcement.new':
      case 'announcement':
        // Tangazo jipya limetumwa — admin mwenyewe hahitaji badge (yeye ndiyo mtumaji);
        // hii inatumika kama user-side. Ili admin aone, tunabump tu kama si yeye.
        break;
    }
  }

  void bumpPayments() {
    payments++;
    notifyListeners();
  }

  void bumpFeedback() {
    feedback++;
    notifyListeners();
  }

  void bumpAnnouncements() {
    announcements++;
    notifyListeners();
  }

  void clearPayments() {
    if (payments == 0) return;
    payments = 0;
    notifyListeners();
  }

  void clearFeedback() {
    if (feedback == 0) return;
    feedback = 0;
    notifyListeners();
  }

  void clearAnnouncements() {
    if (announcements == 0) return;
    announcements = 0;
    notifyListeners();
  }

  /// Weka counts ZOTE sifuri + simamisha polling — logout/session mpya:
  /// badges za mtumiaji wa zamani zisiwekee kwenye session mpya.
  void reset() {
    stop();
    payments = 0;
    feedback = 0;
    announcements = 0;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        ApiService().adminAllDonations(status: 'verifying'),
        ApiService().adminListFeedback(status: '', q: ''),
      ]);

      // Malipo zinasubiri
      final pay = results[0].data;
      final payList = pay is List
          ? pay
          : (pay['payments'] ?? pay['results'] ?? []) as List;
      final newPayments = payList.length;

      // Maoni yasiyojibiwa
      final fb = results[1].data;
      final fbList = fb is List
          ? fb
          : (fb['feedback'] ?? fb['items'] ?? fb['results'] ?? []) as List;
      var newFeedback = 0;
      for (final m in fbList) {
        if (m is! Map) continue;
        final reply =
            m['reply'] ?? m['admin_reply'] ?? m['response'] ?? '';
        if (reply.toString().trim().isEmpty) newFeedback++;
      }

      if (newPayments != payments || newFeedback != feedback) {
        payments = newPayments;
        feedback = newFeedback;
        notifyListeners();
      }
    } catch (_) {}
  }
}
