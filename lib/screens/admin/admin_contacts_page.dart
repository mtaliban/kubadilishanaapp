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

class AdminContactsPage extends StatefulWidget {
  const AdminContactsPage({super.key});

  @override
  State<AdminContactsPage> createState() => _AdminContactsPageState();
}

class _AdminContactsPageState extends State<AdminContactsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _contacts = [];

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
      final res = await ApiService().getContactActivity();
      if (!mounted) return;
      final raw = res.data;
      List<dynamic> items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        items = (raw['contacts'] ?? raw['data'] ?? raw['results'] ?? []) as List<dynamic>;
      }
      setState(() {
        _contacts = items;
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

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return raw.toString();
      final local = dt.toLocal();
      return '${local.day}/${local.month}/${local.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _typeBadge(String type) {
    Color bg;
    Color fg;
    String label;
    switch (type.toLowerCase()) {
      case 'call':
      case 'piga':
        bg = _kBlueBg;
        fg = _kBlue;
        label = 'Piga';
        break;
      case 'sms':
        bg = _kAmberBg;
        fg = _kAmber;
        label = 'SMS';
        break;
      case 'whatsapp':
        bg = _kGreenBg;
        fg = _kGreen;
        label = 'WhatsApp';
        break;
      default:
        bg = _kGrey100;
        fg = _kGrey700;
        label = type;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  String _initial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
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
                child: const Icon(Icons.phone_rounded, color: _kBlue, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mawasiliano', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                  Text('Historia ya mawasiliano', style: TextStyle(fontSize: 13, color: _kGrey500)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kBlueBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 16, color: _kBlue),
                      SizedBox(width: 6),
                      Text('Refresh', style: TextStyle(fontSize: 13, color: _kBlue, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: _kGrey200),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: _kGrey700), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
                            child: const Text('Jaribu Tena'),
                          ),
                        ],
                      ),
                    )
                  : _contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_missed_rounded, size: 56, color: _kGrey400),
                              const SizedBox(height: 12),
                              const Text('Hakuna mawasiliano', style: TextStyle(fontSize: 16, color: _kGrey500, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _contacts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = _contacts[i] as Map<String, dynamic>;
                            final user = item['user'] as Map<String, dynamic>? ?? {};
                            final name = user['full_name'] as String? ?? user['name'] as String? ?? 'Mtumiaji';
                            final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
                            final type = item['type'] as String? ?? item['contact_type'] as String? ?? '';
                            final createdAt = item['created_at'] ?? item['createdAt'];

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kGrey200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: _kGreenBg,
                                    child: Text(
                                      _initial(name),
                                      style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey900)),
                                        const SizedBox(height: 2),
                                        Text(phone, style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (type.isNotEmpty) _typeBadge(type),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(createdAt),
                                        style: const TextStyle(fontSize: 11, color: _kGrey400),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
