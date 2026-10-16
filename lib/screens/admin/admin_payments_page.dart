// =============================================================================
// admin_payments_page.dart
// "Malipo" — inapakua data kutoka API na kuionyesha kwenye MalipoView.
// Data halisi: GET /payments/admin/all
// WS 'notification' inasimama kwa malipo mapya.
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cached_repository.dart';
import '../../services/admin_badge_service.dart';
import '../../widgets/app_drawer.dart' show BadgeController, NavItem;
import '../../services/network_service.dart';
import '../../services/offline_queue.dart';
import '../../services/websocket_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/no_cached_data_widget.dart';
import '../../widgets/skeletons.dart';
import 'malipo_view.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool _loading = true;
  List<Payment> _payments = [];
  int? _totalApprovedTzs;

  /// OFFLINE-FIRST — funguo ya diski ya CachedRepository (orodha + jumla).
  static const String _kKey = 'page:admin/payments';

  void _onWs(Map<String, dynamic> payload) {
    final type =
        (payload['type'] ?? payload['event'])?.toString() ?? '';
    if (type == 'payment.submitted' || type == 'payment.message') {
      if (mounted) _load();
    }
  }

  @override
  void initState() {
    super.initState();
    // DISKI PAPO HAPO — frame ya KWANZA (hakuna spring, hakuna kusubiri).
    CachedRepository().hydrate(_kKey, _applyPayments);
    _load();
    WebSocketService().on('notification', _onWs);
  }

  void _applyPayments(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final map = data is Map ? data : const <String, dynamic>{};
    final list =
        (data is List ? data : (map['payments'] ?? map['results'] ?? const []))
            as List;
    setState(() {
      _payments = list
          .whereType<Map<String, dynamic>>()
          .map(_mapPayment)
          .toList();
      _totalApprovedTzs =
          (map['total_approved_tzs'] as num?)?.toInt();
      _loading = false;
    });
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    super.dispose();
  }

  Future<void> _load() async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: data ya diski inabaki.
    await CachedRepository()
        .loadPage(_kKey, () async => (await ApiService().adminAllDonations()).data,
        _applyPayments);
    if (!mounted) return;
    if (_payments.isEmpty && _loading) setState(() => _loading = false);
  }

  /* ── Data mapping ── */

  static Payment _mapPayment(Map<String, dynamic> m) {
    final statusStr = (m['status'] as String?) ?? 'verifying';
    final status = switch (statusStr) {
      'approved' => PaymentStatus.approved,
      'rejected' => PaymentStatus.rejected,
      _          => PaymentStatus.pending,
    };

    final rawMsgs = (m['messages'] as List?) ?? [];
    final msgs = rawMsgs
        .whereType<Map<String, dynamic>>()
        .map((msg) {
          final from =
              '${msg['from'] ?? msg['sender'] ?? msg['role'] ?? ''}';
          final isAdmin = from.contains('admin') ||
              from == 'staff' ||
              msg['is_admin'] == true;
          DateTime at;
          try {
            at = DateTime.parse(
                    '${msg['at'] ?? msg['created_at']}')
                .toLocal();
          } catch (_) {
            at = DateTime.now();
          }
          return PaymentMessage(
            fromAdmin: isAdmin,
            text: '${msg['text'] ?? msg['message'] ?? ''}',
            at: at,
          );
        })
        .toList();

    DateTime? createdAt;
    try {
      createdAt =
          DateTime.parse('${m['created_at']}').toLocal();
    } catch (_) {}

    return Payment(
      id: '${m['order_id'] ?? m['id'] ?? ''}',
      name: _titleCase('${m['user_name'] ?? ''}'),
      phone: '${m['phone'] ?? ''}',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      reference: '${m['order_id'] ?? ''}',
      createdAt: createdAt,
      status: status,
      sms: '${m['sms_text'] ?? ''}',
      note: '${m['note'] ?? ''}',
      messages: msgs,
    );
  }

  static String _titleCase(String v) => v
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  /* ── Vitendo ── */

  Future<void> _approve(Payment p) async {
    if (NetworkService().isOffline) {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': p.id},
        displayText: 'Thibitisha malipo',
      );
      AppToast.info('Imewekwa foleni. Itatumwa mtandao ukiingia');
      return;
    }
    try {
      await ApiService().adminApproveDonation(p.id);
      if (!mounted) return;
      AdminBadgeService().refresh();
      // Badge ya Malipo ni "pending" — inaisha TU baada ya hatua (siyo kufungua ukurasa)
      BadgeController.instance.decrement(NavItem.malipo);
      AppToast.success('Malipo yamethibitishwa');
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(friendlyError(e));
    }
  }

  Future<void> _reject(Payment p, String reason) async {
    if (NetworkService().isOffline) {
      await OfflineQueue().enqueue(
        type: 'reject_payment',
        payload: {'order_id': p.id, 'note': reason},
        displayText: 'Kataa malipo',
      );
      AppToast.info('Imewekwa foleni. Itatumwa mtandao ukiingia');
      return;
    }
    try {
      await ApiService().adminRejectDonation(p.id, note: reason);
      if (!mounted) return;
      AdminBadgeService().refresh();
      // Badge ya Malipo ni "pending" — inaisha TU baada ya hatua (siyo kufungua ukurasa)
      BadgeController.instance.decrement(NavItem.malipo);
      AppToast.warning('Malipo yamekataliwa');
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(friendlyError(e));
    }
  }

  /* ── Build ── */

  @override
  Widget build(BuildContext context) {
    final hasDisk = CachedRepository().readOrNull<dynamic>(_kKey) != null;
    if (_loading && _payments.isEmpty && !hasDisk) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : Colors.white,
        // KANUNI: KAMWE spinner — skeleton ya malipo tu.
        body: const MalipoSkeleton(),
      );
    }

    if (_payments.isEmpty && !hasDisk) {
      // HAKUNA data diski + API imeshindwa — widget MOYA ya "haijapakuliwa"
      // (pull-to-refresh pekee; hakuna kitufe cha "Jaribu tena").
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : Colors.white,
        body: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF1959D6),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              NoCachedDataWidget(
                hint: 'Vuta chini kupakia — malipo yatahifadhiwa kwenye simu.',
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF1959D6),
        child: MalipoView(
          payments: _payments,
          totalApprovedTzs: _totalApprovedTzs,
          onApprove: _approve,
          onReject: _reject,
        ),
      ),
    );
  }
}
