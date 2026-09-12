/// Admin CSV export page — trigger exports and download CSV files.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue50    = Color(0xFFEFF6FF);
const _kBlue200   = Color(0xFFBFDBFE);
const _kGrey50    = Color(0xFFF9FAFB);
const _kGrey100   = Color(0xFFF3F4F6);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey700   = Color(0xFF374151);
const _kGrey900   = Color(0xFF111827);
const _kGreenDk   = Color(0xFF16A34A);
const _kGreen50   = Color(0xFFF0FDF4);
const _kGreen200  = Color(0xFFBBF7D0);

class AdminCsvPage extends StatefulWidget {
  const AdminCsvPage({super.key});
  @override
  State<AdminCsvPage> createState() => _AdminCsvPageState();
}

class _AdminCsvPageState extends State<AdminCsvPage> {
  List<dynamic> _files = [];
  bool _loading = true;
  String _exportingType = '';

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
    setState(() => _exportingType = type);
    try {
      await ApiService().post('/admin/csv/export', data: {'type': type});
      await _loadList();
      if (mounted) _showFlash('Export ya "$type" imefanikiwa!', ok: true);
    } catch (e) {
      if (mounted) _showFlash('Hitilafu: $e', ok: false);
    } finally {
      if (mounted) setState(() => _exportingType = '');
    }
  }

  Future<void> _download(String fileName) async {
    _showFlash('CSV inapakuliwa...', ok: true);
    try {
      await ApiService().get('/admin/csv/download/$fileName');
    } catch (_) {}
  }

  String? _flashMsg;
  bool _flashOk = true;

  void _showFlash(String msg, {bool ok = true}) {
    setState(() { _flashMsg = msg; _flashOk = ok; });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flashMsg = null);
    });
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.upload_file_rounded, size: 20, color: _kBlue),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hamisha Data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kGrey900)),
              Text('Pakua data kama faili za CSV',
                style: TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
            GestureDetector(
              onTap: _loadList,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kGrey50, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kGrey200)),
                child: const Center(child: Icon(Icons.refresh_rounded, size: 18, color: _kGrey700)),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: _kGrey100),

        // ── Flash ──
        if (_flashMsg != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _flashOk ? _kGreen50 : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _flashOk ? _kGreen200 : const Color(0xFFFECACA)),
            ),
            child: Row(children: [
              Icon(_flashOk ? Icons.check_circle_outline : Icons.error_outline,
                size: 14, color: _flashOk ? _kGreenDk : const Color(0xFFDC2626)),
              const SizedBox(width: 7),
              Expanded(child: Text(_flashMsg!,
                style: TextStyle(fontSize: 12, color: _flashOk ? _kGreenDk : const Color(0xFFDC2626)))),
            ]),
          ),

        // ── Export buttons ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hamisha', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kGrey700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ExportBtn(label: 'Watumiaji', icon: Icons.people_rounded, type: 'users',
                  busy: _exportingType == 'users', onTap: () => _triggerExport('users')),
                _ExportBtn(label: 'Mikataba', icon: Icons.handshake_rounded, type: 'matches',
                  busy: _exportingType == 'matches', onTap: () => _triggerExport('matches')),
                _ExportBtn(label: 'Malipo', icon: Icons.receipt_long_rounded, type: 'payments',
                  busy: _exportingType == 'payments', onTap: () => _triggerExport('payments')),
                _ExportBtn(label: 'Maoni', icon: Icons.rate_review_rounded, type: 'feedback',
                  busy: _exportingType == 'feedback', onTap: () => _triggerExport('feedback')),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Faili Zilizopo',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kGrey700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kBlue, borderRadius: BorderRadius.circular(999)),
                child: Text('${_files.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 4),

        // ── File list ──
        Expanded(
          child: _loading
              ? const Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)))
              : RefreshIndicator(
                  onRefresh: _loadList,
                  color: _kBlue,
                  child: _files.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.folder_open_rounded, size: 48, color: _kGrey200),
                          const SizedBox(height: 12),
                          const Text('Hakuna faili za CSV bado',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey500)),
                          const SizedBox(height: 4),
                          const Text('Bonyeza kitufe hapo juu kuhamisha data',
                            style: TextStyle(fontSize: 12, color: _kGrey400)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                          itemCount: _files.length,
                          itemBuilder: (context, i) {
                            final file = _files[i];
                            final name = (file['name'] ?? '').toString();
                            final date = (file['created_at'] ?? '').toString().split('T').first;
                            final size = _formatSize(file['size']);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kGrey100),
                                boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
                              ),
                              child: Row(children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: _kGreen50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _kGreen200),
                                  ),
                                  child: const Icon(Icons.insert_drive_file_rounded, size: 20, color: _kGreenDk),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900),
                                    overflow: TextOverflow.ellipsis),
                                  Text('$size  •  $date',
                                    style: const TextStyle(fontSize: 11, color: _kGrey400)),
                                ])),
                                GestureDetector(
                                  onTap: name.isNotEmpty ? () => _download(name) : null,
                                  child: Container(
                                    width: 34, height: 34,
                                    decoration: BoxDecoration(
                                      color: _kBlue50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _kBlue200),
                                    ),
                                    child: const Icon(Icons.download_rounded, size: 17, color: _kBlue),
                                  ),
                                ),
                              ]),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

// ── Export button ──────────────────────────────────────────────────────────
class _ExportBtn extends StatelessWidget {
  final String label, type;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;
  const _ExportBtn({required this.label, required this.icon, required this.type,
    required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: busy ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: busy ? _kBlue50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: busy ? _kBlue200 : _kGrey200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        busy
          ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue))
          : Icon(icon, size: 14, color: _kBlue),
        const SizedBox(width: 7),
        Text(label,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: busy ? _kBlue : _kGrey700,
          )),
      ]),
    ),
  );
}
