import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';

const _kAdminCall = '0763795801';
const _kAdminWa   = '255625607088';

// ── Brand colors ──────────────────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue700   = Color(0xFF1D4ED8);
const _kGrey900   = Color(0xFF111827);
const _kGrey700   = Color(0xFF374151);
const _kGrey600   = Color(0xFF4B5563);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey300   = Color(0xFFD1D5DB);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey100   = Color(0xFFF3F4F6);
const _kGrey50    = Color(0xFFF9FAFB);
const _kRed       = Color(0xFFDC2626);
const _kRed100    = Color(0xFFFEE2E2);
const _kEmerald100 = Color(0xFFD1FAE5);
const _kEmerald700 = Color(0xFF047857);
const _kGold100   = Color(0xFFFEF3C7); // brand-gold-100
const _kGold600   = Color(0xFFD97706); // brand-gold-600
const _kGold500   = Color(0xFFF59E0B); // brand-gold-500

// .card = rounded-xl p-4 border-grey-200 bg-white
BoxDecoration _cardDec() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: _kGrey200),
);

// .input = rounded-md=6 border-grey-300 px-2.5=10 py-1.5=6 text-xs=12
InputDecoration _inputDec({String? hint}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey300)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey300)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kBlue, width: 2)),
  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
  filled: true,
  fillColor: Colors.white,
);

// .label = text-sm=14 font-semibold text-grey-700 mb-1.5=6px
Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
);

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});
  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  String _adminPhone = '';
  String _currency = 'TZS';

  final _amountCtrl = TextEditingController(text: '5000');
  final _phoneCtrl  = TextEditingController();
  final _smsCtrl    = TextEditingController();

  List<dynamic> _history = [];
  String  _historyFilter  = '';
  bool    _loadingHistory = true;
  bool    _sending = false;
  bool    _sent    = false;
  bool    _copied  = false;
  String  _error   = '';
  Map<String, dynamic>? _flash;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadHistory();
    _setupRealtime();
    final auth = context.read<AuthProvider>();
    _phoneCtrl.text = auth.user?.phone ?? '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final res = await ApiService().getDonationInfo();
      final d = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _adminPhone = d['phone'] as String? ?? _kAdminCall;
          _currency   = d['currency'] as String? ?? 'TZS';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _adminPhone = _kAdminCall);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await ApiService().getPaymentHistory();
      final data = res.data;
      if (mounted) {
        setState(() {
          if (data is Map) { _history = data['items'] ?? data['payments'] ?? []; }
          else if (data is List) { _history = data; }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  void _setupRealtime() {
    final ws = WebSocketService();
    ws.on('notification', (payload) {
      final type = payload['type'] ?? '';
      if (type == 'payment.approved') {
        _setFlash({'type': 'success', 'msg': '✓ Malipo yamethibitishwa'});
        _loadHistory();
        // Sasisha session — is_verified=True → mtu aweze kupiga SMS/WA (kama web)
        context.read<AuthProvider>().refreshUser();
      } else if (type == 'payment.rejected') {
        _setFlash({'type': 'info', 'msg': '✗ Malipo yamekataliwa'});
        _loadHistory();
      } else if (type == 'payment.reply' || type == 'payment.submitted') {
        _loadHistory();
      }
    });
  }

  void _setFlash(Map<String, dynamic> f) {
    if (!mounted) return;
    setState(() => _flash = f);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _copyPhone() {
    Clipboard.setData(ClipboardData(text: _adminPhone));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final sms    = _smsCtrl.text.trim();
    if (amount < 500) { setState(() => _error = 'Weka kiasi cha TZS 500 au zaidi.'); return; }
    if (sms.length < 3) { setState(() => _error = 'Andika au nakili SMS yoyote uliyopata kutoka kwa mtandao wako.'); return; }

    setState(() => _sending = true);
    try {
      await ApiService().createDonation(
          amount: amount, smsText: sms, phone: _phoneCtrl.text.trim());
      if (mounted) {
        setState(() { _sent = true; _sending = false; });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) { setState(() { _sent = false; _smsCtrl.clear(); }); _loadHistory(); }
      }
    } catch (e) {
      if (mounted) setState(() { _error = _parseError(e); _sending = false; });
    }
  }

  String _parseError(dynamic e) {
    try {
      final d = (e as dynamic).response?.data?['detail'];
      if (d is String) return d;
    } catch (_) {}
    return 'Kosa la mtandao. Jaribu tena.';
  }

  List<dynamic> get _filteredHistory =>
      _historyFilter.isEmpty ? _history : _history.where((p) => p['status'] == _historyFilter).toList();

  bool get _busy => _sending || _sent;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      tabIndex: 1,
      child: RefreshIndicator(
        onRefresh: _loadHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // p-4 md:p-6
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── Header: HandCoins title + subtitle ──
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SvgPicture.asset('assets/icons/hand-coins.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(_kRed, BlendMode.srcIn)),
                const SizedBox(width: 8),
                const Text('Changia Huduma',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900)),
              ]),
              const SizedBox(height: 2),
              const Text(
                'Lipa kwa namba hapa chini, kisha nakili SMS ya kuthibitisha.',
                style: TextStyle(fontSize: 12, color: _kGrey500),
              ),
            ]),

              const SizedBox(height: 16), // space-y-4

              // ── Flash notification ──
              // web: rounded-lg border px-3=12 py-2=8 text-sm=14 font-medium
              if (_flash != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _flash!['type'] == 'success'
                        ? const Color(0xFFECFDF5)  // emerald-50
                        : const Color(0xFFEFF6FF),  // brand-blue-50
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _flash!['type'] == 'success'
                          ? const Color(0xFFA7F3D0)  // emerald-200
                          : const Color(0xFFBFDBFE).withValues(alpha: 0.5), // brand-blue/30
                    ),
                  ),
                  child: Text('${_flash!['msg']}',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500,
                        color: _flash!['type'] == 'success'
                            ? const Color(0xFF047857)  // emerald-700
                            : _kBlue700,               // brand-blue-700
                      )),
                ),
                const SizedBox(height: 16),
              ],

              // ── Admin phone card ──
              // web: .card flex items-center justify-between gap-3 px-4=16 py-3=12
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: _cardDec(),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // text-[10px] uppercase tracking-wide text-grey-500 font-semibold
                    const Text('LIPA KWA NAMBA HII',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: _kGrey500, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    // text-xl=20px font-bold text-brand-blue tracking-wide
                    Text(
                      _adminPhone.isEmpty ? '...' : _adminPhone,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: _kBlue, letterSpacing: 0.5),
                    ),
                  ])),
                  const SizedBox(width: 12), // gap-3=12px

                  // btn-outline when not copied, btn-primary-like when copied
                  // web: px-3=12 py-1.5=6 text-xs=12 font-bold rounded-md=6 gap-1.5=6
                  GestureDetector(
                    onTap: _copyPhone,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _copied ? _kBlue : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _copied ? _kBlue : _kGrey300),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy_outlined,
                          size: 13,
                          color: _copied ? Colors.white : _kGrey700,
                        ),
                        const SizedBox(width: 6), // gap-1.5=6px
                        Text(
                          _copied ? 'Imenakiliwa' : 'Nakili',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: _copied ? Colors.white : _kGrey700,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16), // space-y-4

              // ── Donation form — .card space-y-3 ──
              Container(
                padding: const EdgeInsets.all(16), // p-4=16px
                decoration: _cardDec(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                  // web: grid grid-cols-1 sm:grid-cols-2 — mobile (<640px) ni 1 column stacked
                  _label('Kiasi ($_currency)'),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    enabled: !_busy,
                    style: const TextStyle(fontSize: 12),
                    decoration: _inputDec(hint: '5000'),
                  ),
                  const SizedBox(height: 12), // gap-3=12px
                  _label('Namba ya Simu'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    enabled: !_busy,
                    style: const TextStyle(fontSize: 12),
                    decoration: _inputDec(hint: '0712345678'),
                  ),

                  const SizedBox(height: 12), // space-y-3=12px

                  // SMS textarea
                  _label('SMS ya Kuthibitisha Malipo'),
                  TextField(
                    controller: _smsCtrl,
                    minLines: 4, // min-h-[90px] ≈ 4 lines
                    maxLines: 8,
                    enabled: !_busy,
                    style: const TextStyle(fontSize: 12),
                    onChanged: (_) => setState(() => _error = ''),
                    decoration: _inputDec(
                      hint: 'C2H8MZ3JX1 Confirmed. You have received TZS 5,000.00 from JOHN KAMWENDA...',
                    ).copyWith(
                      contentPadding: const EdgeInsets.all(10),
                      alignLabelWithHint: true,
                    ),
                  ),

                  // Error — bg-brand-red-50 text-brand-red rounded-lg=8 p-2=8 text-sm=14
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2), // bg-brand-red-50
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error, style: const TextStyle(color: _kRed, fontSize: 14)),
                    ),
                  ],

                  const SizedBox(height: 12), // space-y-3

                  // Submit button — btn-primary w-full justify-center
                  // web: btn-primary = bg-brand-blue rounded-md=6 px-3=12 py-1.5=6 text-xs=12 font-bold w-full
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        disabledBackgroundColor: _kBlue.withValues(alpha: 0.7),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), // text-xs=12 font-bold
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // px-3=12 py-1.5=6
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), // rounded-md=6
                        elevation: 0,
                      ),
                      child: _sending
                          ? const Row(mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 8),
                              Text('Inatuma...'),
                            ])
                          : Text(_sent ? '✓ Imetumwa' : 'Thibitisha Malipo'),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16), // space-y-4

              // ── History — onyesha tu kama history ipo ──
              if (_history.isNotEmpty) ...[
                _buildHistorySection(),
                const SizedBox(height: 16),
              ],

              // ── Admin contact ──
              // web: rounded-2xl=16px border-grey-100 bg-white px-4=16 py-3=12
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16), // rounded-2xl
                  border: Border.all(color: _kGrey100), // border-grey-100
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // text-[10px] uppercase tracking-wide text-grey-500 font-semibold mb-2=8px
                  const Text('MASWALI AU MATATIZO? WASILIANA NASI',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: _kGrey500, letterSpacing: 0.8)),
                  const SizedBox(height: 8), // mb-2=8px

                  // flex flex-col gap-2=8px text-sm=14
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('tel:$_kAdminCall'), mode: LaunchMode.externalApplication),
                    child: const Row(children: [
                      Icon(Icons.phone, size: 14, color: _kBlue), // Phone size=14 text-brand-blue
                      SizedBox(width: 8), // gap-2
                      Text(_kAdminCall,
                          style: TextStyle(fontSize: 14, color: _kGrey700, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  const SizedBox(height: 8), // gap-2=8px
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://wa.me/$_kAdminWa'), mode: LaunchMode.externalApplication),
                    child: const Row(children: [
                      Icon(Icons.chat, size: 14, color: Color(0xFF059669)), // MessageCircle text-emerald-600
                      SizedBox(width: 8),
                      Text('+255 625 607 088',
                          style: TextStyle(fontSize: 14, color: _kGrey700, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
    );
  }

  Widget _buildHistorySection() {
    // counts
    final cntAll       = _history.length;
    final cntVerifying = _history.where((p) => p['status'] == 'verifying').length;
    final cntApproved  = _history.where((p) => p['status'] == 'approved').length;
    final cntRejected  = _history.where((p) => p['status'] == 'rejected').length;

    // web: space-y-3=12px between filters and table
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

      // ── Filter pills ──
      // web: flex items-center gap-1.5=6px flex-wrap
      // px-2.5=10 py-1=4 rounded-full border text-[11px] font-semibold
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final f in [
          ['', 'Zote', cntAll],
          ['verifying', 'Inasubiri', cntVerifying],
          ['approved', 'Imekamilika', cntApproved],
          ['rejected', 'Imekataliwa', cntRejected],
        ])
          GestureDetector(
            onTap: () => setState(() => _historyFilter = f[0] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _historyFilter == f[0] ? _kBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(999), // rounded-full
                border: Border.all(
                  color: _historyFilter == f[0] ? _kBlue : _kGrey300,
                ),
              ),
              child: Text(
                '${f[1]} (${f[2]})',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _historyFilter == f[0] ? Colors.white : _kGrey600,
                ),
              ),
            ),
          ),
      ]),

      const SizedBox(height: 12), // space-y-3=12px

      // ── Table ── .card overflow-hidden
      if (_loadingHistory)
        const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator()))
      else
        Container(
          decoration: _cardDec().copyWith(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(children: [
            // thead: bg-grey-50, text-[10px] uppercase tracking-wide text-grey-500
            // px-4=16 py-2=8
            Container(
              color: _kGrey50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(children: [
                SizedBox(width: 24,
                    child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: _kGrey500, letterSpacing: 0.8))),
                SizedBox(width: 8),
                Expanded(child: Text('KIASI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _kGrey500, letterSpacing: 0.8))),
                Expanded(child: Text('MUDA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _kGrey500, letterSpacing: 0.8))),
                Text('HALI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _kGrey500, letterSpacing: 0.8)),
              ]),
            ),
            // divide-y divide-grey-100
            const Divider(height: 1, color: _kGrey100),

            if (_filteredHistory.isEmpty)
              // empty filter state: px-4=16 py-8=32 text-center text-grey-400 text-xs=12
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: Text(
                  _historyFilter.isEmpty ? 'Hakuna michango bado.' : 'Hakuna malipo katika kichujio hiki.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _kGrey400),
                ),
              )
            else
              for (int i = 0; i < _filteredHistory.length; i++) ...[
                _HistoryRow(payment: _filteredHistory[i], index: i),
                if (i < _filteredHistory.length - 1)
                  const Divider(height: 1, color: _kGrey100), // divide-y divide-grey-100
              ],
          ]),
        ),
    ]);
  }
}

// ── HistoryRow — kila malipo ──────────────────────────────────────────────────
// web: <tr> px-4=16 py-2.5=10
class _HistoryRow extends StatelessWidget {
  final dynamic payment;
  final int index;
  const _HistoryRow({required this.payment, required this.index});

  @override
  Widget build(BuildContext context) {
    final status = payment['status'] ?? 'verifying';
    final amount = payment['amount'];
    final note   = payment['note'] ?? payment['admin_note'] ?? '';
    final iso    = payment['created_at'] ?? '';

    // Status badge values — kama web
    Color bgColor; Color txtColor; String label;
    if (status == 'approved') {
      bgColor = _kEmerald100; txtColor = _kEmerald700; label = '✓ Imekamilika';
    } else if (status == 'rejected') {
      bgColor = _kRed100; txtColor = _kRed; label = '✗ Imekataliwa';
    } else {
      bgColor = _kGold100; txtColor = _kGold600; label = 'Inasubiri';
    }

    // Time ago + full date
    String ago = '', fullDate = '';
    try {
      if (iso.isNotEmpty) {
        final d = DateTime.parse(iso).toLocal();
        final diff = DateTime.now().difference(d);
        if (diff.inMinutes < 1)       { ago = 'Sasa hivi'; }
        else if (diff.inMinutes < 60) { ago = 'dakika ${diff.inMinutes} iliyopita'; }
        else if (diff.inHours < 24)   { ago = 'saa ${diff.inHours} iliyopita'; }
        else                          { ago = 'siku ${diff.inDays} iliyopita'; }
        fullDate = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} '
            '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
      }
    } catch (_) {}

    // web: tr px-4=16 py-2.5=10
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // # column — text-xs=12? actually web text-xs font-bold text-grey-400 w-10=40px
        SizedBox(
          width: 24,
          child: Text('${index + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kGrey400)),
        ),
        const SizedBox(width: 8),

        // Amount + date column
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // font-bold text-grey-900
          if (amount != null)
            RichText(text: TextSpan(
              style: const TextStyle(fontFamily: ''),
              children: [
                TextSpan(
                  text: amount is int ? amount.toLocaleString() : '$amount',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900),
                ),
                const TextSpan(text: ' TZS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey500)),
              ],
            )),
          if (ago.isNotEmpty) ...[
            const SizedBox(height: 2),
            // text-grey-900 font-medium
            Text(ago, style: const TextStyle(fontSize: 13, color: _kGrey900, fontWeight: FontWeight.w500)),
            // text-[11px] text-grey-500
            Text(fullDate, style: const TextStyle(fontSize: 11, color: _kGrey500)),
          ],
        ])),

        const SizedBox(width: 8),

        // Status column — text-right
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Status badge: text-[11px] font-bold px-2.5=10 py-1=4 rounded-full
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(999)),
            child: status == 'verifying'
                // verifying: w-1.5 h-1.5 pulse dot + text
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: _kGold500),
                    ),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: txtColor)),
                  ])
                : Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: txtColor)),
          ),

          // Rejection note + Contact Admin — web: mt-1.5 text-right
          if (status == 'rejected' && note.toString().isNotEmpty) ...[
            const SizedBox(height: 6), // mt-1.5=6px
            // text-[10px] text-brand-red
            Text('$note', textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 10, color: _kRed)),
          ],
          if (status == 'rejected') ...[
            const SizedBox(height: 2),
            // text-[10px] text-brand-blue font-semibold "Wasiliana na Admin →"
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:$_kAdminCall'), mode: LaunchMode.externalApplication),
              child: const Text('Wasiliana na Admin →',
                  style: TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ]),
    );
  }
}

// Helper: format int with commas
extension on int {
  String toLocaleString() {
    final s = toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
