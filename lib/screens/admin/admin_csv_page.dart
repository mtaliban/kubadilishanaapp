/// Admin CSV export page — trigger exports and download CSV files.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminCsvPage extends StatefulWidget {
  const AdminCsvPage({super.key});
  @override
  State<AdminCsvPage> createState() => _AdminCsvPageState();
}

class _AdminCsvPageState extends State<AdminCsvPage> {
  List<dynamic> _files = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/admin/csv/list');
      final data = res.data;
      setState(() {
        _files = (data is Map && data['files'] is List)
            ? data['files'] as List
            : [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _triggerExport(String type) async {
    setState(() => _exporting = true);
    try {
      await ApiService().post('/admin/csv/export', data: {'type': type});
      await _loadList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export ya "$type" imefanikiwa!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hitilafu: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _download(String fileName) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV inapakuliwa...')),
      );
    }
    try {
      await ApiService().get('/admin/csv/download/$fileName');
    } catch (_) {}
  }

  String _formatSize(dynamic bytes) {
    if (bytes == null) return '—';
    final b = (bytes is num) ? bytes.toDouble() : double.tryParse('$bytes') ?? 0;
    final kb = b / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Export buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hamisha Data',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              if (_exporting)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.people, size: 16),
                      label: const Text('Export Watumiaji'),
                      onPressed: () => _triggerExport('users'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.compare_arrows, size: 16),
                      label: const Text('Export Mikataba'),
                      onPressed: () => _triggerExport('matches'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Export Malipo'),
                      onPressed: () => _triggerExport('payments'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.feedback, size: 16),
                      label: const Text('Export Maoni'),
                      onPressed: () => _triggerExport('feedback'),
                    ),
                  ],
                ),
              const Divider(height: 20),
              Text(
                'Faili Zilizopo (${_files.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),

        // File list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadList,
                  child: _files.isEmpty
                      ? const Center(
                          child: Text(
                            'Hakuna faili za CSV bado.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _files.length,
                          itemBuilder: (context, i) {
                            final file = _files[i];
                            final name =
                                (file['name'] ?? '').toString();
                            final date = (file['created_at'] ?? '')
                                .toString()
                                .split('T')
                                .first;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file,
                                    color: AppColors.primary),
                                title: Text(name,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                  '${_formatSize(file['size'])}  •  $date',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.download,
                                      color: AppColors.primary),
                                  tooltip: 'Pakua',
                                  onPressed: name.isNotEmpty
                                      ? () => _download(name)
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
