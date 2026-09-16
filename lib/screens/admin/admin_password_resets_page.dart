import 'package:flutter/material.dart';
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

class AdminPasswordResetsPage extends StatefulWidget {
  const AdminPasswordResetsPage({super.key});

  @override
  State<AdminPasswordResetsPage> createState() => _AdminPasswordResetsPageState();
}

class _AdminPasswordResetsPageState extends State<AdminPasswordResetsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<dynamic> _pending = [];
  List<dynamic> _approved = [];
  List<dynamic> _rejected = [];
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService().adminListPasswordResets(status: 'pending'),
        ApiService().adminListPasswordResets(status: 'approved'),
        ApiService().adminListPasswordResets(status: 'rejected'),
      ]);
      if (!mounted) return;

      List<dynamic> _parseList(dynamic raw) {
        if (raw is List) return raw;
        if (raw is Map) return (raw['resets'] ?? raw['data'] ?? raw['results'] ?? []) as List<dynamic>;
        return [];
      }

      setState(() {
        _pending = _parseList(results[0].data);
        _approved = _parseList(results[1].data);
        _rejected = _parseList(results[2].data);
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

  Future<void> _approve(String id) async {
    setState(() => _processingIds.add(id));
    try {
      await ApiService().adminApprovePasswordReset(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ombi limeidhinishwa'), backgroundColor: _kGreen),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(id));
    }
  }

  Future<void> _reject(String id) async {
    setState(() => _processingIds.add(id));
    try {
      await ApiService().adminRejectPasswordReset(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ombi limekataliwa'), backgroundColor: _kAmber),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(id));
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return raw.toString();
      final local = dt.toLocal();
      return '${local.day}/${local.month}/${local.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  String _initial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  Widget _resetCard(Map<String, dynamic> item, {bool showActions = false}) {
    final id = item['_id'] as String? ?? item['id'] as String? ?? '';
    final user = item['user'] as Map<String, dynamic>? ?? {};
    final name = user['full_name'] as String? ?? user['name'] as String? ?? item['full_name'] as String? ?? 'Mtumiaji';
    final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? item['phone'] as String? ?? '';
    final createdAt = item['created_at'] ?? item['createdAt'];
    final isProcessing = _processingIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _kBlueBg,
            child: Text(
              _initial(name),
              style: const TextStyle(color: _kBlue, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey900)),
                const SizedBox(height: 2),
                Text(phone, style: const TextStyle(fontSize: 12, color: _kGrey500)),
                const SizedBox(height: 2),
                Text(_formatDate(createdAt), style: const TextStyle(fontSize: 11, color: _kGrey400)),
              ],
            ),
          ),
          if (showActions && id.isNotEmpty) ...[
            const SizedBox(width: 8),
            if (isProcessing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _approve(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kGreenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Idhinisha', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGreen)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _reject(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kRedBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Kataa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kRed)),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _listView(List<dynamic> items, {bool showActions = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_off_rounded, size: 56, color: _kGrey400),
            const SizedBox(height: 12),
            const Text('Hakuna maombi', style: TextStyle(fontSize: 16, color: _kGrey500, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) => _resetCard(items[i] as Map<String, dynamic>, showActions: showActions),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kBlueBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.key_rounded, color: _kBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manenosiri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                      Text('Maombi ya kubadilisha nenosiri', style: TextStyle(fontSize: 13, color: _kGrey500)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kBlueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 18, color: _kBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: _kBlue,
                unselectedLabelColor: _kGrey500,
                indicatorColor: _kBlue,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
                tabs: [
                  Tab(text: 'Inasubiri (${_pending.length})'),
                  Tab(text: 'Idhinishwa (${_approved.length})'),
                  Tab(text: 'Kataliwa (${_rejected.length})'),
                ],
              ),
            ],
          ),
        ),
        Container(height: 1, color: _kGrey200),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: _kGrey700), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
                            child: const Text('Jaribu Tena'),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _listView(_pending, showActions: true),
                        _listView(_approved),
                        _listView(_rejected),
                      ],
                    ),
        ),
      ],
    );
  }
}
