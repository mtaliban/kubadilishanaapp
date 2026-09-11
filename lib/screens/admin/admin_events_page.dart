// Admin events page — system event log with filtering and pagination.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

// ── Local colour aliases ───────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey700 = Color(0xFF374151);
const _kGrey900 = Color(0xFF111827);

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});
  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  List<dynamic> _events = [];
  Map<String, dynamic> _dailyStats = {};
  bool _loading = true;
  String _filter = '';
  int _page = 1;
  int _total = 0;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final skip = (_page - 1) * _pageSize;
    try {
      final res = await ApiService().adminEvents(
        eventType: _filter.isNotEmpty ? _filter : null,
        limit: _pageSize,
        skip: skip,
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _events = data['events'] ?? [];
        _total = data['total'] ?? 0;
        _dailyStats = data['stats'] as Map<String, dynamic>? ?? {};
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_total / _pageSize).ceil().clamp(1, 9999);

    return Column(
      children: [
        // ── PAGE HEADER ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Icon(Icons.list_alt_outlined, size: 20, color: _kBlue)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Matukio${_total > 0 ? " ($_total)" : ""}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: _kGrey900),
                ),
                const Text('Kumbukumbu ya matukio ya mfumo',
                    style: TextStyle(fontSize: 12, color: _kGrey500)),
              ]),
            ),
            // Refresh button
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kGrey200)),
                child: const Center(
                    child: Icon(Icons.refresh_rounded, size: 18, color: _kGrey700)),
              ),
            ),
          ]),
        ),

        // ── Daily stats cards ──
        if (_dailyStats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: _StatCard(
                  label: 'Wapya Leo',
                  value: '${_dailyStats['users_today'] ?? 0}',
                  icon: Icons.person_add_outlined,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Jana',
                  value: '${_dailyStats['users_yesterday'] ?? 0}',
                  icon: Icons.history,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Views Leo',
                  value: '${_dailyStats['views_today'] ?? 0}',
                  icon: Icons.visibility_outlined,
                  color: AppColors.warning,
                ),
              ),
            ]),
          ),
        ],

        // ── Filter chips ──
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _FilterChip(label: 'Zote',            filter: '',                   current: _filter, onTap: _setFilter),
              const SizedBox(width: 6),
              _FilterChip(label: 'Usajili',          filter: 'user.registered',    current: _filter, onTap: _setFilter),
              const SizedBox(width: 6),
              _FilterChip(label: 'Mikataba',         filter: 'match.found',        current: _filter, onTap: _setFilter),
              const SizedBox(width: 6),
              _FilterChip(label: 'Malipo',           filter: 'payment.submitted',  current: _filter, onTap: _setFilter),
              const SizedBox(width: 6),
              _FilterChip(label: 'Amethibitishwa',  filter: 'user.verified',      current: _filter, onTap: _setFilter),
              const SizedBox(width: 6),
              _FilterChip(label: 'Simu',             filter: 'call.initiated',     current: _filter, onTap: _setFilter),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // ── Total count row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _kBlue50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE))),
              child: Text(
                'Jumla: $_total matukio',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),

        // ── Events list ──
        Expanded(
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: _kBlue),
                  ))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kBlue,
                  child: _events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                    color: _kGrey100,
                                    borderRadius: BorderRadius.circular(32)),
                                child: const Icon(Icons.history_outlined,
                                    size: 32, color: _kGrey400),
                              ),
                              const SizedBox(height: 12),
                              const Text('Hakuna matukio',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _kGrey500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                          itemCount: _events.length,
                          itemBuilder: (context, i) =>
                              _EventCard(event: _events[i]),
                        ),
                ),
        ),

        // ── Pagination ──
        if (_total > _pageSize)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _kGrey200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavBtn(
                  icon: Icons.chevron_left,
                  enabled: _page > 1,
                  onTap: () {
                    setState(() => _page--);
                    _load();
                  },
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: _kBlue50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE))),
                  child: Text(
                    '$_page / $totalPages',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: _kBlue),
                  ),
                ),
                const SizedBox(width: 12),
                _NavBtn(
                  icon: Icons.chevron_right,
                  enabled: _page * _pageSize < _total,
                  onTap: () {
                    setState(() => _page++);
                    _load();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _setFilter(String f) {
    if (_filter == f) return;
    setState(() {
      _filter = f;
      _page = 1;
    });
    _load();
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: _kGrey500),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final String filter;
  final String current;
  final void Function(String) onTap;

  const _FilterChip({
    required this.label,
    required this.filter,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == filter;
    return GestureDetector(
      onTap: () => onTap(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _kBlue : _kGrey200),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: _kBlue.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _kGrey500)),
        ),
      ),
    );
  }
}

// ── Nav button ─────────────────────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? _kGrey200 : _kGrey100),
        ),
        child: Center(
          child: Icon(icon, size: 20,
              color: enabled ? _kGrey700 : _kGrey400),
        ),
      ),
    );
  }
}

// ── Event card ─────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final dynamic event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final e    = event as Map<String, dynamic>;
    final type = (e['event_type'] ?? e['type'] ?? '').toString();
    final userName = (e['user_name'] ?? e['name'] ?? '').toString();
    final desc = (e['message'] ?? e['description'] ?? userName).toString();
    final raw  = (e['occurred_at'] ?? e['created_at'] ?? '').toString();
    final time = raw.replaceAll('T', ' ').split('.').first;

    final meta   = _eventMeta(type);
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGrey200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Event type icon ──
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Icon(meta.icon, size: 20, color: meta.color)),
          ),
          const SizedBox(width: 10),

          // ── Content ──
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Type label + user avatar
              Row(children: [
                Expanded(
                  child: Text(
                    _typeLabel(type),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: _kGrey900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (initial.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(
                      child: Text(initial,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: meta.color)),
                    ),
                  ),
                ],
              ]),

              // User name (if distinct from desc)
              if (userName.isNotEmpty && userName != desc) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.person_outline,
                      size: 11, color: _kGrey400),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(userName,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: _kGrey700),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],

              // Description
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12, color: _kGrey500, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],

              // Date + type raw chip
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.access_time_rounded,
                    size: 11, color: _kGrey400),
                const SizedBox(width: 3),
                Text(time,
                    style: const TextStyle(
                        fontSize: 11, color: _kGrey400)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: meta.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    type.isNotEmpty ? type : 'event',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: meta.color,
                        letterSpacing: 0.3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Map event type → human label ────────────────────────────────────────
  String _typeLabel(String type) {
    if (type.contains('registered')) return 'Msajili Mpya';
    if (type.contains('match'))      return 'Mkataba Mpya';
    if (type.contains('payment'))    return 'Malipo';
    if (type.contains('verified'))   return 'Amethibitishwa';
    if (type.contains('call'))       return 'Simu';
    if (type.contains('message'))    return 'Ujumbe';
    if (type.contains('deleted'))    return 'Imefutwa';
    if (type.contains('admin'))      return 'Hatua ya Admin';
    if (type.contains('updated'))    return 'Imesasishwa';
    if (type.contains('login'))      return 'Kuingia';
    if (type.contains('logout'))     return 'Kutoka';
    if (type.contains('password'))   return 'Nenosiri';
    if (type.contains('data'))       return 'Data';
    if (type.isEmpty)                return 'Tukio';
    return type;
  }

  // ── Map event type → icon + color ───────────────────────────────────────
  ({IconData icon, Color color}) _eventMeta(String type) {
    if (type.contains('registered')) {
      return (icon: Icons.person_add_outlined, color: AppColors.success);
    }
    if (type.contains('match')) {
      return (icon: Icons.people_outline, color: const Color(0xFF7C3AED));
    }
    if (type.contains('payment')) {
      return (icon: Icons.payment_outlined, color: AppColors.warning);
    }
    if (type.contains('verified')) {
      return (icon: Icons.verified_outlined, color: AppColors.success);
    }
    if (type.contains('call')) {
      return (icon: Icons.phone_outlined, color: const Color(0xFF059669));
    }
    if (type.contains('message')) {
      return (icon: Icons.chat_bubble_outline, color: AppColors.primary);
    }
    if (type.contains('deleted')) {
      return (icon: Icons.delete_outline, color: AppColors.error);
    }
    if (type.contains('admin') || type.contains('updated')) {
      return (icon: Icons.admin_panel_settings_outlined, color: const Color(0xFF0369A1));
    }
    if (type.contains('login')) {
      return (icon: Icons.login_outlined, color: AppColors.primary);
    }
    if (type.contains('logout')) {
      return (icon: Icons.logout_outlined, color: _kGrey500);
    }
    if (type.contains('password')) {
      return (icon: Icons.lock_outline, color: const Color(0xFFC2410C));
    }
    if (type.contains('data')) {
      return (icon: Icons.storage_outlined, color: const Color(0xFF0891B2));
    }
    return (icon: Icons.info_outline, color: AppColors.primary);
  }
}
