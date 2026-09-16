import 'package:flutter/material.dart';
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

class AdminCsvPage extends StatefulWidget {
  const AdminCsvPage({super.key});

  @override
  State<AdminCsvPage> createState() => _AdminCsvPageState();
}

class _AdminCsvPageState extends State<AdminCsvPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _files = [];
  final Set<String> _exportingTypes = {};
  final Set<String> _downloadingNames = {};

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
      final res = await ApiService().adminListCsvs();
      if (!mounted) return;
      final raw = res.data;
      List<dynamic> items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        items = (raw['files'] ?? raw['data'] ?? raw['csvs'] ?? []) as List<dynamic>;
      }
      setState(() {
        _files = items;
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

  Future<void> _export(String type) async {
    setState(() => _exportingTypes.add(type));
    try {
      await ApiService().adminExportCsv(type);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV ya $type imetengenezwa'), backgroundColor: _kGreen),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed),
      );
    } finally {
      if (mounted) setState(() => _exportingTypes.remove(type));
    }
  }

  Future<void> _download(String name) async {
    setState(() => _downloadingNames.add(name));
    try {
      await ApiService().adminDownloadCsv(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imepakiwa'), backgroundColor: _kGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed),
      );
    } finally {
      if (mounted) setState(() => _downloadingNames.remove(name));
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return raw.toString();
      final local = dt.toLocal();
      return '${local.day}/${local.month}/${local.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _exportBtn(String label, String type) {
    final isExporting = _exportingTypes.contains(type);
    return Expanded(
      child: GestureDetector(
        onTap: isExporting ? null : () => _export(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isExporting ? _kGrey100 : _kBlueBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isExporting ? _kGrey200 : _kBlue.withOpacity(0.3)),
          ),
          child: isExporting
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
                  ),
                )
              : Column(
                  children: [
                    const Icon(Icons.download_rounded, size: 20, color: _kBlue),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue), textAlign: TextAlign.center),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kBlueBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: _kBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CSV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                      Text('Hamisha data kwa CSV', style: TextStyle(fontSize: 13, color: _kGrey500)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kBlueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 18, color: _kBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Hamisha Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _exportBtn('Watumiaji', 'users'),
                  const SizedBox(width: 10),
                  _exportBtn('Malipo', 'payments'),
                  const SizedBox(width: 10),
                  _exportBtn('Mechi', 'matches'),
                ],
              ),
            ],
          ),
        ),
        Container(height: 1, color: _kGrey200),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: _kGrey700), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
                            child: const Text('Jaribu Tena'),
                          ),
                        ],
                      ),
                    )
                  : _files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 56, color: _kGrey400),
                              const SizedBox(height: 12),
                              const Text('Hakuna faili za CSV', style: TextStyle(fontSize: 16, color: _kGrey500, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              const Text('Bonyeza kitufe hapo juu kuhamisha data', style: TextStyle(fontSize: 13, color: _kGrey400)),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Text(
                                'Faili Zilizopo (${_files.length})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey700),
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _files.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final file = _files[i] as Map<String, dynamic>;
                                  final filename = file['name'] as String? ?? file['filename'] as String? ?? 'file_$i.csv';
                                  final createdAt = file['created_at'] ?? file['createdAt'] ?? file['date'];
                                  final isDownloading = _downloadingNames.contains(filename);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _kGrey200),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _kGreenBg,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.insert_drive_file_rounded, color: _kGreen, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(filename, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900)),
                                              Text(_formatDate(createdAt), style: const TextStyle(fontSize: 11, color: _kGrey400)),
                                            ],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: isDownloading ? null : () => _download(filename),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: isDownloading ? _kGrey100 : _kBlueBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: isDownloading
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
                                                  )
                                                : const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.download_rounded, size: 14, color: _kBlue),
                                                      SizedBox(width: 4),
                                                      Text('Pakua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kBlue)),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
        ),
      ],
    );
  }
}
