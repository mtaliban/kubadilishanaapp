import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey50  = Color(0xFFF9FAFB);

const _kPageSize = 6;

// ─── Type style helpers ───────────────────────────────────────────────────────

({IconData icon, Color color, Color bg, String label}) _typeStyle(String t) {
  switch (t) {
    case 'warning':
      return (icon: PhosphorIcons.warning(PhosphorIconsStyle.fill),
              color: _kAmber, bg: _kAmberBg, label: 'Onyo');
    case 'success':
      return (icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              color: _kGreen, bg: _kGreenBg, label: 'Mafanikio');
    case 'urgent':
      return (icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
              color: _kRed, bg: _kRedBg, label: 'Haraka');
    default:
      return (icon: PhosphorIcons.info(PhosphorIconsStyle.fill),
              color: _kBlue, bg: _kBlueBg, label: 'Taarifa');
  }
}

// ─── Department icon helper ───────────────────────────────────────────────────

({IconData icon, Color color}) _deptStyle(String code) {
  switch (code) {
    case 'health':
      return (icon: PhosphorIcons.heartbeat(PhosphorIconsStyle.fill),
              color: _kRed);
    case 'education':
      return (icon: PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
              color: const Color(0xFF2563EB));
    case 'kilimo':
      return (icon: PhosphorIcons.plant(PhosphorIconsStyle.fill),
              color: _kGreen);
    case 'watumishi_wa_umma':
      return (icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
              color: const Color(0xFF9333EA));
    default:
      return (icon: PhosphorIcons.buildings(PhosphorIconsStyle.fill),
              color: _kGrey500);
  }
}

// ─── Swahili date formatter ───────────────────────────────────────────────────

String _formatDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = ['Januari','Februari','Machi','Aprili','Mei','Juni',
        'Julai','Agosti','Septemba','Oktoba','Novemba','Desemba'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  } catch (_) {
    return iso;
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  int _page = 0;

  final _formKey = GlobalKey<FormState>();
  final _scroll  = ScrollController();

  List<dynamic> _departments = [];

  final _titleCtrl = TextEditingController();
  final _msgCtrl   = TextEditingController();
  String _type     = 'info';
  Set<String> _audiences = {'all'};
  bool   _sending  = false;
  String? _sendResult;

  final _userSearchCtrl = TextEditingController();
  List<dynamic> _userResults = [];
  Map<String, dynamic>? _selectedUser;
  bool _searchingUsers = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadDepts();
    _userSearchCtrl.addListener(_onUserSearch);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _userSearchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminListAnnouncements();
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _items = data is List ? data
            : (data['announcements'] as List?
                ?? data['results'] as List?
                ?? data['items'] as List?
                ?? []);
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadDepts() async {
    try {
      final r = await ApiService().adminListDepartments();
      final raw = r.data;
      if (!mounted) return;
      setState(() {
        _departments = raw is List ? raw
            : (raw['results'] ?? raw['items'] ?? raw['data'] ?? []);
      });
    } catch (_) {}
  }

  void _onUserSearch() async {
    final q = _userSearchCtrl.text.trim();
    if (q.isEmpty) { setState(() { _userResults = []; }); return; }
    setState(() { _searchingUsers = true; });
    try {
      final r = await ApiService().adminUsers(
          params: {'q': q, 'limit': 10}, useCache: false);
      if (!mounted) return;
      final data = r.data;
      setState(() {
        _userResults = data is List ? data : (data['results'] as List? ?? []);
        _searchingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _searchingUsers = false; });
    }
  }

  Future<void> _send() async {
    // Validation yenye maonyesho ya makosa (kama reference)
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final single = _audiences.contains('user');
    if (single && _selectedUser == null) {
      setState(() => _sendResult = 'Chagua mtumiaji mmoja kwanza');
      return;
    }
    setState(() { _sending = true; _sendResult = null; });
    try {
      final targetId = _selectedUser == null
          ? null
          : (_selectedUser!['id']?.toString() ??
              _selectedUser!['user_id']?.toString() ??
              _selectedUser!['_id']?.toString());
      final payload = <String, dynamic>{
        'title':    _titleCtrl.text.trim(),
        'message':  _msgCtrl.text.trim(),
        'type':     _type,
        'audience': single ? 'user' : (_audiences.length == 1 ? _audiences.first : 'all'),
        'audiences': _audiences.toList(),
      };
      if (single && targetId != null) {
        payload['target_user_id'] = targetId;
      }
      await ApiService().adminSendAnnouncement(payload);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendResult = 'ok';
        _titleCtrl.clear();
        _msgCtrl.clear();
        _type = 'info';
        _audiences = {'all'};
        _selectedUser = null;
        _userSearchCtrl.clear();
        _userResults = [];
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _sending = false; _sendResult = e.toString(); });
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        onConfirm: () => Navigator.pop(context, true),
        onCancel:  () => Navigator.pop(context, false),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService().adminDeleteAnnouncement(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _resend(String id) async {
    try {
      await ApiService().adminResendAnnouncement(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Tangazo limetumwa tena'),
            backgroundColor: _kGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  String _audienceLabel(String a) {
    if (a == 'all')  return 'Wote';
    if (a == 'user') return 'Mtu Mmoja';
    try {
      final dept = _departments.firstWhere((d) => (d['code'] ?? '') == a);
      return (dept['display_name'] ?? dept['name'] ?? a) as String;
    } catch (_) {
      return a;
    }
  }

  /// Lebo ya walengwa — audiences nyingi zinajiunga kwa koma.
  String _audiencesLabel(List<String> auds) {
    final clean = auds.where((a) => a.isNotEmpty).toList();
    if (clean.isEmpty) return 'Wote';
    return clean.map(_audienceLabel).join(', ');
  }

  // ── INPUT DECORATION ──────────────────────────────────────────────────────

  InputDecoration _inputDec(String hint, {Widget? suffix, IconData? prefixIcon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: _kGrey400),
        prefixIcon: prefixIcon != null
            ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(prefixIcon, size: 16, color: _kGrey400))
            : null,
        prefixIconConstraints: prefixIcon != null
            ? const BoxConstraints(minWidth: 44, minHeight: 0)
            : null,
        filled: true,
        fillColor: _kGrey50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGrey200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGrey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        suffixIcon: suffix,
      );

  // ── SEND FORM ──────────────────────────────────────────────────────────────

  Widget _buildSendForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kichwa cha kadi
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _kGrey200)),
              ),
              child: Row(children: [
                Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.fill), size: 18, color: _kGrey500),
                const SizedBox(width: 8),
                Text('Tuma tangazo jipya',
                    style: GoogleFonts.inter(fontSize: 16,
                        fontWeight: FontWeight.w700, color: _kGrey900)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1 — Kichwa
                  _stepLabel(1, 'Kichwa cha habari'),
                  TextFormField(
                    controller: _titleCtrl,
                    style: GoogleFonts.inter(fontSize: 14),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Andika kichwa cha tangazo' : null,
                    decoration: _plainDec('Andika kichwa...'),
                  ),
                  const SizedBox(height: 20),

                  // Step 2 — Ujumbe
                  _stepLabel(2, 'Ujumbe'),
                  TextFormField(
                    controller: _msgCtrl,
                    minLines: 4,
                    maxLines: 6,
                    style: GoogleFonts.inter(fontSize: 14),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Andika ujumbe wa tangazo' : null,
                    decoration: _plainDec('Andika ujumbe wa tangazo...'),
                  ),
                  const SizedBox(height: 20),

                  // Step 3 — Wasikilizaji (switches, multi-select)
                  _stepLabel(3, 'Wasikilizaji'),
                  const SizedBox(height: 4),
                  _audienceRow('all',
                      PhosphorIcons.usersThree(PhosphorIconsStyle.fill), 'Wote'),
                  for (final d in _departments)
                    _audienceRow(
                      (d['code'] ?? '') as String,
                      _deptStyle((d['code'] ?? '') as String).icon,
                      d['name'] as String? ?? (d['code'] ?? '') as String,
                    ),
                  _audienceRow('user',
                      PhosphorIcons.user(PhosphorIconsStyle.fill), 'Mtu Mmoja'),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: _audiences.contains('user')
                        ? _buildUserSearch()
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // Step 4 — Aina (chips)
                  _stepLabel(4, 'Aina ya tangazo'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['info', 'warning', 'success', 'urgent'].map((t) {
                        final s = _typeStyle(t);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _AinaChip(
                            icon: s.icon,
                            label: s.label,
                            selected: _type == t,
                            color: s.color,
                            onTap: () => setState(() => _type = t),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Matokeo ya kutuma
                  if (_sendResult != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _sendResult == 'ok' ? _kGreenBg : _kRedBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(
                          _sendResult == 'ok'
                              ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                              : PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                          color: _sendResult == 'ok' ? _kGreen : _kRed,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          _sendResult == 'ok'
                              ? '✓ Tangazo limetumwa!'
                              : 'Kosa: $_sendResult',
                          style: GoogleFonts.inter(fontSize: 12,
                              color: _sendResult == 'ok' ? _kGreen : _kRed,
                              fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Kitufe cha kutuma
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _sending
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Tuma tangazo',
                              style: GoogleFonts.inter(fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step label (duara la namba + maandishi) ──────────────────────────────
  Widget _stepLabel(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle),
          child: Text('$number',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text(text, style: GoogleFonts.inter(fontSize: 13, color: _kGrey500)),
      ]),
    );
  }

  // ── Field nyeupe na border ya kijivu (kama reference) ────────────────────
  InputDecoration _plainDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13.5, color: _kGrey400),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      );

  // ── Mzunguko wa audience (multi-select switches) ──────────────────────────
  void _toggleAudience(String code, bool on) {
    setState(() {
      if (code == 'all' || code == 'user') {
        _audiences = on ? {code} : <String>{'all'};
      } else {
        if (on) {
          _audiences.add(code);
          _audiences.remove('all');
        } else {
          _audiences.remove(code);
        }
        if (_audiences.isEmpty) _audiences.add('all');
      }
    });
  }

  Widget _audienceRow(String code, IconData icon, String label) {
    final isLast = code == 'user';
    final on = _audiences.contains(code);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: _kGrey200),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: on ? _kBlue : _kGrey400),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.inter(
            fontSize: 14,
            color: on ? _kGrey900 : _kGrey500,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400))),
        Switch(
          value: on,
          activeColor: Colors.white,
          activeTrackColor: _kBlue,
          inactiveTrackColor: const Color(0xFFD1D5DB),
          onChanged: (v) => _toggleAudience(code, v),
        ),
      ]),
    );
  }

  // ── USER SEARCH (Mtu Mmoja) ─────────────────────────────────────────────

  Widget _buildUserSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _userSearchCtrl,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDec(
            'Tafuta mtumiaji...',
            prefixIcon: PhosphorIcons.magnifyingGlass(),
            suffix: _searchingUsers
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kBlue)),
                  )
                : null,
          ),
        ),
        if (_selectedUser != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _kBlueBg,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(PhosphorIcons.user(PhosphorIconsStyle.fill),
                  color: _kBlue, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedUser!['full_name'] as String? ?? '',
                  style: GoogleFonts.inter(fontSize: 13, color: _kBlue,
                      fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedUser = null;
                  _userSearchCtrl.clear();
                  _userResults = [];
                }),
                child: Icon(PhosphorIcons.x(), color: _kBlue, size: 15),
              ),
            ]),
          ),
        ],
        if (_userResults.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _kGrey200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _userResults.length,
              itemBuilder: (_, i) {
                final u = asMap(_userResults[i]);
                return InkWell(
                  onTap: () => setState(() {
                    _selectedUser = u;
                    _userSearchCtrl.text = u['full_name'] as String? ?? '';
                    _userResults = [];
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Icon(PhosphorIcons.user(), size: 14, color: _kGrey500),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        u['full_name'] as String? ?? '',
                        style: GoogleFonts.inter(fontSize: 13, color: _kGrey900),
                      )),
                      Text(u['phone_primary'] as String? ?? u['phone'] as String? ?? '',
                          style: GoogleFonts.inter(fontSize: 11,
                              color: _kGrey500)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── ANNOUNCEMENT CARD ─────────────────────────────────────────────────────

  Widget _buildCard(Map<String, dynamic> item) {
    final id             = item['id']?.toString() ?? '';
    final title          = item['title'] as String? ?? '';
    final message        = item['message'] as String? ?? '';
    final type           = item['type'] as String? ?? 'info';
    final audience       = item['audience'] as String? ?? 'all';
    final createdAt      = item['created_at'] as String? ?? '';
    final recipientsCount = item['recipients_count'] as int? ?? 0;

    final s = _typeStyle(type);
    final auds = (item['audiences'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [audience];

    // Kadi nyeupe yenye border (kama reference) — icon + title + pill ya walengwa
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: campaign icon + title + pill ya walengwa ───────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(s.icon, size: 18, color: s.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(fontSize: 14,
                      fontWeight: FontWeight.w600, color: _kGrey900)),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_audiencesLabel(auds),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11,
                        color: _kBlue, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),

          // ── Message (maxLines 3 kama reference) ─────────────────────────
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13,
                    color: _kGrey700, height: 1.5)),
          ],

          const SizedBox(height: 10),

          // ── Meta row: recipients + date ────────────────────────────────
          Row(children: [
            Icon(PhosphorIcons.users(), size: 14, color: _kGrey400),
            const SizedBox(width: 4),
            Text(recipientsCount > 0 ? '$recipientsCount watu' : '—',
                style: GoogleFonts.inter(fontSize: 12, color: _kGrey400)),
            const SizedBox(width: 14),
            Icon(PhosphorIcons.clock(), size: 14, color: _kGrey400),
            const SizedBox(width: 4),
            Expanded(child: Text(
              _formatDate(createdAt),
              style: GoogleFonts.inter(fontSize: 12, color: _kGrey400),
              overflow: TextOverflow.ellipsis,
            )),
          ]),

          const SizedBox(height: 10),

          // ── Action buttons — pills nyeupe rounded 20 (kama reference) ────
          Row(children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => _resend(id),
                icon: Icon(PhosphorIcons.arrowClockwise(), size: 16, color: _kBlue),
                label: const Text('Tuma tena',
                    style: TextStyle(color: _kBlue, fontWeight: FontWeight.w500, fontSize: 13)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _delete(id),
                icon: Icon(PhosphorIcons.trash(), size: 16, color: _kRed),
                label: const Text('Futa',
                    style: TextStyle(color: _kRed, fontWeight: FontWeight.w500, fontSize: 13)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── MAIN BUILD — tabs 2: Tuma / Historia (kama reference) ────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            // ── Header nyeupe (badala ya hero ya gradient) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                    color: _kBlue, size: 22),
                const SizedBox(width: 8),
                const Text('Matangazo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900)),
              ]),
            ),
            // ── TabBar: Tuma / Historia (N) ──
            TabBar(
              labelColor: _kBlue,
              unselectedLabelColor: _kGrey500,
              indicatorColor: _kBlue,
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              dividerColor: const Color(0xFFF1F1F1),
              tabs: [
                const Tab(text: 'Tuma'),
                Tab(text: (!_loading && _error == null && _items.isNotEmpty)
                    ? 'Historia (${_items.length})'
                    : 'Historia'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [
                _buildTumaTab(),
                _buildHistoriaTab(),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── TAB 1: Fomu ya kutuma ──
  Widget _buildTumaTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: _kBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: _buildSendForm(),
      ),
    );
  }

  // ── TAB 2: Historia ya matangazo ──
  Widget _buildHistoriaTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(PhosphorIcons.warningCircle(), color: _kRed, size: 48),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _load,
            icon: Icon(PhosphorIcons.arrowClockwise(), size: 16),
            label: const Text('Jaribu tena'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue, foregroundColor: Colors.white),
          ),
        ]),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(PhosphorIcons.megaphone(), color: _kGrey400, size: 52),
          const SizedBox(height: 12),
          Text('Hakuna tangazo bado',
              style: GoogleFonts.inter(fontSize: 14, color: _kGrey500)),
        ]),
      );
    }
    final totalPages = (_items.length / _kPageSize).ceil().clamp(0, 9999);
    final pageItems  = _items.skip(_page * _kPageSize).take(_kPageSize).toList();
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _kBlue,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: pageItems.length,
            itemBuilder: (_, i) => _buildCard(asMap(pageItems[i])),
          ),
        ),
      ),
      // Pagination (dirisha la kurasa)
      if (totalPages > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PageBtn(
                icon: PhosphorIcons.caretLeft(),
                enabled: _page > 0,
                onTap: () => _goToPage(_page - 1),
              ),
              for (int p = 0; p < totalPages; p++)
                _PageNum(
                  n: p + 1,
                  active: _page == p,
                  onTap: () => _goToPage(p),
                ),
              _PageBtn(
                icon: PhosphorIcons.caretRight(),
                enabled: _page < totalPages - 1,
                onTap: () => _goToPage(_page + 1),
              ),
            ],
          ),
        )
      else
        const SizedBox(height: 16),
    ]);
  }
}

// ─── Aina chip (type/audience selector) ──────────────────────────────────────

class _AinaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _AinaChip({
    required this.icon, required this.label, required this.selected,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.white,
          border: Border.all(
            color: selected ? color : _kGrey200,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: selected ? color : _kGrey400),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : _kGrey700,
              )),
        ]),
      ),
    );
  }
}

// ─── Custom delete dialog ────────────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _DeleteDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _kRedBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.fill),
                  color: _kRed, size: 22),
            ),
            const SizedBox(height: 14),
            Text('Futa tangazo',
                style: GoogleFonts.inter(fontSize: 17,
                    fontWeight: FontWeight.w700, color: _kGrey900)),
            const SizedBox(height: 8),
            Text(
              'Una uhakika unataka kufuta tangazo hili? Hatua hii haiwezi kutenduliwa.',
              style: GoogleFonts.inter(fontSize: 13.5,
                  color: _kGrey500, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _kGrey200),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Hapana',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                          color: _kGrey700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Futa',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Pagination widgets ───────────────────────────────────────────────────────

class _PageNum extends StatelessWidget {
  final int n;
  final bool active;
  final VoidCallback onTap;
  const _PageNum({required this.n, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 30, height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          border: Border.all(color: active ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text('$n',
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kGrey700,
              )),
        ),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30, height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: enabled ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16,
            color: enabled ? _kBlue : _kGrey200),
      ),
    );
  }
}
