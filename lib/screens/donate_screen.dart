import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../providers/auth_provider.dart';
import '../utils/safe_cast.dart';
import '../widgets/app_shell.dart';
import 'changia_view.dart';

const _kAdminCall = '0763795801';
const _kAdminWa = '255625607088';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});
  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  String _adminPhone = _kAdminCall;
  List<dynamic> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadHistory();
    _setupRealtime();
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWsNotification);
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final res = await ApiService().getDonationInfo();
      final d = asMap(res.data);
      if (mounted) {
        setState(() => _adminPhone = d['phone'] as String? ?? _kAdminCall);
      }
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _loadingHistory = true);
    try {
      final res = await ApiService().getPaymentHistory();
      final data = res.data;
      if (mounted) {
        setState(() {
          if (data is Map) {
            _history = data['items'] ?? data['payments'] ?? [];
          } else if (data is List) {
            _history = data;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  void _setupRealtime() {
    WebSocketService().on('notification', _onWsNotification);
  }

  void _onWsNotification(Map<String, dynamic> payload) {
    final type = payload['type'] ?? '';
    if (type == 'payment.approved' ||
        type == 'payment.rejected' ||
        type == 'payment.reply' ||
        type == 'payment.submitted') {
      _loadHistory();
      if (type == 'payment.approved') {
        // Sasisha session — is_verified=True → mtu aweze kupiga SMS/WA
        context.read<AuthProvider>().refreshUser();
      }
    }
  }

  // ── Mappers: API → Contribution ─────────────────────────────────────────
  ContributionStatus _statusOf(dynamic raw) {
    switch ('$raw') {
      case 'approved':
        return ContributionStatus.approved;
      case 'rejected':
        return ContributionStatus.rejected;
      default:
        return ContributionStatus.pending;
    }
  }

  List<Contribution> get _contributions => _history.map((p) {
        final d =
            DateTime.tryParse('${p['created_at'] ?? ''}') ?? DateTime.now();
        return Contribution(
          id: '${p['payment_id'] ?? p['id'] ?? p['donation_id'] ?? ''}',
          amount: int.tryParse('${p['amount'] ?? 0}') ?? 0,
          createdAt: d,
          status: _statusOf(p['status']),
          reason: (p['note'] ?? p['admin_note'])?.toString(),
        );
      }).toList();

  Future<Contribution?> _submit(ContributionDraft draft) async {
    await ApiService().createDonation(
        amount: draft.amount, smsText: draft.sms, phone: draft.phone);
    await _loadHistory();
    return null; // historia inajaza upya kutoka API
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return AppShell(
      tabIndex: 1,
      child: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _loadingHistory && _history.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ChangiaView(
                payNumber: _adminPhone,
                defaultAmount: 2500,
                userPhone: user?.phone,
                supportPhone: _kAdminCall,
                supportWhatsapp: _kAdminWa,
                history: _contributions,
                onSubmit: _submit,
              ),
      ),
    );
  }
}
