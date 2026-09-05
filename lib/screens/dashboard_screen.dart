/// Main dashboard — board cards from /matches/board with real-time updates.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _candidates = [];
  bool _loading = true;
  String _scope = 'incoming';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBoard();
    _setupRealtime();
  }

  Future<void> _loadBoard() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getDashboard(scope: _scope);
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _candidates = data['candidates'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _setupRealtime() {
    final ws = WebSocketService();
    ws.on('match.found', (_) => _loadBoard());
    ws.on('user.changed', (_) => _loadBoard());
    ws.on('user.registered', (_) => _loadBoard());
    ws.on('user.removed', (_) => _loadBoard());
    ws.on('user.verified', (_) => _loadBoard());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kubadilishana'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scope toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'incoming', label: Text('Wanaokuja')),
                ButtonSegment(value: 'all', label: Text('Wote')),
              ],
              selected: {_scope},
              onSelectionChanged: (s) {
                setState(() => _scope = s.first);
                _loadBoard();
              },
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _candidates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: AppColors.textLight),
                            const SizedBox(height: 16),
                            Text(
                              auth.isVerified
                                  ? 'Hakuna watu kwa sasa'
                                  : 'Lipia TZS 2,000 kuona namba za wasioaji',
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            if (!auth.isVerified) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                    context, '/donate'),
                                icon: const Icon(Icons.payment),
                                label: const Text('Lipia Sasa'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBoard,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _candidates.length,
                          itemBuilder: (context, i) {
                            final card = _candidates[i];
                            return _BoardCard(
                              card: card,
                              isVerified: auth.isVerified,
                              onTap: () => _showCardDetail(card),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          switch (i) {
            case 0:
              break;
            case 1:
              Navigator.pushNamed(context, '/donate');
              break;
            case 2:
              Navigator.pushNamed(context, '/feedback');
              break;
            case 3:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Nyumbani'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payment), label: 'Michango'),
          BottomNavigationBarItem(
              icon: Icon(Icons.message), label: 'Maoni'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Wasifu'),
        ],
      ),
    );
  }

  void _showCardDetail(dynamic card) {
    final contactEnabled = card['contact_enabled'] ?? false;
    final isVerified = card['is_verified'] ?? false;
    final auth = context.read<AuthProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                card['full_name'] ?? 'Mtumiaji',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              if (isVerified)
                const Text('✓ Amethibitishwa',
                    style:
                        TextStyle(color: AppColors.success, fontSize: 12)),
              const SizedBox(height: 8),
              _detailRow(Icons.badge,
                  card['cadre_display'] ?? card['cadre_code'] ?? ''),
              _detailRow(
                  Icons.location_on,
                  card['current_station']?['region_name'] ?? ''),
              _detailRow(
                  Icons.map, card['current_station']?['district_name'] ?? ''),
              _detailRow(
                  Icons.business,
                  card['current_station']?['facility_name'] ?? ''),
              const Divider(height: 24),

              // Contact buttons — only if user isVerified and contactEnabled
              if (auth.isVerified && contactEnabled && card['phone_primary'] != null) ...[
                _actionButton(
                  'Piga Simu',
                  Icons.phone,
                  Colors.green,
                  () => launchUrl(
                      Uri.parse('tel:${card['phone_primary']}')),
                ),
                const SizedBox(height: 8),
                _actionButton(
                  'SMS',
                  Icons.sms,
                  Colors.blue,
                  () => launchUrl(
                      Uri.parse('sms:${card['phone_primary']}')),
                ),
                const SizedBox(height: 8),
                _actionButton(
                  'WhatsApp',
                  Icons.chat,
                  const Color(0xFF25D366),
                  () => launchUrl(Uri.parse(
                      'https://wa.me/${card['phone_primary']}')),
                ),
              ] else if (!auth.isVerified) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: AppColors.warning, size: 16),
                      SizedBox(width: 8),
                      Text('Lipia kuona namba za mawasiliano',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.warning)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final dynamic card;
  final bool isVerified;
  final VoidCallback onTap;

  const _BoardCard({
    required this.card,
    required this.isVerified,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final station = card['current_station'] ?? {};
    final name = card['full_name'] ?? 'Mtumiaji';
    final cadre = card['cadre_display'] ?? card['cadre_code'] ?? '';
    final region = station['region_name'] ?? '';
    final phone = card['phone_primary'] ?? '';
    final online = card['online'] ?? false;
    final contactEnabled = card['contact_enabled'] ?? false;
    final initials =
        name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      initials,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ),
                  if (online)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('$cadre • $region',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (isVerified && contactEnabled && phone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone,
                      size: 20, color: Colors.green),
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                )
              else if (!isVerified)
                const Icon(Icons.lock_outline,
                    size: 18, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
