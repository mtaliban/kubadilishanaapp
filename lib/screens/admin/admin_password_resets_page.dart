/// Admin password resets page — approve/reject password reset requests.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue50    = Color(0xFFEFF6FF);
const _kBlue200   = Color(0xFFBFDBFE);
const _kGrey50    = Color(0xFFF9FAFB);
const _kGrey100   = Color(0xFFF3F4F6);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey300   = Color(0xFFD1D5DB);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey700   = Color(0xFF374151);
const _kGrey900   = Color(0xFF111827);
const _kGreenDk   = Color(0xFF16A34A);
const _kGreen50   = Color(0xFFF0FDF4);
const _kGreen200  = Color(0xFFBBF7D0);
const _kGreen700  = Color(0xFF15803D);
const _kRed       = Color(0xFFDC2626);
const _kRed50     = Color(0xFFFEF2F2);
const _kRed200    = Color(0xFFFECACA);
const _kAmber50   = Color(0xFFFFFBEB);
const _kAmber200  = Color(0xFFFDE68A);
const _kAmber700  = Color(0xFFB45309);

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
           '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) { return iso.split('T').first; }
}

class AdminPasswordResetsPage extends StatefulWidget {
  const AdminPasswordResetsPage({super.key});
  @override
  State<AdminPasswordResetsPage> createState() => _AdminPasswordResetsPageState();
}

class _AdminPasswordResetsPageState extends State<AdminPasswordResetsPage> {
  List<dynamic> _resets = [];
  bool _loading = true;
  final Map<String, bool> _busy = {};

  String? _flashMsg;
  bool _flashOk = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/admin/password-resets');
      if (!mounted) return;
      setState(() {
        _resets = res.data is List ? res.data : (res.data['resets'] ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFlash(String msg, {bool ok = true}) {
    if (!mounted) return;
    setState(() { _flashMsg = msg; _flashOk = ok; });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flashMsg = null);
    });
  }

  Future<void> _approve(Map<String, dynamic> r) async {
    final id = (r['_id'] ?? r['id'] ?? '').toString();
    setState(() => _busy[id] = true);
    try {
      await ApiService().post('/admin/password-resets/$id/approve');
      _showFlash('Ombi limekubaliwa');
      await _load();
    } catch (_) {
      _showFlash('Hitilafu ya kukubali', ok: false);
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final id = (r['_id'] ?? r['id'] ?? '').toString();
    setState(() => _busy[id] = true);
    try {
      await ApiService().post('/admin/password-resets/$id/reject');
      _showFlash('Ombi limekataliwa');
      await _load();
    } catch (_) {
      _showFlash('Hitilafu ya kukataa', ok: false);
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final pending  = _resets.where((r) => (r['status'] ?? 'pending') == 'pending').length;
    final approved = _resets.where((r) => r['status'] == 'approved').length;
    final rejected = _resets.where((r) => r['status'] == 'rejected').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.key_rounded, size: 20, color: _kBlue),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ombi la Nenosiri (${_resets.length})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kGrey900)),
              const Text('Maombi ya kubadilisha nenosiri',
                style: TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kGrey50, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kGrey200)),
                child: const Center(child: Icon(Icons.refresh_rounded, size: 18, color: _kGrey700)),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: _kGrey100),

        // ── Stat pills ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            _StatPill(label: 'Zinasubiri', count: pending,  color: _kAmber700, bg: _kAmber50,  border: _kAmber200,  icon: Icons.hourglass_top_rounded),
            const SizedBox(width: 6),
            _StatPill(label: 'Zimekubaliwa', count: approved, color: _kGreen700, bg: _kGreen50,  border: _kGreen200,  icon: Icons.check_circle_outline_rounded),
            const SizedBox(width: 6),
            _StatPill(label: 'Zimekataliwa', count: rejected, color: _kRed,      bg: _kRed50,   border: _kRed200,    icon: Icons.cancel_outlined),
          ]),
        ),

        // ── Flash ──
        if (_flashMsg != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _flashOk ? _kGreen50 : _kRed50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _flashOk ? _kGreen200 : _kRed200),
            ),
            child: Row(children: [
              Icon(_flashOk ? Icons.check_circle_outline : Icons.error_outline,
                size: 14, color: _flashOk ? _kGreenDk : _kRed),
              const SizedBox(width: 7),
              Expanded(child: Text(_flashMsg!,
                style: TextStyle(fontSize: 12, color: _flashOk ? _kGreenDk : _kRed))),
            ]),
          ),

        // ── List ──
        Expanded(
          child: _loading
              ? const Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kBlue,
                  child: _resets.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.key_rounded, size: 48, color: _kGrey200),
                          const SizedBox(height: 12),
                          const Text('Hakuna maombi ya nenosiri',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey500)),
                          const SizedBox(height: 4),
                          const Text('Maombi mapya yataonekana hapa',
                            style: TextStyle(fontSize: 12, color: _kGrey400)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                          itemCount: _resets.length,
                          itemBuilder: (context, i) => _ResetCard(
                            r: Map<String, dynamic>.from(_resets[i] as Map),
                            busy: _busy[(_resets[i]['_id'] ?? _resets[i]['id'] ?? '').toString()] == true,
                            onApprove: () => _approve(Map<String, dynamic>.from(_resets[i] as Map)),
                            onReject:  () => _reject(Map<String, dynamic>.from(_resets[i] as Map)),
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}

// ── Stat pill ──────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color, bg, border;
  final IconData icon;
  const _StatPill({required this.label, required this.count, required this.color,
    required this.bg, required this.border, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(height: 3),
        Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label,
          style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.75), fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ── Reset card ─────────────────────────────────────────────────────────────
class _ResetCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final bool busy;
  final VoidCallback onApprove, onReject;
  const _ResetCard({required this.r, required this.busy, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final status   = (r['status'] ?? 'pending').toString();
    final name     = (r['user_name'] ?? r['full_name'] ?? '').toString();
    final phone    = (r['phone'] ?? r['phone_primary'] ?? '').toString();
    final dateRaw  = (r['created_at'] ?? r['requested_at'] ?? '').toString();
    final dateStr  = _fmtDate(dateRaw.isNotEmpty ? dateRaw : null);
    final isPending = status == 'pending';
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : (phone.isNotEmpty ? phone[0] : '?');

    Color stripeColor, badgeBg, badgeFg, badgeBorder;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        stripeColor = _kGreenDk; badgeBg = _kGreen50; badgeFg = _kGreen700;
        badgeBorder = _kGreen200; statusLabel = 'Imekubaliwa'; statusIcon = Icons.check_circle_outline_rounded;
      case 'rejected':
        stripeColor = _kRed; badgeBg = _kRed50; badgeFg = _kRed;
        badgeBorder = _kRed200; statusLabel = 'Imekataliwa'; statusIcon = Icons.cancel_outlined;
      default:
        stripeColor = _kAmber700; badgeBg = _kAmber50; badgeFg = _kAmber700;
        badgeBorder = _kAmber200; statusLabel = 'Inasubiri'; statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left stripe
            Container(width: 4, color: stripeColor),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Top row: avatar + info + status badge
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: stripeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(initial,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: stripeColor))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name.isNotEmpty ? name : 'Mtumiaji',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900)),
                      if (phone.isNotEmpty)
                        Text(phone,
                          style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w500)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg, borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeBorder)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, size: 10, color: badgeFg),
                        const SizedBox(width: 3),
                        Text(statusLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg)),
                      ]),
                    ),
                  ]),

                  // Date
                  if (dateStr != '—') ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: _kGrey400),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(fontSize: 10, color: _kGrey400)),
                    ]),
                  ],

                  // Actions (pending only)
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Container(height: 1, color: _kGrey100),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: busy ? null : onApprove,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: busy ? _kGreen50 : _kGreenDk,
                            borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            if (busy)
                              const SizedBox(width: 13, height: 13,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _kGreenDk))
                            else
                              const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(busy ? 'Inafanya...' : 'Kubali',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: busy ? _kGreenDk : Colors.white)),
                          ]),
                        ),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: GestureDetector(
                        onTap: busy ? null : onReject,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kRed200)),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.cancel_rounded, size: 14, color: _kRed),
                            SizedBox(width: 5),
                            Text('Kataa',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kRed)),
                          ]),
                        ),
                      )),
                    ]),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
