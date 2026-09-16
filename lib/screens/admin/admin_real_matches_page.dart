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

class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});

  @override
  State<AdminRealMatchesPage> createState() => _AdminRealMatchesPageState();
}

class _AdminRealMatchesPageState extends State<AdminRealMatchesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pairs = [];
  String? _selectedCategory;
  String? _selectedCadre;
  List<String> _categories = [];
  List<String> _cadres = [];

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
      final res = await ApiService().adminRealMatches(
        category: _selectedCategory?.isNotEmpty == true ? _selectedCategory : null,
        cadreCode: _selectedCadre?.isNotEmpty == true ? _selectedCadre : null,
        limit: 100,
      );
      if (!mounted) return;
      final raw = res.data;
      final List<Map<String, dynamic>> pairs = [];
      final cats = <String>{};
      final cads = <String>{};

      if (raw is List) {
        for (var i = 0; i + 1 < raw.length; i += 2) {
          final a = (raw[i] is Map) ? Map<String, dynamic>.from(raw[i] as Map) : <String, dynamic>{};
          final b = (raw[i + 1] is Map) ? Map<String, dynamic>.from(raw[i + 1] as Map) : <String, dynamic>{};
          pairs.add({'userA': a['user'] ?? a, 'userB': b['user'] ?? b});
        }
        if (raw.length.isOdd) {
          final last = (raw.last is Map) ? Map<String, dynamic>.from(raw.last as Map) : <String, dynamic>{};
          pairs.add({'userA': last['user'] ?? last, 'userB': <String, dynamic>{}});
        }
      } else if (raw is Map) {
        final list = raw['matches'] as List? ?? raw['pairs'] as List? ?? [];
        for (final item in list) {
          if (item is Map && item.containsKey('userA')) {
            pairs.add({
              'userA': item['userA'] is Map ? Map<String, dynamic>.from(item['userA'] as Map) : <String, dynamic>{},
              'userB': item['userB'] is Map ? Map<String, dynamic>.from(item['userB'] as Map) : <String, dynamic>{},
            });
          } else if (item is Map) {
            final u = item['user'] ?? item;
            final cat = u['category']?.toString() ?? '';
            final cad = u['cadre_code']?.toString() ?? u['cadreName']?.toString() ?? '';
            if (cat.isNotEmpty) cats.add(cat);
            if (cad.isNotEmpty) cads.add(cad);
          }
        }
      }

      for (final p in pairs) {
        for (final key in ['userA', 'userB']) {
          final u = p[key] as Map<String, dynamic>;
          final cat = u['category']?.toString() ?? '';
          final cad = u['cadre_code']?.toString() ?? u['cadreName']?.toString() ?? u['cadre']?['name']?.toString() ?? '';
          if (cat.isNotEmpty) cats.add(cat);
          if (cad.isNotEmpty) cads.add(cad);
        }
      }

      setState(() {
        _pairs = pairs;
        _categories = cats.toList()..sort();
        _cadres = cads.toList()..sort();
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

  List<Map<String, dynamic>> get _filtered {
    if ((_selectedCategory == null || _selectedCategory!.isEmpty) &&
        (_selectedCadre == null || _selectedCadre!.isEmpty)) {
      return _pairs;
    }
    return _pairs.where((p) {
      for (final key in ['userA', 'userB']) {
        final u = p[key] as Map<String, dynamic>;
        if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
          if ((u['category']?.toString() ?? '') == _selectedCategory) return true;
        }
        if (_selectedCadre != null && _selectedCadre!.isNotEmpty) {
          final cad = u['cadre_code']?.toString() ?? u['cadreName']?.toString() ?? u['cadre']?['name']?.toString() ?? '';
          if (cad == _selectedCadre) return true;
        }
      }
      return false;
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
                            (ctx, i) => _buildPairCard(_filtered[i]),
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
            child: Icon(Icons.stars_rounded, color: _kBlue, size: 24),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Match za Kweli', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900)),
              Text('Mechi za kweli (pande zote)', style: TextStyle(fontSize: 13, color: _kGrey500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountBanner() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: _kGreenBg, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 16, color: _kGreen),
            SizedBox(width: 6),
            Text('${_filtered.length} mechi za kweli', style: TextStyle(color: _kGreen, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _dropdown(
              'Elimu / Afya',
              _selectedCategory,
              _categories,
              (v) {
                setState(() => _selectedCategory = v);
                _load();
              },
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _dropdown(
              'Kada',
              _selectedCadre,
              _cadres,
              (v) {
                setState(() => _selectedCadre = v);
                _load();
              },
            ),
          ),
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
            Icon(Icons.stars_outlined, size: 80, color: _kGrey400),
            SizedBox(height: 16),
            Text('Hakuna match za kweli bado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey700)),
            SizedBox(height: 8),
            Text(
              'Mechi za kweli zinaonekana pale ambapo watumiaji wawili wanataka kubadilishana maeneo yao.',
              style: TextStyle(color: _kGrey500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairCard(Map<String, dynamic> pair) {
    final userA = pair['userA'] as Map<String, dynamic>;
    final userB = pair['userB'] as Map<String, dynamic>;
    final hasB = userB.isNotEmpty;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _kGreenBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, size: 14, color: _kGreen),
                SizedBox(width: 6),
                Text('Match ya Kweli', style: TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              children: [
                _buildUserRow(userA),
                if (hasB) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: _kGrey200)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.swap_vert_rounded, color: _kGreen, size: 22),
                        ),
                        Expanded(child: Divider(color: _kGrey200)),
                      ],
                    ),
                  ),
                  _buildUserRow(userB),
                ],
                SizedBox(height: 12),
                _buildContactButtons(userA, userB, hasB),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> u) {
    final name = u['name']?.toString() ?? u['full_name']?.toString() ?? 'Mtumiaji';
    final phone = u['phone']?.toString() ?? '';
    final category = u['category']?.toString() ?? '';
    final cadreName = u['cadreName']?.toString() ?? u['cadre_name']?.toString() ?? u['cadre']?['name']?.toString() ?? '';
    final fromRegion = u['station']?['region']?.toString() ?? '';
    final fromDistrict = u['station']?['district']?.toString() ?? u['station']?['district_name']?.toString() ?? '';
    final destinations = (u['destinations'] as List?) ?? [];
    final toRegion = destinations.isNotEmpty ? (destinations[0]['region']?.toString() ?? '') : '';
    final toDistrict = destinations.isNotEmpty ? (destinations[0]['district']?.toString() ?? destinations[0]['district_name']?.toString() ?? '') : '';
    final createdAt = u['created_at'] ?? u['createdAt'];
    final ago = _timeAgo(createdAt);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _avatarColor(name).withOpacity(0.15),
          child: Text(initial, style: TextStyle(color: _avatarColor(name), fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
              if (category.isNotEmpty || cadreName.isNotEmpty)
                Text(
                  '${category.isNotEmpty ? category : ''}${category.isNotEmpty && cadreName.isNotEmpty ? ' · ' : ''}$cadreName',
                  style: TextStyle(color: _kBlue, fontSize: 12),
                ),
              SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$fromRegion${fromDistrict.isNotEmpty ? ', $fromDistrict' : ''}',
                      style: TextStyle(color: _kGrey700, fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 13, color: _kGrey400),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$toRegion${toDistrict.isNotEmpty ? ', $toDistrict' : ''}',
                      style: TextStyle(color: _kBlue, fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (ago.isNotEmpty)
                Text(ago, style: TextStyle(color: _kGrey400, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactButtons(Map<String, dynamic> userA, Map<String, dynamic> userB, bool hasB) {
    final phoneA = userA['phone']?.toString() ?? '';
    final phoneB = hasB ? (userB['phone']?.toString() ?? '') : '';
    final nameA = userA['name']?.toString() ?? userA['full_name']?.toString() ?? 'A';
    final nameB = hasB ? (userB['name']?.toString() ?? userB['full_name']?.toString() ?? 'B') : '';

    if (!hasB) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _copyPhone(phoneA),
              icon: Icon(Icons.phone_outlined, size: 14),
              label: Text('Piga', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: _kGrey700, side: BorderSide(color: _kGrey200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _copyPhone(phoneA),
              icon: Icon(Icons.chat_rounded, size: 14),
              label: Text('WhatsApp', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(nameA.split(' ').first, style: TextStyle(color: _kGrey500, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _copyPhone(phoneA),
                icon: Icon(Icons.phone_outlined, size: 13),
                label: Text('Piga', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: _kGrey700, side: BorderSide(color: _kGrey200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 7)),
              ),
              SizedBox(height: 4),
              ElevatedButton.icon(
                onPressed: () => _copyPhone(phoneA),
                icon: Icon(Icons.chat_rounded, size: 13),
                label: Text('WhatsApp', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 7)),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        Container(width: 1, height: 60, color: _kGrey200),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(nameB.split(' ').first, style: TextStyle(color: _kGrey500, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _copyPhone(phoneB),
                icon: Icon(Icons.phone_outlined, size: 13),
                label: Text('Piga', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: _kGrey700, side: BorderSide(color: _kGrey200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 7)),
              ),
              SizedBox(height: 4),
              ElevatedButton.icon(
                onPressed: () => _copyPhone(phoneB),
                icon: Icon(Icons.chat_rounded, size: 13),
                label: Text('WhatsApp', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 7)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
