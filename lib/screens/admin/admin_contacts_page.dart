/// Admin contacts page — view who contacted whom (calls, SMS, WhatsApp).
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminContactsPage extends StatefulWidget {
  const AdminContactsPage({super.key});
  @override
  State<AdminContactsPage> createState() => _AdminContactsPageState();
}

class _AdminContactsPageState extends State<AdminContactsPage> {
  List<dynamic> _contacts = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().getContactActivity();
      setState(() {
        _contacts = res.data is List ? res.data : (res.data['contacts'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? _contacts
        : _contacts.where((c) => c['contact_type'] == _filter).toList();

    return Column(
      children: [
        // Stats chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _chip('Zote', _contacts.length, null),
              _chip('Simu', _contacts.where((c) => c['contact_type'] == 'call').length, 'call'),
              _chip('SMS', _contacts.where((c) => c['contact_type'] == 'sms').length, 'sms'),
              _chip('WhatsApp', _contacts.where((c) => c['contact_type'] == 'whatsapp').length, 'whatsapp'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: filtered.isEmpty
                      ? const Center(child: Text('Hakuna mawasiliano bado', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                leading: _contactIcon(c['contact_type']),
                                title: Text('${c['from_name'] ?? ''} → ${c['to_name'] ?? ''}',
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(c['created_at'] ?? '', style: const TextStyle(fontSize: 11)),
                                trailing: _contactBadge(c['contact_type']),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, int count, String? filter) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)', style: const TextStyle(fontSize: 12)),
        selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter ?? ''),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: _filter == filter ? Colors.white : null),
      ),
    );
  }

  Widget _contactIcon(String? type) {
    switch (type) {
      case 'call': return const Icon(Icons.phone, color: Colors.green, size: 20);
      case 'sms': return const Icon(Icons.sms, color: Colors.blue, size: 20);
      case 'whatsapp': return const Icon(Icons.chat, color: Color(0xFF25D366), size: 20);
      default: return const Icon(Icons.contact_phone, size: 20);
    }
  }

  Widget _contactBadge(String? type) {
    switch (type) {
      case 'call': return const Text('📞 Simu', style: TextStyle(fontSize: 11));
      case 'sms': return const Text('💬 SMS', style: TextStyle(fontSize: 11));
      case 'whatsapp': return const Text('📱 WA', style: TextStyle(fontSize: 11));
      default: return const Text('—', style: TextStyle(fontSize: 11));
    }
  }
}
