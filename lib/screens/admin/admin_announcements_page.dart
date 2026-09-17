import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminListAnnouncements();
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _items = data is List ? data : (data['results'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'warning': return _kAmber;
      case 'success': return _kGreen;
      case 'urgent': return _kRed;
      default: return _kBlue;
    }
  }

  Color _typeBg(String type) {
    switch (type) {
      case 'warning': return _kAmberBg;
      case 'success': return _kGreenBg;
      case 'urgent': return _kRedBg;
      default: return _kBlueBg;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'warning': return 'Onyo';
      case 'success': return 'Mafanikio';
      case 'urgent': return 'Haraka';
      default: return 'Taarifa';
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Tangazo'),
        content: const Text('Una uhakika unataka kufuta tangazo hili?'),
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
      await ApiService().adminDeleteAnnouncement(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _resend(String id) async {
    try {
      await ApiService().adminResendAnnouncement(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tangazo limetumwa tena'), backgroundColor: _kGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  void _showSendForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SendAnnouncementSheet(onSent: _load),
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
                  child: const Icon(Icons.notifications_outlined, color: _kBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Matangazo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                      Text('Tuma taarifa kwa watumiaji',
                          style: TextStyle(fontSize: 12, color: _kGrey500)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showSendForm,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tangazo Jipya', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
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
          else if (_items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, color: _kGrey500, size: 48),
                    const SizedBox(height: 12),
                    Text('Hakuna matangazo', style: TextStyle(color: _kGrey500)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showSendForm,
                      icon: const Icon(Icons.add),
                      label: const Text('Tangazo Jipya'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, foregroundColor: Colors.white,
                      ),
                    ),
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
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = _items[i] as Map<String, dynamic>;
                    final id = item['id']?.toString() ?? '';
                    final title = item['title'] as String? ?? '';
                    final message = item['message'] as String? ?? '';
                    final type = item['type'] as String? ?? 'info';
                    final createdAt = item['created_at'] as String? ?? '';
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
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: _typeBg(type),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.notifications_outlined, color: _typeColor(type), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                                    Container(
                                      margin: const EdgeInsets.only(top: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _typeBg(type),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(_typeLabel(type),
                                          style: TextStyle(fontSize: 10, color: _typeColor(type), fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(message,
                                style: TextStyle(fontSize: 13, color: _kGrey700),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                          ],
                          if (createdAt.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(createdAt, style: TextStyle(fontSize: 11, color: _kGrey500)),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _resend(id),
                                  icon: const Icon(Icons.replay, size: 14),
                                  label: const Text('Tuma Tena', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _kBlue,
                                    side: const BorderSide(color: _kBlue),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _delete(id),
                                  icon: const Icon(Icons.delete_outline, size: 14),
                                  label: const Text('Futa', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _kRed,
                                    side: const BorderSide(color: _kRed),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
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

class _SendAnnouncementSheet extends StatefulWidget {
  final VoidCallback onSent;
  const _SendAnnouncementSheet({required this.onSent});

  @override
  State<_SendAnnouncementSheet> createState() => _SendAnnouncementSheetState();
}

class _SendAnnouncementSheetState extends State<_SendAnnouncementSheet> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _type = 'info';
  String _audience = 'all';
  List<dynamic> _departments = [];
  bool _sending = false;

  static const _types = ['info', 'warning', 'success', 'urgent'];
  static const _typeLabels = ['Taarifa', 'Onyo', 'Mafanikio', 'Haraka'];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final r = await ApiService().adminListDepartments();
      final raw = r.data;
      if (!mounted) return;
      setState(() {
        _departments = raw is List ? raw : (raw['results'] ?? raw['items'] ?? raw['data'] ?? []);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) return;
    setState(() { _sending = true; });
    try {
      await ApiService().adminSendAnnouncement({
        'title': _titleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'type': _type,
        'audience': _audience,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSent();
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
              Text('Tuma Tangazo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: _inputDec('Kichwa cha habari'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _msgCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: _inputDec('Ujumbe'),
          ),
          const SizedBox(height: 12),
          Text('Aina', style: TextStyle(fontSize: 12, color: _kGrey700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: _inputDec('Aina'),
            items: List.generate(_types.length, (i) => DropdownMenuItem(
              value: _types[i],
              child: Text(_typeLabels[i]),
            )),
            onChanged: (v) => setState(() { _type = v ?? 'info'; }),
          ),
          const SizedBox(height: 12),
          Text('Wasikilizaji', style: TextStyle(fontSize: 12, color: _kGrey700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _audience,
            isExpanded: true,
            decoration: _inputDec('Chagua wasikilizaji'),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('Wote')),
              ..._departments.map((d) => DropdownMenuItem<String>(
                value: d['code'] as String? ?? '',
                child: Text('${d['icon'] != null ? '${d['icon']} ' : ''}${d['name'] ?? d['code']}'),
              )),
            ],
            onChanged: (v) => setState(() { _audience = v ?? 'all'; }),
          ),
          const SizedBox(height: 20),
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
                  : const Text('Tuma Tangazo', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
  );
}
