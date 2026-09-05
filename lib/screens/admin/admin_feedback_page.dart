/// Admin feedback page — view and reply to user feedback.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});
  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  List<dynamic> _feedback = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/feedback/admin/all');
      setState(() {
        _feedback = res.data is List ? res.data : (res.data['feedback'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: _feedback.isEmpty
                ? const Center(child: Text('Hakuna maoni bado', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _feedback.length,
                    itemBuilder: (context, i) => _feedbackTile(_feedback[i]),
                  ),
          );
  }

  Widget _feedbackTile(Map<String, dynamic> f) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  f['type'] == 'complaint' ? Icons.warning : Icons.lightbulb,
                  size: 16,
                  color: f['type'] == 'complaint' ? AppColors.warning : AppColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(f['user_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Text(f['created_at'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
              ],
            ),
            const SizedBox(height: 8),
            Text(f['message'] ?? '', style: const TextStyle(fontSize: 13)),
            if (f['reply'] != null) ...[
              const Divider(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f['reply'] ?? '', style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],
            if (f['reply'] == null) ...[
              const SizedBox(height: 8),
              _replyBox(f),
            ],
          ],
        ),
      ),
    );
  }

  Widget _replyBox(Map<String, dynamic> f) {
    final ctrl = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Jibu hapa...', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.send, size: 20, color: AppColors.primary),
          onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            try {
              await ApiService().adminReplyFeedback(f['_id'] ?? f['id'], ctrl.text.trim());
              _load();
            } catch (_) {}
          },
        ),
      ],
    );
  }
}
