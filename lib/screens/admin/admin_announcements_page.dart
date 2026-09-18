import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';

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
const _kGrey100 = Color(0xFFF3F4F6);
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

  List<dynamic> _departments = [];

  final _titleCtrl = TextEditingController();
  final _msgCtrl   = TextEditingController();
  String _type     = 'info';
  String _audience = 'all';
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
    super.dispose();
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
          params: {'search': q, 'limit': 10}, useCache: false);
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
    if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) return;
    setState(() { _sending = true; _sendResult = null; });
    try {
      final payload = <String, dynamic>{
        'title':    _titleCtrl.text.trim(),
        'message':  _msgCtrl.text.trim(),
        'type':     _type,
        'audience': _audience,
      };
      if (_audience == 'user' && _selectedUser != null) {
        payload['user_id'] = _selectedUser!['id'];
      }
      await ApiService().adminSendAnnouncement(payload);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendResult = 'ok';
        _titleCtrl.clear();
        _msgCtrl.clear();
        _type = 'info';
        _audience = 'all';
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
      return dept['name'] as String? ?? a;
    } catch (_) {
      return a;
    }
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F1F1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _kBlueBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(PhosphorIcons.bellRinging(PhosphorIconsStyle.fill),
                  color: _kBlue, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Tuma tangazo',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                    color: _kGrey900)),
          ]),
          const SizedBox(height: 14),

          // Title field
          TextField(
            controller: _titleCtrl,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: _inputDec('Kichwa cha habari',
                prefixIcon: PhosphorIcons.textAa()),
          ),
          const SizedBox(height: 10),

          // Message field
          TextField(
            controller: _msgCtrl,
            minLines: 3,
            maxLines: 6,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: _inputDec('Ujumbe wa tangazo...'),
          ),
          const SizedBox(height: 14),

          // Type chips
          Text('Aina',
              style: GoogleFonts.inter(fontSize: 12, color: _kGrey700,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
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
          const SizedBox(height: 14),

          // Audience chips
          Text('Wasikilizaji',
              style: GoogleFonts.inter(fontSize: 12, color: _kGrey700,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              // Wote
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _AinaChip(
                  icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
                  label: 'Wote',
                  selected: _audience == 'all',
                  color: _kBlue,
                  onTap: () => setState(() => _audience = 'all'),
                ),
              ),
              // Departments
              ..._departments.map((d) {
                final code = (d['code'] ?? '') as String;
                final ds = _deptStyle(code);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _AinaChip(
                    icon: ds.icon,
                    label: d['name'] as String? ?? code,
                    selected: _audience == code,
                    color: ds.color,
                    onTap: () => setState(() => _audience = code),
                  ),
                );
              }),
              // Mtu Mmoja
              _AinaChip(
                icon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                label: 'Mtu Mmoja',
                selected: _audience == 'user',
                color: _kAmber,
                onTap: () => setState(() => _audience = 'user'),
              ),
            ]),
          ),

          // User search (only when "Mtu Mmoja" selected)
          if (_audience == 'user') ...[
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
                    final u = _userResults[i] as Map<String, dynamic>;
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
                          Text(u['phone'] as String? ?? '',
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

          const SizedBox(height: 14),

          // Send result feedback
          if (_sendResult != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            const SizedBox(height: 12),
          ],

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                      size: 17),
              label: Text(
                _sending ? 'Inatuma...' : 'Tuma tangazo',
                style: GoogleFonts.inter(fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
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
    final createdBy      = item['created_by'] as String?
        ?? item['creator_name'] as String? ?? '';
    final recipientsCount = item['recipients_count'] as int? ?? 0;

    final s = _typeStyle(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F1F1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: type icon + title + audience pill ─────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(s.icon, size: 20, color: s.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _kGrey900)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kBlueBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_audienceLabel(audience),
                  style: GoogleFonts.inter(fontSize: 11,
                      color: _kBlue, fontWeight: FontWeight.w600)),
            ),
          ]),

          // ── Message ────────────────────────────────────────────────────────
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(message,
                style: GoogleFonts.inter(fontSize: 13,
                    color: _kGrey700, height: 1.5)),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),

          // ── Meta row: recipients + date + type badge ───────────────────────
          Row(children: [
            if (recipientsCount > 0) ...[
              Icon(PhosphorIcons.users(), size: 13, color: _kGrey400),
              const SizedBox(width: 4),
              Text('$recipientsCount',
                  style: GoogleFonts.inter(fontSize: 11, color: _kGrey400)),
              const SizedBox(width: 10),
            ],
            if (createdBy.isNotEmpty) ...[
              Icon(PhosphorIcons.user(), size: 13, color: _kGrey400),
              const SizedBox(width: 4),
              Text(createdBy,
                  style: GoogleFonts.inter(fontSize: 11, color: _kGrey400)),
              const SizedBox(width: 10),
            ],
            Icon(PhosphorIcons.clock(), size: 13, color: _kGrey400),
            const SizedBox(width: 4),
            Expanded(child: Text(
              _formatDate(createdAt),
              style: GoogleFonts.inter(fontSize: 11, color: _kGrey400),
              overflow: TextOverflow.ellipsis,
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(s.label,
                  style: GoogleFonts.inter(fontSize: 10.5,
                      color: s.color, fontWeight: FontWeight.w700)),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Action buttons ─────────────────────────────────────────────────
          Row(children: [
            _ActionBtn(
              icon: PhosphorIcons.arrowClockwise(),
              label: 'Tuma tena',
              color: _kBlue,
              onTap: () => _resend(id),
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: PhosphorIcons.trash(),
              label: 'Futa',
              color: _kRed,
              onTap: () => _delete(id),
            ),
          ]),
        ],
      ),
    );
  }

  // ── MAIN BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalPages = (_items.length / _kPageSize).ceil().clamp(0, 9999);
    final pageItems  = _loading || _error != null
        ? <dynamic>[]
        : _items.skip(_page * _kPageSize).take(_kPageSize).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(color: _kBlueBg,
                            borderRadius: BorderRadius.circular(13)),
                        child: Icon(
                            PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                            color: _kBlue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Matangazo',
                            style: GoogleFonts.inter(fontSize: 20,
                                fontWeight: FontWeight.w800, color: _kGrey900)),
                        Text('Tuma taarifa kwa watumiaji',
                            style: GoogleFonts.inter(fontSize: 12.5,
                                color: _kGrey500)),
                      ]),
                    ]),
                  ),
                  _buildSendForm(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Text('Historia ya matangazo',
                          style: GoogleFonts.inter(fontSize: 15,
                              fontWeight: FontWeight.w700, color: _kGrey900)),
                      const SizedBox(width: 8),
                      if (!_loading && _error == null && _items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kBlueBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${_items.length}',
                              style: GoogleFonts.inter(fontSize: 11,
                                  color: _kBlue, fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _kBlue)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.warningCircle(),
                        color: _kRed, size: 48),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: Icon(PhosphorIcons.arrowClockwise(), size: 16),
                      label: const Text('Jaribu tena'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          foregroundColor: Colors.white),
                    ),
                  ]),
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.megaphone(),
                        color: _kGrey400, size: 52),
                    const SizedBox(height: 12),
                    Text('Hakuna matangazo bado',
                        style: GoogleFonts.inter(fontSize: 14,
                            color: _kGrey500)),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) =>
                        _buildCard(pageItems[i] as Map<String, dynamic>),
                    childCount: pageItems.length,
                  ),
                ),
              ),
            // Pagination
            if (!_loading && _error == null && totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PageBtn(
                        icon: PhosphorIcons.caretLeft(),
                        enabled: _page > 0,
                        onTap: () => setState(() => _page--),
                      ),
                      for (int p = 0; p < totalPages; p++)
                        _PageNum(
                          n: p + 1,
                          active: _page == p,
                          onTap: () => setState(() => _page = p),
                        ),
                      _PageBtn(
                        icon: PhosphorIcons.caretRight(),
                        enabled: _page < totalPages - 1,
                        onTap: () => setState(() => _page++),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
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

// ─── Action button (Tuma tena / Futa) ────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(fontSize: 12.5,
                    fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
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
