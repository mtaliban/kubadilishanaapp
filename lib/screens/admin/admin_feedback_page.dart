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
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

Color _avatarColor(String name) {
  if (name.isEmpty) return _kBlue;
  final colors = [Color(0xFF16A34A), Color(0xFF2563EB), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF7C3AED), Color(0xFF0891B2)];
  return colors[name.codeUnitAt(0) % colors.length];
}

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});

  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _feedback = [];
  String _tab = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = _tab == 'all' ? '' : _tab == 'replied' ? 'replied' : 'pending';
      final res = await ApiService().adminListFeedback(status: status, q: _searchQuery);
      if (!mounted) return;
      final list = (res.data is List) ? res.data as List : (res.data['feedback'] as List? ?? []);
      setState(() {
        _feedback = list;
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

  List<dynamic> get _filtered {
    return _feedback.where((f) {
      if (_tab == 'replied') return f['reply'] != null && f['reply'].toString().isNotEmpty;
      if (_tab == 'pending') return f['reply'] == null || f['reply'].toString().isEmpty;
      return true;
    }).toList();
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$d/$m/$y';
    } catch (_) {
      return raw.toString().split('T')[0];
    }
  }

  Future<void> _delete(String feedbackId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Futa Maoni', style: TextStyle(color: _kGrey900, fontWeight: FontWeight.bold)),
        content: Text('Una uhakika wa kufuta maoni haya?', style: TextStyle(color: _kGrey700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Ghairi', style: TextStyle(color: _kGrey500))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Futa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService().adminDeleteFeedback(feedbackId);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed));
    }
  }

  void _showReplySheet(Map<String, dynamic> feedback) {
    final replyCtrl = TextEditingController(text: feedback['reply']?.toString() ?? '');
    final feedbackId = feedback['_id']?.toString() ?? feedback['id']?.toString() ?? '';
    final message = feedback['message']?.toString() ?? feedback['subject']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Row(
                  children: [
                    Text('Jibu Maoni', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: _kGrey500),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(10)),
                  child: Text(message, style: TextStyle(color: _kGrey700, fontSize: 13, height: 1.5)),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: replyCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Andika jibu...',
                    hintStyle: TextStyle(color: _kGrey400),
                    filled: true,
                    fillColor: _kGrey100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(foregroundColor: _kGrey500, side: BorderSide(color: _kGrey200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 14)),
                        child: Text('Ghairi'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (replyCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          try {
                            await ApiService().adminReplyFeedback(feedbackId, replyCtrl.text.trim());
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Jibu limetumwa.'), backgroundColor: _kGreen));
                            _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 14)),
                        child: Text('Tuma Jibu'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kGrey100,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _kBlue))
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _kBlue,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: _buildSearch()),
                        SliverToBoxAdapter(child: _buildTabs()),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildFeedbackCard(_filtered[i]),
                            childCount: _filtered.length,
                          ),
                        ),
                        if (_filtered.isEmpty) SliverToBoxAdapter(child: _buildEmpty()),
                        SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: _kRed),
          SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: _kGrey700), textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
            child: Text('Jaribu Tena'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.rate_review_rounded, color: _kBlue, size: 24),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Maoni / Malamiko', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900)),
              Text('Maoni na malalamiko ya watumiaji', style: TextStyle(fontSize: 13, color: _kGrey500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _load();
        },
        decoration: InputDecoration(
          hintText: 'Tafuta maoni...',
          hintStyle: TextStyle(color: _kGrey400),
          prefixIcon: Icon(Icons.search, color: _kGrey400),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kBlue)),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      {'key': 'all', 'label': 'Yote'},
      {'key': 'pending', 'label': 'Hayajajibiwa'},
      {'key': 'replied', 'label': 'Yamejibiwa'},
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: tabs.map((t) {
          final active = _tab == t['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _tab = t['key']!);
                _load();
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: t['key'] != 'replied' ? 6 : 0),
                padding: EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? _kBlue : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? _kBlue : _kGrey200),
                ),
                child: Text(t['label']!, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : _kGrey700, fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    String msg = _tab == 'replied' ? 'Hakuna maoni yaliyojibiwa' : _tab == 'pending' ? 'Hakuna maoni yanayosubiri jibu' : 'Hakuna maoni';
    String sub = _tab == 'replied' ? 'Maoni yaliyojibiwa yataonekana hapa.' : _tab == 'pending' ? 'Vizuri! Maoni yote yamejibiwa.' : 'Bado hakuna maoni yaliyowasilishwa.';
    return Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: _kGrey400),
            SizedBox(height: 16),
            Text(msg, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey700)),
            SizedBox(height: 8),
            Text(sub, style: TextStyle(color: _kGrey500, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final feedbackId = feedback['_id']?.toString() ?? feedback['id']?.toString() ?? '';
    final name = feedback['user']?['name']?.toString() ?? feedback['user']?['full_name']?.toString() ?? 'Mtumiaji';
    final message = feedback['message']?.toString() ?? feedback['subject']?.toString() ?? '';
    final reply = feedback['reply']?.toString() ?? '';
    final date = _formatDate(feedback['created_at'] ?? feedback['createdAt']);
    final hasReply = reply.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _avatarColor(name),
                child: Text(initial, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: _kGrey900, fontSize: 14)),
                    Text(date, style: TextStyle(color: _kGrey500, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _delete(feedbackId),
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: _kRed),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(message, style: TextStyle(color: _kGrey700, fontSize: 13, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          if (hasReply) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply_rounded, size: 14, color: _kBlue),
                  SizedBox(width: 6),
                  Expanded(child: Text(reply, style: TextStyle(color: _kBlue, fontSize: 12, height: 1.4))),
                ],
              ),
            ),
          ],
          SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: hasReply
                ? TextButton(
                    onPressed: () => _showReplySheet(feedback),
                    child: Text('Hariri jibu', style: TextStyle(color: _kBlue, fontSize: 13)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(0, 32)),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _showReplySheet(feedback),
                    icon: Icon(Icons.reply_rounded, size: 15),
                    label: Text('Jibu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: TextStyle(fontSize: 13),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
