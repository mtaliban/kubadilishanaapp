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

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kRed     = Color(0xFFDC2626);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  int _userCount = 0;
  bool _langSw = true; // true = SW

  final List<Widget> _pages = const [
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
    _loadUserCount();
  }

  Future<void> _loadUserCount() async {
    try {
      final res = await ApiService().adminStats();
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() { _userCount = (data['users'] as num?)?.toInt() ?? 0; });
    } catch (_) {}
  }

  void _navigate(int index) {
    setState(() { _currentIndex = index; });
    Navigator.pop(context); // close drawer
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final name = user?.fullName ?? 'Admin';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kGrey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu, color: _kGrey700, size: 20),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: _kGrey700),
            onPressed: () {},
          ),
          GestureDetector(
            onTap: () => setState(() { _langSw = !_langSw; }),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _kGrey200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SW', style: TextStyle(
                    fontSize: 11,
                    fontWeight: _langSw ? FontWeight.bold : FontWeight.normal,
                    color: _langSw ? _kBlue : _kGrey500,
                  )),
                  Text(' | ', style: TextStyle(fontSize: 11, color: _kGrey400)),
                  Text('EN', style: TextStyle(
                    fontSize: 11,
                    fontWeight: !_langSw ? FontWeight.bold : FontWeight.normal,
                    color: !_langSw ? _kBlue : _kGrey500,
                  )),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kGrey200),
        ),
      ),
      drawer: _AdminDrawer(
        currentIndex: _currentIndex,
        userCount: _userCount,
        userName: name,
        initials: initials,
        onNavigate: _navigate,
        onLogout: () async {
          Navigator.pop(context);
          await auth.logout();
        },
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
    );
  }
}

const _kGrey400 = Color(0xFF9CA3AF);

class _AdminDrawer extends StatelessWidget {
  final int currentIndex;
  final int userCount;
  final String userName;
  final String initials;
  final ValueChanged<int> onNavigate;
  final VoidCallback onLogout;

  const _AdminDrawer({
    required this.currentIndex,
    required this.userCount,
    required this.userName,
    required this.initials,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: 280,
      child: SafeArea(
        child: Column(
          children: [
            // Logo + title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kubadilishana',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kGrey900)),
                      Text('Panel ya Usimamizi',
                          style: TextStyle(fontSize: 11, color: _kGrey500)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: _kGrey200, height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _SectionLabel('MENU KUU'),
                  _DrawerItem(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Admin',
                    index: 0,
                    current: currentIndex,
                    onTap: () => onNavigate(0),
                  ),
                  _DrawerItem(
                    icon: Icons.group_outlined,
                    label: 'Watumiaji',
                    index: 1,
                    current: currentIndex,
                    badge: userCount > 0 ? '$userCount' : null,
                    onTap: () => onNavigate(1),
                  ),
                  _DrawerItem(
                    icon: Icons.person_search_outlined,
                    label: 'Waliopata Wenzao',
                    index: 2,
                    current: currentIndex,
                    onTap: () => onNavigate(2),
                  ),
                  _DrawerItem(
                    icon: Icons.swap_horiz,
                    label: 'Match za Kweli',
                    index: 3,
                    current: currentIndex,
                    onTap: () => onNavigate(3),
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Data',
                    index: 4,
                    current: currentIndex,
                    onTap: () => onNavigate(4),
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: _kGrey200, height: 1),
                  const SizedBox(height: 4),
                  _SectionLabel('MFUMO'),
                  _DrawerItem(
                    icon: Icons.notifications_outlined,
                    label: 'Matangazo',
                    index: 5,
                    current: currentIndex,
                    onTap: () => onNavigate(5),
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Malipo',
                    index: 6,
                    current: currentIndex,
                    onTap: () => onNavigate(6),
                  ),
                  _DrawerItem(
                    icon: Icons.phone_in_talk_outlined,
                    label: 'Waliopigiana',
                    index: 7,
                    current: currentIndex,
                    onTap: () => onNavigate(7),
                  ),
                  _DrawerItem(
                    icon: Icons.feedback_outlined,
                    label: 'Maoni',
                    index: 8,
                    current: currentIndex,
                    onTap: () => onNavigate(8),
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: _kGrey200, height: 1),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Profile row
            const Divider(color: _kGrey200, height: 1),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: _kBlue,
                child: Text(initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              title: Text(userName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900),
                  overflow: TextOverflow.ellipsis),
              subtitle: Text('Wasifu wangu', style: TextStyle(fontSize: 11, color: _kGrey500)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: _kGrey500),
              onTap: () {},
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _kRedBg, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.logout, color: _kRed, size: 18),
              ),
              title: const Text('Toka', style: TextStyle(color: _kRed, fontWeight: FontWeight.w600)),
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

const _kRedBg = Color(0xFFFEE2E2);

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(label,
          style: const TextStyle(
            fontSize: 10,
            color: _kGrey500,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          )),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final String? badge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == index;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: active ? _kBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border(left: const BorderSide(color: _kBlue, width: 4))
              : null,
        ),
        child: ListTile(
          dense: true,
          leading: Icon(icon,
              size: 20,
              color: active ? _kBlue : _kGrey700),
          title: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: active ? _kBlue : _kGrey700,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
          trailing: badge != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kBlueBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.bold)),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
