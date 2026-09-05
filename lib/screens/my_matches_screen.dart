/// My Matches screen — two tabs: Mikataba Yangu (/matches/me) and Real Matches (/matches/true).
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechi Zangu'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Mikataba Yangu'),
            Tab(text: 'Real Matches'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyMatchesTab(),
          _RealMatchesTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: /matches/me ──────────────────────────────────────────────────────

class _MyMatchesTab extends StatefulWidget {
  const _MyMatchesTab();

  @override
  State<_MyMatchesTab> createState() => _MyMatchesTabState();
}

class _MyMatchesTabState extends State<_MyMatchesTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final res = await ApiService().get('/matches/me');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _matches = data['matches'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Hitilafu: $_error',
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Jaribu Tena')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _matches.isEmpty
          ? _EmptyState(
              icon: Icons.handshake_outlined,
              message: 'Huna mikataba yoyote bado',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _matches.length,
              itemBuilder: (context, i) {
                final m = _matches[i];
                return _MyMatchCard(match: m);
              },
            ),
    );
  }
}

class _MyMatchCard extends StatelessWidget {
  final dynamic match;
  const _MyMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final userA = match['user_a'] as Map<String, dynamic>? ?? {};
    final userB = match['user_b'] as Map<String, dynamic>? ?? {};
    final score = match['score'];
    final matchedAt = match['matched_at']?.toString() ?? '';
    final dateStr =
        matchedAt.contains('T') ? matchedAt.split('T').first : matchedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score badge
            if (score != null)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Alama: $score',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            // User A
            _UserRow(user: userA, label: 'A'),
            const Divider(height: 16),
            // User B
            _UserRow(user: userB, label: 'B'),
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 13, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: /matches/true ────────────────────────────────────────────────────

class _RealMatchesTab extends StatefulWidget {
  const _RealMatchesTab();

  @override
  State<_RealMatchesTab> createState() => _RealMatchesTabState();
}

class _RealMatchesTabState extends State<_RealMatchesTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final res = await ApiService().get('/matches/true');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _matches = data['matches'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Hitilafu: $_error',
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Jaribu Tena')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _matches.isEmpty
          ? _EmptyState(
              icon: Icons.people_outline,
              message: 'Hakuna real matches kwa sasa',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _matches.length,
              itemBuilder: (context, i) {
                final m = _matches[i];
                return _RealMatchCard(match: m);
              },
            ),
    );
  }
}

class _RealMatchCard extends StatelessWidget {
  final dynamic match;
  const _RealMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final userA = match['user_a'] as Map<String, dynamic>? ?? {};
    final userB = match['user_b'] as Map<String, dynamic>? ?? {};
    final score = match['score'];
    final cadreDisplay = match['cadre_display']?.toString() ?? '';
    final commonSubjects =
        (match['common_subjects'] as List<dynamic>?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score + cadre header
            Row(
              children: [
                if (cadreDisplay.isNotEmpty)
                  Expanded(
                    child: Text(
                      cadreDisplay,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 13),
                    ),
                  ),
                if (score != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Alama: $score',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _UserRow(user: userA, label: 'A'),
            const Divider(height: 16),
            _UserRow(user: userB, label: 'B'),
            // Common subjects
            if (commonSubjects.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Masomo ya Pamoja:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: commonSubjects
                    .map((s) => Chip(
                          label: Text(s.toString(),
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.surfaceDark,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ───────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final String label;
  const _UserRow({required this.user, required this.label});

  @override
  Widget build(BuildContext context) {
    final name = user['full_name']?.toString() ?? 'Mtumiaji';
    final cadre =
        user['cadre_display']?.toString() ?? user['cadre_code']?.toString() ?? '';
    final region =
        (user['current_station'] as Map<String, dynamic>?)?['region_name']
                ?.toString() ??
            '';
    final phone = user['phone_primary']?.toString() ?? '';
    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryLight,
          child: Text(initials,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              if (cadre.isNotEmpty || region.isNotEmpty)
                Text(
                  [cadre, region].where((s) => s.isNotEmpty).join(' • '),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              if (phone.isNotEmpty)
                Text(phone,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
            ],
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    // Wrap in a ListView so RefreshIndicator can scroll
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}
