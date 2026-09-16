import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

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

Color _avatarColor(String name) {
  if (name.isEmpty) return _kBlue;
  final colors = [Color(0xFF16A34A), Color(0xFF2563EB), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF7C3AED), Color(0xFF0891B2)];
  return colors[name.codeUnitAt(0) % colors.length];
}

String _timeAgo(dynamic raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw.toString()).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'leo';
    if (diff.inDays < 7) return 'siku ${diff.inDays} zilizopita';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return 'wiki $weeks zilizopita';
    final months = (diff.inDays / 30).floor();
    return 'miezi $months iliyopita';
  } catch (_) {
    return '';
  }
}

String _shortDate(dynamic raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw.toString()).toLocal();
    const months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return raw.toString().split('T')[0];
  }
}

class AdminMatchesPage extends StatefulWidget {
  const AdminMatchesPage({super.key});

  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _matches = [];
  String? _selectedDept;
  String? _selectedRegion;
  List<String> _departments = [];
  List<String> _regions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminListMatches(limit: 100);
      if (!mounted) return;
      final raw = res.data;
      final list = (raw is List) ? raw : (raw['matches'] as List? ?? raw['users'] as List? ?? []);
      final depts = <String>{};
      final regs = <String>{};
      for (final m in list) {
        final u = (m['user'] ?? m) as Map<String, dynamic>;
        final dept = u['category']?.toString() ?? '';
        final reg = u['station']?['region']?.toString() ?? '';
        if (dept.isNotEmpty) depts.add(dept);
        if (reg.isNotEmpty) regs.add(reg);
      }
      setState(() {
        _matches = list;
        _departments = depts.toList()..sort();
        _regions = regs.toList()..sort();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    return _matches.where((m) {
      final u = (m['user'] ?? m) as Map<String, dynamic>;
      if (_selectedDept != null && _selectedDept!.isNotEmpty) {
        if ((u['category']?.toString() ?? '') != _selectedDept) return false;
      }
      if (_selectedRegion != null && _selectedRegion!.isNotEmpty) {
        if ((u['station']?['region']?.toString() ?? '') != _selectedRegion) return false;
      }
      return true;
    }).toList();
  }

  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nambari $phone imenakiliwa'), backgroundColor: _kBlue, duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kGrey100,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _kBlue))
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _kBlue,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: _buildCountBanner()),
                        SliverToBoxAdapter(child: _buildFilters()),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildMatchCard(_filtered[i]),
                            childCount: _filtered.length,
                          ),
                        ),
                        if (_filtered.isEmpty) SliverToBoxAdapter(child: _buildEmpty()),
                        SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: _kRed),
          SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: _kGrey700), textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
            child: Text('Jaribu Tena'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.handshake_rounded, color: _kBlue, size: 24),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Waliopata Wenzao', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900)),
              Text('Watumiaji waliofanikiwa', style: TextStyle(fontSize: 13, color: _kGrey500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountBanner() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text('${_filtered.length} mechi zilizopatikana', style: TextStyle(color: _kGrey700, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(child: _dropdown('Idara', _selectedDept, _departments, (v) => setState(() => _selectedDept = v))),
          SizedBox(width: 10),
          Expanded(child: _dropdown('Mkoa', _selectedRegion, _regions, (v) => setState(() => _selectedRegion = v))),
        ],
      ),
    );
  }

  Widget _dropdown(String hint, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kGrey200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: _kGrey400, fontSize: 13)),
          isExpanded: true,
          onChanged: onChanged,
          items: [
            DropdownMenuItem<String>(value: null, child: Text('Zote', style: TextStyle(color: _kGrey700, fontSize: 13))),
            ...items.map((i) => DropdownMenuItem<String>(value: i, child: Text(i, style: TextStyle(color: _kGrey900, fontSize: 13)))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: Column(
          children: [
            Icon(Icons.handshake_outlined, size: 64, color: _kGrey400),
            SizedBox(height: 16),
            Text('Hakuna mechi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey700)),
            SizedBox(height: 8),
            Text('Bado hakuna watumiaji waliopata wenzao.', style: TextStyle(color: _kGrey500, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final u = (match['user'] ?? match) as Map<String, dynamic>;
    final name = u['name']?.toString() ?? u['full_name']?.toString() ?? 'Mtumiaji';
    final phone = u['phone']?.toString() ?? '';
    final category = u['category']?.toString() ?? '';
    final cadreName = u['cadreName']?.toString() ?? u['cadre_name']?.toString() ?? u['cadre']?['name']?.toString() ?? '';
    final fromRegion = u['station']?['region']?.toString() ?? '';
    final fromDistrict = u['station']?['district']?.toString() ?? u['station']?['district_name']?.toString() ?? '';
    final destinations = (u['destinations'] as List?) ?? [];
    final toRegion = destinations.isNotEmpty ? (destinations[0]['region']?.toString() ?? '') : '';
    final toDistrict = destinations.isNotEmpty ? (destinations[0]['district']?.toString() ?? destinations[0]['district_name']?.toString() ?? '') : '';
    final subjects = (u['subjects'] as List?) ?? [];
    final createdAt = u['created_at'] ?? u['createdAt'] ?? match['created_at'] ?? match['createdAt'];
    final ago = _timeAgo(createdAt);
    final dateStr = _shortDate(createdAt);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kGrey200)),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFDFEAFE),
                  child: Text(initial, style: TextStyle(color: _kBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kGrey900)),
                      if (category.isNotEmpty || cadreName.isNotEmpty)
                        Text(
                          '${category.isNotEmpty ? category : ''}${category.isNotEmpty && cadreName.isNotEmpty ? ' · ' : ''}$cadreName',
                          style: TextStyle(color: _kBlue, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: _kGrey500),
                SizedBox(width: 4),
                Text('Kutoka: ', style: TextStyle(color: _kGrey500, fontSize: 13)),
                Expanded(
                  child: Text(
                    '$fromRegion${fromDistrict.isNotEmpty ? ', $fromDistrict' : ''}',
                    style: TextStyle(color: _kGrey900, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.my_location_rounded, size: 15, color: _kBlue),
                SizedBox(width: 4),
                Text('Anataka: ', style: TextStyle(color: _kGrey500, fontSize: 13)),
                Expanded(
                  child: Text(
                    '$toRegion${toDistrict.isNotEmpty ? ', $toDistrict' : ''}',
                    style: TextStyle(color: _kBlue, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (toRegion.isNotEmpty) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.swap_vert_rounded, size: 15, color: _kGreen),
                  SizedBox(width: 4),
                  Text('Anakuja $toRegion', style: TextStyle(color: _kGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(' — inalingana!', style: TextStyle(color: _kGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            if (subjects.isNotEmpty) ...[
              SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: subjects.map<Widget>((s) {
                  final subName = s is Map ? (s['name']?.toString() ?? s['code']?.toString() ?? '') : s.toString();
                  final isActive = s is Map && (s['confirmed'] == true || s['active'] == true);
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? _kBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? _kBlue : _kGrey200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive) ...[
                          Icon(Icons.check, size: 11, color: Colors.white),
                          SizedBox(width: 3),
                        ],
                        Text(subName, style: TextStyle(color: isActive ? Colors.white : _kGrey700, fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 13, color: _kGrey400),
                SizedBox(width: 4),
                Text('$ago${dateStr.isNotEmpty ? ' · $dateStr' : ''}', style: TextStyle(color: _kGrey500, fontSize: 12)),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyPhone(phone),
                    icon: Icon(Icons.phone_outlined, size: 15),
                    label: Text('Piga', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kGrey700,
                      side: BorderSide(color: _kGrey200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyPhone(phone),
                    icon: Icon(Icons.sms_outlined, size: 15),
                    label: Text('SMS', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kGrey700,
                      side: BorderSide(color: _kGrey200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _copyPhone(phone),
                    icon: Icon(Icons.chat_rounded, size: 15),
                    label: Text('WhatsApp', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
