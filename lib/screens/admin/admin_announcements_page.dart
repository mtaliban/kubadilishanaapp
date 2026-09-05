/// Admin announcements page — send and manage announcements.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  List<dynamic> _announcements = [];
  bool _loading = true;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/announcements/admin/list');
      setState(() {
        _announcements = res.data is List ? res.data : (res.data['announcements'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // New announcement form
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tuma Tangazo Jipya', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(hintText: 'Kichwa cha habari', isDense: true),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bodyCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'Maelezo ya tangazo...', isDense: true),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _send,
                            child: const Text('Tuma Tangazo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Matangazo Yaliyotumwa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ..._announcements.map((a) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.campaign, color: AppColors.primary, size: 20),
                    title: Text(a['title'] ?? '', style: const TextStyle(fontSize: 14)),
                    subtitle: Text(a['body'] ?? '', style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(a['created_at'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                  ),
                )),
              ],
            ),
          );
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) return;
    try {
      await ApiService().post('/announcements', data: {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tangazo limetumwa!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}
