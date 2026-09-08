import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

const _kBlue = Color(0xFF1E40AF);
const _kGrey300 = Color(0xFFD1D5DB);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey700 = Color(0xFF374151);
const _kGrey900 = Color(0xFF111827);
const _kRed500 = Color(0xFFDC2626); // brand-red
const _kGreen600 = Color(0xFF16A34A);

InputDecoration _inputDec({String? hint, Color borderColor = _kGrey300, Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _kBlue, width: 2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      suffixIcon: suffix,
    );

InputDecoration _dropDec({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _kGrey300)),
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
    );

ButtonStyle _btnPrimary() => ElevatedButton.styleFrom(
      backgroundColor: _kBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
    );

// btn-outline — web: border-brand-grey-300 text-brand-grey-700 px-3 py-1 text-[11px] font-bold rounded-md
ButtonStyle _btnOutline() => OutlinedButton.styleFrom(
      side: const BorderSide(color: _kGrey300), // border-brand-grey-300 = #D1D5DB
      foregroundColor: _kGrey700,               // text-brand-grey-700 = #374151
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );

// Loading row — web: Loader2(spin,20px) mr-2(8px) "Inapakia..." text-sm text-grey-400
Widget _loadingRow({double verticalPad = 32}) => Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPad),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: const [
        SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9CA3AF))),
        SizedBox(width: 8),
        Text('Inapakia...', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
      ]),
    );

// FieldLabel — web: icon size=14 brand-blue + gap-1.5(6px) + label text-sm font-semibold grey-700
Widget _fieldLabel(IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 14, color: _kBlue),
        const SizedBox(width: 6), // gap-1.5=6px
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
      ]),
    );

// FieldError — web: AlertCircle size=12 + text-xs text-red mt-1
Widget _fieldError(String msg) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, size: 12, color: _kRed500),
        const SizedBox(width: 4),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 12, color: _kRed500))),
      ]),
    );

// Button row — web mobile: flex-col-reverse (primary on top, back below), both full-width, gap-2, pt-3
Widget _btnRow({required VoidCallback onBack, required VoidCallback onNext,
    String nextLabel = 'Endelea →', bool nextEnabled = true, bool loading = false}) =>
    Padding(
      padding: const EdgeInsets.only(top: 12), // pt-3
      child: Column(children: [
        SizedBox(
          width: double.infinity,
          height: 28,
          child: ElevatedButton(
            onPressed: (nextEnabled && !loading) ? onNext : null,
            style: _btnPrimary(),
            child: loading
                ? Row(mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 8),
                      Text('Ninajisajili...'),
                    ])
                : Text(nextLabel),
          ),
        ),
        const SizedBox(height: 8), // gap-2
        SizedBox(
          width: double.infinity,
          height: 28,
          child: OutlinedButton(
            onPressed: loading ? null : onBack,
            style: _btnOutline(),
            child: const Text('Rudi'),
          ),
        ),
      ]),
    );

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  String? _error;

  final Map<String, dynamic> _data = {
    'desired_destinations': <Map<String, dynamic>>[],
    'subjects': <String>[],
  };

  void _next(Map<String, dynamic> partial) {
    setState(() { _data.addAll(partial); _step++; _error = null; });
  }

  void _back() {
    if (_step > 0) setState(() { _step--; _error = null; });
  }

  bool get _isHealth => (_data['category'] ?? '') == 'health';
  int get _totalSteps => _isHealth ? 6 : 5;

  String _stepTitle(int n) {
    const health = ['Taarifa', 'Idara', 'Wizara', 'Kada', 'Eneo', 'Maeneo'];
    const edu = ['Taarifa', 'Idara', 'Kada', 'Eneo', 'Maeneo'];
    return _isHealth ? health[n] : edu[n];
  }

  Future<void> _submit(Map<String, dynamic> finalPartial) async {
    _data.addAll(finalPartial);
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(_data);
    if (!mounted) return;
    if (ok) {
      _showSuccessToast();
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (auth.error != null) {
      setState(() => _error = auth.error!);
    }
  }

  void _showSuccessToast() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (ctx) {
      final topPad = MediaQuery.of(ctx).padding.top;
      return Positioned(
        top: topPad + 24, // top-6 = 24px below status bar
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // px-5=20 py-3.5=14
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12), // rounded-xl
                border: Border.all(color: const Color(0xFF86EFAC)), // border-green-300
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                // Green circle with checkmark — w-8 h-8 bg-green-100
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7), // bg-green-100
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check, size: 16, color: Color(0xFF16A34A)), // text-green-600
                  ),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
                  Text('Usajili umefanikiwa',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D))), // text-green-700
                  SizedBox(height: 2),
                  Text('Unaelekezwa kwenye dashibodi...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ]),
              ]),
            ),
          ),
        ),
      );
    });
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = List.generate(_totalSteps, (i) => _stepTitle(i));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Back button — web: inline-flex items-center gap-1.5 text-sm font-medium text-grey-600 mb-4
            GestureDetector(
              onTap: () => Navigator.canPop(context) ? Navigator.pop(context) : null,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF4B5563)), // text-brand-grey-600
                SizedBox(width: 6), // gap-1.5=6px
                Text('Rudi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF4B5563))), // text-brand-grey-600
              ]),
            ),
            const SizedBox(height: 16), // mb-4=16px

            // Badge — web: bg-brand-blue-50 rounded-full text-xs font-semibold text-brand-blue mb-2
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Text('Usajili',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kBlue)),
              ),
            ),
            const SizedBox(height: 8), // mb-2=8px
            // Title — web: text-2xl font-bold text-grey-900
            const Center(
              child: Text('Jaza Taarifa Zako',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _kGrey900)),
            ),
            const SizedBox(height: 4), // mt-1=4px
            // Subtitle — web: text-grey-500
            const Center(
              child: Text('Hatua 4 rahisi. Utamaliza chini ya dakika 3.',
                  style: TextStyle(fontSize: 14, color: _kGrey500)),
            ),
            const SizedBox(height: 24), // mb-6=24px

            _StepBar(currentStep: _step, steps: steps),

            // Global error — web: bg-red-50 border-red-100 AlertCircle(18) rounded-xl p-3.5 gap-2.5 mb-4
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14), // p-3.5=14px
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEE2E2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10), // gap-2.5=10px
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFDC2626))),
                  ),
                ]),
              ),
              const SizedBox(height: 16), // mb-4
            ] else
              const SizedBox(height: 16),

            // Step card — web: .card p-4
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: _buildStep(),
            ),

            // Login link — web: text-sm text-grey-500 mt-6
            const SizedBox(height: 24), // mt-6=24px
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text.rich(TextSpan(
                  text: 'Una akaunti tayari? ',
                  style: const TextStyle(fontSize: 14, color: _kGrey500),
                  children: [
                    TextSpan(
                      text: 'Ingia hapa',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _kBlue),
                    ),
                  ],
                )),
              ),
            ),
          ]),
        ),
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

// ── Step bar — web: w-9 h-9=36px circles border-2, connector h-1 ─────────────
class _StepBar extends StatelessWidget {
  final int currentStep;
  final List<String> steps;
  const _StepBar({required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24), // mb-6=24px
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < currentStep;
          final active = i == currentStep;
          return Expanded(
            child: Row(children: [
              // Left connector — blue if step i-1 is done (i <= currentStep)
              if (i > 0)
                Expanded(
                    child: Container(
                        height: 4,
                        color: i <= currentStep ? _kBlue : const Color(0xFFE5E7EB))),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active || done ? _kBlue : Colors.white,
                    border: Border.all(
                        color: active || done ? _kBlue : const Color(0xFFD1D5DB), width: 2),
                  ),
                  // web: always shows number {s.n}, font-bold text-sm=14px
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: (active || done) ? Colors.white : _kGrey500,
                            fontSize: 14, // text-sm=14px
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[i],
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        color: active ? _kGrey900 : _kGrey500)),
              ]),
              // Right connector — blue if step i is done
              if (i < steps.length - 1)
                Expanded(
                    child: Container(
                        height: 4,
                        color: done ? _kBlue : const Color(0xFFE5E7EB))),
            ]),
          );
        }),
      ),
    );
  }
}

// ── STEP 1: Taarifa Binafsi ──────────────────────────────────────────────────
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
  String _phoneStatus = 'idle'; // idle | checking | available | taken
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

  bool _validPhone(String v) =>
      RegExp(r'^(\+?255|0)\d{9}$').hasMatch(v.replaceAll(RegExp(r'[\s\-]'), ''));

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

  // Status icon — web: Loader2 spin | CheckCircle2 green | AlertCircle red
  Widget _statusIcon(String status) {
    if (status == 'checking') {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9CA3AF))),
      );
    }
    if (status == 'available') {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(Icons.check_circle, size: 16, color: Color(0xFF22C55E)),
      );
    }
    if (status == 'taken') {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(Icons.error_outline, size: 16, color: _kRed500),
      );
    }
    return const SizedBox();
  }

  // Border color based on status
  Color _borderColor(String status) {
    if (status == 'taken') return _kRed500;
    if (status == 'available') return const Color(0xFF22C55E);
    return _kGrey300;
  }

  // Status message below input — web: font-medium(w500) gap-1(4px) size=11
  List<Widget> _statusWidgets(String status, String availableMsg, String takenMsg) {
    if (status == 'available') {
      return [Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          const Icon(Icons.check_circle, size: 11, color: _kGreen600),
          const SizedBox(width: 4),
          Text(availableMsg, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kGreen600)),
        ]),
      )];
    }
    if (status == 'taken') {
      return [Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 11, color: _kRed500),
          const SizedBox(width: 4),
          Text(takenMsg, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kRed500)),
        ]),
      )];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Taarifa Binafsi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kGrey900)),
      const SizedBox(height: 16),

      // Full name
      _fieldLabel(Icons.person_outline, 'Jina Kamili *'),
      TextField(
        controller: _nameCtrl,
        style: const TextStyle(fontSize: 12),
        decoration: _inputDec(hint: 'Jina la kwanza na la ukoo'),
        onChanged: (_) => setState(() => _errors.remove('name')),
      ),
      if (_errors['name'] != null) _fieldError(_errors['name']!),
      const SizedBox(height: 14),

      // Phone primary
      _fieldLabel(Icons.phone_outlined, 'Namba ya Simu *'),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 12),
        decoration: _inputDec(
          hint: '0712345678',
          borderColor: _borderColor(_phoneStatus),
          suffix: _statusIcon(_phoneStatus),
        ),
        onChanged: (v) {
          setState(() => _errors.remove('phone'));
          _onPhoneChanged(v);
        },
      ),
      if (_errors['phone'] != null) _fieldError(_errors['phone']!),
      ..._statusWidgets(_phoneStatus, 'Namba hii ipo huru', 'Namba hii tayari inatumiwa'),
      const SizedBox(height: 14),

      // WhatsApp
      _fieldLabel(Icons.chat_bubble_outline, 'Namba ya WhatsApp *'),
      TextField(
        controller: _altCtrl,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 12),
        decoration: _inputDec(
          hint: '0623456789',
          borderColor: _borderColor(_altStatus),
          suffix: _statusIcon(_altStatus),
        ),
        onChanged: (v) {
          setState(() => _errors.remove('alt'));
          _onAltChanged(v);
        },
      ),
      if (_errors['alt'] != null) _fieldError(_errors['alt']!),
      ..._statusWidgets(_altStatus, 'Namba hii ipo huru', 'Namba hii tayari inatumiwa'),
      const SizedBox(height: 24),

      // Button — web: flex justify-end, btn-primary "Endelea →"
      Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          height: 28, // py-1+text-[11px]+py-1=28px
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
            style: _btnPrimary(),
            child: const Text('Endelea →'),
          ),
        ),
      ),
    ]);
  }
}

// ── STEP 2: Idara ─────────────────────────────────────────────────────────────
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
      final list =
          (res.data as List?)?.where((d) => d['status'] != 'disabled').toList() ?? [];
      if (mounted) setState(() { _departments = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Imeshindikana kupata idara'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Idara',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kGrey900)),
      const SizedBox(height: 4),
      const Text('Unafanya kazi katika idara gani?',
          style: TextStyle(fontSize: 14, color: _kGrey500)),
      const SizedBox(height: 16),

      if (_loading)
        Center(child: _loadingRow(verticalPad: 32)) // py-8
      else if (_error != null)
        _ErrorBox(_error!)
      else ...[
        const Text('Chagua Idara *',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selected.isEmpty ? null : _selected,
          decoration: _dropDec(hint: '-- Chagua Idara --'),
          style: const TextStyle(fontSize: 12, color: _kGrey900),
          items: _departments
              .map((d) => DropdownMenuItem<String>(
                    value: d['code'] as String,
                    child: Text(d['name'] as String, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selected = v ?? ''),
        ),
      ],

      _btnRow(
        onBack: widget.onBack,
        onNext: () => widget.onNext({'category': _selected}),
        nextEnabled: _selected.isNotEmpty,
      ),
    ]);
  }
}

// ── STEP 3: Wizara (health only) ─────────────────────────────────────────────
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Wizara',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kGrey900)),
      const SizedBox(height: 4),
      const Text('Je, unafanya kazi chini ya taasisi gani?',
          style: TextStyle(fontSize: 14, color: _kGrey500)),
      const SizedBox(height: 16),
      const Text('Wizara *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: _sector.isEmpty ? null : _sector,
        decoration: _dropDec(hint: '-- Chagua --'),
        style: const TextStyle(fontSize: 12, color: _kGrey900),
        items: const [
          DropdownMenuItem(
              value: 'wizara_afya',
              child: Text('Wizara ya Afya', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(
              value: 'tamisemi', child: Text('TAMISEMI', style: TextStyle(fontSize: 12))),
        ],
        onChanged: (v) => setState(() => _sector = v ?? ''),
      ),

      _btnRow(
        onBack: widget.onBack,
        onNext: () => widget.onNext({'employment_sector': _sector}),
        nextEnabled: _sector.isNotEmpty,
      ),
    ]);
  }
}

// ── STEP 4: Kada ─────────────────────────────────────────────────────────────
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
      if (sector != null && sector.isNotEmpty) {
        list = list.where((c) {
          final cs = c['employment_sector'];
          return cs == null || cs == sector;
        }).toList();
      }
      if (mounted) setState(() { _cadres = list; _loading = false; });
      if (_cadreCode.isNotEmpty) _onCadreChanged(_cadreCode);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Imeshindikana kupata orodha ya kada'; });
    }
  }

  void _onCadreChanged(String code) {
    setState(() { _cadreCode = code; _subjects = []; _selectedSubjects = []; });
    final cadre = _cadres.firstWhere((c) => c['code'] == code, orElse: () => null);
    if (cadre == null) return;
    final level = cadre['level'] as String?;
    if (level == 'Primary' || level == 'Secondary') _loadSubjects(level!);
  }

  Future<void> _loadSubjects(String level) async {
    setState(() => _loadingSubjects = true);
    try {
      final res = await ApiService().getSubjects(level: level);
      if (mounted) setState(() => _subjects = res.data as List? ?? []);
    } catch (_) {}
    if (mounted) setState(() => _loadingSubjects = false);
  }

  bool get _needsSubjects => _subjects.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Kada',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kGrey900)),
      const SizedBox(height: 16),

      if (_loading)
        Center(child: _loadingRow())
      else ...[
        const Text('Kada *',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _cadreCode.isEmpty ? null : _cadreCode,
          decoration: _dropDec(hint: '-- Chagua Kada --'),
          style: const TextStyle(fontSize: 12, color: _kGrey900),
          items: _cadres
              .map((c) => DropdownMenuItem<String>(
                    value: c['code'] as String,
                    child: Text(
                        c['display_name'] as String? ?? c['code'] as String,
                        style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) _onCadreChanged(v); },
        ),
      ],

      // Subjects — web: styled rows with border/bg, checkbox + emoji + name
      if (_needsSubjects) ...[
        const SizedBox(height: 16),
        Row(children: [
          // web: label class + flex items-center gap-1.5
          const Text('Masomo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
          const Text(' *', style: TextStyle(fontSize: 12, color: _kRed500)),
          const SizedBox(width: 6),
          const Text('(lazima somo 2)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
        ]),
        const SizedBox(height: 6), // mb-1.5=6px
        // "Chagua somo unalofundisha" — web: text-xs text-grey-500 mb-2
        const Text('Chagua somo unalofundisha',
            style: TextStyle(fontSize: 12, color: _kGrey500)),
        const SizedBox(height: 8), // mb-2=8px
        if (_loadingSubjects)
          Center(child: _loadingRow(verticalPad: 24)) // py-6
        else
          Column(
            children: _subjects.map((s) {
              final code = s['code'] as String;
              final name = s['name'] as String;
              final selected = _selectedSubjects.contains(code);
              final disabled = !selected && _selectedSubjects.length >= 2;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4), // space-y-1=4px
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: disabled
                      ? null
                      : () => setState(() {
                            if (selected) { _selectedSubjects.remove(code); }
                            else { _selectedSubjects.add(code); }
                          }),
                  child: Opacity(
                    opacity: disabled ? 0.5 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // px-3 py-2
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFEFF6FF) : Colors.white, // bg-brand-blue-50 or white
                        borderRadius: BorderRadius.circular(8), // rounded-lg
                        border: Border.all(color: selected ? _kBlue : const Color(0xFFE5E7EB)),
                      ),
                      child: Row(children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: IgnorePointer(
                            // IgnorePointer so only GestureDetector above fires (prevents double-toggle)
                            child: Checkbox(
                              value: selected,
                              onChanged: (_) {},
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              activeColor: _kBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10), // gap-2.5=10px
                        Expanded(
                          child: Text(name, // no emoji — web has no emoji
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                  color: selected ? _kBlue : _kGrey700)),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        // Counter — web: BookOpen(12) gap-2(8px) "Umepata: N somoi" text-xs(12) green-600 mt-2(8px)
        if (_selectedSubjects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8), // mt-2=8px
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.menu_book, size: 12, color: _kGreen600), // BookOpen
              const SizedBox(width: 8), // gap-2=8px
              Text(
                'Umepata: ${_selectedSubjects.length} somo${_selectedSubjects.length > 1 ? 'i' : ''}',
                style: const TextStyle(fontSize: 12, color: _kGreen600),
              ),
            ]),
          ),
      ],

      if (_error != null) ...[
        const SizedBox(height: 12),
        _ErrorBox(_error!),
      ],

      _btnRow(
        onBack: widget.onBack,
        onNext: () {
          if (_cadreCode.isEmpty) { setState(() => _error = 'Chagua kada'); return; }
          if (_needsSubjects && _selectedSubjects.length < 2) {
            setState(() => _error = 'Chagua masomo 2 — ni lazima kabisa');
            return;
          }
          setState(() => _error = null);
          widget.onNext({'cadre_code': _cadreCode, 'subjects': _selectedSubjects});
        },
        nextEnabled: _cadreCode.isNotEmpty,
      ),
    ]);
  }
}

// ── STEP 5: Eneo la Sasa ──────────────────────────────────────────────────────
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
      widget.initial['category'] == 'health' &&
      widget.initial['employment_sector'] == 'wizara_afya';

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
      if (mounted) setState(() { _regions = res.data as List? ?? []; _loadingRegions = false; });
      if (_regionId != null) _onRegionChanged(_regionId!);
    } catch (_) {
      if (mounted) setState(() { _loadingRegions = false; _error = 'Imeshindikana kupata mikoa'; });
    }
  }

  Future<void> _onRegionChanged(int rid) async {
    setState(() {
      _regionId = rid;
      _districtId = null;
      _facilityId = null;
      _districts = [];
      _facilities = [];
    });
    if (_isWizara) {
      setState(() => _loadingFacilities = true);
      try {
        final res = await ApiService()
            .getFacilitiesByRegion(rid, category: 'health', employmentSector: 'wizara_afya');
        if (mounted) setState(() => _facilities = res.data as List? ?? []);
      } catch (_) {}
      if (mounted) setState(() => _loadingFacilities = false);
    } else {
      setState(() => _loadingDistricts = true);
      try {
        final res = await ApiService().getDistricts(rid);
        if (mounted) setState(() => _districts = res.data as List? ?? []);
      } catch (_) {}
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _onDistrictChanged(int did) async {
    setState(() { _districtId = did; _facilityId = null; _facilities = []; _loadingFacilities = true; });
    try {
      final cat = widget.initial['category'] as String? ?? 'health';
      final res = await ApiService().getFacilities(did, category: cat);
      if (mounted) setState(() => _facilities = res.data as List? ?? []);
    } catch (_) {}
    if (mounted) setState(() => _loadingFacilities = false);
  }

  void _submit() {
    if (_regionId == null) { setState(() => _error = 'Chagua Mkoa'); return; }
    if (_isWizara && _facilityId == null) { setState(() => _error = 'Chagua Hospitali'); return; }
    if (!_isWizara && _districtId == null) { setState(() => _error = 'Chagua Wilaya'); return; }

    final region = _regions.firstWhere((r) => r['id'] == _regionId, orElse: () => {});
    final district = _districts.firstWhere((d) => d['id'] == _districtId, orElse: () => null);
    final facility = _facilityId != null
        ? _facilities.firstWhere(
            (f) => '${f['id'] ?? f['code']}' == _facilityId, orElse: () => null)
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Eneo la Sasa',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kGrey900)),
      const SizedBox(height: 16),

      if (_error != null) ...[
        _ErrorBox(_error!),
        const SizedBox(height: 12),
      ],

      if (_loadingRegions)
        Center(child: _loadingRow())
      else ...[
        const Text('Mkoa *',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: _regionId,
          decoration: _dropDec(hint: 'Chagua Mkoa'),
          style: const TextStyle(fontSize: 12, color: _kGrey900),
          items: _regions
              .map((r) => DropdownMenuItem<int>(
                    value: r['id'] as int,
                    child: Text(r['name'] as String, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) _onRegionChanged(v); },
        ),

        if (_isWizara && _regionId != null) ...[
          const SizedBox(height: 14),
          const Text('Hospitali ya Rufaa *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
          const SizedBox(height: 6),
          if (_loadingFacilities)
            Center(child: _loadingRow(verticalPad: 8))
          else
            DropdownButtonFormField<String>(
              initialValue: _facilityId,
              decoration: _dropDec(hint: 'Chagua Hospitali'),
              style: const TextStyle(fontSize: 12, color: _kGrey900),
              items: _facilities
                  .map((f) => DropdownMenuItem<String>(
                        value: '${f['id'] ?? f['code']}',
                        child: Text(f['name'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _facilityId = v),
            ),
        ],

        if (!_isWizara && _regionId != null) ...[
          const SizedBox(height: 14),
          const Text('Wilaya *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
          const SizedBox(height: 6),
          if (_loadingDistricts)
            Center(child: _loadingRow(verticalPad: 8))
          else
            DropdownButtonFormField<int>(
              initialValue: _districtId,
              decoration: _dropDec(hint: 'Chagua Wilaya'),
              style: const TextStyle(fontSize: 12, color: _kGrey900),
              items: _districts
                  .map((d) => DropdownMenuItem<int>(
                        value: d['id'] as int,
                        child: Text(d['name'] as String, style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (v) { if (v != null) _onDistrictChanged(v); },
            ),
        ],

        if (!_isWizara && _districtId != null && _facilities.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            widget.initial['category'] == 'health'
                ? 'Hospitali/Kituo (hiari)'
                : 'Shule (hiari)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700),
          ),
          const SizedBox(height: 6),
          if (_loadingFacilities)
            Center(child: _loadingRow(verticalPad: 8))
          else
            DropdownButtonFormField<String>(
              initialValue: _facilityId,
              decoration: _dropDec(hint: 'Chagua (hiari)'),
              style: const TextStyle(fontSize: 12, color: _kGrey900),
              items: _facilities
                  .map((f) => DropdownMenuItem<String>(
                        value: '${f['id'] ?? f['code']}',
                        child: Text(f['name'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _facilityId = v),
            ),
        ],
      ],

      _btnRow(onBack: widget.onBack, onNext: _submit),
    ]);
  }
}

// ── STEP 6: Maeneo ya Lengo ───────────────────────────────────────────────────
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
  const _Step6Destinations(
      {required this.initial, required this.onBack, required this.onSubmit});
  @override
  State<_Step6Destinations> createState() => _Step6DestinationsState();
}

class _Step6DestinationsState extends State<_Step6Destinations> {
  final List<_DestEntry> _dests = [_DestEntry()];
  List<dynamic> _regions = [];
  final Map<int, List<dynamic>> _regionDistricts = {};
  final Map<int, List<dynamic>> _regionFacilities = {};
  final Map<int, bool> _regionFacLoading = {}; // loading per region (Wizara ya Afya)
  final Map<int, List<dynamic>> _districtFacilities = {};
  String _years = '';
  bool _submitting = false;
  String? _error;

  bool get _isWizara =>
      widget.initial['category'] == 'health' &&
      widget.initial['employment_sector'] == 'wizara_afya';

  String get _category => widget.initial['category'] as String? ?? 'health';

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      if (mounted) setState(() => _regions = res.data as List? ?? []);
    } catch (_) {}
  }

  Future<void> _ensureDistricts(int rid) async {
    if (_regionDistricts.containsKey(rid)) return;
    try {
      final res = await ApiService().getDistricts(rid);
      if (mounted) setState(() => _regionDistricts[rid] = res.data as List? ?? []);
    } catch (_) {}
  }

  Future<void> _ensureRegionFacilities(int rid) async {
    if (_regionFacilities.containsKey(rid)) return;
    if (mounted) setState(() => _regionFacLoading[rid] = true);
    try {
      final res = await ApiService()
          .getFacilitiesByRegion(rid, category: 'health', employmentSector: 'wizara_afya');
      if (mounted) setState(() => _regionFacilities[rid] = res.data as List? ?? []);
    } catch (_) {
      if (mounted) setState(() => _regionFacilities[rid] = []);
    } finally {
      if (mounted) setState(() => _regionFacLoading[rid] = false);
    }
  }

  Future<void> _ensureDistrictFacilities(int did) async {
    if (_districtFacilities.containsKey(did)) return;
    try {
      final res = await ApiService().getFacilities(did, category: _category);
      if (mounted) setState(() => _districtFacilities[did] = res.data as List? ?? []);
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
    if (_isWizara) { _ensureRegionFacilities(rid); }
    else { _ensureDistricts(rid); }
  }

  void _toggleDistrict(int destIdx, int did) {
    setState(() {
      final d = _dests[destIdx];
      if (d.selectedDistricts.contains(did)) { d.selectedDistricts.remove(did); }
      else { d.selectedDistricts.add(did); }
    });
    _ensureDistrictFacilities(did);
  }

  Future<void> _submit() async {
    final validDests = _dests.where((d) => d.regionId != null).toList();
    if (validDests.isEmpty) { setState(() => _error = 'Ongeza angalau mkoa mmoja'); return; }
    if (_years.isEmpty) { setState(() => _error = 'Chagua miaka ya kazi'); return; }

    final destinations = <Map<String, dynamic>>[];
    for (final d in validDests) {
      final rid = d.regionId!;
      if (_isWizara) {
        if (d.facilityId == null) {
          setState(() => _error = 'Chagua hospitali kwa mkoa ${d.regionName}');
          return;
        }
        final facList = _regionFacilities[rid] ?? [];
        final fac = facList.firstWhere(
            (f) => '${f['id'] ?? f['code']}' == d.facilityId, orElse: () => null);
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
                ? facList.firstWhere(
                    (f) => '${f['id'] ?? f['code']}' == d.facilityId, orElse: () => null)
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

    setState(() { _submitting = true; _error = null; });
    await widget.onSubmit({
      'desired_destinations': destinations,
      'years_of_service': int.tryParse(_years),
    });
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Maeneo ya Lengo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kGrey900)),
      const SizedBox(height: 4),
      const Text('Unataka kwenda mkoa/wilaya gani?',
          style: TextStyle(fontSize: 14, color: _kGrey500)),
      const SizedBox(height: 16),

      if (_error != null) ...[
        _ErrorBox(_error!),
        const SizedBox(height: 12),
      ],

      ...List.generate(_dests.length, (i) => _buildDestCard(i)),

      // "Ongeza Mkoa Mwingine" — web: Plus(16) gap-1.5(6px) text-sm font-semibold text-brand-blue
      GestureDetector(
        onTap: () => setState(() => _dests.add(_DestEntry())),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.add, size: 16, color: _kBlue),
            SizedBox(width: 6), // gap-1.5=6px
            Text('Ongeza Mkoa Mwingine',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kBlue)),
          ]),
        ),
      ),

      // Years of service — web: pt-2=8px label then select
      const SizedBox(height: 8), // pt-2=8px
      const Text('Umefanya kazi kwa miaka mingapi? *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: _years.isEmpty ? null : _years,
        decoration: _dropDec(hint: 'Chagua miaka ya kazi'),
        style: const TextStyle(fontSize: 12, color: _kGrey900), // .input = text-xs=12px
        items: const [
          DropdownMenuItem(value: '1', child: Text('1', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: '2', child: Text('2', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(
              value: '3',
              child: Text('3+ (miaka 3 au zaidi)', style: TextStyle(fontSize: 12))),
        ],
        onChanged: (v) => setState(() => _years = v ?? ''),
      ),

      _btnRow(
        onBack: widget.onBack,
        onNext: _submit,
        nextLabel: 'Najisajili',
        loading: _submitting,
      ),
    ]);
  }

  Widget _buildDestCard(int i) {
    final d = _dests[i];
    final rid = d.regionId;
    final isLoading = rid != null && (_regionFacLoading[rid] == true);

    // TAMISEMI: collect facilities from selected districts (or empty if none selected)
    final selectedDids = d.selectedDistricts;
    final seen = <String>{};
    final tamisemiFacs = selectedDids
        .expand((did) => _districtFacilities[did] ?? [])
        .where((f) => seen.add('${f['id'] ?? f['code']}'))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12), // p-3=12px
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // bg-brand-grey-50
        borderRadius: BorderRadius.circular(12), // rounded-xl
        border: Border.all(color: const Color(0xFFE5E7EB)), // border-brand-grey-200
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header — web: text-[11px] font-bold text-brand-blue flex items-center gap-1
        Row(children: [
          const Icon(Icons.keyboard_arrow_down, size: 12, color: _kBlue),
          const SizedBox(width: 4), // gap-1=4px
          Expanded(
            child: Text('Mkoa wa Lengo ${i + 1}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kBlue)),
          ),
          if (_dests.length > 1)
            GestureDetector(
              onTap: () => setState(() => _dests.removeAt(i)),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
              ),
            ),
        ]),
        const SizedBox(height: 12),

        // Region select — web: input text-sm → fontSize 14
        DropdownButtonFormField<int>(
          initialValue: rid,
          decoration: _dropDec(hint: '— Chagua Mkoa wa Lengo —'),
          style: const TextStyle(fontSize: 14, color: _kGrey900),
          items: _regions
              .map((r) => DropdownMenuItem<int>(
                    value: r['id'] as int,
                    child: Text(r['name'] as String, style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (v) => _onRegionChanged(i, v),
        ),

        // ── Wizara ya Afya: Hospitali ya Rufaa ──
        if (_isWizara && rid != null) ...[
          const SizedBox(height: 12),
          if (isLoading)
            // web: <div className="input text-sm text-brand-grey-400">Inapakia hospitali...</div>
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kGrey300),
              ),
              child: const Text('Inapakia hospitali...',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: d.facilityId,
              decoration: _dropDec(hint: 'Chagua Hospitali ya Rufaa'),
              style: const TextStyle(fontSize: 14, color: _kGrey900),
              items: (_regionFacilities[rid] ?? [])
                  .map((f) => DropdownMenuItem<String>(
                        value: '${f['id'] ?? f['code']}',
                        child: Text(
                          '${f['name']}${f['type'] != null ? ' (${f['type']})' : ''}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                d.facilityId = v;
                final fac = (_regionFacilities[rid] ?? [])
                    .firstWhere((f) => '${f['id'] ?? f['code']}' == v, orElse: () => null);
                d.facilityName = fac?['name'] as String?;
              }),
            ),
        ],

        // ── TAMISEMI/Elimu: Wilaya checkboxes + Kituo ──
        if (!_isWizara && rid != null) ...[
          const SizedBox(height: 12),
          // web: text-[10px] font-bold text-brand-grey-500 uppercase
          const Text('WILAYA ZA LENGO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kGrey500)),
          const SizedBox(height: 6),
          // Wilaya checkboxes — web: bg-white rounded-lg p-2 border-brand-grey-200 space-y-1.5
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(children: [
              _DistCheckbox(
                label: 'Wilaya yeyote',
                bold: true,
                checked: d.selectedDistricts.isEmpty,
                onChanged: (_) => setState(() {
                  d.selectedDistricts = [];
                  d.facilityId = null;
                  d.facilityName = null;
                }),
              ),
              ...(_regionDistricts[rid] ?? []).map((dist) {
                final did = dist['id'] as int;
                return _DistCheckbox(
                  label: dist['name'] as String,
                  checked: d.selectedDistricts.contains(did),
                  onChanged: (_) => _toggleDistrict(i, did),
                );
              }),
            ]),
          ),
          const SizedBox(height: 8),
          // Kituo select — web: input text-sm (optional)
          DropdownButtonFormField<String>(
            initialValue: d.facilityId,
            decoration: _dropDec(
              hint: _category == 'health'
                  ? 'Chagua Hospitali/Kituo (hiari)'
                  : 'Chagua Shule (hiari)',
            ),
            style: const TextStyle(fontSize: 14, color: _kGrey900),
            items: tamisemiFacs
                .map((f) => DropdownMenuItem<String>(
                      value: '${f['id'] ?? f['code']}',
                      child: Text(
                        '${f['name']}${f['type'] != null ? ' (${f['type']})' : ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              d.facilityId = v;
              final fac = tamisemiFacs.firstWhere(
                  (f) => '${f['id'] ?? f['code']}' == v, orElse: () => null);
              d.facilityName = fac?['name'] as String?;
            }),
          ),
        ],
      ]),
    );
  }
}

class _DistCheckbox extends StatelessWidget {
  final String label;
  final bool checked;
  final bool bold;
  final ValueChanged<bool?> onChanged;
  const _DistCheckbox({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.bold = false,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3), // space-y-1.5
        child: Row(children: [
          SizedBox(
            width: 14, height: 14, // w-3.5 h-3.5=14px
            child: IgnorePointer(
              child: Checkbox(
                value: checked,
                onChanged: (_) {},
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: _kBlue,
              ),
            ),
          ),
          const SizedBox(width: 8), // gap-2=8px
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: bold ? _kGrey700 : const Color(0xFF4B5563), // grey-700 vs grey-600
              )),
        ]),
      ),
    );
  }
}

// Step-level inline error — web: bg-red-50 border-red-100 AlertCircle(16) p-3(12px) gap-2(8px) text-sm(14) font-medium rounded-xl
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // p-3=12px
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // bg-red-50
        borderRadius: BorderRadius.circular(12), // rounded-xl
        border: Border.all(color: const Color(0xFFFEE2E2)), // border-red-100
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)), // size=16
        const SizedBox(width: 8), // gap-2=8px
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 14, // text-sm
                  fontWeight: FontWeight.w500, // font-medium
                  color: Color(0xFFDC2626))),
        ),
      ]),
    );
  }
}
