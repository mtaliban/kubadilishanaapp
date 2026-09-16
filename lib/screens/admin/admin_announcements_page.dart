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

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _announcements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminListAnnouncements();
      if (!mounted) return;
      final list = (res.data is List) ? res.data as List : (res.data['announcements'] as List? ?? []);
      setState(() {
        _announcements = list;
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

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Futa Tangazo', style: TextStyle(color: _kGrey900, fontWeight: FontWeight.bold)),
        content: Text('Una uhakika wa kufuta tangazo hili?', style: TextStyle(color: _kGrey700)),
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
      await ApiService().adminDeleteAnnouncement(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed));
    }
  }

  Future<void> _resend(String id) async {
    try {
      await ApiService().adminSendAnnouncement({'id': id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tangazo limetumwa tena.'), backgroundColor: _kGreen));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed));
    }
  }

  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String selectedType = 'General';
    final types = ['General', 'Important', 'Update'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                      Text('Tangazo Jipya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close, color: _kGrey500),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  Text('Tuma arifa kwa watumiaji wote', style: TextStyle(color: _kGrey500, fontSize: 13)),
                  SizedBox(height: 20),
                  Text('Kichwa', style: TextStyle(color: _kGrey700, fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Kichwa cha tangazo',
                      hintStyle: TextStyle(color: _kGrey400),
                      filled: true,
                      fillColor: _kGrey100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text('Ujumbe', style: TextStyle(color: _kGrey700, fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 6),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Andika ujumbe wa tangazo...',
                      hintStyle: TextStyle(color: _kGrey400),
                      filled: true,
                      fillColor: _kGrey100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text('Aina', style: TextStyle(color: _kGrey700, fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _kGrey100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kGrey200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        onChanged: (v) => setSheetState(() => selectedType = v ?? 'General'),
                        items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
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
                            if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;
                            Navigator.pop(ctx);
                            try {
                              await ApiService().adminSendAnnouncement({
                                'title': titleCtrl.text.trim(),
                                'body': bodyCtrl.text.trim(),
                                'type': selectedType,
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tangazo limetumwa.'), backgroundColor: _kGreen));
                              _load();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(vertical: 14)),
                          child: Text('Tuma Sasa'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildAnnouncementCard(_announcements[i]),
                            childCount: _announcements.length,
                          ),
                        ),
                        if (_announcements.isEmpty) SliverToBoxAdapter(child: _buildEmpty()),
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
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.campaign_rounded, color: _kBlue, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Matangazo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900)),
                    Text('Tuma matangazo kwa watumiaji', style: TextStyle(fontSize: 13, color: _kGrey500)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddSheet,
                icon: Icon(Icons.add, size: 16),
                label: Text('Tangazo Jipya'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: Column(
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: _kGrey400),
            SizedBox(height: 16),
            Text('Hakuna matangazo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey700)),
            SizedBox(height: 8),
            Text('Bado hakuna matangazo yaliyotumwa.', style: TextStyle(color: _kGrey500, fontSize: 14), textAlign: TextAlign.center),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showAddSheet,
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Tuma kwanza'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final id = announcement['_id']?.toString() ?? announcement['id']?.toString() ?? '';
    final title = announcement['title']?.toString() ?? '';
    final body = announcement['body']?.toString() ?? announcement['message']?.toString() ?? '';
    final date = _formatDate(announcement['created_at'] ?? announcement['createdAt']);

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.notifications_rounded, color: _kBlue, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _kGrey900, fontSize: 14)),
                    SizedBox(height: 2),
                    Text(date, style: TextStyle(color: _kGrey500, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _resend(id),
                icon: Icon(Icons.send_rounded, color: _kBlue, size: 18),
                tooltip: 'Tuma tena',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: () => _delete(id),
                icon: Icon(Icons.delete_outline_rounded, color: _kRed, size: 18),
                tooltip: 'Futa',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: _kGrey700, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
