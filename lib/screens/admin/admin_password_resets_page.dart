import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminPasswordResetsPage extends StatefulWidget {
  const AdminPasswordResetsPage({super.key});
  @override
  State<AdminPasswordResetsPage> createState() => _AdminPasswordResetsPageState();
}

class _AdminPasswordResetsPageState extends State<AdminPasswordResetsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  final Map<String, List<dynamic>> _cache = {};

  static const _tabs = ['pending', 'approved', 'rejected'];
  static const _labels = ['Inasubiri', 'Imeidhinishwa', 'Imekataliwa'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) _loadTab(); });
    _load('pending');
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String get _currentStatus => _tabs[_tabCtrl.index];

  Future<void> _loadTab() async => _load(_currentStatus);

  Future<void> _load(String status) async {
    if (_cache.containsKey(status)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminListPasswordResets(status: status);
      if (!mounted) return;
      final data = res.data;
      _cache[status] = data is List ? data : (data['results'] as List? ?? []);
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _approve(String id) async {
    try {
      await ApiService().adminApprovePasswordReset(id);
      if (!mounted) return;
      _cache.remove('pending');
      _cache.remove('approved');
      await _load('pending');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ApiService().adminRejectPasswordReset(id);
      if (!mounted) return;
      _cache.remove('pending');
      _cache.remove('rejected');
      await _load('pending');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock_reset, color: _kBlue, size: 22),
                ),
                const SizedBox(width: 12),
                // Expanded: jina/subtitle zinapishana mstari kwenye skrini ndogo
                // badala ya kumwaga kulia (overflow ya piksel 111 kwenye 320px).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Manenosiri',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                      Text('Maombi ya kubadilisha nywila',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: _kGrey500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _kGrey100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(3),
              labelColor: _kBlue,
              unselectedLabelColor: _kGrey500,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: _labels.map((l) => Tab(text: l)).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _kGrey200),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _tabs.map((status) {
                if (_loading && !_cache.containsKey(status)) {
                  return const Center(child: CircularProgressIndicator(color: _kBlue));
                }
                if (_error != null && !_cache.containsKey(status)) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: _kRed, size: 48),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () { _cache.remove(status); _load(status); },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Jaribu tena'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue, foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final items = _cache[status] ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, color: _kGrey500, size: 48),
                        const SizedBox(height: 12),
                        Text('Hakuna maombi', style: TextStyle(color: _kGrey500)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _cache.remove(status);
                    await _load(status);
                  },
                  color: _kBlue,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = asMap(items[i]);
                      final id = item['id']?.toString() ?? '';
                      final name = item['full_name'] as String? ?? item['user_name'] as String? ?? 'Mtumiaji';
                      final phone = item['phone'] as String? ?? item['phone_primary'] as String? ?? '';
                      final createdAt = item['created_at'] as String? ?? '';
                      final initials = name.isNotEmpty ? name[0].toUpperCase() : 'M';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _kGrey200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: _kBlueBg,
                              child: Text(initials,
                                  style: TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                                  if (phone.isNotEmpty)
                                    Text(phone, style: TextStyle(fontSize: 12, color: _kBlue)),
                                  if (createdAt.isNotEmpty)
                                    Text(createdAt, style: TextStyle(fontSize: 11, color: _kGrey500)),
                                ],
                              ),
                            ),
                            if (status == 'pending') ...[
                              const SizedBox(width: 8),
                              _ActionBtn(
                                icon: Icons.check,
                                color: _kGreen,
                                bgColor: _kGreenBg,
                                onTap: () => _approve(id),
                              ),
                              const SizedBox(width: 6),
                              _ActionBtn(
                                icon: Icons.close,
                                color: _kRed,
                                bgColor: _kRedBg,
                                onTap: () => _reject(id),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.bgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
