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
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kPurple  = Color(0xFF7C3AED);
const _kPurpleBg = Color(0xFFF5F3FF);

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
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminStats();
      if (!mounted) return;
      setState(() {
        _stats = (res.data as Map<String, dynamic>?) ?? {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _int(String key) => (_stats[key] as num?)?.toInt() ?? 0;

  Widget _statCard({
    required String label,
    required int value,
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required Color textColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kGrey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _kGrey500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityRow(IconData icon, Color iconColor, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kGrey100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900)),
                Text(sub, style: const TextStyle(fontSize: 12, color: _kGrey500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: _kGrey700), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStats,
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
              child: const Text('Jaribu Tena'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kBlueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: _kBlue, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                  Text('Muhtasari wa mfumo', style: TextStyle(fontSize: 13, color: _kGrey500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _statCard(
                label: 'Watumiaji',
                value: _int('users'),
                icon: Icons.group_rounded,
                bg: _kBlueBg,
                iconColor: _kBlue,
                textColor: _kBlue,
              ),
              const SizedBox(width: 12),
              _statCard(
                label: 'Wanaolipa',
                value: _int('paid'),
                icon: Icons.check_circle_rounded,
                bg: _kGreenBg,
                iconColor: _kGreen,
                textColor: _kGreen,
              ),
              const SizedBox(width: 12),
              _statCard(
                label: 'Hawajalipia',
                value: _int('unpaid'),
                icon: Icons.cancel_rounded,
                bg: _kAmberBg,
                iconColor: _kAmber,
                textColor: _kAmber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                label: 'Matangazo',
                value: _int('announcements'),
                icon: Icons.campaign_rounded,
                bg: _kPurpleBg,
                iconColor: _kPurple,
                textColor: _kPurple,
              ),
              const SizedBox(width: 12),
              _statCard(
                label: 'Malipo Pending',
                value: _int('pending_payments'),
                icon: Icons.hourglass_empty_rounded,
                bg: _kAmberBg,
                iconColor: _kAmber,
                textColor: _kAmber,
              ),
              const SizedBox(width: 12),
              _statCard(
                label: 'Mechi',
                value: _int('matches'),
                icon: Icons.auto_awesome_rounded,
                bg: _kBlueBg,
                iconColor: _kBlue,
                textColor: _kBlue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGrey200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shughuli za Hivi Karibuni', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kGrey900)),
                const SizedBox(height: 4),
                Container(height: 1, color: _kGrey200),
                _activityRow(Icons.person_add_alt_rounded, _kBlue, 'Watumiaji wapya', 'Angalia watumiaji waliojisajili hivi karibuni'),
                Container(height: 1, color: _kGrey200),
                _activityRow(Icons.payments_rounded, _kGreen, 'Malipo mapya', 'Malipo yanayosubiri uidhinisho'),
                Container(height: 1, color: _kGrey200),
                _activityRow(Icons.handshake_rounded, _kPurple, 'Mechi mpya', 'Mechi za hivi karibuni zilizotokea'),
                Container(height: 1, color: _kGrey200),
                _activityRow(Icons.rate_review_rounded, _kAmber, 'Maoni mapya', 'Maoni na malamiko mapya kutoka watumiaji'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
