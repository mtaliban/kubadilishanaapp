/// Admin shell — drawer navigation to all admin pages.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import 'admin_dashboard_page.dart';
import 'admin_users_page.dart';
import 'admin_data_page.dart';
import 'admin_payments_page.dart';
import 'admin_contacts_page.dart';
import 'admin_feedback_page.dart';
import 'admin_announcements_page.dart';
import 'admin_password_resets_page.dart';
import 'admin_reports_page.dart';
import 'admin_events_page.dart';
import 'admin_matches_page.dart';
import 'admin_real_matches_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  final _pages = [
    const AdminDashboardPage(),
    const AdminUsersPage(),
    const AdminDataPage(),
    const AdminPaymentsPage(),
    const AdminContactsPage(),
    const AdminFeedbackPage(),
    const AdminAnnouncementsPage(),
    const AdminPasswordResetsPage(),
    const AdminReportsPage(),
    const AdminEventsPage(),
    const AdminMatchesPage(),
    const AdminRealMatchesPage(),
  ];

  final _titles = const [
    'Admin Dashboard',
    'Watumiaji',
    'Data',
    'Malipo',
    'Waliopigiana',
    'Maoni',
    'Matangazo',
    'Nenosiri',
    'Ripoti',
    'Events',
    'Mikataba',
    'Real Matches',
  ];

  final _icons = [
    Icons.dashboard,
    Icons.people,
    Icons.storage,
    Icons.payment,
    Icons.phone_in_talk,
    Icons.message,
    Icons.campaign,
    Icons.lock_reset,
    Icons.assessment,
    Icons.timeline,
    Icons.people,
    Icons.star,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: AppColors.primary),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _titles.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: Icon(_icons[i], color: _currentIndex == i ? AppColors.primary : null),
                    title: Text(_titles[i], style: TextStyle(fontWeight: _currentIndex == i ? FontWeight.bold : FontWeight.normal)),
                    selected: _currentIndex == i,
                    selectedTileColor: AppColors.primaryLight,
                    onTap: () {
                      setState(() => _currentIndex = i);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex < 6 ? _currentIndex : 0,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Watu'),
          BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'Data'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Malipo'),
          BottomNavigationBarItem(icon: Icon(Icons.phone_in_talk), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Maoni'),
        ],
      ),
    );
  }
}
