import 'dart:async';
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

  // Accumulated data across steps
  final Map<String, dynamic> _data = {
    'desired_destinations': <Map<String, dynamic>>[],
    'subjects': <String>[],
  };

  void _next(Map<String, dynamic> partial) {
    setState(() {
      _data.addAll(partial);
      _step++;
    });
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  bool get _isHealth => (_data['category'] ?? '') == 'health';

  // Total steps: Health=6, Education=5
  int get _totalSteps => _isHealth ? 6 : 5;

  String _stepTitle(int n) {
    final health = ['Taarifa', 'Idara', 'Wizara', 'Kada', 'Eneo', 'Maeneo'];
    final edu = ['Taarifa', 'Idara', 'Kada', 'Eneo', 'Maeneo'];
    return _isHealth ? health[n] : edu[n];
  }

  Future<void> _submit(Map<String, dynamic> finalPartial) async {
    _data.addAll(finalPartial);
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(_data);
    if (!mounted) return;
    if (ok) {
      final phone = _data['phone_primary'] ?? '';
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = List.generate(_totalSteps, (i) => _stepTitle(i));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jisajili'),
        leading: _step > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back)
            : null,
      ),
      body: Column(
        children: [
          _StepBar(currentStep: _step, steps: steps),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) return _Step1Identity(onNext: _next);
    if (_step == 1) return _Step2Idara(initial: _data, onBack: _back, onNext: _next);
    if (_isHealth) {
      if (_step == 2) return _Step3Wizara(initial: _data, onBack: _back, onNext: _next);
      if (_step == 3) return _Step4Kada(initial: _data, onBack: _back, onNext: _next);
      if (_step == 4) return _Step5Station(initial: _data, onBack: _back, onNext: _next);
      if (_step == 5) return _Step6Destinations(initial: _data, onBack: _back, onSubmit: _submit);
    } else {
      if (_step == 2) return _Step4Kada(initial: _data, onBack: _back, onNext: _next);
      if (_step == 3) return _Step5Station(initial: _data, onBack: _back, onNext: _next);
      if (_step == 4) return _Step6Destinations(initial: _data, onBack: _back, onSubmit: _submit);
    }
    return const SizedBox();
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────
class _StepBar extends StatelessWidget {
  final int currentStep;
  final List<String> steps;
  const _StepBar({required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < currentStep;
          final active = i == currentStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(child: Container(height: 2, color: done ? AppColors.primary : AppColors.border)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active || done ? AppColors.primary : AppColors.border,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text('${i + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(steps[i],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          color: active ? AppColors.primary : AppColors.textLight,
                        )),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(child: Container(height: 2, color: done ? AppColors.primary : AppColors.border)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── STEP 1: Identity — Jina + Simu + WhatsApp ─────────────────────────────────
class _Step1Identity extends StatefulWidget {
  final void Function(Map<String, dynamic>) onNext;
  const _Step1Identity({required this.onNext});
  @override
  State<_Step1Identity> createState() => _Step1IdentityState();
}

class _Step1IdentityState extends State<_Step1Identity> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altCtrl = TextEditingController();
  final Map<String, String> _errors = {};

  // Phone availability state: idle | checking | available | taken
  String _phoneStatus = 'idle';
  String _altStatus = 'idle';
  Timer? _phoneTimer;
  Timer? _altTimer;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _altCtrl.dispose();
    _phoneTimer?.cancel();
    _altTimer?.cancel();
    super.dispose();
  }

  bool _validPhone(String v) => RegExp(r'^(\+?255|0)\d{9}$').hasMatch(v.replaceAll(RegExp(r'[\s\-]'), ''));

  void _onPhoneChanged(String v) {
    _phoneTimer?.cancel();
    setState(() => _phoneStatus = 'idle');
    if (!_validPhone(v)) return;
    setState(() => _phoneStatus = 'checking');
    _phoneTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await ApiService().checkPhone(v.trim());
        final available = res.data['available'] == true;
        if (mounted) setState(() => _phoneStatus = available ? 'available' : 'taken');
      } catch (_) {
        if (mounted) setState(() => _phoneStatus = 'idle');
      }
    });
  }

  void _onAltChanged(String v) {
    _altTimer?.cancel();
    setState(() => _altStatus = 'idle');
    if (!_validPhone(v)) return;
    setState(() => _altStatus = 'checking');
    _altTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await ApiService().checkPhone(v.trim());
        final available = res.data['available'] == true;
        if (mounted) setState(() => _altStatus = available ? 'available' : 'taken');
      } catch (_) {
        if (mounted) setState(() => _altStatus = 'idle');
      }
    });
  }

  bool _validate() {
    _errors.clear();
    if (_nameCtrl.text.trim().length < 3) _errors['name'] = 'Jina lazima liwe na herufi 3 au zaidi';
    if (!_validPhone(_phoneCtrl.text)) {
      _errors['phone'] = 'Namba ya simu si sahihi (mfano: 0712345678)';
    } else if (_phoneStatus == 'taken') {
      _errors['phone'] = 'Namba hii tayari inatumiwa';
    }
    if (_altCtrl.text.isEmpty) {
      _errors['alt'] = 'Namba ya WhatsApp inahitajika';
    } else if (!_validPhone(_altCtrl.text)) {
      _errors['alt'] = 'Namba ya WhatsApp si sahihi';
    } else if (_altStatus == 'taken') {
      _errors['alt'] = 'Namba hii tayari inatumiwa';
    }
    setState(() {});
    return _errors.isEmpty;
  }

  Widget _statusIcon(String status) {
    if (status == 'checking') return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    if (status == 'available') return const Icon(Icons.check_circle, size: 18, color: Colors.green);
    if (status == 'taken') return const Icon(Icons.error, size: 18, color: AppColors.error);
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Taarifa Binafsi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),

        // Full name
        const Text('Jina Kamili *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            hintText: 'Jina la kwanza na la ukoo',
            errorText: _errors['name'],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            prefixIcon: const Icon(Icons.person, size: 18),
          ),
          onChanged: (_) => setState(() => _errors.remove('name')),
        ),
        const SizedBox(height: 14),

        // Phone primary
        const Text('Namba ya Simu *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '0712345678',
            errorText: _errors['phone'],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            prefixIcon: const Icon(Icons.phone, size: 18),
            suffixIcon: Padding(padding: const EdgeInsets.all(12), child: _statusIcon(_phoneStatus)),
          ),
          onChanged: (v) {
            setState(() => _errors.remove('phone'));
            _onPhoneChanged(v);
          },
        ),
        if (_phoneStatus == 'available')
          const Padding(padding: EdgeInsets.only(top: 4, left: 4),
            child: Text('Namba hii ipo huru', style: TextStyle(fontSize: 11, color: Colors.green))),
        if (_phoneStatus == 'taken')
          const Padding(padding: EdgeInsets.only(top: 4, left: 4),
            child: Text('Namba hii tayari inatumiwa', style: TextStyle(fontSize: 11, color: AppColors.error))),
        const SizedBox(height: 14),

        // WhatsApp
        const Text('Namba ya WhatsApp *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _altCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '0623456789',
            errorText: _errors['alt'],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            prefixIcon: const Icon(Icons.message, size: 18),
            suffixIcon: Padding(padding: const EdgeInsets.all(12), child: _statusIcon(_altStatus)),
          ),
          onChanged: (v) {
            setState(() => _errors.remove('alt'));
            _onAltChanged(v);
          },
        ),
        if (_altStatus == 'available')
          const Padding(padding: EdgeInsets.only(top: 4, left: 4),
            child: Text('Namba hii ipo huru', style: TextStyle(fontSize: 11, color: Colors.green))),
        if (_altStatus == 'taken')
          const Padding(padding: EdgeInsets.only(top: 4, left: 4),
            child: Text('Namba hii tayari inatumiwa', style: TextStyle(fontSize: 11, color: AppColors.error))),
        const SizedBox(height: 24),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () {
              if (_validate()) {
                widget.onNext({
                  'full_name': _nameCtrl.text.trim(),
                  'phone_primary': _phoneCtrl.text.trim(),
                  'phone_alt': _altCtrl.text.trim(),
                });
              }
            },
            child: const Text('Endelea →'),
          ),
        ),
      ],
    );
  }
}

// ── STEP 2: Idara (category from API) ─────────────────────────────────────────
class _Step2Idara extends StatefulWidget {
  final Map<String, dynamic> initial;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onNext;
  const _Step2Idara({required this.initial, required this.onBack, required this.onNext});
  @override
  State<_Step2Idara> createState() => _Step2IdaraState();
}

class _Step2IdaraState extends State<_Step2Idara> {
  List<dynamic> _departments = [];
  bool _loading = true;
  String _selected = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial['category'] ?? '';
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().getDepartments();
      final list = (res.data as List?)?.where((d) => d['status'] != 'disabled').toList() ?? [];
      setState(() { _departments = list; _loading = false; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Imeshindikana kupata idara'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Idara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Unafanya kazi katika idara gani?', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _ErrorBox(_error!)
        else ...[
          const Text('Chagua Idara *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selected.isEmpty ? null : _selected,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            hint: const Text('-- Chagua Idara --'),
            items: _departments.map((d) => DropdownMenuItem<String>(
              value: d['code'] as String,
              child: Text(d['name'] as String),
            )).toList(),
            onChanged: (v) => setState(() => _selected = v ?? ''),
          ),
        ],
        const SizedBox(height: 24),
        Row(children: [
          OutlinedButton(onPressed: widget.onBack, child: const Text('Rudi')),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _selected.isEmpty ? null : () => widget.onNext({'category': _selected}),
              child: const Text('Endelea →'),
            ),
          ),
        ]),
      ],
    );
  }
}

// ── STEP 3: Wizara (health only) ───────────────────────────────────────────────
class _Step3Wizara extends StatefulWidget {
  final Map<String, dynamic> initial;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onNext;
  const _Step3Wizara({required this.initial, required this.onBack, required this.onNext});
  @override
  State<_Step3Wizara> createState() => _Step3WizaraState();
}

class _Step3WizaraState extends State<_Step3Wizara> {
  String _sector = '';

  @override
  void initState() {
    super.initState();
    _sector = widget.initial['employment_sector'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Wizara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Je, unafanya kazi chini ya taasisi gani?', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        const Text('Wizara *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _sector.isEmpty ? null : _sector,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          hint: const Text('-- Chagua --'),
          items: const [
            DropdownMenuItem(value: 'wizara_afya', child: Text('Wizara ya Afya')),
            DropdownMenuItem(value: 'tamisemi', child: Text('TAMISEMI')),
          ],
          onChanged: (v) => setState(() => _sector = v ?? ''),
        ),
        const SizedBox(height: 24),
        Row(children: [
          OutlinedButton(onPressed: widget.onBack, child: const Text('Rudi')),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _sector.isEmpty ? null : () => widget.onNext({'employment_sector': _sector}),
              child: const Text('Endelea →'),
            ),
          ),
        ]),
      ],
    );
  }
}

// ── STEP 4: Kada (cadre from API) ─────────────────────────────────────────────
class _Step4Kada extends StatefulWidget {
  final Map<String, dynamic> initial;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onNext;
  const _Step4Kada({required this.initial, required this.onBack, required this.onNext});
  @override
  State<_Step4Kada> createState() => _Step4KadaState();
}

class _Step4KadaState extends State<_Step4Kada> {
  List<dynamic> _cadres = [];
  List<dynamic> _subjects = [];
  bool _loading = true;
  bool _loadingSubjects = false;
  String _cadreCode = '';
  List<String> _selectedSubjects = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cadreCode = widget.initial['cadre_code'] ?? '';
    _selectedSubjects = List<String>.from(widget.initial['subjects'] ?? []);
    _loadCadres();
  }

  Future<void> _loadCadres() async {
    try {
      final cat = widget.initial['category'] as String?;
      final sector = widget.initial['employment_sector'] as String?;
      final res = await ApiService().getCadres(category: cat);
      var list = res.data as List? ?? [];
      // Filter by employment_sector if health
      if (sector != null && sector.isNotEmpty) {
        list = list.where((c) {
          final cs = c['employment_sector'];
          return cs == null || cs == sector;
        }).toList();
      }
      setState(() { _cadres = list; _loading = false; });
      if (_cadreCode.isNotEmpty) _onCadreChanged(_cadreCode);
    } catch (_) {
      setState(() { _loading = false; _error = 'Imeshindikana kupata orodha ya kada'; });
    }
  }

  void _onCadreChanged(String code) {
    setState(() { _cadreCode = code; _subjects = []; _selectedSubjects = []; });
    final cadre = _cadres.firstWhere((c) => c['code'] == code, orElse: () => null);
    if (cadre == null) return;
    final level = cadre['level'] as String?;
    if (level == 'Primary' || level == 'Secondary') {
      _loadSubjects(level!);
    }
  }

  Future<void> _loadSubjects(String level) async {
    setState(() => _loadingSubjects = true);
    try {
      final res = await ApiService().getSubjects(level: level);
      setState(() { _subjects = res.data as List? ?? []; });
    } catch (_) {}
    setState(() => _loadingSubjects = false);
  }

  bool get _needsSubjects => _subjects.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cadreObj = _cadres.firstWhere((c) => c['code'] == _cadreCode, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Kada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _ErrorBox(_error!)
        else ...[
          const Text('Kada *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _cadreCode.isEmpty ? null : _cadreCode,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            hint: const Text('-- Chagua Kada --'),
            items: _cadres.map((c) => DropdownMenuItem<String>(
              value: c['code'] as String,
              child: Text(c['display_name'] as String? ?? c['code'] as String),
            )).toList(),
            onChanged: (v) { if (v != null) _onCadreChanged(v); },
          ),
        ],

        if (_needsSubjects) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Masomo *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('(chagua somo 2)', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingSubjects)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _subjects.map((s) {
                final code = s['code'] as String;
                final name = s['name'] as String;
                final selected = _selectedSubjects.contains(code);
                final disabled = !selected && _selectedSubjects.length >= 2;
                return FilterChip(
                  label: Text(name, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  selected: selected,
                  onSelected: disabled ? null : (v) {
                    setState(() {
                      if (v) _selectedSubjects.add(code);
                      else _selectedSubjects.remove(code);
                    });
                  },
                );
              }).toList(),
            ),
          if (_selectedSubjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Umechagua: ${_selectedSubjects.length} somo',
                  style: const TextStyle(fontSize: 11, color: Colors.green)),
            ),
        ],

        const SizedBox(height: 24),
        Row(children: [
          OutlinedButton(onPressed: widget.onBack, child: const Text('Rudi')),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _cadreCode.isEmpty ? null : () {
                if (_needsSubjects && _selectedSubjects.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chagua masomo 2 — ni lazima kabisa')),
                  );
                  return;
                }
                widget.onNext({'cadre_code': _cadreCode, 'subjects': _selectedSubjects});
              },
              child: const Text('Endelea →'),
            ),
          ),
        ]),
      ],
    );
  }
}

// ── STEP 5: Current Station ───────────────────────────────────────────────────
class _Step5Station extends StatefulWidget {
  final Map<String, dynamic> initial;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onNext;
  const _Step5Station({required this.initial, required this.onBack, required this.onNext});
  @override
  State<_Step5Station> createState() => _Step5StationState();
}

class _Step5StationState extends State<_Step5Station> {
  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  int? _regionId;
  int? _districtId;
  String? _facilityId;
  bool _loadingRegions = true;
  bool _loadingDistricts = false;
  bool _loadingFacilities = false;
  String? _error;

  bool get _isWizara =>
      widget.initial['category'] == 'health' && widget.initial['employment_sector'] == 'wizara_afya';

  @override
  void initState() {
    super.initState();
    final cs = widget.initial['current_station'] as Map<String, dynamic>? ?? {};
    _regionId = cs['region_id'] as int?;
    _districtId = cs['district_id'] as int?;
    _facilityId = cs['facility_id'] as String?;
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      setState(() { _regions = res.data as List? ?? []; _loadingRegions = false; });
      if (_regionId != null) _onRegionChanged(_regionId!);
    } catch (_) {
      setState(() { _loadingRegions = false; _error = 'Imeshindikana kupata mikoa'; });
    }
  }

  Future<void> _onRegionChanged(int rid) async {
    setState(() {
      _regionId = rid; _districtId = null; _facilityId = null;
      _districts = []; _facilities = [];
    });
    if (_isWizara) {
      setState(() => _loadingFacilities = true);
      try {
        final res = await ApiService().getFacilitiesByRegion(rid,
            category: 'health', employmentSector: 'wizara_afya');
        setState(() { _facilities = res.data as List? ?? []; });
      } catch (_) {}
      setState(() => _loadingFacilities = false);
    } else {
      setState(() => _loadingDistricts = true);
      try {
        final res = await ApiService().getDistricts(rid);
        setState(() { _districts = res.data as List? ?? []; });
      } catch (_) {}
      setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _onDistrictChanged(int did) async {
    setState(() { _districtId = did; _facilityId = null; _facilities = []; _loadingFacilities = true; });
    try {
      final cat = widget.initial['category'] as String? ?? 'health';
      final res = await ApiService().getFacilities(did, category: cat);
      setState(() { _facilities = res.data as List? ?? []; });
    } catch (_) {}
    setState(() => _loadingFacilities = false);
  }

  void _submit() {
    if (_regionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chagua Mkoa')));
      return;
    }
    if (_isWizara && _facilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chagua Hospitali')));
      return;
    }
    if (!_isWizara && _districtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chagua Wilaya')));
      return;
    }

    final region = _regions.firstWhere((r) => r['id'] == _regionId, orElse: () => {});
    final district = _districts.firstWhere((d) => d['id'] == _districtId, orElse: () => null);
    final facility = _facilityId != null
        ? _facilities.firstWhere((f) => '${f['id'] ?? f['code']}' == _facilityId, orElse: () => null)
        : null;

    widget.onNext({
      'current_station': {
        'region_id': _regionId,
        'region_name': region['name'],
        'district_id': district?['id'],
        'district_name': district?['name'],
        'facility_id': _facilityId,
        'facility_name': facility?['name'],
        'facility_type': facility?['type'] ?? facility?['type_category'],
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Eneo la Sasa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        if (_loadingRegions)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _ErrorBox(_error!)
        else ...[
          // Region
          const Text('Mkoa *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: _regionId,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            hint: const Text('Chagua Mkoa'),
            items: _regions.map((r) => DropdownMenuItem<int>(
              value: r['id'] as int,
              child: Text(r['name'] as String),
            )).toList(),
            onChanged: (v) { if (v != null) _onRegionChanged(v); },
          ),

          // Wizara ya Afya: show hospital list
          if (_isWizara && _regionId != null) ...[
            const SizedBox(height: 14),
            const Text('Hospitali ya Rufaa *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (_loadingFacilities)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else
              DropdownButtonFormField<String>(
                value: _facilityId,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                hint: const Text('Chagua Hospitali'),
                items: _facilities.map((f) => DropdownMenuItem<String>(
                  value: '${f['id'] ?? f['code']}',
                  child: Text(f['name'] as String? ?? ''),
                )).toList(),
                onChanged: (v) => setState(() => _facilityId = v),
              ),
          ],

          // TAMISEMI/Elimu: wilaya + kituo
          if (!_isWizara && _regionId != null) ...[
            const SizedBox(height: 14),
            const Text('Wilaya *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (_loadingDistricts)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else
              DropdownButtonFormField<int>(
                value: _districtId,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                hint: const Text('Chagua Wilaya'),
                items: _districts.map((d) => DropdownMenuItem<int>(
                  value: d['id'] as int,
                  child: Text(d['name'] as String),
                )).toList(),
                onChanged: (v) { if (v != null) _onDistrictChanged(v); },
              ),
          ],

          if (!_isWizara && _districtId != null && _facilities.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              widget.initial['category'] == 'health' ? 'Hospitali/Kituo (hiari)' : 'Shule (hiari)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (_loadingFacilities)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else
              DropdownButtonFormField<String>(
                value: _facilityId,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                hint: const Text('Chagua (hiari)'),
                items: _facilities.map((f) => DropdownMenuItem<String>(
                  value: '${f['id'] ?? f['code']}',
                  child: Text(f['name'] as String? ?? ''),
                )).toList(),
                onChanged: (v) => setState(() => _facilityId = v),
              ),
          ],
        ],
        const SizedBox(height: 24),
        Row(children: [
          OutlinedButton(onPressed: widget.onBack, child: const Text('Rudi')),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: _submit, child: const Text('Endelea →'))),
        ]),
      ],
    );
  }
}

// ── STEP 6: Desired Destinations + years_of_service ──────────────────────────
class _DestEntry {
  int? regionId;
  String regionName = '';
  List<int> selectedDistricts = [];
  String? facilityId;
  String? facilityName;
}

class _Step6Destinations extends StatefulWidget {
  final Map<String, dynamic> initial;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const _Step6Destinations({required this.initial, required this.onBack, required this.onSubmit});
  @override
  State<_Step6Destinations> createState() => _Step6DestinationsState();
}

class _Step6DestinationsState extends State<_Step6Destinations> {
  List<_DestEntry> _dests = [_DestEntry()];
  List<dynamic> _regions = [];
  final Map<int, List<dynamic>> _regionDistricts = {};
  final Map<int, List<dynamic>> _regionFacilities = {};
  final Map<int, List<dynamic>> _districtFacilities = {};
  String _years = '';
  bool _submitting = false;

  bool get _isWizara =>
      widget.initial['category'] == 'health' && widget.initial['employment_sector'] == 'wizara_afya';

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      setState(() => _regions = res.data as List? ?? []);
    } catch (_) {}
  }

  Future<void> _ensureDistricts(int rid) async {
    if (_regionDistricts.containsKey(rid)) return;
    try {
      final res = await ApiService().getDistricts(rid);
      setState(() => _regionDistricts[rid] = res.data as List? ?? []);
    } catch (_) {}
  }

  Future<void> _ensureRegionFacilities(int rid) async {
    if (_regionFacilities.containsKey(rid)) return;
    try {
      final res = await ApiService().getFacilitiesByRegion(rid,
          category: 'health', employmentSector: 'wizara_afya');
      setState(() => _regionFacilities[rid] = res.data as List? ?? []);
    } catch (_) {}
  }

  Future<void> _ensureDistrictFacilities(int did) async {
    if (_districtFacilities.containsKey(did)) return;
    try {
      final cat = widget.initial['category'] as String? ?? 'health';
      final res = await ApiService().getFacilities(did, category: cat);
      setState(() => _districtFacilities[did] = res.data as List? ?? []);
    } catch (_) {}
  }

  void _onRegionChanged(int destIdx, int? rid) {
    setState(() {
      _dests[destIdx].regionId = rid;
      _dests[destIdx].regionName = rid != null
          ? (_regions.firstWhere((r) => r['id'] == rid, orElse: () => {})['name'] ?? '') as String
          : '';
      _dests[destIdx].selectedDistricts = [];
      _dests[destIdx].facilityId = null;
      _dests[destIdx].facilityName = null;
    });
    if (rid == null) return;
    if (_isWizara) {
      _ensureRegionFacilities(rid);
    } else {
      _ensureDistricts(rid);
    }
  }

  void _toggleDistrict(int destIdx, int did) {
    setState(() {
      final d = _dests[destIdx];
      if (d.selectedDistricts.contains(did)) {
        d.selectedDistricts.remove(did);
      } else {
        d.selectedDistricts.add(did);
      }
    });
    _ensureDistrictFacilities(did);
  }

  Future<void> _submit() async {
    final validDests = _dests.where((d) => d.regionId != null).toList();
    if (validDests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ongeza angalau mkoa mmoja')));
      return;
    }
    if (_years.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chagua miaka ya kazi')));
      return;
    }

    final destinations = <Map<String, dynamic>>[];
    for (final d in validDests) {
      final rid = d.regionId!;
      if (_isWizara) {
        if (d.facilityId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chagua hospitali kwa mkoa ${d.regionName}')));
          return;
        }
        final facList = _regionFacilities[rid] ?? [];
        final fac = facList.firstWhere((f) => '${f['id'] ?? f['code']}' == d.facilityId, orElse: () => null);
        destinations.add({
          'region_id': rid,
          'region_name': d.regionName,
          'district_id': fac?['district_id'],
          'district_name': fac?['district'],
          'facility_id': d.facilityId,
          'facility_name': fac?['name'],
          'notes': null,
        });
      } else {
        final districts = d.selectedDistricts;
        if (districts.isEmpty) {
          destinations.add({
            'region_id': rid,
            'region_name': d.regionName,
            'district_id': null,
            'district_name': null,
            'facility_id': d.facilityId,
            'facility_name': d.facilityName,
            'notes': null,
          });
        } else {
          for (final did in districts) {
            final distList = _regionDistricts[rid] ?? [];
            final dist = distList.firstWhere((x) => x['id'] == did, orElse: () => null);
            final facList = _districtFacilities[did] ?? [];
            final fac = d.facilityId != null
                ? facList.firstWhere((f) => '${f['id'] ?? f['code']}' == d.facilityId, orElse: () => null)
                : null;
            destinations.add({
              'region_id': rid,
              'region_name': d.regionName,
              'district_id': did,
              'district_name': dist?['name'],
              'facility_id': d.facilityId,
              'facility_name': fac?['name'],
              'notes': null,
            });
          }
        }
      }
    }

    setState(() => _submitting = true);
    await widget.onSubmit({
      'desired_destinations': destinations,
      'years_of_service': int.tryParse(_years),
    });
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Maeneo ya Lengo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Unataka kwenda mkoa/wilaya gani?', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        ...List.generate(_dests.length, (i) => _buildDestCard(i)),

        TextButton.icon(
          onPressed: () => setState(() => _dests.add(_DestEntry())),
          icon: const Icon(Icons.add),
          label: const Text('Ongeza Mkoa Mwingine'),
        ),

        const SizedBox(height: 16),
        const Text('Umefanya kazi kwa miaka mingapi? *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _years.isEmpty ? null : _years,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          hint: const Text('Chagua miaka ya kazi'),
          items: const [
            DropdownMenuItem(value: '1', child: Text('1')),
            DropdownMenuItem(value: '2', child: Text('2')),
            DropdownMenuItem(value: '3', child: Text('3+ (miaka 3 au zaidi)')),
          ],
          onChanged: (v) => setState(() => _years = v ?? ''),
        ),

        const SizedBox(height: 24),
        Row(children: [
          OutlinedButton(onPressed: _submitting ? null : widget.onBack, child: const Text('Rudi')),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Jisajili'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildDestCard(int i) {
    final d = _dests[i];
    final rid = d.regionId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Mkoa wa Lengo ${i + 1}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Spacer(),
            if (_dests.length > 1)
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                onPressed: () => setState(() => _dests.removeAt(i)),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
          ]),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: rid,
            decoration: InputDecoration(
              hintText: '-- Chagua Mkoa --',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              isDense: true,
            ),
            items: _regions.map((r) => DropdownMenuItem<int>(
              value: r['id'] as int,
              child: Text(r['name'] as String, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) => _onRegionChanged(i, v),
          ),

          // Wizara ya Afya — hospital
          if (_isWizara && rid != null) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: d.facilityId,
              decoration: InputDecoration(
                hintText: 'Chagua Hospitali ya Rufaa',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
              items: (_regionFacilities[rid] ?? []).map((f) => DropdownMenuItem<String>(
                value: '${f['id'] ?? f['code']}',
                child: Text(f['name'] as String? ?? '', style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) => setState(() {
                d.facilityId = v;
                final fac = (_regionFacilities[rid] ?? [])
                    .firstWhere((f) => '${f['id'] ?? f['code']}' == v, orElse: () => null);
                d.facilityName = fac?['name'] as String?;
              }),
            ),
          ],

          // TAMISEMI/Elimu — wilaya checkboxes
          if (!_isWizara && rid != null) ...[
            const SizedBox(height: 8),
            const Text('Wilaya za lengo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _DistCheckbox(
                    label: 'Wilaya yeyote',
                    checked: d.selectedDistricts.isEmpty,
                    onChanged: (_) => setState(() { d.selectedDistricts = []; d.facilityId = null; }),
                  ),
                  ...(_regionDistricts[rid] ?? []).map((dist) {
                    final did = dist['id'] as int;
                    return _DistCheckbox(
                      label: dist['name'] as String,
                      checked: d.selectedDistricts.contains(did),
                      onChanged: (_) => _toggleDistrict(i, did),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DistCheckbox extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool?> onChanged;
  const _DistCheckbox({required this.label, required this.checked, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Checkbox(value: checked, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

// ── Shared error box ──────────────────────────────────────────────────────────
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
      ]),
    );
  }
}
