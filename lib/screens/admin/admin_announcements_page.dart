import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import 'admin_users_v2_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MATANGAZO (Admin) — design mpya v2: segmented tabs, kadi nyeupe,
// steps za namba, switches za walengwa, chips za aina, skeleton,
// pagination. API halisi zote zimebaki hazikuguswa.
// ═══════════════════════════════════════════════════════════════════════════

const _kPageSize = 8;
const _kAmber = Color(0xFFB45309);
const _kAmberBg = Color(0xFFFEF3C7);

// ─── Aina ya tangazo: icon + rangi + lebo ────────────────────────────────────

({IconData icon, Color color, Color bg, String label}) _typeStyle(String t) {
  switch (t) {
    case 'warning':
      return (
        icon: PhosphorIcons.warning(PhosphorIconsStyle.fill),
        color: _kAmber,
        bg: _kAmberBg,
        label: 'Onyo'
      );
    case 'success':
      return (
        icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
        color: v2Success,
        bg: v2SuccessBg,
        label: 'Mafanikio'
      );
    case 'urgent':
      return (
        icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
        color: v2Danger,
        bg: v2DangerBg,
        label: 'Haraka'
      );
    default:
      return (
        icon: PhosphorIcons.info(PhosphorIconsStyle.fill),
        color: v2Accent,
        bg: v2AccentBg,
        label: 'Taarifa'
      );
  }
}

// ─── Idara: icon + rangi ──────────────────────────────────────────────────────

({IconData icon, Color color}) _deptStyle(String code) {
  switch (code) {
    case 'health':
      return (icon: PhosphorIcons.heartbeat(PhosphorIconsStyle.fill), color: v2Danger);
    case 'education':
      return (icon: PhosphorIcons.graduationCap(PhosphorIconsStyle.fill), color: v2Accent);
    case 'kilimo':
      return (icon: PhosphorIcons.plant(PhosphorIconsStyle.fill), color: v2Success);
    case 'watumishi_wa_umma':
      return (icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
          color: const Color(0xFF9333EA));
    default:
      return (icon: PhosphorIcons.buildings(PhosphorIconsStyle.fill), color: v2TextSecondary);
  }
}

// ─── Tarehe kwa Kiswahili ────────────────────────────────────────────────────

String _formatDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = [
      'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
      'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  } catch (_) {
    return iso;
  }
}

// ═══════════════════════════════ PAGE ═══════════════════════════════════════

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  int _tab = 0;

  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  int _page = 0;

  final _formKey = GlobalKey<FormState>();

  List<dynamic> _departments = [];

  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _type = 'info';
  Set<String> _audiences = {'all'};
  bool _sending = false;
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
    super.dispose();
  }

  void _goToPage(int p) => setState(() => _page = p);

  // ── DATA ────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminListAnnouncements();
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _items = data is List
            ? data
            : (data['announcements'] as List? ??
                data['results'] as List? ??
                data['items'] as List? ??
                []);
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadDepts() async {
    try {
      final r = await ApiService().adminListDepartments();
      final raw = r.data;
      if (!mounted) return;
      setState(() {
        _departments = raw is List
            ? raw
            : (raw['results'] ?? raw['items'] ?? raw['data'] ?? []);
      });
    } catch (_) {}
  }

  void _onUserSearch() async {
    final q = _userSearchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _userResults = [];
      });
      return;
    }
    setState(() {
      _searchingUsers = true;
    });
    try {
      final r = await ApiService()
          .adminUsers(params: {'q': q, 'limit': 10}, useCache: false);
      if (!mounted) return;
      final data = r.data;
      setState(() {
        _userResults = data is List
            ? data
            : (data['users'] ?? data['results'] as List? ?? []);
        _searchingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchingUsers = false;
      });
    }
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final single = _audiences.contains('user');
    if (single && _selectedUser == null) {
      setState(() => _sendResult = 'Chagua mtumiaji mmoja kwanza');
      return;
    }
    setState(() {
      _sending = true;
      _sendResult = null;
    });
    try {
      final targetId = _selectedUser == null
          ? null
          : (_selectedUser!['user_id']?.toString() ??
              _selectedUser!['id']?.toString() ??
              _selectedUser!['_id']?.toString());
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'type': _type,
        'audience': single
            ? 'user'
            : (_audiences.length == 1 ? _audiences.first : 'all'),
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
      setState(() {
        _sending = false;
        _sendResult = e.toString();
      });
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
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
        SnackBar(content: Text('Kosa: $e'), backgroundColor: v2Danger),
      );
    }
  }

  Future<void> _resend(String id) async {
    try {
      await ApiService().adminResendAnnouncement(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✓ Tangazo limetumwa tena'),
            backgroundColor: v2Success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: v2Danger),
      );
    }
  }

  String _audienceLabel(String a) {
    if (a == 'all') return 'Wote';
    if (a == 'user') return 'Mtu Mmoja';
    for (final d in _departments) {
      if ((d['code'] ?? '') == a) {
        return (d['display_name'] ?? d['name'] ?? a) as String;
      }
    }
    return a;
  }

  // ── MULTI-SELECT SWITCHES ───────────────────────────────────────────────

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

  // ═══════════════════════════════ BUILD ═══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // ── Header: megaphone + jina + hesabu ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: v2AccentBg, borderRadius: BorderRadius.circular(11)),
                child: Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                    color: v2Accent, size: 19),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Matangazo',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: v2TextPrimary)),
                      Text('Fikia watumiaji wote papo hapo',
                          style:
                              TextStyle(fontSize: 11.5, color: v2TextMuted)),
                    ]),
              ),
            ]),
          ),
          // ── Segmented tabs: Tuma / Historia ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: v2SurfaceMuted,
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              _seg(PhosphorIcons.paperPlaneTilt(), 'Tuma', 0),
              _seg(
                  PhosphorIcons.clock(),
                  (!_loading && _error == null && _items.isNotEmpty)
                      ? 'Historia · ${_items.length}'
                      : 'Historia',
                  1),
            ]),
          ),
          const Divider(height: 1, color: v2Border),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: _tab == 0
                  ? _buildTumaTab()
                  : _buildHistoriaTab(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _seg(IconData icon, String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: .07),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: active ? v2Accent : v2TextMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? v2TextPrimary : v2TextMuted)),
            ),
          ]),
        ),
      ),
    );
  }

  // ── TAB 1: FOMA YA KUTUMA ───────────────────────────────────────────────

  Widget _buildTumaTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: v2Accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: _buildSendForm(),
      ),
    );
  }

  Widget _buildSendForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: v2Border),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: v2Border)),
              ),
              child: Row(children: [
                Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                    size: 17, color: v2Accent),
                const SizedBox(width: 9),
                Text('Tuma tangazo jipya',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: v2TextPrimary)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepLabel(1, 'Kichwa cha habari'),
                  TextFormField(
                    controller: _titleCtrl,
                    style: GoogleFonts.inter(fontSize: 14),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Andika kichwa cha tangazo'
                        : null,
                    decoration: _plainDec('Andika kichwa...'),
                  ),
                  const SizedBox(height: 18),

                  _stepLabel(2, 'Ujumbe'),
                  TextFormField(
                    controller: _msgCtrl,
                    minLines: 4,
                    maxLines: 6,
                    style: GoogleFonts.inter(fontSize: 14),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Andika ujumbe wa tangazo'
                        : null,
                    decoration: _plainDec('Andika ujumbe wa tangazo...'),
                  ),
                  const SizedBox(height: 18),

                  _stepLabel(3, 'Wasikilizaji'),
                  const SizedBox(height: 2),
                  _audienceRow('all',
                      PhosphorIcons.usersThree(PhosphorIconsStyle.fill), 'Wote'),
                  for (final d in _departments)
                    _audienceRow(
                      (d['code'] ?? '') as String,
                      _deptStyle((d['code'] ?? '') as String).icon,
                      (d['display_name'] ?? d['name'] ?? d['code']) as String,
                    ),
                  _audienceRow(
                      'user', PhosphorIcons.user(PhosphorIconsStyle.fill), 'Mtu Mmoja'),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: _audiences.contains('user')
                        ? _buildUserSearch()
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  _stepLabel(4, 'Aina ya tangazo'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['info', 'warning', 'success', 'urgent']
                          .map((t) {
                        final s = _typeStyle(t);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _AinaChip(
                            icon: s.icon,
                            label: s.label,
                            selected: _type == t,
                            color: s.color,
                            bg: s.bg,
                            onTap: () => setState(() => _type = t),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Matokeo ya kutuma
                  if (_sendResult != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _sendResult == 'ok' ? v2SuccessBg : v2DangerBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(
                          _sendResult == 'ok'
                              ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                              : PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                          color:
                              _sendResult == 'ok' ? v2Success : v2Danger,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          _sendResult == 'ok'
                              ? '✓ Tangazo limetumwa!'
                              : 'Kosa: $_sendResult',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  _sendResult == 'ok' ? v2Success : v2Danger,
                              fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Kitufe cha kutuma
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sending ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: v2Accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Icon(PhosphorIcons.paperPlaneTilt(),
                              size: 16),
                      label: Text('Tuma tangazo',
                          style: GoogleFonts.inter(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
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

  // ── Step label ──────────────────────────────────────────────────────────

  Widget _stepLabel(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: v2Accent, shape: BoxShape.circle),
          child: Text('$number',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: v2TextSecondary)),
      ]),
    );
  }

  InputDecoration _plainDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13.5, color: v2TextMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: v2SurfaceMuted,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: v2Accent, width: 1.5)),
      );

  // ── Audience row (switch) ───────────────────────────────────────────────

  Widget _audienceRow(String code, IconData icon, String label) {
    final isLast = code == 'user';
    final on = _audiences.contains(code);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: v2Border),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: on ? v2AccentBg : v2SurfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: on ? v2Accent : v2TextMuted),
        ),
        const SizedBox(width: 11),
        Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: on ? v2TextPrimary : v2TextSecondary,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400))),
        Switch(
          value: on,
          activeThumbColor: Colors.white,
          activeTrackColor: v2Accent,
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
        const SizedBox(height: 10),
        TextField(
          controller: _userSearchCtrl,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tafuta mtumiaji...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: v2TextMuted),
            prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(PhosphorIcons.magnifyingGlass(),
                    size: 16, color: v2TextMuted)),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 0),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: v2Border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: v2Border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: v2Accent, width: 1.5)),
            suffixIcon: _searchingUsers
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: v2Accent)),
                  )
                : null,
          ),
        ),
        if (_selectedUser != null) ...[
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: v2AccentBg,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(PhosphorIcons.user(PhosphorIconsStyle.fill),
                  color: v2Accent, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  v2TitleCase(_selectedUser!['full_name'] as String? ?? ''),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: v2Accent,
                      fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedUser = null;
                  _userSearchCtrl.clear();
                  _userResults = [];
                }),
                child: Icon(PhosphorIcons.x(), color: v2Accent, size: 15),
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
              border: Border.all(color: v2Border),
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
                      Icon(PhosphorIcons.user(),
                          size: 14, color: v2TextMuted),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        v2TitleCase(u['full_name'] as String? ?? ''),
                        style: GoogleFonts.inter(
                            fontSize: 13, color: v2TextPrimary),
                      )),
                      Text(
                          v2FmtPhone(u['phone_primary'] as String? ??
                              u['phone'] as String? ??
                              ''),
                          style: GoogleFonts.inter(
                              fontSize: 11, color: v2TextMuted)),
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

  // ── TAB 2: HISTORIA ─────────────────────────────────────────────────────

  Widget _buildHistoriaTab() {
    if (_loading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, _) => const _HistSkeleton(),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(PhosphorIcons.cloudSlash(), color: v2TextMuted, size: 44),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _load,
            icon: Icon(PhosphorIcons.arrowClockwise(), size: 16),
            label: const Text('Jaribu tena'),
            style: ElevatedButton.styleFrom(
                backgroundColor: v2Accent, foregroundColor: Colors.white),
          ),
        ]),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration:
                const BoxDecoration(color: v2SurfaceMuted, shape: BoxShape.circle),
            child: Icon(PhosphorIcons.megaphone(),
                color: v2TextMuted, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('Hakuna tangazo bado',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: v2TextPrimary)),
          const SizedBox(height: 4),
          const Text('Tangazo lako la kwanza litajitokeza hapa',
              style: TextStyle(fontSize: 12, color: v2TextMuted)),
        ]),
      );
    }
    final totalPages = (_items.length / _kPageSize).ceil().clamp(0, 9999);
    final pageItems =
        _items.skip(_page * _kPageSize).take(_kPageSize).toList();
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          color: v2Accent,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: pageItems.length,
            itemBuilder: (_, i) => _buildCard(asMap(pageItems[i])),
          ),
        ),
      ),
      // Pagination
      if (totalPages > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
          ]),
        )
      else
        const SizedBox(height: 14),
    ]);
  }

  // ── KADI YA TANGAZO ─────────────────────────────────────────────────────

  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final title = item['title'] as String? ?? '';
    final message = item['message'] as String? ?? '';
    final type = item['type'] as String? ?? 'info';
    final audience = item['audience'] as String? ?? 'all';
    final createdAt = item['created_at'] as String? ?? '';
    final recipientsCount = item['recipients_count'] as int? ?? 0;

    final s = _typeStyle(type);
    final auds = (item['audiences'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [audience];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: v2Border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon chip ya aina + kichwa ──
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: s.bg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(s.icon, color: s.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: v2TextPrimary,
                            height: 1.3)),
                  ),
                ]),
                const SizedBox(height: 10),

                // ── Chips za walengwa + idadi ──
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final a in auds)
                    _audPill(_audienceLabel(a)),
                  if (recipientsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: v2SuccessBg,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(PhosphorIcons.users(),
                            size: 11, color: v2Success),
                        const SizedBox(width: 3),
                        Text('${v2FmtNum(recipientsCount)} walipokea',
                            style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: v2Success)),
                      ]),
                    ),
                ]),

                // ── Ujumbe ──
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: v2TextSecondary,
                          height: 1.5)),
                ],

                const SizedBox(height: 9),
                // ── Tarehe ──
                Row(children: [
                  Icon(PhosphorIcons.clock(),
                      size: 13, color: v2TextMuted),
                  const SizedBox(width: 5),
                  Expanded(
                      child: Text(_formatDate(createdAt),
                          style: GoogleFonts.inter(
                              fontSize: 11.5, color: v2TextMuted),
                          overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ),
          ),
          // ── Vitufe: Tuma tena / Futa ──
          const Divider(height: 1, color: v2Border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(children: [
              Expanded(
                child: _pillBtn('Tuma tena', PhosphorIcons.arrowClockwise(),
                    v2Accent, () => _resend(id)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pillBtn('Futa', PhosphorIcons.trash(), v2Danger,
                    () => _delete(id)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _audPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: v2AccentBg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(PhosphorIcons.users(), size: 11, color: v2Accent),
          const SizedBox(width: 3),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: v2Accent)),
          ),
        ]),
      );

  Widget _pillBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label,
          style: GoogleFonts.inter(
              fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Skeleton ya historia ────────────────────────────────────────────────────

class _HistSkeleton extends StatelessWidget {
  const _HistSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: v2SurfaceMuted, borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: v2Border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: v2SurfaceMuted,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 10),
          bar(180, 14),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          bar(60, 18),
          bar(80, 18),
          bar(90, 18),
        ]),
        const SizedBox(height: 10),
        bar(280, 12),
        const SizedBox(height: 6),
        bar(220, 12),
      ]),
    );
  }
}

// ─── Aina chip (type selector) ───────────────────────────────────────────────

class _AinaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _AinaChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.white,
          border: Border.all(
            color: selected ? color : v2Border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? color : v2TextMuted),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : v2TextSecondary,
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: v2DangerBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.fill),
                  color: v2Danger, size: 22),
            ),
            const SizedBox(height: 14),
            Text('Futa tangazo?',
                style: GoogleFonts.inter(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: v2TextPrimary)),
            const SizedBox(height: 8),
            Text(
              'Una uhakika unataka kufuta tangazo hili? Hatua hii haiwezi kutenduliwa.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: v2TextSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: v2Border),
                    foregroundColor: v2TextSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Hapana',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: v2Danger,
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

// ─── Pagination widgets ──────────────────────────────────────────────────────

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
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? v2Accent : Colors.white,
          border: Border.all(color: active ? v2Accent : v2Border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text('$n',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : v2TextSecondary,
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
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: enabled ? v2Accent : v2Border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: enabled ? v2Accent : v2TextMuted),
      ),
    );
  }
}
