/// Feedback screen — submit and view feedback/complaints with admin replies.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  List<dynamic> _feedback = [];
  bool _loading = true;
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    try {
      final res = await ApiService().getMyFeedback();
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _feedback = data['items'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maoni na Malalamiko')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFeedback,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Submit form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tuma Maoni',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _subjectCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Kichwa (Subject)'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _messageCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                hintText: 'Andika maoni yako hapa...'),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Text('Tuma'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Maoni Yako',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_feedback.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text('Huna maoni bado',
                                style: TextStyle(
                                    color: AppColors.textSecondary))),
                      ),
                    ),
                  ..._feedback.map((f) => _FeedbackTile(item: f)),
                ],
              ),
            ),
    );
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final msg = _messageCtrl.text.trim();
    if (subject.isEmpty || msg.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ApiService().submitFeedback(subject: subject, message: msg);
      _subjectCtrl.clear();
      _messageCtrl.clear();
      await _loadFeedback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Umefanikiwa kutuma!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Hitilafu — jaribu tena'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _FeedbackTile extends StatelessWidget {
  final dynamic item;
  const _FeedbackTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item['status'] ?? 'pending';
    final adminReply = item['admin_reply'] as String?;
    Color statusColor = status == 'replied'
        ? AppColors.success
        : status == 'closed'
            ? AppColors.textLight
            : AppColors.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item['subject'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 0.5),
                  ),
                  child: Text(
                    status == 'replied'
                        ? 'Amejibiwa'
                        : status == 'closed'
                            ? 'Imefungwa'
                            : 'Inasubiri',
                    style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item['message'] ?? '',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              (item['created_at'] ?? '').toString().split('T').first,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textLight),
            ),
            if (adminReply != null) ...[
              const Divider(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.reply,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Jibu la Admin',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success)),
                        const SizedBox(height: 2),
                        Text(adminReply,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
