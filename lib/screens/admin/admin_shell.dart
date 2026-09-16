import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'admin_dashboard_page.dart';
import 'admin_users_page.dart';
import 'admin_matches_page.dart';
import 'admin_real_matches_page.dart';
import 'admin_data_page.dart';
import 'admin_announcements_page.dart';
import 'admin_payments_page.dart';
import 'admin_feedback_page.dart';
import 'admin_monitoring_page.dart';
import 'admin_contacts_page.dart';
import 'admin_password_resets_page.dart';
import 'admin_csv_page.dart';

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

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  int _userCount = 0;

  final List<String> _pageTitles = [
    'Admin Panel',
    'Watumiaji',
    'Waliopata Wenzao',
    'Match za Kweli',
    'Data',
    'Matangazo',
    'Malipo',
    'Maoni / Malamiko',
    'Moni',
    'Mawasiliano',
    'Manenosiri',
    'CSV',
  ];

  List<Widget> get _pages => [
    AdminDashboardPage(),
    AdminUsersPage(),
    AdminMatchesPage(),
    AdminRealMatchesPage(),
    AdminDataPage(),
    AdminAnnouncementsPage(),
    AdminPaymentsPage(),
    AdminFeedbackPage(),
    AdminMonitoringPage(),
    AdminContactsPage(),
    AdminPasswordResetsPage(),
    AdminCsvPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final res = await ApiService().adminStats();
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _userCount = (data['users'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
    Navigator.of(context).pop();
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required int index,
    Widget? trailing,
  }) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _selectPage(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _kBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border(left: BorderSide(color: _kBlue, width: 4))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? _kBlue : _kGrey700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? _kBlue : _kGrey700,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kGrey400,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _kBlueBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kBlue,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: _kGrey900),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _pageTitles[_selectedIndex],
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _kGrey900,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: _kGrey700),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: _kGrey700),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kGrey200),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kBlueBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: _kBlue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kubadilishana',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _kGrey900,
                            ),
                          ),
                          Text(
                            'Panel ya Usimamizi',
                            style: TextStyle(
                              fontSize: 12,
                              color: _kGrey500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: _kGrey200),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('MENU KUU'),
                      _drawerItem(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Admin Panel',
                        index: 0,
                      ),
                      _drawerItem(
                        icon: Icons.group_rounded,
                        label: 'Watumiaji',
                        index: 1,
                        trailing: _userCount > 0 ? _countBadge(_userCount) : null,
                      ),
                      _drawerItem(
                        icon: Icons.handshake_rounded,
                        label: 'Waliopata Wenzao',
                        index: 2,
                      ),
                      _drawerItem(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Match za Kweli',
                        index: 3,
                      ),
                      _sectionLabel('MFUMO'),
                      _drawerItem(
                        icon: Icons.storage_rounded,
                        label: 'Data',
                        index: 4,
                      ),
                      _drawerItem(
                        icon: Icons.campaign_rounded,
                        label: 'Matangazo',
                        index: 5,
                      ),
                      _drawerItem(
                        icon: Icons.payments_rounded,
                        label: 'Malipo',
                        index: 6,
                      ),
                      _drawerItem(
                        icon: Icons.rate_review_rounded,
                        label: 'Maoni / Malamiko',
                        index: 7,
                      ),
                      _drawerItem(
                        icon: Icons.monitor_heart_rounded,
                        label: 'Moni',
                        index: 8,
                      ),
                      _drawerItem(
                        icon: Icons.phone_rounded,
                        label: 'Mawasiliano',
                        index: 9,
                      ),
                      _drawerItem(
                        icon: Icons.key_rounded,
                        label: 'Manenosiri',
                        index: 10,
                      ),
                      _drawerItem(
                        icon: Icons.table_chart_rounded,
                        label: 'CSV',
                        index: 11,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: _kGrey200),
              GestureDetector(
                onTap: _logout,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _kRedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: _kRed),
                      SizedBox(width: 12),
                      Text(
                        'Ondoka',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
    );
  }
}
