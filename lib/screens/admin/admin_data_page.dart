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
        case 'regions': res = await ApiService().getRegions(); break;
        case 'cadres': res = await ApiService().getCadres(); break;
        case 'subjects': res = await ApiService().getSubjects(); break;
        case 'departments': res = await ApiService().getDepartments(); break;
        default: res = await ApiService().getRegions();
      }
      setState(() {
        _data = res.data is List ? res.data : (res.data['data'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Chip(label: Text('${_data.length} vitu', style: const TextStyle(fontSize: 12))),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _data.length,
                    itemBuilder: (context, i) {
                      final item = _data[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Icon(_iconForSection(), size: 20),
                          title: Text(item['name'] ?? item['code'] ?? '', style: const TextStyle(fontSize: 14)),
                          subtitle: Text(item['code'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ),
                      );
                    },
                  ),
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
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: active,
        onSelected: (_) {
          setState(() => _section = section);
          _load();
        },
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: active ? Colors.white : null),
      ),
    );
  }

  IconData _iconForSection() {
    switch (_section) {
      case 'regions': return Icons.location_on;
      case 'cadres': return Icons.badge;
      case 'subjects': return Icons.book;
      case 'departments': return Icons.school;
      default: return Icons.data_object;
    }
  }
}
