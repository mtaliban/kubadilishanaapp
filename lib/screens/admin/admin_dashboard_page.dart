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
const _kGrey500 = Color(0xFF6B7280);

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminStats();
      if (!mounted) return;
      setState(() {
        _stats = (res.data as Map<String, dynamic>? ?? {});
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _kBlueBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium, color: _kBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Panel',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                        Text('Muhtasari wa mfumo',
                            style: TextStyle(fontSize: 12, color: _kGrey500)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _kBlue)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: _kRed, size: 48),
                      const SizedBox(height: 12),
                      Text('Kosa la kupakia data', style: TextStyle(color: _kGrey500)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Jaribu tena'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue, foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  delegate: SliverChildListDelegate([
                    _StatCard(
                      icon: Icons.group_outlined,
                      label: 'Watumiaji',
                      value: '${_stats['users'] ?? 0}',
                      color: _kBlue,
                      bgColor: _kBlueBg,
                    ),
                    _StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Wanaolipa',
                      value: '${_stats['paid'] ?? 0}',
                      color: _kGreen,
                      bgColor: _kGreenBg,
                    ),
                    _StatCard(
                      icon: Icons.cancel_outlined,
                      label: 'Hawajalipia',
                      value: '${_stats['unpaid'] ?? 0}',
                      color: _kRed,
                      bgColor: _kRedBg,
                    ),
                    _StatCard(
                      icon: Icons.notifications_outlined,
                      label: 'Matangazo',
                      value: '${_stats['announcements'] ?? 0}',
                      color: _kAmber,
                      bgColor: _kAmberBg,
                    ),
                    _StatCard(
                      icon: Icons.receipt_long_outlined,
                      label: 'Malipo',
                      value: '${_stats['payments'] ?? 0}',
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF3E8FF),
                    ),
                    _StatCard(
                      icon: Icons.swap_horiz,
                      label: 'Mechi',
                      value: '${_stats['matches'] ?? 0}',
                      color: const Color(0xFF0D9488),
                      bgColor: const Color(0xFFCCFBF1),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(value,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
