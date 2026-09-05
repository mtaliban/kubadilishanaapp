/// Admin announcements page — send and manage announcements.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override
  State<AdminAnnouncementsPage> createState() =>
      _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  List<dynamic> _announcements = [];
  bool _loading = true;
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _audience = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().adminListAnnouncements();
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _announcements = data['announcements'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
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
                        const Text('Tuma Tangazo Jipya',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        // Audience selector
                        DropdownButtonFormField<String>(
                          value: _audience,
                          decoration: const InputDecoration(
                              labelText: 'Walengwa', isDense: true),
                          items: const [
                            DropdownMenuItem(
                                value: 'all',
                                child: Text('Wote')),
                            DropdownMenuItem(
                                value: 'health',
                                child: Text('Afya tu')),
                            DropdownMenuItem(
                                value: 'education',
                                child: Text('Elimu tu')),
                          ],
                          onChanged: (v) =>
                              setState(() => _audience = v ?? 'all'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                              hintText: 'Kichwa cha habari',
                              isDense: true),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _messageCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              hintText:
                                  'Maelezo ya tangazo...',
                              isDense: true),
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
                Text(
                    'Matangazo Yaliyotumwa (${_announcements.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                ..._announcements.map((a) {
                      final id = (a['announcement_id'] ?? a['_id'] ?? '')
                          .toString();
                      return _AnnouncementTile(
                        item: a,
                        onDelete: () => _delete(id),
                        onResend: () => _resend(id),
                      );
                    }),
              ],
            ),
          );
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (title.isEmpty || message.isEmpty) return;
    try {
      await ApiService().adminSendAnnouncement({
        'title': title,
        'message': message,
        'audience': _audience,
      });
      _titleCtrl.clear();
      _messageCtrl.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tangazo limetumwa!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _delete(String id) async {
    if (id.isEmpty) return;
    try {
      await ApiService().adminDeleteAnnouncement(id);
      _load();
    } catch (_) {}
  }

  Future<void> _resend(String id) async {
    if (id.isEmpty) return;
    try {
      await ApiService().post('/admin/announcements/$id/resend');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tangazo limetumwa tena!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hitilafu: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }
}

class _AnnouncementTile extends StatelessWidget {
  final dynamic item;
  final VoidCallback onDelete;
  final VoidCallback onResend;
  const _AnnouncementTile(
      {required this.item, required this.onDelete, required this.onResend});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['title'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.send,
                          size: 18, color: AppColors.primary),
                      tooltip: 'Tuma Tena',
                      onPressed: onResend,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                      tooltip: 'Futa',
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item['message'] ?? item['body'] ?? '',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Walengwa: ${item['audience'] ?? 'all'}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight),
                ),
                const SizedBox(width: 12),
                Text(
                  '${item['recipient_count'] ?? 0} watu',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight),
                ),
                const Spacer(),
                Text(
                  (item['created_at'] ?? '').toString().split('T').first,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textLight),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
