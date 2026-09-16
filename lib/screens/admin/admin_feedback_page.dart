import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});
  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();
  int _tabIndex = 0; // 0=Yote 1=Hayajajibiwa 2=Yamejibiwa

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminListFeedback(status: '', q: '');
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _all = data is List ? data : (data['results'] as List? ?? []);
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((item) {
        final m = item as Map<String, dynamic>;
        final name = (m['user_name'] as String? ?? m['full_name'] as String? ?? '').toLowerCase();
        final msg = (m['message'] as String? ?? m['subject'] as String? ?? '').toLowerCase();
        final replied = m['reply'] != null || m['admin_reply'] != null;
        final matchQ = q.isEmpty || name.contains(q) || msg.contains(q);
        bool matchTab = true;
        if (_tabIndex == 1) matchTab = !replied;
        if (_tabIndex == 2) matchTab = replied;
        return matchQ && matchTab;
      }).toList();
    });
  }

  void _setTab(int i) {
    setState(() { _tabIndex = i; });
    _applyFilter();
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Maoni'),
        content: const Text('Una uhakika unataka kufuta maoni haya?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Futa', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().adminDeleteFeedback(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  void _showReplySheet(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReplySheet(
        feedbackId: id,
        onReplied: _load,
      ),
    );
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
                  child: const Icon(Icons.feedback_outlined, color: _kBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Maoni',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                    Text('Maoni na malamiko ya watumiaji',
                        style: TextStyle(fontSize: 12, color: _kGrey500)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tafuta maoni...',
                prefixIcon: const Icon(Icons.search, color: _kGrey500),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kGrey200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kGrey200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBlue),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _TabPill(label: 'Yote', selected: _tabIndex == 0, onTap: () => _setTab(0)),
                const SizedBox(width: 8),
                _TabPill(label: 'Hayajajibiwa', selected: _tabIndex == 1, onTap: () => _setTab(1)),
                const SizedBox(width: 8),
                _TabPill(label: 'Yamejibiwa', selected: _tabIndex == 2, onTap: () => _setTab(2)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _kGrey200),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: _kRed, size: 48),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Jaribu tena'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.feedback_outlined, color: _kGrey500, size: 48),
                    const SizedBox(height: 12),
                    Text('Hakuna maoni', style: TextStyle(color: _kGrey500)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = _filtered[i] as Map<String, dynamic>;
                    final id = item['id']?.toString() ?? '';
                    final name = item['user_name'] as String? ?? item['full_name'] as String? ?? 'Mtumiaji';
                    final msg = item['message'] as String? ?? item['subject'] as String? ?? '';
                    final createdAt = item['created_at'] as String? ?? '';
                    final reply = item['reply'] as String? ?? item['admin_reply'] as String?;
                    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'M';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _kGrey200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: _kBlueBg,
                                child: Text(initials,
                                    style: TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey900)),
                                    if (createdAt.isNotEmpty)
                                      Text(createdAt, style: TextStyle(fontSize: 11, color: _kGrey500)),
                                  ],
                                ),
                              ),
                              if (reply != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _kGreenBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Imejibiwa',
                                      style: TextStyle(fontSize: 10, color: _kGreen, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          if (msg.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(msg, style: TextStyle(fontSize: 13, color: _kGrey700)),
                          ],
                          if (reply != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _kBlueBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.reply, color: _kBlue, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(reply,
                                        style: TextStyle(fontSize: 12, color: _kBlue)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showReplySheet(item),
                                icon: const Icon(Icons.reply, size: 14),
                                label: const Text('Jibu', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kBlue,
                                  side: const BorderSide(color: _kBlue),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _delete(id),
                                icon: const Icon(Icons.delete_outline, size: 14),
                                label: const Text('Futa', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kRed,
                                  side: const BorderSide(color: _kRed),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  final String feedbackId;
  final VoidCallback onReplied;
  const _ReplySheet({required this.feedbackId, required this.onReplied});
  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _sending = true; });
    try {
      await ApiService().adminReplyFeedback(widget.feedbackId, _ctrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      widget.onReplied();
    } catch (e) {
      if (!mounted) return;
      setState(() { _sending = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Jibu Maoni',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Andika jibu...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _sending
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Tuma Jibu', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kBlueBg : Colors.white,
          border: Border.all(color: selected ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? _kBlue : _kGrey700,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
