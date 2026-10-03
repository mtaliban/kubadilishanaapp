// =============================================================================
// admin_payments_page.dart
// "Malipo" — inapakua data kutoka API na kuionyesha kwenye MalipoView.
// Data halisi: GET /payments/admin/all
// WS 'notification' inasimama kwa malipo mapya.
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/admin_badge_service.dart';
import '../../widgets/app_drawer.dart' show BadgeController, NavItem;
import '../../services/network_service.dart';
import '../../services/offline_queue.dart';
import '../../services/websocket_service.dart';
import '../../widgets/app_toast.dart';
import 'malipo_view.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool _loading = true;
  String? _error;
  List<Payment> _payments = [];
  int? _totalApprovedTzs;

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
    _load();
    WebSocketService().on('notification', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    super.dispose();
  }

  Future<void> _load() async {
    if (_payments.isEmpty) setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminAllDonations();
      if (!mounted) return;
      final d = res.data;
      final map =
          d is Map ? d as Map<String, dynamic> : <String, dynamic>{};
      final list =
          (d is List ? d : (map['payments'] ?? map['results'] ?? []))
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
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = friendlyError(e); });
    }
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
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF1959D6)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child:
                Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 52, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 14),
              const Text('Imeshindikana kupakia',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF5B6475), fontSize: 13)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Jaribu tena'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1959D6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
