/// Admin badge service — namba za icons kwenye drawer na bottom nav.
///
/// Inapoll /admin/badges kila sekunde 45 + WS events kwa haraka ya papo hapo.
/// Ukurasa wa "angalia tu" (Watumiaji/Wenzao/Simu): badge inaisha ukifungua
/// ukurasa (server inakumbuka muda huo, namba zinahesabiwa upya tena).
/// Ukurasa wa "hatua" (Malipo/Maoni): badge inaisha tu baada ya kuchukua hatua.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart' show BadgeController, NavItem;
import 'websocket_service.dart';

class AdminBadgeService extends ChangeNotifier {
  static final AdminBadgeService _i = AdminBadgeService._();
  factory AdminBadgeService() => _i;
  AdminBadgeService._();

  int payments     = 0; // malipo yanasubiri uidhinishaji
  int feedback     = 0; // maoni yasiyojibiwa
  int users        = 0; // watumiaji wapya tangu admin aliona
  int matches      = 0; // mechi mpya tangu admin aliona
  int contacts     = 0; // simu/mawasiliano mapya tangu admin aliona
  int announcements = 0; // matangazo (WS bump tu — hayana API count)

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
    final type = resolveNotificationEventType(event);
    switch (type) {
      case 'payment.submitted':
      case 'payment.message':
        bumpPayments();
      case 'feedback.new':
        bumpFeedback();
      case 'user.registered':
        bumpUsers();
      case 'match.found':
      case 'match.new':
        bumpMatches();
      case 'contact.activity':
        bumpContacts();
      case 'announcement.new':
      case 'announcement':
        bumpAnnouncements();
    }
  }

  // ── Bump (haraka ya papo hapo kabla ya refresh) ──────────────────────────

  void bumpUsers()         { users++;         notifyListeners(); }
  void bumpMatches()       { matches++;        notifyListeners(); }
  void bumpContacts()      { contacts++;       notifyListeners(); }
  void bumpAnnouncements() { announcements++;  notifyListeners(); }
  void bumpPayments()      { payments++;       notifyListeners(); }
  void bumpFeedback()      { feedback++;       notifyListeners(); }

  // ── Clear (admin amefungua ukurasa) ──────────────────────────────────────

  Future<void> clearUsers() async {
    if (users == 0) return;
    users = 0;
    notifyListeners();
    await _markSeen('users');
  }

  Future<void> clearMatches() async {
    if (matches == 0) return;
    matches = 0;
    notifyListeners();
    await _markSeen('matches');
  }

  Future<void> clearContacts() async {
    if (contacts == 0) return;
    contacts = 0;
    notifyListeners();
    await _markSeen('contacts');
  }

  Future<void> clearAnnouncements() async {
    if (announcements == 0) return;
    announcements = 0;
    notifyListeners();
    await _markSeen('matangazo');
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

  // ── Reset (logout) ────────────────────────────────────────────────────────

  void reset() {
    stop();
    payments = feedback = users = matches = contacts = announcements = 0;
    notifyListeners();
  }

  // ── Refresh kutoka server ─────────────────────────────────────────────────

  Future<void> refresh() async {
    try {
      final res = await ApiService().adminBadges();
      final d   = res.data as Map<String, dynamic>? ?? {};
      final int p  = (d['payments']  as num? ?? 0).toInt();
      final int f  = (d['feedback']  as num? ?? 0).toInt();
      final int u  = (d['users']     as num? ?? 0).toInt();
      final int m  = (d['matches']   as num? ?? 0).toInt();
      final int c  = (d['contacts']  as num? ?? 0).toInt();

      if (p != payments || f != feedback || u != users ||
          m != matches  || c != contacts) {
        payments = p;
        feedback = f;
        users    = u;
        matches  = m;
        contacts = c;
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Bridge → BadgeController (drawer mpya: AppDrawer + hamburger dot) ──────
  // Kila mabadiliko ya namba (poll ya sekunde 45, WS events, clear*, reset)
  // yanamwagika kwenye BadgeController mara moja — drawer na dot ya hamburger
  // zinabaki live bila wiring ya ziada. Matangazo/Data/Takwimu haziwekwi
  // (BadgeRule.none kwenye design mpya — hazionyeshi badge).
  @override
  void notifyListeners() {
    super.notifyListeners();
    BadgeController.instance.setCounts({
      NavItem.watumiaji:    users,
      NavItem.wenzao:       matches,
      NavItem.matchZaKweli: matches,
      NavItem.waliopigiana: contacts,
      NavItem.malipo:       payments,
      NavItem.maoni:        feedback,
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _markSeen(String page) async {
    try { await ApiService().adminMarkPageSeen(page); } catch (_) {}
  }
}
