/// Feedback screen — submit and view feedback/complaints.
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
  final _messageCtrl = TextEditingController();
  String _type = 'complaint';

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    try {
      final res = await ApiService().getMyFeedback();
      setState(() {
        _feedback = res.data is List ? res.data : (res.data['feedback'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
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
                          const Text('Tuma Maoni', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'complaint', label: Text('Lalamiko')),
                              ButtonSegment(value: 'suggestion', label: Text('Pendekezo')),
                              ButtonSegment(value: 'question', label: Text('Swali')),
                            ],
                            selected: {_type},
                            onSelectionChanged: (s) => setState(() => _type = s.first),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _messageCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(hintText: 'Andika maoni yako hapa...'),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submit,
                              child: const Text('Tuma'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Maoni Yako', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_feedback.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Huna maoni bado', style: TextStyle(color: AppColors.textSecondary))),
                      ),
                    ),
                  ..._feedback.map((f) => Card(
                    child: ListTile(
                      leading: Icon(
                        f['type'] == 'complaint' ? Icons.warning : f['type'] == 'suggestion' ? Icons.lightbulb : Icons.help,
                        color: f['type'] == 'complaint' ? AppColors.warning : AppColors.info,
                        size: 20,
                      ),
                      title: Text(f['message'] ?? '', style: const TextStyle(fontSize: 13)),
                      subtitle: Text(f['created_at'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                      trailing: f['reply'] != null
                          ? const Icon(Icons.reply, color: AppColors.success, size: 18)
                          : null,
                    ),
                  )),
                ],
              ),
            ),
    );
  }

  Future<void> _submit() async {
    final msg = _messageCtrl.text.trim();
    if (msg.isEmpty) return;
    try {
      await ApiService().submitFeedback({'type': _type, 'message': msg});
      _messageCtrl.clear();
      await _loadFeedback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Umefanikiwa kutuma!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hitilafu — jaribu tena'), backgroundColor: AppColors.error));
      }
    }
  }
}
