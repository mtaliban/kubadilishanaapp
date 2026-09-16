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

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  String? _selectedRegion;
  String? _selectedCategory;
  int _selectedDays = 30;

  final List<int> _dayOptions = [30, 90, 365];
  final List<String> _categoryOptions = ['', 'afya', 'elimu', 'serikali'];
  final List<String> _categoryLabels = ['Zote', 'Afya', 'Elimu', 'Serikali'];

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
      final res = await ApiService().adminReports(
        days: _selectedDays,
        region: _selectedRegion,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _data = (res.data as Map<String, dynamic>?) ?? {};
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

  Widget _statRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: _kGrey700)),
          ),
          Text(
            value?.toString() ?? '0',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kGrey900),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Color iconColor, required Color iconBg, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kGrey900)),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _kGrey200),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _regionRows() {
    final byRegion = _data['by_region'];
    if (byRegion == null) return [const Text('Hakuna data', style: TextStyle(fontSize: 13, color: _kGrey400))];
    if (byRegion is Map) {
      return byRegion.entries
          .take(10)
          .map((e) => _statRow(e.key, e.value))
          .toList();
    }
    if (byRegion is List) {
      return (byRegion as List<dynamic>)
          .take(10)
          .map((e) {
            if (e is Map) {
              final name = e['region'] ?? e['name'] ?? e['_id'] ?? '';
              final count = e['count'] ?? e['total'] ?? 0;
              return _statRow(name.toString(), count);
            }
            return const SizedBox.shrink();
          })
          .toList();
    }
    return [const Text('Hakuna data', style: TextStyle(fontSize: 13, color: _kGrey400))];
  }

  List<Widget> _categoryRows() {
    final byCategory = _data['by_category'];
    if (byCategory == null) return [const Text('Hakuna data', style: TextStyle(fontSize: 13, color: _kGrey400))];
    if (byCategory is Map) {
      return byCategory.entries
          .map((e) => _statRow(e.key, e.value))
          .toList();
    }
    if (byCategory is List) {
      return (byCategory as List<dynamic>)
          .map((e) {
            if (e is Map) {
              final name = e['category'] ?? e['name'] ?? e['_id'] ?? '';
              final count = e['count'] ?? e['total'] ?? 0;
              return _statRow(name.toString(), count);
            }
            return const SizedBox.shrink();
          })
          .toList();
    }
    return [const Text('Hakuna data', style: TextStyle(fontSize: 13, color: _kGrey400))];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
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
                      Text('Ripoti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                      Text('Takwimu na michoro', style: TextStyle(fontSize: 13, color: _kGrey500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kGrey200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRegion ?? '',
                          hint: const Text('Mkoa', style: TextStyle(fontSize: 12, color: _kGrey500)),
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: _kGrey900),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Mikoa Yote')),
                            ...['Dar es Salaam', 'Mwanza', 'Dodoma', 'Arusha', 'Mbeya', 'Morogoro', 'Zanzibar', 'Tanga']
                                .map((r) => DropdownMenuItem(value: r, child: Text(r))),
                          ],
                          onChanged: (v) => setState(() => _selectedRegion = v == '' ? null : v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kGrey200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory ?? '',
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: _kGrey900),
                          items: List.generate(_categoryOptions.length, (i) {
                            return DropdownMenuItem(
                              value: _categoryOptions[i],
                              child: Text(_categoryLabels[i]),
                            );
                          }),
                          onChanged: (v) => setState(() => _selectedCategory = v == '' ? null : v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kGrey200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedDays,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: _kGrey900),
                          items: _dayOptions
                              .map((d) => DropdownMenuItem(value: d, child: Text('Siku $d')))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedDays = v ?? 30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Tafuta', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
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
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _sectionCard(
                            title: 'Takwimu za Jumla',
                            icon: Icons.people_rounded,
                            iconColor: _kBlue,
                            iconBg: _kBlueBg,
                            children: [
                              _statRow('Jumla ya Usajili', _data['total_registrations'] ?? _data['total'] ?? _data['users'] ?? 0),
                              _statRow('Wanaolipa', _data['paid'] ?? _data['paying_users'] ?? 0),
                              _statRow('Hawajalipia', _data['unpaid'] ?? _data['free_users'] ?? 0),
                              _statRow('Mechi Zilizotokea', _data['matches'] ?? _data['total_matches'] ?? 0),
                              _statRow('Matangazo Yaliyotumwa', _data['announcements'] ?? 0),
                            ],
                          ),
                          _sectionCard(
                            title: 'Kwa Mkoa',
                            icon: Icons.map_rounded,
                            iconColor: _kGreen,
                            iconBg: _kGreenBg,
                            children: _regionRows(),
                          ),
                          _sectionCard(
                            title: 'Kwa Kategoria',
                            icon: Icons.category_rounded,
                            iconColor: _kAmber,
                            iconBg: _kAmberBg,
                            children: _categoryRows(),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}
