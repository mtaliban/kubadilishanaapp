/// Admin data page — manage regions, districts, facilities, cadres, subjects.
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminDataPage extends StatefulWidget {
  const AdminDataPage({super.key});
  @override
  State<AdminDataPage> createState() => _AdminDataPageState();
}

class _AdminDataPageState extends State<AdminDataPage> {
  String _section = 'regions';
  List<dynamic> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      Response res;
      switch (_section) {
        case 'regions':
          res = await ApiService().getRegions();
          break;
        case 'cadres':
          res = await ApiService().getCadres();
          break;
        case 'subjects':
          res = await ApiService().getSubjects();
          break;
        case 'departments':
          res = await ApiService().getDepartments();
          break;
        default:
          res = await ApiService().getRegions();
      }
      setState(() {
        _data = res.data is List ? res.data : (res.data['data'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Whether this section uses both name + code fields
  bool get _hasCode => _section == 'cadres' || _section == 'subjects';

  String _itemId(dynamic item) =>
      (item['_id'] ?? item['id'] ?? '').toString();

  // ── Add dialog ──────────────────────────────────────────────────────────────
  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ongeza ${_sectionLabel()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Jina'),
            ),
            if (_hasCode) ...[
              const SizedBox(height: 8),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Msimbo'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ghairi'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _createItem(name, codeCtrl.text.trim());
            },
            child: const Text('Hifadhi'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    codeCtrl.dispose();
  }

  Future<void> _createItem(String name, String code) async {
    try {
      final body = <String, dynamic>{'name': name};
      if (_hasCode && code.isNotEmpty) body['code'] = code;
      await ApiService().post('/admin/data/$_section', data: body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Kimeongezwa!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hitilafu: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  // ── Edit dialog ─────────────────────────────────────────────────────────────
  Future<void> _showEditDialog(dynamic item) async {
    final nameCtrl =
        TextEditingController(text: (item['name'] ?? '').toString());
    final codeCtrl =
        TextEditingController(text: (item['code'] ?? '').toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hariri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Jina'),
            ),
            if (_hasCode) ...[
              const SizedBox(height: 8),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Msimbo'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ghairi'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _editItem(item, name, codeCtrl.text.trim());
            },
            child: const Text('Hifadhi'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    codeCtrl.dispose();
  }

  Future<void> _editItem(dynamic item, String name, String code) async {
    final id = _itemId(item);
    if (id.isEmpty) return;
    try {
      final body = <String, dynamic>{'name': name};
      if (_hasCode && code.isNotEmpty) body['code'] = code;
      await ApiService()
          .patch('/admin/data/$_section/$id', data: body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Imesasishwa!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hitilafu: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(dynamic item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thibitisha Kufuta'),
        content: Text(
            'Una uhakika wa kufuta "${item['name'] ?? ''}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hapana'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Futa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteItem(item);
  }

  Future<void> _deleteItem(dynamic item) async {
    final id = _itemId(item);
    if (id.isEmpty) return;
    try {
      await ApiService().delete('/admin/data/$_section/$id');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Imefutwa!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hitilafu: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Section tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _tab('regions', 'Mikoa'),
                  _tab('cadres', 'Kada'),
                  _tab('subjects', 'Masomo'),
                  _tab('departments', 'Idara'),
                ],
              ),
            ),
            // Data count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Chip(
                      label: Text('${_data.length} vitu',
                          style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
            // Data list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: _data.length,
                        itemBuilder: (context, i) {
                          final item = _data[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: Icon(_iconForSection(), size: 20),
                              title: Text(
                                  item['name'] ?? item['code'] ?? '',
                                  style:
                                      const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                  item['code'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    size: 18),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditDialog(item);
                                  } else if (value == 'delete') {
                                    _confirmDelete(item);
                                  }
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 16),
                                        SizedBox(width: 8),
                                        Text('Hariri'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 16,
                                            color: AppColors.error),
                                        SizedBox(width: 8),
                                        Text('Futa',
                                            style: TextStyle(
                                                color: AppColors.error)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),

        // FAB
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showAddDialog,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _tab(String section, String label) {
    final active = _section == section;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label:
            Text(label, style: const TextStyle(fontSize: 12)),
        selected: active,
        onSelected: (_) {
          setState(() => _section = section);
          _load();
        },
        selectedColor: AppColors.primary,
        labelStyle:
            TextStyle(color: active ? Colors.white : null),
      ),
    );
  }

  IconData _iconForSection() {
    switch (_section) {
      case 'regions':
        return Icons.location_on;
      case 'cadres':
        return Icons.badge;
      case 'subjects':
        return Icons.book;
      case 'departments':
        return Icons.school;
      default:
        return Icons.data_object;
    }
  }

  String _sectionLabel() {
    switch (_section) {
      case 'regions':
        return 'Mkoa';
      case 'cadres':
        return 'Kada';
      case 'subjects':
        return 'Somo';
      case 'departments':
        return 'Idara';
      default:
        return 'Kipengele';
    }
  }
}
