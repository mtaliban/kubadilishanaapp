import 'package:flutter/material.dart';
import 'admin_theme.dart';
import '../../services/api_service.dart';
import '../../services/cached_repository.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/no_cached_data_widget.dart';

// OFFLINE-FIRST — funguo za diski: kila status iwe na funguo yake.
String _kKey(String status) => 'page:admin/password-resets/$status';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg = Color(0xFFEFF6FF);
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
  bool _loading = true; // tab bado hakuna diski kabisa
  final Map<String, List<dynamic>> _cache = {};

  static const _tabs = ['pending', 'approved', 'rejected'];
  static const _labels = ['Inasubiri', 'Imeidhinishwa', 'Imekataliwa'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) _loadTab(); });
    // DISKI PAPO HAPO — frame ya KWANZA (hakuna spring, hakuna kusubiri).
    CachedRepository().hydrate(_kKey('pending'),
        (data) => _applyTab('pending', data));
    _load('pending');
  }

  void _applyTab(String status, dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final list = data is List
        ? data
        : (asMap(data)['results'] as List? ?? []);
    _cache[status] = list;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String get _currentStatus => _tabs[_tabCtrl.index];

  Future<void> _loadTab() async => _load(_currentStatus);

  Future<void> _load(String status) async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: orodha ya diski inabaki.
    if (!_cache.containsKey(status)) setState(() => _loading = true);
    await CachedRepository().loadPage(_kKey(status),
        () async =>
            (await ApiService().adminListPasswordResets(status: status)).data,
        (data) => _applyTab(status, data));
    if (mounted && _loading) setState(() => _loading = false);
  }

  Future<void> _approve(String id) async {
    try {
      await ApiService().adminApprovePasswordReset(id);
      if (!mounted) return;
      _cache.remove('pending');
      _cache.remove('approved');
      // Diski ya tab mbili pia ifutwe — ifunguliwe tena ipakie data mpya.
      CachedRepository().invalidateKey(_kKey('pending'));
      CachedRepository().invalidateKey(_kKey('approved'));
      await _load('pending');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(friendlyError(e));
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ApiService().adminRejectPasswordReset(id);
      if (!mounted) return;
      _cache.remove('pending');
      _cache.remove('rejected');
      // Diski ya tab mbili pia ifutwe — ifunguliwe tena ipakie data mpya.
      CachedRepository().invalidateKey(_kKey('pending'));
      CachedRepository().invalidateKey(_kKey('rejected'));
      await _load('pending');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF0F172A)
          : Ad.card(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Ad.blueSoft(context), borderRadius: BorderRadius.circular(10)),
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Ad.ink(context))),
                      Text('Maombi ya kubadilisha nywila',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Ad.muted(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Ad.tile(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: Ad.card(context),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(3),
              labelColor: _kBlue,
              unselectedLabelColor: Ad.muted(context),
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: _labels.map((l) => Tab(text: l)).toList(),
            ),
          ),
          SizedBox(height: 8),
          Divider(height: 1, color: Ad.border(context)),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _tabs.map((status) {
                if (_loading && !_cache.containsKey(status)) {
                  // Bado hakuna diski — NoCachedDataWidget (spinner mtandaoni).
                  return NoCachedDataWidget(onLoad: () => _load(status));
                }
                if (_cache[status] == null &&
                    CachedRepository().readOrNull<dynamic>(_kKey(status)) == null) {
                  // HAKUNA data diski + API imeshindwa — widget MOYA ya
                  // "haijapakuliwa" (pull-to-refresh pekee).
                  return NoCachedDataWidget(
                    onLoad: () => _load(status),
                    hint: 'Vuta chini kupakia, au subiri mtandao — maombi yataonekana.',
                  );
                }
                final items = _cache[status] ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, color: Ad.muted(context), size: 48),
                        SizedBox(height: 12),
                        Text('Hakuna maombi', style: TextStyle(color: Ad.muted(context))),
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
                          color: Ad.card(context),
                          border: Border.all(color: Ad.border(context)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Ad.blueSoft(context),
                              child: Text(initials,
                                  style: TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Ad.ink(context))),
                                  if (phone.isNotEmpty)
                                    Text(phone, style: TextStyle(fontSize: 12, color: _kBlue)),
                                  if (createdAt.isNotEmpty)
                                    Text(createdAt, style: TextStyle(fontSize: 11, color: Ad.muted(context))),
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
