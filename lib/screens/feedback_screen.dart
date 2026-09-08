import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/app_shell.dart';

const _kBlue = Color(0xFF1E40AF);
const _kGrey900 = Color(0xFF111827);
const _kGrey800 = Color(0xFF1F2937);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey300 = Color(0xFFD1D5DB);
const _kGrey200 = Color(0xFFE5E7EB);
const _kRed = Color(0xFFDC2626);

BoxDecoration _cardDec() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12), // rounded-xl=12
      border: Border.all(color: _kGrey200), // border-grey-200
    );

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _msgCtrl = TextEditingController();
  List<dynamic> _items = [];
  bool _loading = true;
  bool _sending = false;
  bool _sent = false;
  String _error = '';
  String _ok = '';
  int _page = 1;
  static const _perPage = 2;

  void _onWs(dynamic payload) {
    if (payload['type'] == 'feedback.replied' && mounted) _load();
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
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMyFeedback();
      final data = res.data;
      if (mounted) {
        if (data is Map) {
          setState(() => _items = (data['items'] ?? data['feedbacks'] ?? []) as List);
        } else if (data is List) {
          setState(() => _items = data);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    setState(() { _error = ''; _ok = ''; });
    final text = _msgCtrl.text.trim();
    if (text.length < 3) {
      setState(() => _error = 'Andika maoni yako kwanza.');
      return;
    }
    setState(() => _sending = true);
    try {
      final subject = text.length > 60 ? '${text.substring(0, 60)}...' : text;
      await ApiService().submitFeedback(subject: subject, message: text);
      if (mounted) {
        setState(() {
          _ok = '✓ Maoni yako yametumwa kwa admin — utajibiwa hivi karibuni.';
          _msgCtrl.clear();
          _sent = true;
        });
        _load();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _sent = false);
      }
    } catch (e) {
      if (mounted) {
        try {
          final d = (e as dynamic).response?.data?['detail'];
          setState(() => _error = d is String ? d : 'Imeshindikana kutuma — jaribu tena.');
        } catch (_) {
          setState(() => _error = 'Imeshindikana kutuma — jaribu tena.');
        }
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = (_items.length / _perPage).ceil().clamp(1, 9999);
    final safe = _page.clamp(1, total);
    final start = (safe - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _items.length);
    final paged = _items.sublist(start, end);

    return AppShell(
      tabIndex: 2,
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: icon + title + subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset('assets/icons/clipboard-list.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(_kBlue, BlendMode.srcIn)),
                      const SizedBox(width: 8),
                      const Text(
                        'Maoni na Malalamiko',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tuma maoni au malalamiko yako moja kwa moja kwa admin — utajibiwa hapa.',
                    style: TextStyle(fontSize: 12, color: _kGrey500),
                  ),
                ],
              ),
              const SizedBox(height: 16), // space-y-4

                // Form card (.card = rounded-xl p-4 border-grey-200)
                Container(
                  padding: const EdgeInsets.all(16), // p-4=16px
                  decoration: _cardDec(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // .label: text-sm=14px font-semibold text-grey-700 mb-1.5=6px
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Ujumbe wako',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kGrey700,
                          ),
                        ),
                      ),
                      // Textarea: rounded-lg=8 border-grey-300 px-4=16 py-2.5=10 min-h-[110px]
                      TextField(
                        controller: _msgCtrl,
                        maxLines: 5,
                        minLines: 5,
                        style: const TextStyle(fontSize: 14, color: _kGrey900),
                        decoration: InputDecoration(
                          hintText: 'Andika maoni/malalamiko yako hapa...',
                          hintStyle: const TextStyle(color: _kGrey500, fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10), // px-4=16 py-2.5=10
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8), // rounded-lg=8
                            borderSide: const BorderSide(color: _kGrey300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _kBlue, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      // Error: bg-red-50 text-red text-sm=14 rounded-lg=8 p-3=12
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12), // p-3=12px
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2), // bg-red-50
                            borderRadius: BorderRadius.circular(8), // rounded-lg=8
                          ),
                          child: Text(_error,
                              style: const TextStyle(color: _kRed, fontSize: 14)),
                        ),
                      ],
                      // Ok: bg-green-50 text-green-700 text-sm=14 rounded-lg=8 p-3=12
                      if (_ok.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12), // p-3=12px
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4), // bg-green-50
                            borderRadius: BorderRadius.circular(8), // rounded-lg=8
                          ),
                          child: Text(_ok,
                              style: const TextStyle(
                                  color: Color(0xFF15803D), // text-green-700
                                  fontSize: 14)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Submit button: justify-end, text-xs=12 px-4=16 py-1.5=6 rounded-lg=8 bg-brand-blue
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: _sending ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue,
                              disabledBackgroundColor:
                                  _kBlue.withValues(alpha: 0.4),
                              foregroundColor: Colors.white,
                              minimumSize: Size.zero, // iwe ndogo kama web
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6), // px-4=16 py-1.5=6
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)), // rounded-lg=8
                              elevation: 0,
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(_sent ? 'Imetumwa ✓' : 'Tuma'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16), // space-y-4

                // History header: font-semibold text-sm=14 text-grey-700 mb-2=8px
                Text(
                  'Maoni yangu (${_items.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _kGrey700,
                  ),
                ),
                const SizedBox(height: 8), // mb-2=8px

                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_items.isEmpty)
                  const Text(
                    'Hujatuma maoni bado.',
                    style: TextStyle(fontSize: 14, color: _kGrey500),
                  )
                else ...[
                  // space-y-2=8px between cards
                  for (final f in paged)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FbCard(item: f),
                    ),
                  // Pagination (only if > perPage items)
                  if (_items.length > _perPage)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PageBtn(
                            label: '← Rudi',
                            enabled: safe > 1,
                            onTap: () => setState(() => _page = safe - 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$safe / $total',
                              style: const TextStyle(
                                fontSize: 14, // text-sm
                                fontWeight: FontWeight.bold,
                                color: _kGrey500,
                              ),
                            ),
                          ),
                          _PageBtn(
                            label: 'Endelea →',
                            enabled: safe < total,
                            onTap: () => setState(() => _page = safe + 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44), // min-w/h-[44px]
        padding: const EdgeInsets.symmetric(horizontal: 12), // px-3=12
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), // rounded-xl=12
          border: Border.all(color: _kGrey200), // border-grey-200
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14, // text-sm
            fontWeight: FontWeight.w600,
            color: enabled ? _kGrey700 : _kGrey400,
          ),
        ),
      ),
    );
  }
}

class _FbCard extends StatelessWidget {
  final dynamic item;
  const _FbCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isReplied = item['status'] == 'replied';
    final message = '${item['message'] ?? ''}';
    final reply = '${item['admin_reply'] ?? ''}';
    final iso = '${item['created_at'] ?? ''}';
    String ago = '';
    try {
      if (iso.isNotEmpty) {
        final d = DateTime.parse(iso).toLocal();
        final diff = DateTime.now().difference(d);
        if (diff.inMinutes < 1) {
          ago = 'Sasa hivi';
        } else if (diff.inMinutes < 60) {
          ago = 'dakika ${diff.inMinutes} iliyopita';
        } else if (diff.inHours < 24) {
          ago = 'saa ${diff.inHours} iliyopita';
        } else {
          ago = 'siku ${diff.inDays} iliyopita';
        }
      }
    } catch (_) {}

    // .card = rounded-xl=12 p-4=16 border-grey-200 bg-white
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDec(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + time: flex justify-between mb-1=4px
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2), // px-2=8 py-0.5=2
                decoration: BoxDecoration(
                  // green-100 / amber-100 (brand-gold-100)
                  color: isReplied
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999), // rounded-full
                ),
                child: Text(
                  isReplied ? '✓ Yamejibiwa' : 'Hakuna jibu',
                  style: TextStyle(
                    fontSize: 10, // text-[10px]
                    fontWeight: FontWeight.bold,
                    color: isReplied
                        ? const Color(0xFF15803D) // green-700
                        : const Color(0xFFD97706), // brand-gold-600
                  ),
                ),
              ),
              const Spacer(),
              if (ago.isNotEmpty)
                Text(ago,
                    style:
                        const TextStyle(fontSize: 11, color: _kGrey400)), // text-[11px]
            ],
          ),
          const SizedBox(height: 4), // mb-1=4px
          // Message: text-sm=14 text-grey-700 whitespace-pre-wrap
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: _kGrey700),
          ),
          // Admin reply block
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 8), // mt-2=8px
            Container(
              padding: const EdgeInsets.all(10), // p-2.5=10px
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // bg-brand-blue-50
                borderRadius: BorderRadius.circular(8), // rounded-lg=8
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JIBU LA ADMIN',
                    style: TextStyle(
                      fontSize: 10, // text-[10px]
                      fontWeight: FontWeight.bold,
                      color: _kBlue,
                      letterSpacing: 0.8, // tracking-wide
                    ),
                  ),
                  const SizedBox(height: 2), // mb-0.5=2px
                  Text(
                    reply,
                    style: const TextStyle(
                        fontSize: 14, color: _kGrey800), // text-sm text-grey-800
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
