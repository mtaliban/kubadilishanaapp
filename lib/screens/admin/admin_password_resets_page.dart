/// Admin password resets page — approve/reject password reset requests.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminPasswordResetsPage extends StatefulWidget {
  const AdminPasswordResetsPage({super.key});
  @override
  State<AdminPasswordResetsPage> createState() => _AdminPasswordResetsPageState();
}

class _AdminPasswordResetsPageState extends State<AdminPasswordResetsPage> {
  List<dynamic> _resets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/admin/password-resets');
      setState(() {
        _resets = res.data is List ? res.data : (res.data['resets'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── PAGE HEADER ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Icon(Icons.lock_reset_outlined, size: 20, color: Color(0xFF1E40AF))),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ombi la Nenosiri (${_resets.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const Text('Maombi ya kubadilisha nenosiri', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _resets.isEmpty
                      ? const Center(child: Text('Hakuna ombi la nenosiri', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                          itemCount: _resets.length,
                          itemBuilder: (context, i) => _resetTile(_resets[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _resetTile(Map<String, dynamic> r) {
    final status = r['status'] ?? 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status == 'pending' ? AppColors.warning : status == 'approved' ? AppColors.success : AppColors.error,
          child: Icon(
            status == 'pending' ? Icons.hourglass_empty : status == 'approved' ? Icons.check : Icons.close,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(r['user_name'] ?? r['phone'] ?? '', style: const TextStyle(fontSize: 14)),
        subtitle: Text(status == 'pending' ? 'Inasubiri' : status == 'approved' ? 'Imekubaliwa' : 'Imekataliwa',
            style: TextStyle(fontSize: 12, color: status == 'pending' ? AppColors.warning : status == 'approved' ? AppColors.success : AppColors.error)),
        trailing: status == 'pending'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: AppColors.success, size: 20),
                    onPressed: () => _approve(r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.error, size: 20),
                    onPressed: () => _reject(r),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _approve(Map<String, dynamic> r) async {
    try {
      await ApiService().post('/admin/password-resets/${r['_id']}/approve');
      _load();
    } catch (_) {}
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    try {
      await ApiService().post('/admin/password-resets/${r['_id']}/reject');
      _load();
    } catch (_) {}
  }
}
