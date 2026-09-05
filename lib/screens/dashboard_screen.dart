/// Main dashboard — board cards with real-time WebSocket updates.
import 'dart:convert';
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
  List<dynamic> _boardCards = [];
  bool _loading = true;
  String _filterMkoa = '';
  String _filterKada = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBoard();
    _setupRealtime();
  }

  Future<void> _loadBoard() async {
    try {
      final res = await ApiService().getDashboard();
      setState(() {
        _boardCards = res.data is List ? res.data : (res.data['users'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _setupRealtime() {
    final ws = WebSocketService();
    ws.on('match.found', (_) => _loadBoard());
    ws.on('user.changed', (_) => _loadBoard());
    ws.on('user.registered', (_) => _loadBoard());
    ws.on('user.removed', (_) => _loadBoard());
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _boardCards.isEmpty
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
                            fontSize: 16, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      if (!auth.isVerified) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/donate'),
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
                    padding: const EdgeInsets.all(12),
                    itemCount: _boardCards.length,
                    itemBuilder: (context, i) {
                      final card = _boardCards[i];
                      return _BoardCard(
                        card: card,
                        isVerified: auth.isVerified,
                        onTap: () => _showCardDetail(card),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          switch (i) {
            case 0: break; // Dashboard
            case 1: Navigator.pushNamed(context, '/donate'); break;
            case 2: Navigator.pushNamed(context, '/feedback'); break;
            case 3: Navigator.pushNamed(context, '/profile'); break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Nyumbani'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Michango'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Maoni'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Wasifu'),
        ],
      ),
    );
  }

  void _showCardDetail(dynamic card) {
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
              const SizedBox(height: 8),
              _detailRow(Icons.school, card['cadre_code'] ?? ''),
              _detailRow(Icons.location_on,
                  card['current_station']?['region_name'] ?? ''),
              const Divider(height: 24),
              // Action buttons
              if (card['phone_primary'] != null) ...[
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
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

/// Individual board card widget.
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
    final cadre = card['cadre_code'] ?? '';
    final region = station['region_name'] ?? '';
    final phone = card['phone_primary'] ?? '';
    final initials =
        name.split(' ').map((w) => w[0]).take(2).join().toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
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
              const SizedBox(width: 12),
              // Info
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
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // Phone (if verified)
              if (isVerified && phone.isNotEmpty)
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.phone,
                          size: 20, color: Colors.green),
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:$phone')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
