/// User profile public view — shows identity, station, destinations, subjects.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/safe_cast.dart';
import '../widgets/app_toast.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kBlue200 = Color(0xFFBFDBFE);

// ── DARK MODE variants ──
const _kGrey900D = Color(0xFFE7ECF8);
const _kGrey700D = Color(0xFFB4BFD6);
const _kGrey500D = Color(0xFF9AA8C7);
const _kGrey400D = Color(0xFF8B99B4);
const _kGrey200D = Color(0xFF2A3240);
const _kGrey100D = Color(0xFF18202F);
const _kBlueBgD  = Color(0xFF0F172A);
const _kBlue50D  = Color(0xFF1C2A44);
// ── LIGHT consts (zimerefutwa hapa — LESO ziwe existed baada ya script ya awali) ─◆
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);
Color _kOf(BuildContext c, Color light, Color dark) =>
    Theme.of(c).brightness == Brightness.dark ? dark : light;
Color _kGrey900Of(BuildContext c) => _kOf(c, _kGrey900, _kGrey900D);
Color _kGrey700Of(BuildContext c) => _kOf(c, _kGrey700, _kGrey700D);
Color _kGrey500Of(BuildContext c) => _kOf(c, _kGrey500, _kGrey500D);
Color _kGrey400Of(BuildContext c) => _kOf(c, _kGrey400, _kGrey400D);
Color _kGrey200Of(BuildContext c) => _kOf(c, _kGrey200, _kGrey200D);
Color _kGrey100Of(BuildContext c) => _kOf(c, _kGrey100, _kGrey100D);
Color _kBgOf(BuildContext c)      => _kOf(c, Colors.white, _kBlueBgD);
Color _kBlue50Of(BuildContext c)  => _kOf(c, _kBlue50, _kBlue50D);
const _kGreen50 = Color(0xFFF0FDF4);
const _kGreen200 = Color(0xFFBBF7D0);
const _kGreenDk = Color(0xFF16A34A);

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

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
      final res = await ApiService().get('/users/${widget.userId}');
      setState(() {
        _user = asMap(res.data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['full_name']?.toString() ?? 'Mtumiaji';

    return Scaffold(
      backgroundColor: _kBgOf(context),
      body: Column(children: [
        Container(
          color: _kBgOf(context),
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _kGrey100Of(context), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kGrey700Of(context))),
            ),
            SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50Of(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withValues(alpha: 0.2))),
              child: Icon(Icons.person_outline_rounded, size: 20, color: _kBlue)),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_loading ? 'Wasifu' : name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900Of(context))),
              Text('Taarifa za mtumiaji',
                  style: TextStyle(fontSize: 12, color: _kGrey500Of(context))),
            ])),
          ]),
        ),
        Container(height: 1, color: _kGrey200Of(context)),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kBlue))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(16)),
                          child: const Center(child: Icon(Icons.error_outline, size: 26, color: Color(0xFFDC2626))),
                        ),
                        SizedBox(height: 14),
                        Text('Hitilafu ya kupakia wasifu',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700Of(context))),
                        SizedBox(height: 4),
                        Text(_error!,
                            style: TextStyle(fontSize: 11, color: _kGrey400Of(context)),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Jaribu Tena'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue, foregroundColor: Colors.white,
                            minimumSize: const Size(140, 44),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                      ],
                    ),
                  )
                : _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    final u = _user!;
    final fullName = u['full_name']?.toString() ?? 'Mtumiaji';
    final phone = u['phone_primary']?.toString() ?? '';
    final cadreDisplay = u['cadre_display']?.toString() ?? '';
    final cadreCode = u['cadre_code']?.toString() ?? '';
    final category = u['category']?.toString() ?? '';
    final isVerified = u['is_verified'] == true;
    final online = u['online'] == true;
    final station = u['current_station'] as Map<String, dynamic>? ?? {};
    final destinations =
        (u['desired_destinations'] as List<dynamic>?) ?? [];
    final subjects = (u['subjects'] as List<dynamic>?) ?? [];

    final initials = fullName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + badges
          Center(
            child: Column(
              children: [
                Stack(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kBlue50Of(context),
                      border: Border.all(color: _kBlue200, width: 2)),
                    child: Center(child: Text(initials,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _kBlue))),
                  ),
                  if (online) Positioned(right: 2, bottom: 2,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: _kGreenDk, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)))),
                ]),
                SizedBox(height: 12),
                Text(fullName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900Of(context))),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (isVerified) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kGreen50, borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kGreen200)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified_rounded, size: 12, color: _kGreenDk),
                      const SizedBox(width: 4),
                      const Text('Amethibitishwa',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGreenDk)),
                    ]),
                  ),
                  if (isVerified && online) const SizedBox(width: 6),
                  if (online) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kGreen50, borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kGreen200)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6,
                        decoration: const BoxDecoration(color: _kGreenDk, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('Mtandaoni',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGreenDk)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Identity card
          _SectionCard(
            title: 'Maelezo ya Mtumiaji',
            icon: Icons.badge_outlined,
            children: [
              _InfoRow(label: 'Jina', value: fullName),
              if (cadreDisplay.isNotEmpty)
                _InfoRow(label: 'Cheo', value: cadreDisplay),
              if (cadreCode.isNotEmpty && cadreCode != cadreDisplay)
                _InfoRow(label: 'Namba ya Cheo', value: cadreCode),
              if (category.isNotEmpty)
                _InfoRow(label: 'Sekta', value: category),
              if (phone.isNotEmpty)
                _InfoRow(label: 'Simu', value: phone),
            ],
          ),
          const SizedBox(height: 12),

          // Station card
          _SectionCard(
            title: 'Kituo cha Sasa',
            icon: Icons.location_on_outlined,
            children: [
              if ((station['region_name']?.toString() ?? '').isNotEmpty)
                _InfoRow(
                    label: 'Mkoa',
                    value: station['region_name'].toString()),
              if ((station['district_name']?.toString() ?? '').isNotEmpty)
                _InfoRow(
                    label: 'Wilaya',
                    value: station['district_name'].toString()),
              if ((station['facility_name']?.toString() ?? '').isNotEmpty)
                _InfoRow(
                    label: 'Kituo',
                    value: station['facility_name'].toString()),
              if (station.isEmpty ||
                  (station['region_name'] == null &&
                      station['district_name'] == null))
                Text('Hakuna taarifa za kituo',
                    style: TextStyle(color: _kGrey400Of(context), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),

          // Desired destinations card
          _SectionCard(
            title: 'Maeneo Yanayotakiwa',
            icon: Icons.map_outlined,
            children: [
              if (destinations.isEmpty)
                Text('Hakuna maeneo yaliyochaguliwa',
                    style: TextStyle(color: _kGrey400Of(context), fontSize: 13))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: destinations.map((d) {
                    final regionName = d is Map
                        ? (d['region_name']?.toString() ?? '')
                        : d.toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kBlue50Of(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _kBlue200)),
                      child: Text(regionName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue)),
                    );
                  }).toList(),
                ),
            ],
          ),

          // Subjects card (only if non-empty)
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Masomo',
              icon: Icons.school_outlined,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: subjects.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kGrey100Of(context),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kGrey200Of(context))),
                    child: Text(s.toString(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kGrey700Of(context))),
                  )).toList(),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Shared card / row widgets ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGrey200Of(context)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _kBlue50Of(context), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Icon(icon, size: 15, color: _kBlue)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _kGrey900Of(context))),
          ),
        ]),
        Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 1, color: _kGrey200Of(context)),
        ...children,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    // Flexible lebo + Expanded thamani: kwenye simu ndogo lebo inapungua
    // (ellipsis) badala ya Row kubeyuka nje ya kadi.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: _kGrey400Of(context), fontWeight: FontWeight.w500)),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13, color: _kGrey700Of(context), fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
