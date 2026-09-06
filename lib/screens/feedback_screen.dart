import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _msgCtrl = TextEditingController();
  List<dynamic> _items = [];
  bool _loading = true;
  bool _sending = false;
  bool _sent = false;
  String _error = '';
  String _ok = '';
  int _page = 1;
  static const _perPage = 2;

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('notification', (payload) {
      if (payload['type'] == 'feedback.replied' && mounted) _load();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMyFeedback();
      final data = res.data;
      if (mounted) {
        if (data is Map) {
          setState(() => _items = (data['items'] ?? data['feedbacks'] ?? []) as List);
        } else if (data is List) {
          setState(() => _items = data);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    setState(() { _error = ''; _ok = ''; });
    final text = _msgCtrl.text.trim();
    if (text.length < 3) { setState(() => _error = 'Andika maoni yako kwanza.'); return; }
    setState(() => _sending = true);
    try {
      final subject = text.length > 60 ? '${text.substring(0, 60)}...' : text;
      await ApiService().submitFeedback(subject: subject, message: text);
      if (mounted) {
        setState(() { _ok = 'Maoni yako yametumwa kwa admin.'; _msgCtrl.clear(); _sent = true; });
        _load();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _sent = false);
      }
    } catch (e) {
      if (mounted) {
        try {
          final d = (e as dynamic).response?.data?['detail'];
          setState(() => _error = d is String ? d : 'Imeshindikana kutuma.');
        } catch (_) {
          setState(() => _error = 'Imeshindikana kutuma.');
        }
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = (_items.length / _perPage).ceil().clamp(1, 9999);
    final safe = _page.clamp(1, total);
    final start = (safe - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _items.length);
    final paged = _items.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: const [
          Icon(Icons.list_alt, size: 20, color: AppColors.primary),
          SizedBox(width: 8), Text('Maoni na Malamiko'),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Tuma maoni yako', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Maoni yako', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _msgCtrl, maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Andika maoni au malalamiko yako hapa...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error, style: const TextStyle(color: AppColors.error, fontSize: 12))),
              ],
              if (_ok.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_ok, style: TextStyle(color: Colors.green.shade700, fontSize: 12))),
              ],
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_sent ? 'Imetumwa' : 'Tuma', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Historia (${_items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24),
              child: Text('Bado hujatuma maoni yoyote', style: TextStyle(color: AppColors.textSecondary))))
          else ...[
            ...paged.map((f) => _FbCard(item: f)),
            if (_items.length > _perPage)
              Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  OutlinedButton(onPressed: safe > 1 ? () => setState(() => _page = safe - 1) : null,
                    child: const Text('← Rudi', style: TextStyle(fontSize: 12))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$safe / $total', style: const TextStyle(fontWeight: FontWeight.bold))),
                  OutlinedButton(onPressed: safe < total ? () => setState(() => _page = safe + 1) : null,
                    child: const Text('Endelea →', style: TextStyle(fontSize: 12))),
                ])),
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _FbCard extends StatelessWidget {
  final dynamic item;
  const _FbCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final isReplied = item['status'] == 'replied';
    final message = '${item['message'] ?? ''}';
    final reply = '${item['admin_reply'] ?? ''}';
    final iso = '${item['created_at'] ?? ''}';
    String ago = '';
    try {
      if (iso.isNotEmpty) {
        final d = DateTime.parse(iso).toLocal();
        final diff = DateTime.now().difference(d);
        if (diff.inMinutes < 1) ago = 'Sasa hivi';
        else if (diff.inMinutes < 60) ago = 'dakika ${diff.inMinutes} iliyopita';
        else if (diff.inHours < 24) ago = 'saa ${diff.inHours} iliyopita';
        else ago = 'siku ${diff.inDays} iliyopita';
      }
    } catch (_) {}
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isReplied ? Colors.green.shade100 : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20)),
            child: Text(isReplied ? 'Imejibiwa' : 'Wazi',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                    color: isReplied ? Colors.green.shade700 : const Color(0xFFD97706))),
          ),
          const Spacer(),
          if (ago.isNotEmpty) Text(ago, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
        ]),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        if (reply.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('JIBU LA ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 4),
              Text(reply, style: const TextStyle(fontSize: 12)),
            ])),
        ],
      ]),
    );
  }
}
