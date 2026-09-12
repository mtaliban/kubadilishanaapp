/// Admin reports page — revenue, user trends, match trends.
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
const _kRed       = Color(0xFFDC2626);
const _kRed50     = Color(0xFFFEF2F2);
const _kAmber50   = Color(0xFFFFFBEB);
const _kAmber200  = Color(0xFFFDE68A);
const _kAmber700  = Color(0xFFB45309);
const _kPurple50  = Color(0xFFF5F3FF);
const _kPurple200 = Color(0xFFDDD6FE);
const _kPurple700 = Color(0xFF6D28D9);

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  Map<String, dynamic> _reports = {};
  bool _loading = true;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/admin/reports', queryParameters: {'days': _days});
      setState(() { _reports = res.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
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
              child: const Icon(Icons.bar_chart_rounded, size: 20, color: _kBlue),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ripoti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kGrey900)),
              Text('Takwimu za mapato, watumiaji na mikataba',
                style: TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
          ]),
        ),
        const Divider(height: 1, color: _kGrey100),

        // ── Period selector ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [7, 30, 90, 365].map((d) {
              final active = _days == d;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () { setState(() => _days = d); _load(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? _kBlue : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: active ? _kBlue : _kGrey200),
                    ),
                    child: Text(
                      '${d}s',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : _kGrey500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Content ──
        Expanded(
          child: _loading
              ? const Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kBlue,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                    children: [
                      // Revenue
                      _ReportCard(
                        title: 'Mapato',
                        icon: Icons.trending_up_rounded,
                        color: _kGreenDk,
                        bg: _kGreen50,
                        border: _kGreen200,
                        rows: [
                          ('Jumla ya Malipo', 'TZS ${_reports['total_revenue'] ?? 0}'),
                          ('Malipo Yaliyokubaliwa', '${_reports['approved_payments'] ?? 0}'),
                          ('Malipo Yakataliwa', '${_reports['rejected_payments'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Users
                      _ReportCard(
                        title: 'Watumiaji',
                        icon: Icons.people_rounded,
                        color: _kBlue,
                        bg: _kBlue50,
                        border: _kBlue200,
                        rows: [
                          ('Watumiaji Wote', '${_reports['total_users'] ?? 0}'),
                          ('Wapya wiki hii', '${_reports['new_users_week'] ?? 0}'),
                          ('Waliolipia', '${_reports['verified_users'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Matches
                      _ReportCard(
                        title: 'Mikataba',
                        icon: Icons.handshake_rounded,
                        color: _kPurple700,
                        bg: _kPurple50,
                        border: _kPurple200,
                        rows: [
                          ('Mikataba Yote', '${_reports['total_matches'] ?? 0}'),
                          ('Wiki hii', '${_reports['matches_week'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Feedback
                      _ReportCard(
                        title: 'Maoni',
                        icon: Icons.rate_review_rounded,
                        color: _kAmber700,
                        bg: _kAmber50,
                        border: _kAmber200,
                        rows: [
                          ('Maoni Yote', '${_reports['total_feedback'] ?? 0}'),
                          ('Malalamiko', '${_reports['total_complaints'] ?? 0}'),
                          ('Mapendekezo', '${_reports['total_suggestions'] ?? 0}'),
                        ],
                      ),

                      // Top regions
                      if (_reports['top_regions'] != null) ...[
                        const SizedBox(height: 20),
                        const Text('Mikoa Inayoongoza',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kGrey700)),
                        const SizedBox(height: 8),
                        ...((_reports['top_regions'] as List?) ?? []).asMap().entries.map((e) {
                          final r = e.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kGrey200),
                              boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
                            ),
                            child: Row(children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: _kBlue50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(child: Text('${e.key + 1}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kBlue))),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.location_on_rounded, size: 14, color: _kGrey400),
                              const SizedBox(width: 4),
                              Expanded(child: Text(r['name'] ?? '',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900))),
                              Text('${r['count'] ?? 0}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kBlue)),
                            ]),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Report card ────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color, bg, border;
  final List<(String, String)> rows;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF3F4F6)),
      boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
      // Rows
      ...rows.asMap().entries.map((e) {
        final (label, value) = e.value;
        final isLast = e.key == rows.length - 1;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Expanded(child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
              Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ]),
          ),
          if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFF3F4F6)),
        ]);
      }),
    ]),
  );
}
