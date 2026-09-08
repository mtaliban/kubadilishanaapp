// Admin contacts page — view who contacted whom (calls, SMS, WhatsApp).
// Mobile-card layout matching the web version's design.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Brand colours ────────────────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue50    = Color(0xFFEFF6FF);
const _kBlue100   = Color(0xFFDBEAFE);
const _kBlue200   = Color(0xFFBFDBFE);
const _kGrey50    = Color(0xFFF9FAFB);
const _kGrey100   = Color(0xFFF3F4F6);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey300   = Color(0xFFD1D5DB);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey700   = Color(0xFF374151);
const _kGrey900   = Color(0xFF111827);
const _kGreen50   = Color(0xFFF0FDF4);
const _kGreen200  = Color(0xFFBBF7D0);
const _kGreen600  = Color(0xFF16A34A);
const _kGreen700  = Color(0xFF15803D);
const _kEmerald50  = Color(0xFFECFDF5);
const _kEmerald200 = Color(0xFFA7F3D0);
const _kEmerald700 = Color(0xFF047857);

const _kPageSize = 20;

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatTime(dynamic raw) {
  if (raw == null || raw.toString().isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw.toString()).toLocal();
    const months = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Ago','Sep','Okt','Nov','Des',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  } catch (_) {
    return raw.toString();
  }
}

String _typeName(String? type) {
  switch (type) {
    case 'call':      return 'Simu';
    case 'sms':       return 'SMS';
    case 'whatsapp':  return 'WhatsApp';
    default:          return type ?? '—';
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class AdminContactsPage extends StatefulWidget {
  const AdminContactsPage({super.key});
  @override
  State<AdminContactsPage> createState() => _AdminContactsPageState();
}

class _AdminContactsPageState extends State<AdminContactsPage> {
  List<dynamic> _contacts = [];
  bool _loading = true;
  String _filterType = '';   // '' | 'call' | 'sms' | 'whatsapp'
  String _search    = '';
  int    _page      = 0;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getContactActivity();
      final raw = res.data;
      setState(() {
        _contacts = (raw is Map ? (raw['contacts'] ?? []) : (raw ?? [])) as List;
        _loading  = false;
        _page     = 0;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    var list = _contacts;
    if (_filterType.isNotEmpty) {
      list = list.where((c) => c['contact_type'] == _filterType).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) {
        return (c['from_full_name'] ?? '').toLowerCase().contains(q) ||
               (c['to_full_name']   ?? '').toLowerCase().contains(q) ||
               (c['from_phone']     ?? '').toLowerCase().contains(q) ||
               (c['to_phone']       ?? '').toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  int get _callCount      => _contacts.where((c) => c['contact_type'] == 'call').length;
  int get _smsCount       => _contacts.where((c) => c['contact_type'] == 'sms').length;
  int get _whatsappCount  => _contacts.where((c) => c['contact_type'] == 'whatsapp').length;

  void _setFilter(String type) => setState(() { _filterType = type; _page = 0; });
  void _setSearch(String v)    => setState(() { _search = v;        _page = 0; });

  @override
  Widget build(BuildContext context) {
    final filtered   = _filtered;
    final totalPages = (filtered.length / _kPageSize).ceil().clamp(1, 9999);
    final pageItems  = filtered.skip(_page * _kPageSize).take(_kPageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HEADER ──────────────────────────────────────────────────────────
        _buildHeader(filtered.length),

        // ── STATS CHIPS ─────────────────────────────────────────────────────
        _buildStatsChips(),

        // ── SEARCH ──────────────────────────────────────────────────────────
        _buildSearch(),

        // ── CONTENT ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kBlue,
                  child: filtered.isEmpty
                      ? _buildEmpty()
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: pageItems.length,
                                itemBuilder: (ctx, i) => _buildCard(
                                  pageItems[i],
                                  _page * _kPageSize + i + 1,
                                ),
                              ),
                            ),
                            if (totalPages > 1) _buildPagination(totalPages),
                          ],
                        ),
                ),
        ),

        // ── FOOTER NOTE ─────────────────────────────────────────────────────
        _buildFooter(),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(int visibleCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          // Icon box
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kBlue50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.trending_up, size: 20, color: _kBlue),
            ),
          ),
          const SizedBox(width: 12),
          // Title + count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waliopigiana',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _kGrey900),
                ),
                Text(
                  '$visibleCount / ${_contacts.length}',
                  style: const TextStyle(fontSize: 12, color: _kGrey500),
                ),
              ],
            ),
          ),
          // LIVE badge
          if (!_loading) _buildLiveBadge(),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kGreen50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGreen200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(color: _kGreen600, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          const Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen600)),
        ],
      ),
    );
  }

  // ── Stats chips ────────────────────────────────────────────────────────────

  Widget _buildStatsChips() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            _statsChip(
              label: 'Zote',
              count: _contacts.length,
              icon: Icons.trending_up,
              filter: '',
              activeBg: _kBlue50,
              activeBorder: _kBlue200,
              activeText: _kBlue,
            ),
            const SizedBox(width: 8),
            _statsChip(
              label: 'Simu',
              count: _callCount,
              icon: Icons.phone,
              filter: 'call',
              activeBg: _kGreen50,
              activeBorder: _kGreen200,
              activeText: _kGreen700,
            ),
            const SizedBox(width: 8),
            _statsChip(
              label: 'SMS',
              count: _smsCount,
              icon: Icons.sms,
              filter: 'sms',
              activeBg: _kBlue100,
              activeBorder: _kBlue200,
              activeText: _kBlue,
            ),
            const SizedBox(width: 8),
            _statsChip(
              label: 'WhatsApp',
              count: _whatsappCount,
              icon: Icons.chat_bubble_outline,
              filter: 'whatsapp',
              activeBg: _kEmerald50,
              activeBorder: _kEmerald200,
              activeText: _kEmerald700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsChip({
    required String label,
    required int count,
    required IconData icon,
    required String filter,
    required Color activeBg,
    required Color activeBorder,
    required Color activeText,
  }) {
    final active = _filterType == filter;
    return GestureDetector(
      onTap: () => _setFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:        active ? activeBg   : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeBorder : _kGrey200,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? activeText : _kGrey500),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? activeText : _kGrey700,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active ? activeBorder : _kGrey100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? activeText : _kGrey500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _setSearch,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Tafuta kwa jina au namba ya simu...',
          hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
          prefixIcon: const Icon(Icons.filter_list, size: 18, color: _kGrey500),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16, color: _kGrey400),
                  onPressed: () {
                    _searchCtrl.clear();
                    _setSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: _kGrey50,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGrey200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGrey200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Contact card ───────────────────────────────────────────────────────────

  Widget _buildCard(Map contact, int index) {
    final type        = contact['contact_type'] as String?;
    final fromName    = contact['from_full_name'] ?? contact['from_name'] ?? '—';
    final toName      = contact['to_full_name']   ?? contact['to_name']   ?? '—';
    final fromPhone   = contact['from_phone'] ?? '';
    final toPhone     = contact['to_phone']   ?? '';
    final fromRegion  = contact['from_region'] ?? '';
    final toRegion    = contact['to_region']   ?? '';
    final fromCat     = contact['from_category'] ?? '';
    final fromCadre   = contact['from_cadre']    ?? '';
    final toCat       = contact['to_category']   ?? '';
    final toCadre     = contact['to_cadre']      ?? '';
    final timeRaw     = contact['initiated_at']  ?? contact['created_at'];
    final timeStr     = _formatTime(timeRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGrey200),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: index + badge + time
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '#$index',
                  style: const TextStyle(fontSize: 11, color: _kGrey400, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                _typeBadge(type),
                const Spacer(),
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 11, color: _kGrey400),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Mtumaji
            _personRow(
              label: 'Mtumaji',
              name: fromName,
              phone: fromPhone,
              category: fromCat,
              cadre: fromCadre,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 2),

            // Arrow divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 28),
                  const Icon(Icons.arrow_forward, size: 14, color: _kGrey300),
                ],
              ),
            ),

            // Row 3: Mpokeaji
            _personRow(
              label: 'Mpokeaji',
              name: toName,
              phone: toPhone,
              category: toCat,
              cadre: toCadre,
              icon: Icons.person,
            ),

            // Row 4: Regions (only when present)
            if (fromRegion.isNotEmpty || toRegion.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: _kGrey100),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: _kGrey400),
                  const SizedBox(width: 4),
                  Text(
                    fromRegion.isNotEmpty ? fromRegion : '—',
                    style: const TextStyle(fontSize: 11, color: _kGrey500),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.swap_horiz, size: 14, color: _kGrey300),
                  ),
                  Text(
                    toRegion.isNotEmpty ? toRegion : '—',
                    style: const TextStyle(fontSize: 11, color: _kGrey500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _personRow({
    required String label,
    required String name,
    required String phone,
    required String category,
    required String cadre,
    required IconData icon,
  }) {
    final sub = [category, cadre].where((s) => s.isNotEmpty).join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Icon(icon, size: 15, color: _kGrey400),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: _kGrey400, fontWeight: FontWeight.w500),
              ),
              Text(
                name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900),
              ),
              if (phone.isNotEmpty)
                Text(phone, style: const TextStyle(fontSize: 11, color: _kGrey500)),
              if (sub.isNotEmpty)
                Text(sub, style: const TextStyle(fontSize: 11, color: _kGrey400)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeBadge(String? type) {
    Color bg, border, textColor;
    IconData icon;
    switch (type) {
      case 'call':
        bg = _kGreen50; border = _kGreen200; textColor = _kGreen700; icon = Icons.phone;
        break;
      case 'sms':
        bg = _kBlue50; border = _kBlue200; textColor = _kBlue; icon = Icons.sms;
        break;
      case 'whatsapp':
        bg = _kEmerald50; border = _kEmerald200; textColor = _kEmerald700; icon = Icons.chat_bubble_outline;
        break;
      default:
        bg = _kGrey100; border = _kGrey300; textColor = _kGrey700; icon = Icons.contact_phone;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            _typeName(type),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  Widget _buildPagination(int totalPages) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Prev
          _pageBtn(
            label: null,
            icon: Icons.chevron_left,
            enabled: _page > 0,
            active: false,
            onTap: () => setState(() => _page--),
          ),
          const SizedBox(width: 4),
          // Page numbers (show up to 7 around current)
          ..._pageNumbers(totalPages).map((p) {
            if (p == -1) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: _kGrey400, fontSize: 13)),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _pageBtn(
                label: '${p + 1}',
                icon: null,
                enabled: true,
                active: _page == p,
                onTap: () => setState(() => _page = p),
              ),
            );
          }),
          const SizedBox(width: 4),
          // Next
          _pageBtn(
            label: null,
            icon: Icons.chevron_right,
            enabled: _page < totalPages - 1,
            active: false,
            onTap: () => setState(() => _page++),
          ),
        ],
      ),
    );
  }

  /// Returns page indices (0-based) to render, with -1 for ellipsis.
  List<int> _pageNumbers(int total) {
    if (total <= 7) return List.generate(total, (i) => i);
    final cur = _page;
    final pages = <int>[];
    pages.add(0);
    if (cur > 2) pages.add(-1); // ellipsis
    for (int i = (cur - 1).clamp(1, total - 2);
         i <= (cur + 1).clamp(1, total - 2);
         i++) {
      pages.add(i);
    }
    if (cur < total - 3) pages.add(-1); // ellipsis
    pages.add(total - 1);
    return pages;
  }

  Widget _pageBtn({
    required String? label,
    required IconData? icon,
    required bool enabled,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? _kBlue : _kGrey200),
        ),
        child: Center(
          child: label != null
              ? Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : (enabled ? _kGrey700 : _kGrey300),
                  ),
                )
              : Icon(
                  icon!,
                  size: 18,
                  color: enabled ? _kGrey700 : _kGrey300,
                ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
                child: const Icon(Icons.phone_missed_outlined, size: 28, color: _kGrey400),
              ),
              const SizedBox(height: 12),
              const Text('Hakuna mawasiliano', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kGrey700)),
              const SizedBox(height: 4),
              const Text('Jaribu kubadilisha kichujio au utafutaji', style: TextStyle(fontSize: 12, color: _kGrey400)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: _kGrey50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Mawasiliano yote (SIMU, SMS, WhatsApp) yanaoneshwa hapa kwa real-time. '
        'Bofya aina ya kuichuja.',
        style: const TextStyle(fontSize: 11, color: _kGrey500),
        textAlign: TextAlign.center,
      ),
    );
  }
}
