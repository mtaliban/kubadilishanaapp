/// Register screen — multi-step registration wizard.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _category = '';
  String _cadreCode = '';
  bool _obscure = true;

  // Region/district/facility
  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  int? _regionId;
  int? _districtId;
  int? _facilityId;

  // Subjects
  List<dynamic> _subjects = [];
  List<String> _selectedSubjects = [];

  // Destinations
  int? _destRegion;
  int? _destDistrict;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      setState(() => _regions = res.data);
    } catch (_) {}
  }

  Future<void> _loadDistricts(int regionId) async {
    try {
      final res = await ApiService().getDistricts(regionId);
      setState(() => _districts = res.data);
    } catch (_) {}
  }

  Future<void> _loadFacilities(int districtId) async {
    try {
      final res = await ApiService().getFacilities(districtId);
      setState(() => _facilities = res.data);
    } catch (_) {}
  }

  Future<void> _loadSubjects() async {
    try {
      final res = await ApiService().getSubjects();
      setState(() => _subjects = res.data);
    } catch (_) {}
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit() async {
    final data = {
      'full_name': _nameController.text.trim(),
      'phone_primary': _phoneController.text.trim(),
      'password': _passwordController.text,
      'category': _category,
      'cadre_code': _cadreCode,
      'region_id': _regionId,
      'district_id': _districtId,
      'facility_id': _facilityId,
      'subjects': _selectedSubjects,
      'desired_destinations': [
        if (_destRegion != null)
          {'region_id': _destRegion, 'district_id': _destDistrict},
      ],
    };

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(data);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Umefanikiwa kusajiliwa! Ingia sasa.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final steps = ['Taarifa Binafsi', 'Idara & Kada', 'Eneo', 'Mikoa'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jisajili'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _back)
            : null,
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(steps.length, (i) {
                final active = i == _step;
                final done = i < _step;
                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (i > 0)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: done ? AppColors.primary : AppColors.border,
                              ),
                            ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active || done
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : Text('${i + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                          if (i < steps.length - 1)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: done ? AppColors.primary : AppColors.border,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(steps[i],
                          style: TextStyle(
                              fontSize: 10,
                              color: active ? AppColors.primary : AppColors.textLight)),
                    ],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStep(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: auth.loading ? null : _next,
              child: auth.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_step == 3 ? 'Jisajili' : 'Endelea'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Jina kamili'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Namba ya simu',
                  prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Nenosiri',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Thibitisha nenosiri',
                  prefixIcon: Icon(Icons.lock)),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _category.isEmpty ? null : _category,
              decoration: const InputDecoration(labelText: 'Idara'),
              items: const [
                DropdownMenuItem(value: 'education', child: Text('Elimu')),
                DropdownMenuItem(value: 'health', child: Text('Afya')),
              ],
              onChanged: (v) => setState(() {
                _category = v ?? '';
                _loadSubjects();
              }),
            ),
            const SizedBox(height: 12),
            if (_category.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _cadreCode.isEmpty ? null : _cadreCode,
                decoration: const InputDecoration(labelText: 'Kada'),
                items: _category == 'education'
                    ? const [
                        DropdownMenuItem(value: 'P1', child: Text('Mwalimu Shule ya Msingi')),
                        DropdownMenuItem(value: 'S1', child: Text('Mwalimu Shule ya Sekondari')),
                      ]
                    : const [
                        DropdownMenuItem(value: 'Nurse', child: Text('Nurse')),
                        DropdownMenuItem(value: 'Doctor', child: Text('Daktari')),
                        DropdownMenuItem(value: 'Clinical Officer', child: Text('Clinical Officer')),
                      ],
                onChanged: (v) => setState(() => _cadreCode = v ?? ''),
              ),
            const SizedBox(height: 12),
            if (_subjects.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _subjects.map((s) {
                  final name = s['name'] ?? s.toString();
                  final selected = _selectedSubjects.contains(name);
                  return FilterChip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedSubjects.add(name);
                        } else {
                          _selectedSubjects.remove(name);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
          ],
        );
      case 2:
        return Column(
          children: [
            DropdownButtonFormField<int>(
              value: _regionId,
              decoration: const InputDecoration(labelText: 'Mkoa wa sasa'),
              items: _regions
                  .map((r) => DropdownMenuItem<int>(
                      value: (r['region_id'] ?? r['_id']) as int?,
                      child: Text(r['name'] ?? '')))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _regionId = v;
                  _districtId = null;
                  _facilityId = null;
                  _districts = [];
                  _facilities = [];
                });
                if (v != null) _loadDistricts(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _districtId,
              decoration: const InputDecoration(labelText: 'Wilaya'),
              items: _districts
                  .map((d) => DropdownMenuItem<int>(
                      value: (d['district_id'] ?? d['_id']) as int?,
                      child: Text(d['name'] ?? '')))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _districtId = v;
                  _facilityId = null;
                  _facilities = [];
                });
                if (v != null) _loadFacilities(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _facilityId,
              decoration: const InputDecoration(labelText: 'Kituo'),
              items: _facilities
                  .map((f) => DropdownMenuItem<int>(
                      value: (f['facility_id'] ?? f['_id']) as int?,
                      child: Text(f['name'] ?? '')))
                  .toList(),
              onChanged: (v) => setState(() => _facilityId = v),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            const Text('Unataka kwenda wapi?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _destRegion,
              decoration: const InputDecoration(labelText: 'Mkoa unaokwenda'),
              items: _regions
                  .map((r) => DropdownMenuItem<int>(
                      value: (r['region_id'] ?? r['_id']) as int?,
                      child: Text(r['name'] ?? '')))
                  .toList(),
              onChanged: (v) => setState(() => _destRegion = v),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}
