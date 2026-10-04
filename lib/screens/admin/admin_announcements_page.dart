import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart';
import 'admin_users_v2_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MATANGAZO (Admin) — design mpya (sawa na code ya MatangazoScreen + picha):
// - TUMA: timeline ya hatua 5 (Aina chips → Kichwa 60 → Ujumbe 500 →
//   Wasikilizaji switches Wote/kundi/Mtu mmoja + search highlight →
//   Muonekano preview) + send bar (reach + kitufe ↑↗).
// - HISTORIA: filter chips (Yote/Taarifa/Onyo/Mafanikio), timeline kwa mwezi,
//   Tuma tena + Futa (confirm inline), pager ndogo (1 … 4 5 6 … 12).
// API halisi zote zimebaki: adminListAnnouncements / adminSendAnnouncement /
// adminResendAnnouncement / adminDeleteAnnouncement / adminListDepartments /
// adminStats (counts za makundi) / adminUsers (utafutaji wa mtu mmoja).
// ═══════════════════════════════════════════════════════════════════════════

// ─── RANGI ────────────────────────────────────────────────────────────────
const _cPrimary = Color(0xFF1E6FE0);
const _cTint = Color(0xFFEAF2FE);
const _cBgTint = Color(0xFFF3F7FE);
const _cBorder = Color(0xFFD6E4FA);
const _cText = Color(0xFF0F2A4D);
const _cSub = Color(0xFF5B7399);
const _cHint = Color(0xFF9DB1CF);
const _cAmber = Color(0xFFD97706);
const _cAmberBg = Color(0xFFFEF3C7);
const _cGreen = Color(0xFF16A34A);
const _cGreenBg = Color(0xFFDCFCE7);
const _cRed = Color(0xFFB42318);
const _cRedBg = Color(0xFFFDECEA);

const _kTitleMax = 60;
const _kMsgMax = 500;
const _kPerPage = 6; // Historia: items kwenye kila ukurasa wa pager

// ─── AINA YA TANGAZO ──────────────────────────────────────────────────────

enum AinaTangazo { taarifa, onyo, mafanikio }

extension AinaX on AinaTangazo {
  String get label => const ['Taarifa', 'Onyo', 'Mafanikio'][index];
  Color get color => const [_cPrimary, _cAmber, _cGreen][index];
  Color get bg => const [_cTint, _cAmberBg, _cGreenBg][index];
  IconData get icon => const [
        Icons.info_outline,
        Icons.warning_amber_rounded,
        Icons.check_circle_outline,
      ][index];

  String get apiValue => const ['info', 'warning', 'success'][index];

  static AinaTangazo fromApi(String? v) {
    switch (v) {
      case 'warning':
        return AinaTangazo.onyo;
      case 'success':
        return AinaTangazo.mafanikio;
      default:
        return AinaTangazo.taarifa;
    }
  }
}

// ─── TAREHE KWA KISWAHILI ─────────────────────────────────────────────────

const _miezi = [
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
];
const _mieziFupi = [
  'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
  'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
];

DateTime? _parseDate(dynamic iso) {
  if (iso == null) return null;
  try {
    return DateTime.parse(iso.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

// ─── MODELS ───────────────────────────────────────────────────────────────

class Tangazo {
  final String id;
  final AinaTangazo aina;
  final String kichwa;
  final String ujumbe;
  final DateTime? tarehe;
  final int walipokea;
  final int wameiondoa;
  final List<String> walengwa;
  Tangazo({
    required this.id,
    required this.aina,
    required this.kichwa,
    required this.ujumbe,
    required this.tarehe,
    required this.walipokea,
    required this.wameiondoa,
    required this.walengwa,
  });

  factory Tangazo.fromJson(Map<String, dynamic> m) {
    return Tangazo(
      id: (m['announcement_id'] ?? m['id'] ?? '').toString(),
      aina: AinaX.fromApi(m['type']?.toString()),
      kichwa: m['title']?.toString() ?? '',
      ujumbe: m['message']?.toString() ?? '',
      tarehe: _parseDate(m['created_at']),
      walipokea: (m['recipient_count'] as num?)?.toInt() ?? 0,
      wameiondoa: (m['dismissed_count'] as num?)?.toInt() ?? 0,
      walengwa: (m['audiences'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [m['audience']?.toString() ?? 'all'],
    );
  }
}

/// Mtu (Mtu mmoja) — kutoka utafutaji wa /admin/users
class Mtu {
  final String jina;
  final String simu;
  final String id;
  final Map<String, dynamic> raw;
  const Mtu(this.id, this.jina, this.simu, this.raw);
}

/// Kundi la wasikilizaji (idara) — kutoka /admin/departments + stats
class Kundi {
  final String key;
  final String jina;
  final IconData icon;
  final int idadi;
  const Kundi(this.key, this.jina, this.icon, this.idadi);
}

IconData _kundiIcon(String code) {
  switch (code) {
    case 'health':
      return Icons.monitor_heart_outlined;
    case 'education':
      return Icons.school_outlined;
    case 'kilimo':
      return Icons.eco_outlined;
    case 'watumishi_wa_umma':
    case 'service':
      return Icons.badge_outlined;
    default:
      return Icons.groups_outlined;
  }
}

String _kundiLabel(String code, String fallback) {
  switch (code) {
    case 'health':
      return 'Afya';
    case 'education':
      return 'Elimu';
    case 'kilimo':
      return 'Kilimo na ufugaji';
    case 'watumishi_wa_umma':
    case 'service':
      return 'Watumishi wa Umma';
    default:
      return fallback;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════════════════

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _scroll = ScrollController();
  final _kichwaCtrl = TextEditingController();
  final _ujumbeCtrl = TextEditingController();
  final _tafutaCtrl = TextEditingController();

  bool _historia = false;

  // ── Tuma (fomu) ──
  AinaTangazo _aina = AinaTangazo.taarifa;
  Map<String, bool> _on = {}; // kwa kila kundi (key → chaguliwa)
  bool _wote = false;
  bool _mtuMmoja = false;
  Mtu? _mtu;
  bool _sending = false;
  String? _error;
  String? _success;

  // ── Historia ──
  bool _loading = true;
  String? _loadError;
  List<Tangazo> _list = [];
  AinaTangazo? _filter; // null = Yote
  int _page = 1;
  String? _confirmId;

  // ── Wasikilizaji (data ya server) ──
  List<Kundi> _makundi = [];
  int _jumlaWote = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadWasikilizaji();
    _kichwaCtrl.addListener(_onFieldChange);
    _ujumbeCtrl.addListener(_onFieldChange);
    _tafutaCtrl.addListener(_onFieldChange);
  }

  void _onFieldChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scroll.dispose();
    _kichwaCtrl.dispose();
    _ujumbeCtrl.dispose();
    _tafutaCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════ DATA (API halisi) ═══════════════════════

  Future<void> _load() async {
    // SILENT REFRESH: spinner TU wakati orodha bado tupu.
    final first = _list.isEmpty && _loading;
    setState(() {
      if (first) _loading = true;
      _loadError = null;
    });
    try {
      final res = await ApiService().adminListAnnouncements();
      if (!mounted) return;
      final data = res.data;
      final map = data is List ? <String, dynamic>{} : asMap(data);
      final rawList = data is List
          ? data
          : (map['announcements'] as List? ?? map['results'] as List? ?? []);
      setState(() {
        _list = rawList.map((e) => Tangazo.fromJson(asMap(e))).toList();
        _loading = false;
        final pages = _pagesFor(_filteredCount);
        if (_page > pages) _page = pages;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = friendlyError(e);
      });
    }
  }

  /// Makundi (idara) + idadi za watumiaji kwa kila kundi (kutoka /admin/stats)
  Future<void> _loadWasikilizaji() async {
    List<Map<String, dynamic>> depts = [];
    Map<String, int> counts = {};
    try {
      final r = await ApiService().adminListDepartments();
      final raw = r.data;
      depts = ((raw is List
              ? raw
              : (asMap(raw)['results'] ?? asMap(raw)['items'] ?? [])) as List)
          .map((e) => asMap(e))
          .toList();
    } catch (_) {}
    try {
      final r = await ApiService().adminStats();
      final d = asMap(r.data);
      final totals = asMap(d['totals']);
      counts['__total'] = (totals['users'] as num?)?.toInt() ?? 0;
      for (final row in asList(d['by_cadre'])) {
        final m = asMap(row);
        final cat = m['category']?.toString() ?? '';
        if (cat.isEmpty) continue;
        counts[cat] = (counts[cat] ?? 0) + ((m['count'] as num?)?.toInt() ?? 0);
      }
      final health = (totals['users_health'] as num?)?.toInt() ?? 0;
      final edu = (totals['users_education'] as num?)?.toInt() ?? 0;
      if (health > 0) counts['health'] = health;
      if (edu > 0) counts['education'] = edu;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _jumlaWote = counts['__total'] ?? 0;
      _makundi = [
        for (final d in depts)
          if ((d['code'] ?? '').toString().isNotEmpty &&
              d['code'] != 'all' &&
              d['code'] != 'user')
            Kundi(
              d['code'].toString(),
              _kundiLabel(
                  d['code'].toString(),
                  (d['display_name'] ?? d['name'] ?? d['code'] ?? '')
                      .toString()),
              _kundiIcon(d['code'].toString()),
              counts[d['code'].toString()] ?? 0,
            ),
      ];
      // Weka chaguo za mapema (fomu isivunjike kama departments bado hazijaletwa)
      final newOn = <String, bool>{};
      for (final k in _makundi) {
        newOn[k.key] = _on[k.key] ?? false;
      }
      _on = newOn;
    });
  }

  // ── Tuma (API) ──
  Future<void> _tuma() async {
    final kichwa = _kichwaCtrl.text.trim();
    final ujumbe = _ujumbeCtrl.text.trim();
    String? err;
    if (kichwa.isEmpty || ujumbe.isEmpty) {
      err = 'Weka kichwa cha habari na ujumbe.';
    } else if (_mtuMmoja && _mtu == null) {
      err = 'Chagua mtu wa kutumia tangazo.';
    } else if (!_mtuMmoja && !_on.values.any((e) => e) && !_wote) {
      err = 'Chagua angalau kundi moja la wasikilizaji.';
    }
    if (err != null) {
      setState(() {
        _error = err;
        _success = null;
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _success = null;
    });
    try {
      final payload = <String, dynamic>{
        'title': kichwa,
        'message': ujumbe,
        'type': _aina.apiValue,
        'audience': _mtuMmoja ? 'user' : (_wote ? 'all' : 'custom'),
        'audiences': _mtuMmoja
            ? ['user']
            : (_wote
                ? ['all']
                : _makundi.where((k) => _on[k.key] == true).map((k) => k.key).toList()),
      };
      if (_mtuMmoja && _mtu != null) {
        payload['target_user_id'] = _mtu!.id;
      }
      await ApiService().adminSendAnnouncement(payload);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _success = 'Limetumwa kwa watu ${_fmt(_reach)}';
        _kichwaCtrl.clear();
        _ujumbeCtrl.clear();
        _wote = false;
        _mtuMmoja = false;
        _mtu = null;
        _tafutaCtrl.clear();
        _on = {for (final k in _makundi) k.key: false};
      });
      _load(); // pakia historia upya — tangazo jipya linajitokeza
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _futa(Tangazo t) async {
    if (t.id.isEmpty) return;
    try {
      await ApiService().adminDeleteAnnouncement(t.id);
      if (!mounted) return;
      setState(() {
        _list.removeWhere((x) => x.id == t.id);
        _confirmId = null;
        final pages = _pagesFor(_filteredCount);
        if (_page > pages) _page = pages;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(friendlyError(e));
    }
  }

  void _tumaTena(Tangazo t) {
    setState(() {
      _historia = false;
      _aina = t.aina;
      _kichwaCtrl.text = t.kichwa;
      _ujumbeCtrl.text = t.ujumbe;
      _error = null;
      _success = null;
      _wote = false;
      _mtuMmoja = false;
      _mtu = null;
      _tafutaCtrl.clear();
      _on = {for (final k in _makundi) k.key: false};
      if (t.walengwa.length == 1 && t.walengwa.first == 'all') {
        _wote = true;
      } else if (t.walengwa.contains('user')) {
        _mtuMmoja = true;
      } else {
        for (final k in _makundi) {
          _on[k.key] = t.walengwa.contains(k.key);
        }
      }
    });
    _scrollTop();
  }

  // ── Utafutaji wa mtu mmoja (API halisi) ──
  List<Mtu> _watu = [];
  bool _searchingUsers = false;

  Future<void> _tafutaWatu(String q) async {
    if (q.trim().length < 2) {
      if (mounted) setState(() => _watu = []);
      return;
    }
    setState(() => _searchingUsers = true);
    try {
      final r = await ApiService()
          .adminUsers(params: {'q': q.trim(), 'limit': 5}, useCache: false);
      if (!mounted) return;
      final data = r.data;
      final list = data is List
          ? data
          : (asMap(data)['users'] ?? asMap(data)['results'] as List? ?? []);
      setState(() {
        _watu = list.map((e) {
          final m = asMap(e);
          return Mtu(
            (m['user_id'] ?? m['id'] ?? m['_id'] ?? '').toString(),
            m['full_name']?.toString() ?? '',
            (m['phone_primary'] ?? m['phone'] ?? '').toString(),
            m,
          );
        }).toList();
        _searchingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchingUsers = false);
    }
  }

  // ═══════════════════════ MANTIKI ═══════════════════════

  int get _reach {
    if (_mtuMmoja) return _mtu == null ? 0 : 1;
    if (_wote) return _jumlaWote;
    return _makundi
        .where((k) => _on[k.key] == true)
        .fold(0, (s, k) => s + k.idadi);
  }

  void _toggleWote(bool v) {
    setState(() {
      _wote = v;
      _mtuMmoja = false;
      _mtu = null;
      _tafutaCtrl.clear();
      _watu = [];
      for (final k in _makundi) {
        _on[k.key] = v;
      }
      _error = null;
    });
  }

  void _toggleKundi(String key, bool v) {
    setState(() {
      _on[key] = v;
      if (v) {
        _mtuMmoja = false;
        _mtu = null;
        _tafutaCtrl.clear();
        _watu = [];
      }
      _wote = _makundi.isNotEmpty && _makundi.every((k) => _on[k.key] == true);
      _error = null;
    });
  }

  void _toggleMtuMmoja(bool v) {
    setState(() {
      _mtuMmoja = v;
      if (v) {
        _wote = false;
        for (final k in _makundi) {
          _on[k.key] = false;
        }
      } else {
        _mtu = null;
        _tafutaCtrl.clear();
        _watu = [];
      }
      _error = null;
    });
  }

  void _chaguaMtu(Mtu m) {
    setState(() {
      _mtu = m;
      _error = null;
      _watu = [];
      _tafutaCtrl.text = m.jina;
    });
  }

  void _scrollTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  // ── Historia helpers ──
  List<Tangazo> get _filtered => _filter == null
      ? _list
      : _list.where((t) => t.aina == _filter).toList();

  int get _filteredCount => _filtered.length;

  int _pagesFor(int n) => (n / _kPerPage).ceil().clamp(1, 9999);

  void _goto(int p) {
    setState(() {
      _page = p;
      _confirmId = null;
    });
    _scrollTop();
  }

  // 1 … 4 5 6 … 12  (null = ellipsis)
  List<int?> _pageItems(int total, int cur) {
    if (total <= 5) return List.generate(total, (i) => i + 1);
    final s = <int>{1, total, cur - 1, cur, cur + 1}
        .where((p) => p >= 1 && p <= total)
        .toList()
      ..sort();
    final out = <int?>[];
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && s[i] - s[i - 1] > 1) out.add(null);
      out.add(s[i]);
    }
    return out;
  }

  // ═══════════════════════ BUILD ═══════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _historia ? _historiaView() : _tumaView()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('Matangazo',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _cText,
                    letterSpacing: -0.5)),
          ),
          Material(
            color: _cTint,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                _historia = !_historia;
                _page = 1;
                _confirmId = null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _historia
                      ? const [
                          Icon(Icons.arrow_back, size: 16, color: _cPrimary),
                          SizedBox(width: 6),
                          Text('Rudi',
                              style: TextStyle(
                                  color: _cPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ]
                      : [
                          Text('Historia (${_list.length})',
                              style: const TextStyle(
                                  color: _cPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward,
                              size: 16, color: _cPrimary),
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════ TUMA VIEW ═══════════════════════

  Widget _tumaView() {
    return ListView(
      key: const ValueKey('tuma'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _Step(
          n: 1,
          title: 'Aina ya tangazo',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AinaTangazo.values.map(_ainaChip).toList(),
          ),
        ),
        _Step(
          n: 2,
          title: 'Kichwa cha habari',
          trailing: '${_kichwaCtrl.text.length}/$_kTitleMax',
          child: _field(_kichwaCtrl, 'Andika kichwa cha habari', _kTitleMax, 1),
        ),
        _Step(
          n: 3,
          title: 'Ujumbe',
          trailing: '${_ujumbeCtrl.text.length}/$_kMsgMax',
          child:
              _field(_ujumbeCtrl, 'Andika ujumbe wako hapa...', _kMsgMax, 4),
        ),
        _Step(n: 4, title: 'Wasikilizaji', child: _wasikilizaji()),
        _Step(n: 5, title: 'Muonekano', last: true, child: _preview()),
        const SizedBox(height: 24),
        _sendBar(),
      ],
    );
  }

  Widget _ainaChip(AinaTangazo a) {
    final sel = a == _aina;
    return GestureDetector(
      onTap: () => setState(() => _aina = a),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? a.color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? a.color : _cBorder, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a.icon, size: 16, color: sel ? Colors.white : a.color),
            const SizedBox(width: 6),
            Text(a.label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : _cText)),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, int max, int lines) {
    return TextField(
      controller: c,
      maxLength: max,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      style: const TextStyle(fontSize: 15.5, color: _cText, height: 1.4),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _cHint),
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _cBorder, width: 1.5)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _cPrimary, width: 2)),
      ),
    );
  }

  // ───── Wasikilizaji (switches) ─────
  Widget _wasikilizaji() {
    return Column(
      children: [
        _switchRow(Icons.groups_outlined, 'Wote', _wote, _toggleWote),
        for (final k in _makundi)
          _switchRow(
              k.icon, k.jina, _on[k.key] == true, (v) => _toggleKundi(k.key, v)),
        _switchRow(Icons.person_outline, 'Mtu mmoja', _mtuMmoja, _toggleMtuMmoja),
        if (_mtuMmoja) _mtuSearch(),
      ],
    );
  }

  Widget _switchRow(
      IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value ? _cPrimary : _cTint,
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, size: 18, color: value ? Colors.white : _cPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _cText)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: Colors.white,
            activeTrackColor: _cPrimary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFC9D8F0),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _mtuSearch() {
    if (_mtu != null) {
      final m = _mtu!;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cBgTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cBorder),
        ),
        child: Row(
          children: [
            _avatar(m.jina),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.jina,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: _cText)),
                  const SizedBox(height: 2),
                  Text(m.simu,
                      style:
                          const TextStyle(fontSize: 12.5, color: _cSub)),
                ],
              ),
            ),
            _IconBox(
              icon: Icons.close,
              color: _cPrimary,
              bg: _cTint,
              onTap: () => setState(() {
                _mtu = null;
                _tafutaCtrl.clear();
              }),
            ),
          ],
        ),
      );
    }

    final q = _tafutaCtrl.text.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _tafutaCtrl,
            onChanged: (v) => _tafutaWatu(v),
            style: const TextStyle(fontSize: 14.5, color: _cText),
            decoration: InputDecoration(
              hintText: 'Tafuta kwa jina au namba ya simu',
              hintStyle: const TextStyle(color: _cHint, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: _cPrimary),
              isDense: true,
              filled: true,
              fillColor: _cBgTint,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _cBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _cBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _cPrimary, width: 1.6)),
              suffixIcon: _searchingUsers
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _cPrimary)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Andika herufi 2 au zaidi za jina au namba ya simu.',
              style: TextStyle(fontSize: 11.5, color: _cHint)),
          if (q.length >= 2 && !_searchingUsers && _watu.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10, left: 4),
              child: Text('Hakuna aliyepatikana',
                  style: TextStyle(color: _cSub, fontSize: 13)),
            ),
          for (final m in _watu)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _chaguaMtu(m),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    _avatar(m.jina),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: _cText),
                              children: _highlight(m.jina, q),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined,
                                  size: 13, color: _cSub),
                              const SizedBox(width: 4),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 12.5, color: _cSub),
                                  children: _highlight(m.simu, q),
                                ),
                              ),
                            ],
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
    );
  }

  List<TextSpan> _highlight(String text, String q) {
    final i = text.toLowerCase().indexOf(q.toLowerCase());
    if (q.isEmpty || i < 0) return [TextSpan(text: text)];
    return [
      TextSpan(text: text.substring(0, i)),
      TextSpan(
        text: text.substring(i, i + q.length),
        style: const TextStyle(
            color: _cPrimary,
            backgroundColor: _cTint,
            fontWeight: FontWeight.w800),
      ),
      TextSpan(text: text.substring(i + q.length)),
    ];
  }

  Widget _avatar(String jina) {
    final parts = jina.trim().split(RegExp(r'\s+'));
    final init = parts.isNotEmpty && parts.first.isNotEmpty
        ? (parts.length > 1 && parts.last.isNotEmpty
            ? '${parts.first[0]}${parts.last[0]}'
            : parts.first[0])
        : '?';
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: _cTint, shape: BoxShape.circle),
      child: Text(init.toUpperCase(),
          style: const TextStyle(
              color: _cPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13)),
    );
  }

  // ───── Preview ─────
  Widget _preview() {
    final k = _kichwaCtrl.text.trim();
    final u = _ujumbeCtrl.text.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cBgTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _typeBadge(_aina),
          const SizedBox(height: 10),
          Text(k.isEmpty ? 'Kichwa cha habari' : k,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: k.isEmpty ? _cHint : _cText)),
          const SizedBox(height: 6),
          Text(u.isEmpty ? 'Ujumbe wako utaonekana hapa...' : u,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: u.isEmpty ? _cHint : _cSub)),
        ],
      ),
    );
  }

  Widget _typeBadge(AinaTangazo a) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: a.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(a.icon, size: 13, color: a.color),
          const SizedBox(width: 5),
          Text(a.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: a.color)),
        ],
      ),
    );
  }

  // ───── Send bar ─────
  Widget _sendBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_outlined, size: 20, color: _cSub),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14, color: _cSub),
                  children: [
                    const TextSpan(text: 'Watu '),
                    TextSpan(
                        text: _fmt(_reach),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _cText)),
                  ],
                ),
              ),
            ),
            Material(
              color: _cPrimary,
              shape: const CircleBorder(),
              elevation: 3,
              shadowColor: _cPrimary.withValues(alpha: 0.4),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _tuma,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.north_east,
                            color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!,
                style: const TextStyle(
                    color: _cRed,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ),
        if (_success != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 18, color: _cGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_success!,
                      style: const TextStyle(
                          color: _cGreen,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════ HISTORIA VIEW ═══════════════════════

  Widget _historiaView() {
    if (_loading) {
      return ListView(
        key: const ValueKey('historia'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          SizedBox(height: 60),
          Center(child: CircularProgressIndicator(color: _cPrimary)),
        ],
      );
    }
    if (_loadError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, color: _cSub, size: 44),
          const SizedBox(height: 12),
          Text(_loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _cSub, fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Jaribu tena'),
            style: FilledButton.styleFrom(
                backgroundColor: _cPrimary, foregroundColor: Colors.white),
          ),
        ]),
      );
    }

    final all = _filtered;
    final pages = _pagesFor(all.length);
    if (_page > pages) _page = pages;
    final start = (_page - 1) * _kPerPage;
    final end = (start + _kPerPage).clamp(0, all.length);
    final slice = all.sublist(start, end);

    // kundi kwa mwezi
    final groups = <String, List<Tangazo>>{};
    for (final t in slice) {
      final d = t.tarehe;
      final key = d == null
          ? 'Bila tarehe'
          : '${_miezi[d.month - 1]} ${d.year}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    return ListView(
      key: const ValueKey('historia'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('Yote', null),
              for (final a in AinaTangazo.values) _filterChip(a.label, a),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('Hakuna matangazo',
                  style: TextStyle(color: _cSub, fontSize: 14)),
            ),
          ),
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Text(e.key.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: _cSub)),
          ),
          for (var i = 0; i < e.value.length; i++)
            _historyItem(e.value[i], last: i == e.value.length - 1),
        ],
        if (all.isNotEmpty) ...[
          const SizedBox(height: 12),
          _pager(pages, start + 1, end, all.length),
        ],
      ],
    );
  }

  Widget _filterChip(String label, AinaTangazo? a) {
    final sel = _filter == a;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _filter = a;
          _page = 1;
          _confirmId = null;
        }),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? _cPrimary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: sel ? _cPrimary : _cBorder, width: 1.4),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : _cText)),
        ),
      ),
    );
  }

  Widget _historyItem(Tangazo t, {required bool last}) {
    final d = t.tarehe;
    final confirming = _confirmId == t.id;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.aina.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: t.aina.color, shape: BoxShape.circle),
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: _cBorder)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.kichwa,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _cText)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _typeBadge(t.aina),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                            d == null
                                ? ''
                                : '${d.day} ${_mieziFupi[d.month - 1]} ${d.year}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: _cSub)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(t.ujumbe,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, height: 1.45, color: _cSub)),
                  const SizedBox(height: 8),
                  Text(
                      '${_fmt(t.walipokea)} walipokea'
                      '${t.wameiondoa > 0 ? ' · ${t.wameiondoa} wameiondoa' : ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _cSub)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _IconBox(
                        icon: Icons.refresh,
                        color: _cPrimary,
                        bg: _cTint,
                        tooltip: 'Tuma tena',
                        onTap: () => _tumaTena(t),
                      ),
                      const SizedBox(width: 6),
                      _IconBox(
                        icon: Icons.delete_outline,
                        color: _cRed,
                        bg: _cRedBg,
                        tooltip: 'Futa',
                        onTap: () => setState(() => _confirmId = t.id),
                      ),
                    ],
                  ),
                  if (confirming)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _cRedBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Futa tangazo?',
                                style: TextStyle(
                                    color: _cRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                          ),
                          _miniBtn('Ndiyo', _cRed, Colors.white, () => _futa(t)),
                          const SizedBox(width: 8),
                          _miniBtn('Hapana', Colors.white, _cText,
                              () => setState(() => _confirmId = null)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, Color bg, Color fg, VoidCallback onTap) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label,
              style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5)),
        ),
      ),
    );
  }

  // ───── Pager ndogo ─────
  Widget _pager(int pages, int from, int to, int total) {
    final items = _pageItems(pages, _page);
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: _cBgTint,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _cBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _arrow(Icons.chevron_left, _page > 1, () => _goto(_page - 1)),
                for (final it in items)
                  if (it == null)
                    const SizedBox(
                      width: 20,
                      child: Center(
                        child: Text('…',
                            style: TextStyle(color: _cSub, fontSize: 13)),
                      ),
                    )
                  else
                    _pageBtn(it),
                _arrow(
                    Icons.chevron_right, _page < pages, () => _goto(_page + 1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('$from–$to ya $total',
            style: const TextStyle(fontSize: 12, color: _cSub)),
      ],
    );
  }

  Widget _pageBtn(int n) {
    final sel = n == _page;
    return GestureDetector(
      onTap: () => _goto(n),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? _cPrimary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text('$n',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : _cText)),
      ),
    );
  }

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.3,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(child: Icon(icon, size: 18, color: _cPrimary)),
        ),
      ),
    );
  }
}

// ───────────────────────── VIDGET ZA PAMOJA ─────────────────────────

/// Hatua moja ya timeline (namba ya bluu + mstari wa kuunganisha)
class _Step extends StatelessWidget {
  final int n;
  final String title;
  final String? trailing;
  final Widget child;
  final bool last;
  const _Step({
    required this.n,
    required this.title,
    required this.child,
    this.trailing,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: _cPrimary, shape: BoxShape.circle),
                  child: Text('$n',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                if (!last)
                  Expanded(child: Container(width: 2, color: _cBorder)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _cText)),
                      ),
                      if (trailing != null)
                        Text(trailing!,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _cSub)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kitufe cha icon cha mraba, icon iko katikati kabisa
class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String? tooltip;
  final VoidCallback onTap;
  const _IconBox({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(child: Icon(icon, size: 18, color: color)),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
