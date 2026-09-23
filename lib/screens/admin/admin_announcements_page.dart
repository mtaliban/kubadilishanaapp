import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import 'admin_users_v2_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MATANGAZO (Admin) — design mpya (kama picha + code ya AnnouncementsView):
// segmented tabs (Tuma/Historia), aina za tangazo (Taarifa/Onyo/Mafanikio),
// kichwa + ujumbe na hesabu (0/60, 0/500), wasikilizaji chips (multi-select,
// "Mtu mmoja" na utafutaji wa mtumiaji), muonekano (preview ya moja kwa moja),
// historia na filter chips + "Pakia zaidi". API halisi zote zimebaki.
// ═══════════════════════════════════════════════════════════════════════════

// ─── Aina ya tangazo: icon + rangi + lebo ────────────────────────────────
const _kAmber = Color(0xFFB45309);
const _kAmberBg = Color(0xFFFEF3C7);
const _kBlue = v2Accent;

const _kTitleMax = 60;
const _kMsgMax = 500;

const _kPageSize = 8; // Historia: idadi inayoonyeshwa kila mphatso ya "Pakia zaidi" (client-side)

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
        color: _kBlue,
        bg: v2AccentBg,
        label: 'Taarifa'
      );
  }
}

// ─── Idara: icon + rangi ──────────────────────────────────────────────────
({IconData icon, Color color, Color bg}) _deptStyle(String code) {
  switch (code) {
    case 'health':
      return (icon: PhosphorIcons.heartbeat(PhosphorIconsStyle.fill), color: v2Danger, bg: v2DangerBg);
    case 'education':
      return (icon: PhosphorIcons.graduationCap(PhosphorIconsStyle.fill), color: _kBlue, bg: v2AccentBg);
    case 'kilimo':
      return (icon: PhosphorIcons.plant(PhosphorIconsStyle.fill), color: v2Success, bg: v2SuccessBg);
    case 'watumishi_wa_umma':
      return (
        icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
        color: const Color(0xFF9333EA),
        bg: const Color(0xFFF3E8FF),
      );
    default:
      return (
        icon: PhosphorIcons.buildings(PhosphorIconsStyle.fill),
        color: v2TextSecondary,
        bg: v2SurfaceMuted,
      );
  }
}

// ─── Tarehe kwa Kiswahili ────────────────────────────────────────────────
String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  if (DateTime.now().difference(dt).inMinutes < 1) return 'Sasa hivi';
  return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m';
}

String _formatDateIso(String iso) {
  if (iso.isEmpty) return '';
  try {
    return _formatDate(DateTime.parse(iso).toLocal());
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
  // ── Tabs ──
  int _tab = 0; // 0 = Tuma, 1 = Historia

  // ── Historia (data) ──
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  int _total = 0;
  int _visibleCount = _kPageSize; // "Pakia zaidi" huongeza hii (client-side)
  List<dynamic> _departments = [];
  Map<String, int> _catCounts = {}; // idadi za watumiaji kwa kundi (kutoka /admin/stats)
  String? _confirmDelete; // id ya tangazo linalothibitishwa kufuta
  String? _filter; // null = Yote | info | warning | success | urgent
  final Set<String> _expanded = {};

  // ── Tuma (fomu) ──
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _type = 'info';
  Set<String> _audiences = {'all'};

  // ── Mtu mmoja ──
  final _userSearchCtrl = TextEditingController();
  List<dynamic> _userResults = [];
  Map<String, dynamic>? _selectedUser;
  bool _searchingUsers = false;

  // ── Hali ya kutuma ──
  bool _sending = false;
  bool _sent = false; // "Limetumwa" (green state)

  @override
  void initState() {
    super.initState();
    _load();
    _loadDepts();
    _loadStats();
    _userSearchCtrl.addListener(_onUserSearch);
    _titleCtrl.addListener(() => setState(() {}));
    _msgCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════ DATA ═══════════════════════

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminListAnnouncements();
      if (!mounted) return;
      final data = res.data;
      final map = data is List ? <String, dynamic>{} : asMap(data);
      final list = data is List
          ? data
          : (map['announcements'] as List? ??
              map['results'] as List? ??
              []);
      setState(() {
        _items = list;
        _total = (map['total'] as num?)?.toInt() ?? list.length;
        _loading = false;
        _visibleCount = _kPageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _showMore() {
    // Client-side: onyesha zaidi kutoka kwenye orodha iliyopakiwa tayari
    setState(() => _visibleCount += _kPageSize);
  }

  Future<void> _loadDepts() async {
    try {
      final r = await ApiService().adminListDepartments();
      final raw = r.data;
      if (!mounted) return;
      setState(() {
        _departments = raw is List
            ? raw
            : (asMap(raw)['results'] ?? asMap(raw)['items'] ?? []);
      });
    } catch (_) {}
  }

  /// Idadi za watumiaji (jumla + kwa kila category) kutoka /admin/stats
  Future<void> _loadStats() async {
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      final d = asMap(r.data);
      final totals = asMap(d['totals']);
      final counts = <String, int>{
        '__total': (totals['users'] as num?)?.toInt() ?? 0,
      };
      // by_cadre: [{category, cadre, count}] — jumlisha kwa category
      for (final row in asList(d['by_cadre'])) {
        final m = asMap(row);
        final cat = m['category']?.toString() ?? '';
        if (cat.isEmpty) continue;
        counts[cat] = (counts[cat] ?? 0) + ((m['count'] as num?)?.toInt() ?? 0);
      }
      // Kamilisha kutoka totals
      final health = (totals['users_health'] as num?)?.toInt() ?? 0;
      final edu = (totals['users_education'] as num?)?.toInt() ?? 0;
      if (health > 0) counts['health'] = health;
      if (edu > 0) counts['education'] = edu;
      setState(() => _catCounts = counts);
    } catch (_) {}
  }

  /// Idadi ya watu kwenye kundi (code) — 0 kama haijulikani
  int _countOf(String code) =>
      code == 'all' ? (_catCounts['__total'] ?? 0) : (_catCounts[code] ?? 0);

  void _onUserSearch() async {
    final q = _userSearchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _userResults = []);
      return;
    }
    setState(() => _searchingUsers = true);
    try {
      final r =
          await ApiService().adminUsers(params: {'q': q, 'limit': 10}, useCache: false);
      if (!mounted) return;
      final data = r.data;
      setState(() {
        _userResults = data is List
            ? data
            : (asMap(data)['users'] ?? asMap(data)['results'] as List? ?? []);
        _searchingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchingUsers = false);
    }
  }

  // ═══════════════════════ VITENDO ═══════════════════════

  Future<void> _send() async {
    // Validate (kama design ya picha: jaza kichwa + ujumbe)
    if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Jaza kichwa na ujumbe kwanza'),
            backgroundColor: v2Danger),
      );
      return;
    }
    if (_audiences.contains('user') && _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tafuta na chagua mtumiaji mmoja kwanza'),
            backgroundColor: v2Danger),
      );
      return;
    }
    setState(() {
      _sending = true;
      _sent = false;
    });
    try {
      final single = _audiences.contains('user');
      final targetId = _selectedUser == null
          ? null
          : (_selectedUser!['user_id']?.toString() ??
              _selectedUser!['id']?.toString() ??
              _selectedUser!['_id']?.toString());
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        // 'type' haihifadhiwa na backend ya sasa — tunaiweka tu kwa ajili ya siku zijazo
        if (_type != 'info') 'type': _type,
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
        _sent = true;
        _titleCtrl.clear();
        _msgCtrl.clear();
        _type = 'info';
        _audiences = {'all'};
        _selectedUser = null;
        _userSearchCtrl.clear();
        _userResults = [];
      });
      _load(); // pakia historia upya
      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted) setState(() => _sent = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imeshindikana kutuma: $e'), backgroundColor: v2Danger),
      );
    }
  }

  void _resend(Map<String, dynamic> a) {
    // Kama design: rudi kwenye fomu ukiwa na data ya tangazo hili,
    // kisha admin anabonyeza "Tuma" — watumiaji wapya wanaingia pia.
    setState(() {
      _type = a['type'] as String? ?? 'info';
      _titleCtrl.text = a['title'] as String? ?? '';
      _msgCtrl.text = a['message'] as String? ?? '';
      final auds =
          (a['audiences'] as List?)?.map((e) => e.toString()).toList() ??
              ['all'];
      _audiences = auds.isEmpty ? {'all'} : auds.toSet();
      _tab = 0;
      _confirmDelete = null;
    });
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final id = a['announcement_id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await ApiService().adminDeleteAnnouncement(id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((x) => (asMap(x)['announcement_id']?.toString() ?? '') == id);
        if (_total > 0) _total--;
        _confirmDelete = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imeshindikana kufuta: $e'), backgroundColor: v2Danger),
      );
    }
  }

  // ── Multi-select chips za walengwa ──
  void _toggleAudience(String code) {
    setState(() {
      if (code == 'all' || code == 'user') {
        _audiences = {code};
      } else {
        _audiences.remove('all');
        _audiences.contains(code) ? _audiences.remove(code) : _audiences.add(code);
        if (_audiences.isEmpty) _audiences.add('all');
      }
    });
  }

  // ── USER SEARCH (Mtu mmoja) ──
  Widget _buildUserSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _userSearchCtrl,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tafuta jina au namba ya simu',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: v2TextMuted),
            prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(PhosphorIcons.magnifyingGlass(),
                    size: 16, color: v2TextMuted)),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 0),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: v2Border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: v2Border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBlue, width: 1.5)),
            suffixIcon: _searchingUsers
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
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
            decoration: BoxDecoration(
                color: v2AccentBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(PhosphorIcons.user(PhosphorIconsStyle.fill),
                  color: _kBlue, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  v2TitleCase(_selectedUser!['full_name'] as String? ?? ''),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _kBlue,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  // ── Chipse za walengwa (fomu): API + fallback za kawaida ──
  List<({String code, String label, IconData icon, int count})> get _audienceOptions {
    final list = <({String code, String label, IconData icon, int count})>[
      (code: 'all', label: 'Wote', icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill), count: _countOf('all')),
    ];
    for (final d in _departments) {
      final m = asMap(d);
      final code = m['code']?.toString() ?? '';
      if (code.isEmpty || code == 'all' || code == 'user') continue;
      final s = _deptStyle(code);
      list.add((
        code: code,
        label: (m['display_name'] ?? m['name'] ?? code) as String,
        icon: s.icon,
        count: _countOf(code),
      ));
    }
    list.add((code: 'user', label: 'Mtu mmoja', icon: PhosphorIcons.user(PhosphorIconsStyle.fill), count: 1));
    return list;
  }

  // ── Wasikilizaji wataofikia (reach) ──
  int get _reach {
    if (_audiences.contains('all')) return _countOf('all');
    var sum = 0;
    for (final code in _audiences) {
      sum += code == 'user' ? 1 : _countOf(code);
    }
    return sum;
  }

  // ── Chipse za filter (Historia) ──
  List<Map<String, String>> get _filterChips {
    return [
      {'key': '', 'label': 'Yote'},
      {'key': 'info', 'label': 'Taarifa'},
      {'key': 'warning', 'label': 'Onyo'},
      {'key': 'success', 'label': 'Mafanikio'},
    ];
  }

  // ═══════════════════════ BUILD ═══════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: v2Border),
            Expanded(
              child: _tab == 0 ? _buildTumaTab() : _buildHistoriaTab(),
            ),
            if (_tab == 0) _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── HEADER (megaphone + Matangazo + tabs) ──
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(children: [
              Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                  size: 21, color: _kBlue),
              const SizedBox(width: 9),
              const Text('Matangazo',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: v2TextPrimary)),
            ]),
          ),
          // ── Segmented tabs: Tuma / Historia ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: v2Border)),
            child: Row(children: [
              _seg(PhosphorIcons.paperPlaneTilt(), 'Tuma', 0),
              _seg(PhosphorIcons.clockCounterClockwise(),
                  'Historia · $_total', 1),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _seg(IconData icon, String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tab = idx;
          _confirmDelete = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          decoration: BoxDecoration(
            color: active ? _kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: active ? Colors.white : v2TextMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? Colors.white : v2TextMuted)),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════ TAB 1: TUMA ═══════════════════════

  Widget _buildTumaTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: _kBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Aina ya tangazo ──
            _label('Aina ya tangazo'),
            Row(children: [
              for (final t in ['info', 'warning', 'success']) ...[
                Expanded(child: _typeCard(t)),
                if (t != 'success') const SizedBox(width: 8),
              ],
            ]),

            // ── Kichwa cha habari ──
            _label('Kichwa cha habari',
                trailing: '${_titleCtrl.text.length}/$_kTitleMax'),
            _input(
              controller: _titleCtrl,
              hint: 'mf. Maboresho ya mfumo',
              maxLength: _kTitleMax,
            ),

            // ── Ujumbe ──
            _label('Ujumbe', trailing: '${_msgCtrl.text.length}/$_kMsgMax'),
            _input(
              controller: _msgCtrl,
              hint: 'Andika ujumbe wa tangazo...',
              maxLength: _kMsgMax,
              lines: 4,
            ),

            // ── Wasikilizaji ──
            _label('Wasikilizaji',
                trailingWidget: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIcons.users(), size: 13, color: _kBlue),
                  const SizedBox(width: 4),
                  Text('Watu ${v2FmtNum(_reach)}',
                      style: const TextStyle(
                          color: _kBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ])),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _audienceOptions.map((o) {
                final on = _audiences.contains(o.code);
                return _chip(
                  label: o.label,
                  icon: on ? PhosphorIcons.check() : o.icon,
                  selected: on,
                  onTap: () => _toggleAudience(o.code),
                );
              }).toList(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _audiences.contains('user')
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildUserSearch(),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 6),

            // ── Muonekano (preview) ──
            _label('Muonekano'),
            _buildPreview(),
          ],
        ),
      ),
    );
  }

  // ── Label ya section (na trailing ya hiari) ──
  Widget _label(String text, {String? trailing, Widget? trailingWidget}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(children: [
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: v2TextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        ?trailingWidget,
        if (trailing != null)
          Text(trailing,
              style: const TextStyle(color: v2TextMuted, fontSize: 12)),
      ]),
    );
  }

  // ── Aina ya tangazo (kadi moja kwa moja) ──
  Widget _typeCard(String t) {
    final s = _typeStyle(t);
    final on = _type == t;
    return Material(
      color: on ? s.bg : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _type = t),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? s.color : v2Border, width: on ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(s.icon, size: 20, color: s.color),
            const SizedBox(height: 4),
            Text(s.label,
                style: TextStyle(
                    color: on ? s.color : v2TextPrimary,
                    fontSize: 13,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }

  // ── Input ──
  Widget _input({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int lines = 1,
  }) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: col, width: w),
        );
    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines,
      style: GoogleFonts.inter(fontSize: 14, color: v2TextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: v2TextMuted),
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: b(v2Border),
        enabledBorder: b(v2Border),
        focusedBorder: b(_kBlue, 1.5),
      ),
    );
  }

  // ── Chip (Wasikilizaji / Filter) ──
  Widget _chip({
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _kBlue : v2Border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon,
                size: 15, color: selected ? Colors.white : v2TextPrimary),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : v2TextPrimary,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  // ── MUONEKANO (preview ya moja kwa moja) ──
  Widget _buildPreview() {
    final s = _typeStyle(_type);
    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: v2Border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: s.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: s.bg, borderRadius: BorderRadius.circular(10)),
                        child: Icon(s.icon, size: 18, color: s.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  title.isEmpty ? 'Kichwa cha habari' : title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: title.isEmpty
                                        ? v2TextMuted
                                        : v2TextPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('sasa hivi',
                                  style: const TextStyle(
                                      color: v2TextMuted, fontSize: 12)),
                            ]),
                            const SizedBox(height: 2),
                            Text(
                              msg.isEmpty
                                  ? 'Ujumbe wako utaonekana hapa…'
                                  : msg,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: v2TextSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FOOTER (Litawafikia watu X + Tuma) ──
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: v2Border)),
      ),
      child: Row(children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'Litawafikia watu ',
              style: const TextStyle(color: v2TextMuted, fontSize: 12),
              children: [
                TextSpan(
                  text: v2FmtNum(_reach),
                  style: const TextStyle(
                      color: v2TextPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: _sent ? v2Success : _kBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_sent ? PhosphorIcons.check() : PhosphorIcons.paperPlaneTilt(),
                        size: 16),
                    const SizedBox(width: 6),
                    Text(_sent ? 'Limetumwa' : 'Tuma',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════ TAB 2: HISTORIA ═══════════════════════

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
                backgroundColor: _kBlue, foregroundColor: Colors.white),
          ),
        ]),
      );
    }

    final list = (_filter == null
            ? _items
            : _items
                .where((x) => (asMap(x)['type'] as String? ?? 'info') == _filter)
                .toList())
        .take(_visibleCount)
        .toList();

    return Column(children: [
      // ── Chipse za filter (sticky) ──
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: v2Border)),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _filterChips.map((f) {
            final key = f['key']!;
            return _chip(
              label: f['label']!,
              selected: _filter == (key.isEmpty ? null : key),
              onTap: () =>
                  setState(() => _filter = key.isEmpty ? null : key),
            );
          }).toList(),
        ),
      ),
      // ── Orodha ya historia ──
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                        color: v2SurfaceMuted, shape: BoxShape.circle),
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
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final item = asMap(list[i]);
                    return _buildCard(item);
                  },
                ),
              ),
      ),
      // ── Pakia zaidi ──
      if (_visibleCount <
          (_filter == null
              ? _items.length
              : _items
                  .where((x) =>
                      (asMap(x)['type'] as String? ?? 'info') == _filter)
                  .length))
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: _showMore,
              style: OutlinedButton.styleFrom(
                foregroundColor: v2TextPrimary,
                backgroundColor: Colors.white,
                side: const BorderSide(color: v2Border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(PhosphorIcons.caretDown(), size: 16),
                const SizedBox(width: 6),
                Text('Pakia zaidi',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
    ]);
  }

  // ── KADI YA HISTORIA ──
  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['announcement_id']?.toString() ?? '';
    final title = item['title'] as String? ?? '';
    final message = item['message'] as String? ?? '';
    final type = item['type'] as String? ?? 'info';
    final audience = item['audience'] as String? ?? 'all';
    final createdAt = item['created_at'] as String? ?? '';
    final recipientsCount = item['recipient_count'] as int? ?? 0;
    final dismissedCount = item['dismissed_count'] as int? ?? 0;

    final s = _typeStyle(type);
    final auds = (item['audiences'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [audience];
    final open = _expanded.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: v2Border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon ya aina ──
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: s.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(s.icon, color: s.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kichwa
                  Text(title,
                      style: const TextStyle(
                          color: v2TextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  // ── Walengwa + tarehe ──
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: v2SurfaceMuted,
                            borderRadius: BorderRadius.circular(999)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.users(), size: 12, color: v2TextMuted),
                          const SizedBox(width: 3),
                          Text(auds.map(_audienceLabel).join(', '),
                              style: const TextStyle(
                                  color: v2TextMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(PhosphorIcons.clock(), size: 12, color: v2TextMuted),
                        const SizedBox(width: 3),
                        Text(_formatDateIso(createdAt),
                            style: const TextStyle(
                                color: v2TextMuted, fontSize: 12)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // ── Ujumbe (expand/collapse) ──
                  GestureDetector(
                    onTap: () => setState(() {
                      open ? _expanded.remove(id) : _expanded.add(id);
                    }),
                    child: Text(
                      message,
                      maxLines: open ? null : 2,
                      overflow: open ? null : TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: v2TextSecondary, fontSize: 13, height: 1.45),
                    ),
                  ),
                  if (recipientsCount > 0 || dismissedCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      dismissedCount > 0
                          ? '${v2FmtNum(recipientsCount)} walipokea · $dismissedCount wameiondoa'
                          : '${v2FmtNum(recipientsCount)} walipokea',
                      style: const TextStyle(
                          color: v2TextMuted, fontSize: 11),
                    ),
                  ],
                  if (_confirmDelete == id) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                      decoration: BoxDecoration(
                        color: v2DangerBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Expanded(
                          child: Text('Futa tangazo hili?',
                              style: TextStyle(
                                  color: v2Danger, fontSize: 13)),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _confirmDelete = null),
                          child: const Text('Hapana',
                              style: TextStyle(
                                  color: v2TextMuted, fontSize: 13)),
                        ),
                        SizedBox(
                          height: 30,
                          child: FilledButton(
                            onPressed: () => _delete(item),
                            style: FilledButton.styleFrom(
                              backgroundColor: v2Danger,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Futa'),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── Vitufe: Tuma tena / Futa ──
            Column(children: [
              _smallAction(
                icon: PhosphorIcons.arrowsClockwise(),
                color: _kBlue,
                tooltip: 'Tuma tena',
                onTap: () => _resend(item),
              ),
              const SizedBox(height: 6),
              _smallAction(
                icon: PhosphorIcons.trash(),
                color: v2Danger,
                tooltip: 'Futa',
                onTap: () => setState(() => _confirmDelete = id),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _audienceLabel(String a) {
    if (a == 'all') return 'Wote';
    if (a == 'user') return 'Mtu mmoja';
    for (final d in _departments) {
      final m = asMap(d);
      if ((m['code'] ?? '') == a) {
        return (m['display_name'] ?? m['name'] ?? a) as String;
      }
    }
    // Fallback za kawaida
    switch (a) {
      case 'health':
        return 'Afya';
      case 'education':
        return 'Elimu';
      case 'kilimo':
        return 'Kilimo na ufugaji';
      case 'watumishi_wa_umma':
        return 'Watumishi wa umma';
    }
    return a;
  }

  // ── Kitufe kidogo cha vitendo (Tuma tena / Futa) ──
  Widget _smallAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: v2SurfaceMuted,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton ya historia ────────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: v2SurfaceMuted,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 12),
          bar(180, 14),
        ]),
        const SizedBox(height: 10),
        bar(120, 18),
        const SizedBox(height: 8),
        bar(280, 12),
        const SizedBox(height: 6),
        bar(220, 12),
      ]),
    );
  }
}
