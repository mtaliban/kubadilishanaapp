import 'dart:async';
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
import 'admin_contacts_page.dart';
import 'admin_feedback_page.dart';

const _kBlue   = Color(0xFF1E40AF);
const _kBlueBg = Color(0xFFEFF6FF);
const _kRed    = Color(0xFFDC2626);
const _kRedBg  = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey400 = Color(0xFF9CA3AF);

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _idx = 0;
  int _userCount = 0;
  bool _sw = true;

  final _pages = const [
    AdminDashboardPage(),
    AdminUsersPage(),
    AdminMatchesPage(),
    AdminRealMatchesPage(),
    AdminDataPage(),
    AdminAnnouncementsPage(),
    AdminPaymentsPage(),
    AdminContactsPage(),
    AdminFeedbackPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      final d = r.data as Map<String, dynamic>? ?? {};
      setState(() => _userCount = (d['users'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  void _go(int i) {
    setState(() => _idx = i);
    Navigator.pop(context);
  }

  Future<void> _logout() async {
    Navigator.pop(context);
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = auth.user?.fullName ?? 'Admin';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                decoration: BoxDecoration(
                  color: _kGrey100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_rounded, color: _kGrey900, size: 20),
              ),
            ),
          ),
        ),
        actions: [
          // User avatar button — plain icon kama picha
          GestureDetector(
            onTap: () => _showUserMenu(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.person_rounded, color: _kBlue, size: 26),
            ),
          ),
          const SizedBox(width: 8),
          // SW/EN language toggle pill
          GestureDetector(
            onTap: () => setState(() => _sw = !_sw),
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: _kBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _langChip('SW', _sw),
                  _langChip('EN', !_sw),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kGrey200, height: 1),
        ),
      ),
      drawer: _buildDrawer(initial, name),
      body: IndexedStack(index: _idx, children: _pages),
    );
  }

  Widget _langChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? _kBlue : Colors.white,
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    final RenderBox btn = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        btn.localToGlobal(Offset.zero, ancestor: overlay),
        btn.localToGlobal(btn.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<String>(
      context: context,
      position: pos,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      items: [
        PopupMenuItem(
          value: 'profile',
          child: Row(children: const [
            Icon(Icons.person_outline_rounded, size: 18, color: _kGrey700),
            SizedBox(width: 10),
            Text('Wasifu', style: TextStyle(fontSize: 14, color: _kGrey900)),
          ]),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: const [
            Icon(Icons.logout_rounded, size: 18, color: _kRed),
            SizedBox(width: 10),
            Text('Toka', style: TextStyle(fontSize: 14, color: _kRed, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    ).then((v) {
      if (!mounted) return;
      if (v == 'logout') _logout();
      if (v == 'profile') Navigator.pushNamed(context, '/profile');
    });
  }

  Widget _buildDrawer(String initial, String name) {
    return Drawer(
      backgroundColor: Colors.white,
      width: 285,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  _section('MENU KUU'),
                  _item(Icons.workspace_premium_outlined, 'Admin', 0),
                  _item(Icons.group_outlined, 'Watumiaji', 1,
                      badge: _userCount > 0 ? '$_userCount' : null),
                  _item(Icons.person_search_outlined, 'Waliopata wenzao', 2),
                  _item(Icons.swap_horiz_rounded, 'Match za kweli', 3),
                  _item(Icons.bar_chart_outlined, 'Data', 4),
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: _kGrey200, indent: 16, endIndent: 16),
                  _section('MFUMO'),
                  _item(Icons.notifications_none_rounded, 'Matangazo', 5),
                  _item(Icons.payments_outlined, 'Malipo', 6),
                  _item(Icons.phone_in_talk_outlined, 'Waliopigiana', 7),
                  _item(Icons.assignment_outlined, 'Maoni', 8),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const Divider(height: 1, color: _kGrey200),
            // Wasifu wangu — kama picha: avatar + "Wasifu wangu" + arrow
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: _kBlue,
                child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              title: const Text('Wasifu wangu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey900)),
              subtitle: Text(name, style: const TextStyle(fontSize: 11, color: _kGrey500), overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _kGrey400),
              onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/profile'); },
            ),
            // Toka
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _kRedBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.logout_rounded, color: _kRed, size: 18),
              ),
              title: const Text('Toka', style: TextStyle(color: _kRed, fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: _logout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kGrey400, letterSpacing: 1.0),
      ),
    );
  }

  Widget _item(IconData icon, String label, int index, {String? badge}) {
    final active = _idx == index;
    return GestureDetector(
      onTap: () => _go(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: active ? _kBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 20, color: active ? _kBlue : _kGrey700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? _kBlue : _kGrey900,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(12)),
                  child: Text(badge, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
