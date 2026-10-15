import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/cached_repository.dart';
import '../services/websocket_service.dart';
import '../providers/auth_provider.dart';
import '../utils/safe_cast.dart';
import '../widgets/app_shell.dart';
import 'changia_view.dart';

// OFFLINE-FIRST — funguo za diski za ukurasa wa donate (changia).
const _kDonateInfoKey = 'page:donate/info';
const _kDonateHistoryKey = 'page:donate/history';

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
    // DISKI PAPO HAPO — frame ya KWANZA (hakuna spring, hakuna kusubiri).
    final repo = CachedRepository();
    repo.hydrate(_kDonateInfoKey, _applyDonateInfo);
    repo.hydrate(_kDonateHistoryKey, _applyHistory);
    _loadInfo();
    _loadHistory();
    _setupRealtime();
  }

  void _applyDonateInfo(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    setState(() => _adminPhone = asMap(data)['phone'] as String? ?? _kAdminCall);
  }

  void _applyHistory(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    setState(() {
      if (data is Map) {
        _history = data['items'] ?? data['payments'] ?? [];
      } else if (data is List) {
        _history = data;
      }
      _loadingHistory = false;
    });
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWsNotification);
    super.dispose();
  }

  Future<void> _loadInfo() async {
    // OFFLINE-FIRST: namba ya admin za diski (papo hapo), kisha refresh.
    await CachedRepository().loadPage(_kDonateInfoKey, _fetchInfo, _applyDonateInfo);
  }

  /// API ya info — huitwa na CachedRepository nyuma ya pazia.
  Future<dynamic> _fetchInfo() async =>
      (await ApiService().getDonationInfo()).data;

  Future<void> _loadHistory() async {
    // OFFLINE-FIRST: historia za diski (papo hapo), kisha refresh nyuma ya pazia.
    if (mounted) setState(() => _loadingHistory = true);
    await CachedRepository().loadPage(_kDonateHistoryKey, _fetchHistory, _applyHistory);
    if (mounted) setState(() => _loadingHistory = false);
  }

  /// API ya historia — huitwa na CachedRepository nyuma ya pazia.
  Future<dynamic> _fetchHistory() async =>
      (await ApiService().getPaymentHistory()).data;


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
        // Jibu la mwisho la admin (messages[] kutoka server — mazungumzo
        // ya malipo; la mwisho ndilo la hivi karibuni)
        String? adminReply;
        final msgs = p['messages'];
        if (msgs is List && msgs.isNotEmpty) {
          for (final m in msgs.reversed) {
            if (m is! Map) continue;
            // Backend inarudisha from/sender/role — jibu la admin litambuliwa
            // kila sharti; text inaweza kuwa message|text|reply.
            final sender =
                '${m['sender'] ?? m['from'] ?? m['role'] ?? ''}';
            final isAdminMsg = sender.contains('admin') || m['is_admin'] == true;
            if (isAdminMsg) {
              final t = '${m['message'] ?? m['text'] ?? m['reply'] ?? ''}'.trim();
              if (t.isNotEmpty) {
                adminReply = t;
                break;
              }
            }
          }
        }
        return Contribution(
          id: '${p['payment_id'] ?? p['id'] ?? p['donation_id'] ?? ''}',
          amount: int.tryParse('${p['amount'] ?? 0}') ?? 0,
          createdAt: d,
          status: _statusOf(p['status']),
          reason: (p['note'] ?? p['admin_note'] ?? adminReply)?.toString(),
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
