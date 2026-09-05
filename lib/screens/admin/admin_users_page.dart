/// Admin users page — list, search, create, edit, delete users.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<dynamic> _users = [];
  bool _loading = true;
  String _q = '';
  int _page = 1;
  int _total = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final skip = (_page - 1) * _pageSize;
      final res = await ApiService().adminUsers(params: {
        if (_q.isNotEmpty) 'q': _q,
        'skip': skip,
        'limit': _pageSize,
      });
      setState(() {
        _users = res.data['users'] ?? [];
        _total = res.data['total'] ?? 0;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(children: _buildContent(context)),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _showCreateDialog,
            tooltip: 'Ongeza Mtumiaji',
            child: const Icon(Icons.person_add),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    return [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tafuta mtumiaji...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _q.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { setState(() => _q = ''); _load(); })
                  : null,
            ),
            onChanged: (v) => _q = v,
            onSubmitted: (_) => { setState(() => _page = 1), _load() },
          ),
        ),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Chip(label: Text('Jumla: $_total', style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Chip(label: Text('Page $_page', style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
        // User list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _users.length,
                    itemBuilder: (context, i) => _userTile(_users[i]),
                  ),
                ),
        ),
        // Pagination
        if (_total > _pageSize)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_page > 1)
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () { setState(() => _page--); _load(); }),
                Text('Page $_page / ${(_total / _pageSize).ceil()}'),
                if (_page * _pageSize < _total)
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () { setState(() => _page++); _load(); }),
              ],
            ),
          ),
    ];
  }

  Widget _userTile(Map<String, dynamic> u) {
    final isAdmin = u['is_admin'] ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin ? AppColors.warning : AppColors.primaryLight,
          child: Text(
            (u['full_name'] ?? '?')[0].toString().toUpperCase(),
            style: TextStyle(color: isAdmin ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(u['full_name'] ?? '', style: const TextStyle(fontSize: 14))),
            if (isAdmin) const Icon(Icons.shield, size: 14, color: AppColors.warning),
          ],
        ),
        subtitle: Text('${u['phone_primary'] ?? ''} • ${u['cadre_code'] ?? ''}', style: const TextStyle(fontSize: 12)),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('Angalia')),
            const PopupMenuItem(value: 'password', child: Text('Angalia Nywila')),
            const PopupMenuItem(value: 'contact', child: Text('Badilisha Mawasiliano')),
            if (isAdmin)
              const PopupMenuItem(value: 'revoke', child: Text('Ondoa Admin')),
            if (!isAdmin)
              const PopupMenuItem(value: 'grant', child: Text('Weka Admin')),
            const PopupMenuItem(value: 'delete', child: Text('Futa', style: TextStyle(color: AppColors.error))),
          ],
          onSelected: (v) => _handleAction(v, u),
        ),
      ),
    );
  }

  Future<void> _handleAction(String action, Map<String, dynamic> u) async {
    switch (action) {
      case 'revoke':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ondoa Admin?'),
            content: Text('Ondoa hadhi ya admin kwa ${u['full_name']}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ndiyo', style: TextStyle(color: AppColors.error))),
            ],
          ),
        );
        if (ok == true) {
          await ApiService().adminRevoke(u['_id']);
          _load();
        }
        break;
      case 'grant':
        await ApiService().adminGrant(u['_id']);
        _load();
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Futa Mtumiaji?'),
            content: Text('Futa ${u['full_name']}? Kitendo hiki hakiwezi kutenduliwa.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Futa', style: TextStyle(color: AppColors.error))),
            ],
          ),
        );
        if (ok == true) {
          await ApiService().adminDeleteUser(u['_id']);
          _load();
        }
        break;
      case 'view':
        _showUserDetail(u);
        break;
      case 'password':
        _showPassword(u['_id']?.toString() ?? '');
        break;
      case 'contact':
        await ApiService().adminToggleContact(u['_id']?.toString() ?? '');
        _load();
        break;
    }
  }

  Future<void> _showPassword(String userId) async {
    if (userId.isEmpty) return;
    try {
      final res = await ApiService().get('/admin/users/$userId/password');
      final pw = res.data['password'] ?? res.data['plain_password'] ?? '—';
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nywila ya Mtumiaji'),
          content: SelectableText(pw,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pw));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nywila imenakiliwa')));
              },
              child: const Text('Nakili'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Funga')),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hitilafu kupata nywila')));
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pwCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ongeza Mtumiaji'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Jina Kamili')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Simu'), keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            TextField(controller: pwCtrl, decoration: const InputDecoration(labelText: 'Nywila'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ghairi')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
              try {
                await ApiService().adminCreateUser({
                  'full_name': nameCtrl.text.trim(),
                  'phone_primary': phoneCtrl.text.trim(),
                  if (pwCtrl.text.isNotEmpty) 'password': pwCtrl.text,
                });
                Navigator.pop(ctx);
                _load();
              } catch (_) {}
            },
            child: const Text('Ongeza'),
          ),
        ],
      ),
    );
  }

  void _showUserDetail(Map<String, dynamic> u) {
    final st = u['current_station'] ?? {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(u['full_name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            _row('Namba ya Simu', u['phone_primary'] ?? '—'),
            _row('Kada', u['cadre_code'] ?? '—'),
            _row('Idara', u['category'] ?? '—'),
            _row('Mkoa', st['region_name'] ?? '—'),
            _row('Wilaya', st['district_name'] ?? '—'),
            _row('Kituo', st['facility_name'] ?? '—'),
            _row('Admin', (u['is_admin'] ?? false) ? 'Ndiyo' : 'Hapana'),
            _row('Imelipa', (u['is_verified'] ?? false) ? 'Ndiyo' : 'Hapana'),
            _row('Mikoa Unayotaka', (u['desired_destinations'] ?? []).isNotEmpty
                ? (u['desired_destinations'] as List).map((d) => d['region_name'] ?? d).join(', ')
                : '—'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
