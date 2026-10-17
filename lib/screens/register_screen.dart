// ============================================================================
// REGISTRATION FLOW (Flutter)
//
// MAELEKEZO KWA AI: USIBADILISHE muonekano, rangi, icons, ukubwa wa vitufe wala
// mpangilio wa ukurasa huu. Unganisha API kwa kutekeleza tu `RegistrationRepository`
// (angalia chini) na kuipitisha kwenye `RegistrationFlowPage`.
//
// pubspec.yaml:  flutter pub add tabler_icons_plus
//
// Matumizi:
//   RegistrationFlowPage(
//     repository: MyApiRepository(),      // au MockRegistrationRepository()
//     onLoginTap: () { /* nenda login */ },
//     onFinished: (data) { /* data.toJson() */ },
//   )
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../widgets/app_toast.dart' show AppToast, friendlyError;

// ============================================================================
// RANGI (badilisha hapa tu kama unataka bluu nyingine)
// ============================================================================
class _C {
  static const blue = Color(0xFF1E40AF);
  static const blueSoft = Color(0xFFEFF3FF);
  static const blueBorder = Color(0xFFBFD0F5);
  static const text = Color(0xFF111827);
  static const textSec = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const borderStronger = Color(0xFF9CA3AF);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const surface = Color(0xFFF3F4F6);
}

// ============================================================================
// ICONS: zote ziko sehemu moja na ni Tabler Icons (package: tabler_icons_plus),
// zile zile za mockup. Ongeza kwenye pubspec: flutter pub add tabler_icons_plus
// ============================================================================
class RegIcons {
  RegIcons._();
  static const IconData back = TablerIcons.arrowLeft;
  static const IconData next = TablerIcons.arrowRight;
  static const IconData edit = TablerIcons.pencil;
  static const IconData add = TablerIcons.plus;
  static const IconData search = TablerIcons.search;
  static const IconData chevronUp = TablerIcons.chevronUp;
  static const IconData chevronDown = TablerIcons.chevronDown;
  static const IconData ok = TablerIcons.circleCheck;
  static const IconData bad = TablerIcons.circleX;
  static const IconData check = TablerIcons.check;
  static const IconData name = TablerIcons.userSquareRounded;
  static const IconData phone = TablerIcons.phone;
  static const IconData whatsapp = TablerIcons.brandWhatsapp;
  static const IconData afya = TablerIcons.stethoscope;
  static const IconData elimu = TablerIcons.school;
  static const IconData kilimo = TablerIcons.wheat;
  static const IconData umma = TablerIcons.buildingCommunity;
  static const IconData wizaraAfya = TablerIcons.buildingBank;
  static const IconData tamisemi = TablerIcons.buildingCommunity;
  static const IconData msingi = TablerIcons.blocks;
  static const IconData sekondari = TablerIcons.mathFunction;
  static const IconData cheo = TablerIcons.stethoscope;
  static const IconData mkoa = TablerIcons.mapPin;
  static const IconData wilaya = TablerIcons.building;
  static const IconData shule = TablerIcons.school;
  static const IconData kituo = TablerIcons.buildingHospital;
  static const IconData mwaka1 = TablerIcons.calendar;
  static const IconData miaka2 = TablerIcons.calendarStats;
  static const IconData miaka3 = TablerIcons.medal;
  static const IconData register = TablerIcons.userPlus;
  static const IconData route = TablerIcons.route;
}

// ============================================================================
// MODELS
// ============================================================================
/// API mara nyingine inarudisha maandishi kama "ST. RITA&#039;S" au "D &amp; T".
/// Hii inayabadilisha kuwa herufi za kawaida.
String decodeHtmlEntities(String s) {
  if (!s.contains('&')) return s;
  var out = s.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.parse(m[1]!)),
  );
  out = out.replaceAllMapped(
    RegExp(r'&#[xX]([0-9a-fA-F]+);'),
    (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
  );
  return out
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');
}

class RegOption {
  final String id;
  final String label;
  final String? subtitle;
  RegOption({required this.id, required String label, String? subtitle})
      : label = decodeHtmlEntities(label),
        subtitle = subtitle == null ? null : decodeHtmlEntities(subtitle);

  @override
  bool operator ==(Object other) => other is RegOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

enum EduLevel { msingi, sekondari }

class RegTargetData {
  final RegOption region;
  final bool anyDistrict;
  final List<RegOption> districts;
  final RegOption? facility;
  const RegTargetData({
    required this.region,
    required this.anyDistrict,
    required this.districts,
    this.facility,
  });

  Map<String, dynamic> toJson() => {
        'region': region.toJson(),
        'anyDistrict': anyDistrict,
        'districts': districts.map((d) => d.toJson()).toList(),
        'facility': facility?.toJson(),
      };
}

class RegistrationData {
  final String name;
  final String phone;
  final String whatsapp;
  final String idara; // Afya, Elimu, Kilimo na ufugaji, Watumishi wa Umma
  final String? wizara; // Wizara ya Afya au TAMISEMI (Afya tu)
  final RegOption? cheo; // Afya tu
  final EduLevel? level; // si Afya
  final List<RegOption> subjects; // si Afya
  final RegOption region;
  final RegOption? district; // si Wizara ya Afya
  final RegOption? school; // Elimu na zingine
  final RegOption? facility; // Afya, TAMISEMI
  final RegOption? hospital; // Wizara ya Afya
  final List<RegTargetData> targets;
  final RegOption? targetHospital; // Wizara ya Afya, hiari
  final String years; // Mwaka 1, Miaka 2, Miaka 3+

  const RegistrationData({
    required this.name,
    required this.phone,
    required this.whatsapp,
    required this.idara,
    this.wizara,
    this.cheo,
    this.level,
    this.subjects = const [],
    required this.region,
    this.district,
    this.school,
    this.facility,
    this.hospital,
    required this.targets,
    this.targetHospital,
    required this.years,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'whatsapp': whatsapp,
        'idara': idara,
        'wizara': wizara,
        'cheo': cheo?.toJson(),
        'level': level?.name,
        'subjects': subjects.map((s) => s.toJson()).toList(),
        'region': region.toJson(),
        'district': district?.toJson(),
        'school': school?.toJson(),
        'facility': facility?.toJson(),
        'hospital': hospital?.toJson(),
        'targets': targets.map((t) => t.toJson()).toList(),
        'targetHospital': targetHospital?.toJson(),
        'years': years,
      };
}

// ============================================================================
// REPOSITORY: hapa ndipo unaunganisha API zako.
// Tengeneza class inayotekeleza interface hii na uipitishe kwenye
// RegistrationFlowPage. Mfano wa data uko kwenye
// mock_registration_repository.dart
// ============================================================================
abstract class RegistrationRepository {
  Future<bool> isPhoneAvailable(String phone);
  Future<List<RegOption>> regions();
  Future<List<RegOption>> districts(RegOption region);
  Future<List<RegOption>> schools(RegOption district);
  Future<List<RegOption>> facilities(RegOption district);
  Future<List<RegOption>> referralHospitals(RegOption region);
  Future<List<RegOption>> cadres();
  Future<List<RegOption>> subjects(EduLevel level);
  Future<void> submit(RegistrationData data);
}

/// Kosa la usajili lenye UJUMBE HALISI — inatupwa na repo (register_repo.dart)
/// ujumbe wa backend (namba imetumika, kada isiyo sahihi n.k.) ukionyeshwa kama
/// ulivyo kwenye skrini ya usajili. Sio ujumbe generic.
class RegisterException implements Exception {
  final String message;
  RegisterException(this.message);
  @override
  String toString() => message;
}

// ============================================================================
// PAGE
// ============================================================================
enum _PhoneStatus { idle, checking, available, taken }

Color? _statusColor(_PhoneStatus s) => s == _PhoneStatus.available
    ? _C.success
    : (s == _PhoneStatus.taken ? _C.danger : null);

class _Target {
  RegOption? region;
  List<RegOption> districts = [];
  bool anyDistrict = false;
  RegOption? facility;
}

class RegistrationFlowPage extends StatefulWidget {
  final RegistrationRepository repository;
  final VoidCallback? onLoginTap;
  final ValueChanged<RegistrationData>? onFinished;

  const RegistrationFlowPage({
    super.key,
    required this.repository,
    this.onLoginTap,
    this.onFinished,
  });

  @override
  State<RegistrationFlowPage> createState() => _RegistrationFlowPageState();
}

class _RegistrationFlowPageState extends State<RegistrationFlowPage> {
  static const _idaraItems = <_Item>[
    _Item('Afya', RegIcons.afya),
    _Item('Elimu', RegIcons.elimu),
    _Item('Kilimo na ufugaji', RegIcons.kilimo),
    _Item('Watumishi wa Umma', RegIcons.umma),
  ];
  static const _wizaraItems = <_Item>[
    _Item('Wizara ya Afya', RegIcons.wizaraAfya),
    _Item('TAMISEMI', RegIcons.tamisemi),
  ];
  static const _yearsItems = <_Item>[
    _Item('Mwaka 1', RegIcons.mwaka1),
    _Item('Miaka 2', RegIcons.miaka2),
    _Item('Miaka 3+', RegIcons.miaka3),
  ];
  static final _noHospital = RegOption(id: '__none__', label: 'Bila Hospitali (Hiari)');

  RegistrationRepository get _repo => widget.repository;

  final _scroll = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  int _step = 0;
  bool _finished = false;
  bool _submitting = false;
  String? _error;
  // Makosa ya kila uga wa 'Taarifa' — yanaonyeshwa CHINI ya uga husika,
  // sio ujumbe mmoja wa jina pekee. Yote hujifuta (auto-dismiss).
  String? _nameError;
  String? _phoneError;
  String? _waError;
  Timer? _errorTimer;
  String? _open; // dropdown iliyo wazi
  String? _edit; // orodha inayobadilishwa

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  _PhoneStatus _phoneStatus = _PhoneStatus.idle;
  _PhoneStatus _waStatus = _PhoneStatus.idle;
  int _phoneReq = 0;
  int _waReq = 0;

  String? _idara;
  String? _wizara;
  RegOption? _cheo;
  EduLevel _level = EduLevel.sekondari;
  List<RegOption> _subjects = [];
  RegOption? _region;
  RegOption? _district;
  RegOption? _school;
  RegOption? _facility;
  RegOption? _hospital;
  List<_Target> _targets = [_Target()];
  RegOption? _targetHospital;
  String? _years;

  bool get _isAfya => _idara == 'Afya';
  bool get _isWA => _isAfya && _wizara == 'Wizara ya Afya';

  List<String> get _steps => _isAfya
      ? const ['Taarifa', 'Idara', 'Wizara', 'Kada', 'Eneo', 'Maeneo']
      : const ['Taarifa', 'Idara', 'Kada', 'Eneo', 'Maeneo'];

  @override
  void dispose() {
    _errorTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Kosa linajiondoa lenyewe — mtumiaji hakubaki na ujumbe uleule muda
  /// mrefu (tazama footer + maeneo ya uga).
  void _scheduleErrorDismiss() {
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _error = null;
        _nameError = null;
        _phoneError = null;
        _waError = null;
      });
    });
  }

  // --------------------------------------------------------------------------
  // BUILD
  // --------------------------------------------------------------------------
  GlobalKey _sectionKey(String id) => _sectionKeys.putIfAbsent(id, () => GlobalKey());

  /// Baada ya kuchagua, orodha inajifunga na ukurasa unapanda juu kuonyesha
  /// kilichochaguliwa na orodha inayofuata.
  void _reveal(String id, {double alignment = 0.04}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: alignment,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, cons) {
            final minH = math.max(0.0, cons.maxHeight - 42);
            return SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minH),
                child: Align(
                  // Kila hatua fupi inakaa katikati ya screen (ikiwa ndefu, inatembea)
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(),
                        const SizedBox(height: 14),
                        _card(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _C.blueSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _C.blueBorder, width: 0.5),
          ),
          child: const Text(
            'Usajili',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _C.blue),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Jaza Taarifa Zako',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: _C.text),
        ),
        const SizedBox(height: 2),
        const Text(
          'Hatua chache rahisi. Utamaliza chini ya dakika 3.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _C.textSec),
        ),
      ],
    );
  }

  Widget _card() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _finished
            ? _doneChildren()
            : [_progress(), ..._stepBody(), _footer()],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PROGRESS
  // --------------------------------------------------------------------------
  Widget _progress() {
    final steps = _steps;
    final total = steps.length;
    final n = _step + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                steps[_step],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: _C.blue),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Hatua $n ya $total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _C.textSec)),
            ),
            const Spacer(),
            Text(
              '${(n * 100 / total).round()}%',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _C.blue),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < n ? _C.blue : _C.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (int i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  steps[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == _step ? FontWeight.w500 : FontWeight.w400,
                    color: i == _step ? _C.blue : _C.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // STEPS
  // --------------------------------------------------------------------------
  List<Widget> _stepBody() {
    switch (_steps[_step]) {
      case 'Taarifa':
        return _taarifaStep();
      case 'Idara':
        return _idaraStep();
      case 'Wizara':
        return _wizaraStep();
      case 'Kada':
        return _kadaStep();
      case 'Eneo':
        return _eneoStep();
      default:
        return _maeneoStep();
    }
  }

  // ---- 1. Taarifa -----------------------------------------------------------
  List<Widget> _taarifaStep() {
    return [
      const _Head('Taarifa Zako', 'Tuanze na taarifa zako za msingi.'),
      _label('Jina kamili'),
      _UnderlineField(
        icon: RegIcons.name,
        hint: 'Andika jina lako',
        controller: _nameCtrl,
        keyboardType: TextInputType.name,
        capitalization: TextCapitalization.words,
        onChanged: (_) => setState(() => _nameError = null),
        errorText: _nameError,
      ),
      _label('Namba ya simu'),
      _UnderlineField(
        icon: RegIcons.phone,
        hint: '07xxxxxxxx',
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        onChanged: (v) => _checkPhone(v, false),
        underlineColor: _phoneError != null ? _C.danger : _statusColor(_phoneStatus),
        errorText: _phoneError,
      ),
      _PhoneStatusRow(status: _phoneStatus),
      _label('Namba ya WhatsApp'),
      _UnderlineField(
        icon: RegIcons.whatsapp,
        hint: '07xxxxxxxx',
        controller: _waCtrl,
        keyboardType: TextInputType.phone,
        onChanged: (v) => _checkPhone(v, true),
        underlineColor: _waError != null ? _C.danger : _statusColor(_waStatus),
        errorText: _waError,
      ),
      _PhoneStatusRow(status: _waStatus),
    ];
  }

  Future<void> _checkPhone(String v, bool wa) async {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    final id = wa ? ++_waReq : ++_phoneReq;
    if (digits.length < 10) {
      setState(() {
        // Mtumiaji ameanza kurekebisha — kosa liondoke mara moja.
        _phoneError = null;
        _waError = null;
        if (wa) {
          _waStatus = _PhoneStatus.idle;
        } else {
          _phoneStatus = _PhoneStatus.idle;
        }
      });
      return;
    }
    setState(() {
      if (wa) {
        _waError = null;
        _waStatus = _PhoneStatus.checking;
      } else {
        _phoneError = null;
        _phoneStatus = _PhoneStatus.checking;
      }
    });
    bool available;
    try {
      available = await _repo.isPhoneAvailable(v.trim());
    } catch (_) {
      available = true;
    }
    if (!mounted) return;
    if ((wa ? _waReq : _phoneReq) != id) return;
    setState(() {
      final s = available ? _PhoneStatus.available : _PhoneStatus.taken;
      if (wa) {
        _waStatus = s;
      } else {
        _phoneStatus = s;
      }
    });
  }

  // ---- 2. Idara -------------------------------------------------------------
  List<Widget> _idaraStep() {
    return [
      const _Head('Idara', 'Unafanya kazi katika idara gani?'),
      _ChoiceCards(
        items: _idaraItems,
        selected: _idara,
        onTap: (i) => _pickIdara(_idaraItems[i].label),
      ),
    ];
  }

  void _pickIdara(String v) {
    setState(() {
      if (v != _idara) {
        _wizara = null;
        _cheo = null;
        _level = EduLevel.sekondari;
        _subjects = [];
        _region = null;
        _district = null;
        _school = null;
        _facility = null;
        _hospital = null;
        _targets = [_Target()];
        _targetHospital = null;
        _years = null;
      }
      _idara = v;
      _error = null;
    });
  }

  // ---- 3. Wizara (Afya tu) --------------------------------------------------
  List<Widget> _wizaraStep() {
    return [
      const _Head('Wizara', 'Je, unafanya kazi chini ya taasisi gani?'),
      _ChoiceCards(
        items: _wizaraItems,
        selected: _wizara,
        onTap: (i) {
          final v = _wizaraItems[i].label;
          setState(() {
            if (v != _wizara) {
              _region = null;
              _district = null;
              _school = null;
              _facility = null;
              _hospital = null;
              _targets = [_Target()];
              _targetHospital = null;
            }
            _wizara = v;
            _error = null;
          });
        },
      ),
    ];
  }

  // ---- 4. Kada --------------------------------------------------------------
  List<Widget> _kadaStep() {
    if (_isAfya) {
      return [
        const _Head('Kada / Cheo Chako', 'Chagua kada au cheo chako cha kazi.'),
        _choose(
          id: 'cheo',
          label: 'Cheo',
          icon: RegIcons.cheo,
          value: _cheo,
          loadKey: 'cadres',
          load: () => _repo.cadres(),
          onPick: (o) => _cheo = o,
        ),
      ];
    }
    final sek = _level == EduLevel.sekondari;
    return [
      const _Head('Kada', null),
      const SizedBox(height: 10),
      _Segmented(
        leftLabel: 'Msingi',
        leftIcon: RegIcons.msingi,
        rightLabel: 'Sekondari',
        rightIcon: RegIcons.sekondari,
        rightSelected: sek,
        onChanged: (right) {
          setState(() {
            final nl = right ? EduLevel.sekondari : EduLevel.msingi;
            if (nl != _level) {
              _level = nl;
              _subjects = [];
            }
            _error = null;
          });
        },
      ),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Masomo ya ${sek ? 'Sekondari' : 'Msingi'}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _C.text),
              ),
              const TextSpan(text: ' *', style: TextStyle(fontSize: 15, color: _C.danger)),
              const TextSpan(
                text: ' (lazima somo 2)',
                style: TextStyle(fontSize: 12, color: _C.textMuted),
              ),
            ],
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text('Chagua somo unalofundisha', style: TextStyle(fontSize: 13, color: _C.textSec)),
      ),
      const SizedBox(height: 6),
      _Async(
        key: ValueKey('subjects-${_level.name}'),
        load: () => _repo.subjects(_level),
        builder: (opts) => _TwoCol(
          children: [
            for (final o in opts)
              _OptionRow(
                label: o.label,
                selected: _subjects.contains(o),
                onTap: () {
                  setState(() {
                    if (_subjects.contains(o)) {
                      _subjects.remove(o);
                      _error = null;
                    } else if (_subjects.length < 2) {
                      _subjects.add(o);
                      _error = null;
                    } else {
                      _error = 'Unaweza kuchagua masomo 2 tu.';
                    }
                  });
                },
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'Umepata: ${_subjects.length} somo',
          style: const TextStyle(fontSize: 12, color: _C.textSec),
        ),
      ),
    ];
  }

  // ---- 5. Eneo la sasa ------------------------------------------------------
  List<Widget> _eneoStep() {
    final list = <Widget>[];
    if (_isWA) {
      list.add(const _Head('Eneo la Sasa', 'Mkoa na hospitali unayofanya kazi.'));
      list.add(_regionChooser());
      if (_region != null && _edit != 'mkoa') {
        final r = _region!;
        list.add(_choose(
          id: 'hosp',
          label: 'Hospitali ya rufaa za mkoa',
          sub: 'Chagua hospitali unayofanya kazi',
          icon: RegIcons.kituo,
          value: _hospital,
          loadKey: 'hosp-${r.id}',
          load: () => _repo.referralHospitals(r),
          onPick: (o) => _hospital = o,
        ));
      }
      return list;
    }
    list.add(const _Head('Eneo la Sasa', 'Unafanya kazi wapi sasa?'));
    list.add(_regionChooser());
    if (_region != null && _edit != 'mkoa') {
      final r = _region!;
      list.add(_choose(
        id: 'wilaya',
        label: 'Wilaya',
        sub: 'Chagua wilaya',
        icon: RegIcons.wilaya,
        value: _district,
        loadKey: 'dist-${r.id}',
        load: () => _repo.districts(r),
        onPick: (o) {
          if (o != _district) {
            _school = null;
            _facility = null;
          }
          _district = o;
        },
      ));
      if (_district != null && _edit != 'wilaya') {
        final d = _district!;
        if (_isAfya) {
          list.add(_dropdown(
            id: 'kituo',
            label: 'Kituo',
            icon: RegIcons.kituo,
            value: _facility,
            placeholder: 'Chagua Kituo',
            loadKey: 'fac-${d.id}',
            load: () => _repo.facilities(d),
            onPick: (o) => _facility = o,
          ));
        } else {
          list.add(_dropdown(
            id: 'shule',
            label: 'Shule',
            icon: RegIcons.shule,
            value: _school,
            placeholder: 'Chagua Shule',
            loadKey: 'sch-${d.id}',
            load: () => _repo.schools(d),
            onPick: (o) => _school = o,
          ));
        }
      }
    }
    return list;
  }

  Widget _regionChooser() {
    return _choose(
      id: 'mkoa',
      label: 'Mkoa',
      sub: 'Chagua mkoa unaofanyia kazi',
      icon: RegIcons.mkoa,
      value: _region,
      loadKey: 'regions',
      load: () => _repo.regions(),
      onPick: (o) {
        if (o != _region) {
          _district = null;
          _school = null;
          _facility = null;
          _hospital = null;
        }
        _region = o;
      },
    );
  }

  // ---- 6. Maeneo ya lengo ---------------------------------------------------
  List<Widget> _maeneoStep() {
    final list = <Widget>[
      _Head(
        'Maeneo ya Lengo',
        _isWA ? 'Unataka kwenda mkoa gani?' : 'Unataka kwenda mkoa/wilaya gani?',
      ),
    ];

    if (_isWA) {
      final t0 = _targets[0];
      list.add(_choose(
        id: 'tm0',
        label: 'Mkoa wa Lengo',
        sub: 'Chagua mkoa unaotaka kwenda',
        icon: RegIcons.mkoa,
        value: t0.region,
        loadKey: 'regions',
        load: () => _repo.regions(),
        onPick: (o) {
          if (o != t0.region) _targetHospital = null;
          t0.region = o;
        },
      ));
      if (t0.region != null && _edit != 'tm0') {
        final r = t0.region!;
        list.add(_dropdown(
          id: 'lh',
          label: 'Hospitali ya rufaa ya mkoa',
          icon: RegIcons.kituo,
          value: _targetHospital,
          placeholder: 'Bila Hospitali',
          loadKey: 'lh-${r.id}',
          load: () async => [_noHospital, ...await _repo.referralHospitals(r)],
          onPick: (o) => _targetHospital = o.id == _noHospital.id ? null : o,
          fallbackSelectedId: _noHospital.id,
        ));
      }
    } else {
      for (int i = 0; i < _targets.length; i++) {
        list.add(_targetCard(i));
      }
      if (_targets.length < 3) {
        list.add(InkWell(
          onTap: () => setState(() => _targets.add(_Target())),
          child: const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Row(
              children: [
                Icon(RegIcons.add, size: 18, color: _C.blue),
                SizedBox(width: 8),
                Text(
                  'Ongeza Mkoa Mwingine',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _C.blue),
                ),
              ],
            ),
          ),
        ));
      }
    }

    list.add(const Padding(
      padding: EdgeInsets.only(top: 18),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Umefanya kazi kwa miaka mingapi?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _C.text),
            ),
            TextSpan(text: ' *', style: TextStyle(fontSize: 15, color: _C.danger)),
          ],
        ),
      ),
    ));
    list.add(const Padding(
      padding: EdgeInsets.only(top: 2),
      child: Text('Chagua miaka ya kazi', style: TextStyle(fontSize: 13, color: _C.textSec)),
    ));
    list.add(_ChoiceCards(
      items: _yearsItems,
      selected: _years,
      onTap: (i) => setState(() {
        _years = _yearsItems[i].label;
        _error = null;
      }),
    ));
    return list;
  }

  Widget _targetCard(int i) {
    final t = _targets[i];
    final id = 'tm$i';
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Mkoa wa Lengo ${i + 1}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _C.blue),
        ),
      ),
      _choose(
        id: id,
        label: 'Mkoa wa Lengo',
        sub: 'Chagua mkoa unaotaka kwenda',
        icon: RegIcons.mkoa,
        value: t.region,
        loadKey: 'regions',
        load: () => _repo.regions(),
        onPick: (o) {
          if (o != t.region) {
            t.districts = [];
            t.anyDistrict = false;
            t.facility = null;
          }
          t.region = o;
        },
      ),
    ];

    if (t.region != null && _edit != id) {
      final r = t.region!;
      children.add(const Padding(
        padding: EdgeInsets.only(top: 14),
        child: Text('Wilaya za lengo', style: TextStyle(fontSize: 12, color: _C.textSec)),
      ));
      children.add(const SizedBox(height: 2));
      children.add(_Async(
        key: ValueKey('tdist-${r.id}'),
        load: () => _repo.districts(r),
        builder: (opts) => _TwoCol(
          children: [
            _OptionRow(
              label: 'Wilaya yeyote',
              selected: t.anyDistrict,
              minHeight: 44,
              onTap: () => setState(() {
                t.anyDistrict = !t.anyDistrict;
                if (t.anyDistrict) t.districts = [];
                t.facility = null;
                _error = null;
              }),
            ),
            for (final d in opts)
              _OptionRow(
                label: d.label,
                selected: t.districts.contains(d),
                minHeight: 44,
                onTap: () => setState(() {
                  t.anyDistrict = false;
                  if (t.districts.contains(d)) {
                    t.districts.remove(d);
                  } else {
                    t.districts.add(d);
                  }
                  t.facility = null;
                  _error = null;
                }),
              ),
          ],
        ),
      ));

      Future<List<RegOption>> loadFacilityOptions(bool schools) async {
        final d = t.districts.isNotEmpty ? t.districts.first : (await _repo.districts(r)).first;
        return schools ? _repo.schools(d) : _repo.facilities(d);
      }

      final firstKey = t.districts.isNotEmpty ? t.districts.first.id : 'any';
      if (_isAfya) {
        children.add(_dropdown(
          id: 'tk$i',
          label: 'Kituo',
          icon: RegIcons.kituo,
          value: t.facility,
          placeholder: 'Bila Kituo',
          loadKey: 'tfac-${r.id}-$firstKey',
          load: () => loadFacilityOptions(false),
          onPick: (o) => t.facility = o,
        ));
      } else {
        children.add(_dropdown(
          id: 'tk$i',
          label: 'Shule',
          icon: RegIcons.shule,
          value: t.facility,
          placeholder: 'Bila Shule',
          loadKey: 'tsch-${r.id}-$firstKey',
          load: () => loadFacilityOptions(true),
          onPick: (o) => t.facility = o,
        ));
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.borderStrong, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // --------------------------------------------------------------------------
  // REUSABLE BUILDERS (orodha iliyo wazi, muhtasari, dropdown)
  // --------------------------------------------------------------------------
  Widget _label(String t, {bool required = true, double size = 14}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: t,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w500, color: _C.text),
            ),
            if (required)
              TextSpan(text: ' *', style: TextStyle(fontSize: size, color: _C.danger))
            else
              const TextSpan(text: ' (Hiari)', style: TextStyle(fontSize: 12, color: _C.textMuted)),
          ],
        ),
      ),
    );
  }

  /// Orodha inafunguka moja kwa moja. Ukichagua inajifunga kuwa muhtasari
  /// (na "Badilisha"), kisha orodha inayofuata inafunguka yenyewe.
  Widget _choose({
    required String id,
    required String label,
    String? sub,
    required IconData icon,
    required RegOption? value,
    required Object loadKey,
    required Future<List<RegOption>> Function() load,
    required void Function(RegOption) onPick,
  }) {
    final Widget body;
    if (value == null || _edit == id) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, size: 15),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub, style: const TextStyle(fontSize: 13, color: _C.textSec)),
            ),
          _Async(
            key: ValueKey('$id-$loadKey'),
            load: load,
            builder: (opts) => _PickList(
              options: opts,
              selectedId: value?.id,
              hint: label,
              onPick: (o) {
                setState(() {
                  onPick(o);
                  _edit = null;
                  _open = null;
                  _error = null;
                });
                _reveal(id);
              },
            ),
          ),
        ],
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: _C.textSec)),
            InkWell(
              onTap: () {
                setState(() {
                  _edit = id;
                  _open = null;
                });
                _reveal(id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _C.borderStrong, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: _C.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value.label,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _C.text),
                      ),
                    ),
                    const Icon(RegIcons.edit, size: 15, color: _C.blue),
                    const SizedBox(width: 4),
                    const Text('Badilisha', style: TextStyle(fontSize: 13, color: _C.blue)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return KeyedSubtree(key: _sectionKey(id), child: body);
  }

  /// Dropdown ya hiari (Shule, Kituo). Inafunguka ukibonyeza, na inajifunga ukichagua.
  Widget _dropdown({
    required String id,
    required String label,
    required IconData icon,
    required RegOption? value,
    required String placeholder,
    required Object loadKey,
    required Future<List<RegOption>> Function() load,
    required void Function(RegOption) onPick,
    String? fallbackSelectedId,
  }) {
    final open = _open == id;
    return KeyedSubtree(
      key: _sectionKey(id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: false),
          InkWell(
            onTap: () => setState(() => _open = open ? null : id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _C.borderStrong, width: 2)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: _C.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value?.label ?? placeholder,
                      style: TextStyle(
                        fontSize: 15,
                        color: value == null ? _C.textMuted : _C.text,
                      ),
                    ),
                  ),
                  Icon(open ? RegIcons.chevronUp : RegIcons.chevronDown, size: 20, color: _C.blue),
                ],
              ),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.borderStrong, width: 0.5),
              ),
              child: _Async(
                key: ValueKey('$id-$loadKey'),
                load: load,
                builder: (opts) => _PickList(
                  options: opts,
                  selectedId: value?.id ?? fallbackSelectedId,
                  hint: label,
                  onPick: (o) {
                    setState(() {
                      onPick(o);
                      _open = null;
                      _error = null;
                    });
                    _reveal(id, alignment: 0.25);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FOOTER
  // --------------------------------------------------------------------------
  Widget _footer() {
    final last = _step == _steps.length - 1;
    final Widget left = _step == 0
        ? InkWell(
            onTap: widget.onLoginTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Una akaunti? ', style: TextStyle(fontSize: 14, color: _C.textSec)),
                    TextSpan(
                      text: 'Ingia',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _C.blue),
                    ),
                  ],
                ),
              ),
            ),
          )
        : InkWell(
            onTap: _goBack,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(RegIcons.back, size: 18, color: _C.blue),
                  SizedBox(width: 6),
                  Text('Rudi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _C.blue)),
                ],
              ),
            ),
          );

    final Widget right = last
        ? _ActionButton(
            label: 'Najisajili',
            leading: RegIcons.register,
            loading: _submitting,
            onTap: _submitting ? null : _goNext,
          )
        : _ActionButton(
            label: 'Endelea',
            trailing: RegIcons.next,
            square: true,
            onTap: _goNext,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(fontSize: 13, color: _C.danger)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          // LAYOUT ILIYOTAKA: link ('Una akaunti? Ingia' ama 'Rudi') JUU,
          // kitufe ('Endelea'/'Najisajili') CHINI yake — siyo nusu flex.
          // Kitufe kinabaki kidogo (32px) na kikongoja kushoto.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [left, const SizedBox(height: 10), right],
          ),
        ),
      ],
    );
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _open = null;
      _edit = null;
      if (_step > 0) _step--;
    });
    _scrollTop();
  }

  Future<void> _goNext() async {
    FocusScope.of(context).unfocus();
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      // Kosa linaonyeshwa, kisha HUJIFUTA (auto-dismiss) — hakikubaki muda mrefu.
      _scheduleErrorDismiss();
      return;
    }
    if (_step < _steps.length - 1) {
      setState(() {
        _error = null;
        _open = null;
        _edit = null;
        _step++;
      });
      _scrollTop();
      return;
    }
    await _submit();
  }

  String? _validate() {
    final key = _steps[_step];
    final p = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final w = _waCtrl.text.replaceAll(RegExp(r'\D'), '');
    switch (key) {
      case 'Taarifa':
        // Kila uga tupu una ujumbe WAKE, unaoonyeshwa chini ya uga husika —
        // sio "jina lako kamili" daima. Yote yaliyoachwa yapate alama.
        _nameError = _nameCtrl.text.trim().isEmpty ? 'Jaza jina lako kamili.' : null;
        _phoneError = p.isEmpty
            ? 'Jaza namba ya simu (mf. 07xxxxxxxx).'
            : (p.length < 10 ? 'Namba ya simu si kamili.' : (_phoneStatus == _PhoneStatus.taken ? 'Namba hii imetumika.' : null));
        _waError = w.isEmpty
            ? 'Jaza namba ya WhatsApp (mf. 07xxxxxxxx).'
            : (w.length < 10 ? 'Namba ya WhatsApp si kamili.' : (_waStatus == _PhoneStatus.taken ? 'Namba hii imetumika.' : null));
        if (_phoneError == null && _phoneStatus == _PhoneStatus.checking ||
            _waError == null && _waStatus == _PhoneStatus.checking) {
          return 'Subiri, tunakagua namba za simu.';
        }
        if (_nameError != null || _phoneError != null || _waError != null) {
          return 'Jaza taarifa zote ulizoacha wazi (ona maeneo yenye alama chini).';
        }
        return null;
      case 'Idara':
        return _idara == null ? 'Chagua idara.' : null;
      case 'Wizara':
        return _wizara == null ? 'Chagua wizara.' : null;
      case 'Kada':
        if (_isAfya) return _cheo == null ? 'Chagua kada au cheo chako.' : null;
        return _subjects.length != 2 ? 'Chagua masomo 2 kamili.' : null;
      case 'Eneo':
        if (_isWA) return (_region == null || _hospital == null) ? 'Chagua mkoa na hospitali.' : null;
        return (_region == null || _district == null) ? 'Chagua mkoa na wilaya.' : null;
      default:
        if (_isWA) {
          if (_targets[0].region == null) return 'Chagua mkoa wa lengo.';
        } else {
          for (final t in _targets) {
            if (t.region == null || (!t.anyDistrict && t.districts.isEmpty)) {
              return 'Chagua mkoa wa lengo na wilaya angalau moja.';
            }
          }
        }
        return _years == null ? 'Chagua miaka ya kazi.' : null;
    }
  }

  RegistrationData _buildData() {
    return RegistrationData(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      whatsapp: _waCtrl.text.trim(),
      idara: _idara!,
      wizara: _isAfya ? _wizara : null,
      cheo: _isAfya ? _cheo : null,
      level: _isAfya ? null : _level,
      subjects: _isAfya ? const [] : List.of(_subjects),
      region: _region!,
      district: _isWA ? null : _district,
      school: _isAfya ? null : _school,
      facility: _isAfya && !_isWA ? _facility : null,
      hospital: _isWA ? _hospital : null,
      targets: [
        for (final t in _targets)
          if (t.region != null)
            RegTargetData(
              region: t.region!,
              anyDistrict: t.anyDistrict,
              districts: List.of(t.districts),
              facility: t.facility,
            ),
      ],
      targetHospital: _isWA ? _targetHospital : null,
      years: _years!,
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data = _buildData();
      await _repo.submit(data);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _finished = true;
      });
      // TOAST YA MAFANIKIO — mtindo uleule wa tosti za app (AppToast).
      AppToast.success('Hongera ${data.name.split(' ').first}, umefanikiwa kujisajili!');
      widget.onFinished?.call(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Kosa HALISI (namba imetumika, kada isiyo sahihi, n.k.) — sio ujumbe
        // generic; tuonyeshe kama ulivyo kutoka backend, kisha tosti pia.
        _error = e is RegisterException ? e.message : friendlyError(e);
      });
      AppToast.error(_error!);
      _scheduleErrorDismiss();
    }
  }

  // --------------------------------------------------------------------------
  // DONE
  // --------------------------------------------------------------------------
  List<Widget> _doneChildren() {
    final lines = <MapEntry<IconData, String>>[
      MapEntry(RegIcons.name, _nameCtrl.text.trim()),
      MapEntry(RegIcons.phone, _phoneCtrl.text.trim()),
    ];
    if (_isAfya) {
      lines.add(MapEntry(RegIcons.afya, 'Afya, $_wizara: ${_cheo?.label ?? ''}'));
    } else {
      lines.add(MapEntry(
        RegIcons.elimu,
        '$_idara, ${_level == EduLevel.sekondari ? 'Sekondari' : 'Msingi'}: ${_subjects.map((s) => s.label).join(', ')}',
      ));
    }
    if (_isWA) {
      lines.add(MapEntry(RegIcons.mkoa, '${_region?.label}, ${_hospital?.label}'));
    } else {
      final extra = [
        if (_school != null) _school!.label,
        if (_facility != null) _facility!.label,
      ].join(', ');
      lines.add(MapEntry(
        RegIcons.mkoa,
        '${_region?.label}, ${_district?.label}${extra.isEmpty ? '' : ', $extra'}',
      ));
    }
    if (_isWA) {
      final th = _targetHospital == null ? '' : ', ${_targetHospital!.label}';
      lines.add(MapEntry(RegIcons.route, '${_targets[0].region?.label}$th'));
    } else {
      lines.add(MapEntry(
        RegIcons.route,
        _targets.where((t) => t.region != null).map((t) {
          final d = t.anyDistrict ? 'Wilaya yeyote' : t.districts.map((x) => x.label).join(', ');
          return '${t.region!.label} ($d)${t.facility == null ? '' : ', ${t.facility!.label}'}';
        }).join(' | '),
      ));
    }
    lines.add(MapEntry(RegIcons.miaka3, _years ?? ''));

    return [
      const SizedBox(height: 10),
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: _C.successSoft, shape: BoxShape.circle),
          child: const Icon(RegIcons.check, size: 34, color: _C.success),
        ),
      ),
      const SizedBox(height: 14),
      const Center(
        child: Text(
          'Umefanikiwa kujisajili',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: _C.text),
        ),
      ),
      const SizedBox(height: 2),
      const Center(
        child: Text(
          'Karibu. Taarifa zako zimehifadhiwa.',
          style: TextStyle(fontSize: 13, color: _C.textSec),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _C.border, width: 0.5)),
        ),
        child: Column(
          children: [
            for (final l in lines)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _C.border, width: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(l.key, size: 18, color: _C.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.value,
                        style: const TextStyle(fontSize: 14, height: 1.4, color: _C.text),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _restart,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.borderStronger, width: 0.5),
          ),
          child: const Text(
            'Anza upya',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _C.text),
          ),
        ),
      ),
    ];
  }

  void _restart() {
    _scrollTop();
    setState(() {
      _step = 0;
      _finished = false;
      _error = null;
      _open = null;
      _edit = null;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _waCtrl.clear();
      _phoneStatus = _PhoneStatus.idle;
      _waStatus = _PhoneStatus.idle;
      _idara = null;
      _wizara = null;
      _cheo = null;
      _level = EduLevel.sekondari;
      _subjects = [];
      _region = null;
      _district = null;
      _school = null;
      _facility = null;
      _hospital = null;
      _targets = [_Target()];
      _targetHospital = null;
      _years = null;
    });
  }
}

// ============================================================================
// WIDGETS ZA KUTUMIA TENA
// ============================================================================
class _Item {
  final String label;
  final IconData icon;
  const _Item(this.label, this.icon);
}

class _Head extends StatelessWidget {
  final String title;
  final String? sub;
  const _Head(this.title, this.sub);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: _C.text),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub!, style: const TextStyle(fontSize: 13, color: _C.textSec)),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool on;
  const _Dot(this.on);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? _C.blue : _C.borderStronger, width: on ? 5 : 2),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;

  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.minHeight = 46,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _C.border, width: 0.5)),
        ),
        child: Row(
          children: [
            _Dot(selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: selected ? _C.blue : _C.text,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, height: 1.3, color: _C.textSec),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Orodha ya nguzo mbili, kama Masomo.
class _TwoCol extends StatelessWidget {
  final List<Widget> children;
  const _TwoCol({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < children.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 20),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

/// Orodha yenye kutafuta (ikiwa chaguo ni zaidi ya 12) na nguzo mbili.
class _PickList extends StatefulWidget {
  final List<RegOption> options;
  final String? selectedId;
  final String hint;
  final ValueChanged<RegOption> onPick;

  const _PickList({
    required this.options,
    required this.selectedId,
    required this.hint,
    required this.onPick,
  });

  @override
  State<_PickList> createState() => _PickListState();
}

class _PickListState extends State<_PickList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.label.toLowerCase().contains(q)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        if (widget.options.length > 12)
          _SearchBox(
            hint: 'Tafuta ${widget.hint}...',
            onChanged: (v) => setState(() => _q = v),
          ),
        const SizedBox(height: 4),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text('Hakuna kilichopatikana.', style: TextStyle(fontSize: 13, color: _C.textSec)),
            ),
          )
        else
          _TwoCol(
            children: [
              for (final o in shown)
                _OptionRow(
                  label: o.label,
                  subtitle: o.subtitle,
                  selected: o.id == widget.selectedId,
                  onTap: () => widget.onPick(o),
                ),
            ],
          ),
      ],
    );
  }
}

/// Inapakia orodha kutoka API na kuonyesha spinner au kosa.
class _Async extends StatefulWidget {
  final Future<List<RegOption>> Function() load;
  final Widget Function(List<RegOption>) builder;

  const _Async({super.key, required this.load, required this.builder});

  @override
  State<_Async> createState() => _AsyncState();
}

class _AsyncState extends State<_Async> {
  late Future<List<RegOption>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.load();
  }

  void _retry() => setState(() => _f = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RegOption>>(
      future: _f,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: InkWell(
                onTap: _retry,
                child: const Text(
                  'Imeshindikana kupakia. Bonyeza kujaribu tena.',
                  style: TextStyle(fontSize: 13, color: _C.danger),
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue),
              ),
            ),
          );
        }
        return widget.builder(snap.data!);
      },
    );
  }
}

class _ChoiceCards extends StatelessWidget {
  final List<_Item> items;
  final String? selected;
  final ValueChanged<int> onTap;

  const _ChoiceCards({required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _card(i),
          ],
        ],
      ),
    );
  }

  Widget _card(int i) {
    final item = items[i];
    final on = selected == item.label;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onTap(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? _C.blue : _C.borderStrong, width: on ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _C.blueSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 20, color: _C.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(item.label, style: const TextStyle(fontSize: 15, color: _C.text)),
            ),
            _Dot(on),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final String leftLabel;
  final IconData leftIcon;
  final String rightLabel;
  final IconData rightIcon;
  final bool rightSelected;
  final ValueChanged<bool> onChanged; // true = kulia

  const _Segmented({
    required this.leftLabel,
    required this.leftIcon,
    required this.rightLabel,
    required this.rightIcon,
    required this.rightSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _seg(leftLabel, leftIcon, !rightSelected, () => onChanged(false))),
          const SizedBox(width: 4),
          Expanded(child: _seg(rightLabel, rightIcon, rightSelected, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, bool on, VoidCallback tap) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: tap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: on ? _C.blueBorder : Colors.transparent, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: on ? _C.blue : _C.textSec),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                color: on ? _C.blue : _C.textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnderlineField extends StatelessWidget {
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final Color? underlineColor;

  /// Kosa la uga husika (namba si kamili, imetumika, imeachwa wazi n.k.) —
  /// si null: mcatiano ukuwe mekundu na ujumbe uonekane chini ya uga huu.
  final String? errorText;

  const _UnderlineField({
    required this.icon,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
    this.underlineColor,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: errorText != null
                  ? _C.danger
                  : (underlineColor ?? _C.borderStrong),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _C.blue),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                textCapitalization: capitalization,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 15, color: _C.text),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 15, color: _C.textMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          ],
        ),
      ),
      // KOSA CHINI YA UGA HUSIKA — mtumiaji anajua wazi uga gani kumekosea.
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(children: [
              const Icon(RegIcons.bad, size: 14, color: _C.danger),
              const SizedBox(width: 5),
              Text(errorText!,
                  style: const TextStyle(fontSize: 12, color: _C.danger)),
            ]),
          ),
        ),
    ]);
  }
}

class _PhoneStatusRow extends StatelessWidget {
  final _PhoneStatus status;
  const _PhoneStatusRow({required this.status});

  @override
  Widget build(BuildContext context) {
    Widget? child;
    switch (status) {
      case _PhoneStatus.available:
        child = const Row(
          children: [
            Icon(RegIcons.ok, size: 16, color: _C.success),
            SizedBox(width: 6),
            Expanded(
              child: Text('Namba inapatikana',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _C.success)),
            ),
          ],
        );
        break;
      case _PhoneStatus.taken:
        child = const Row(
          children: [
            Icon(RegIcons.bad, size: 16, color: _C.danger),
            SizedBox(width: 6),
            Expanded(
              child: Text('Namba imetumika',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _C.danger)),
            ),
          ],
        );
        break;
      case _PhoneStatus.checking:
        child = const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _C.textSec),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text('Inakagua...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _C.textSec)),
            ),
          ],
        );
        break;
      case _PhoneStatus.idle:
        child = null;
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(height: 18, child: child),
    );
  }
}

/// Kisanduku cha kutafuta: cheupe, mpaka wa kijivu, unakuwa bluu ukibonyeza.
class _SearchBox extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.hint, required this.onChanged});

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _focus.hasFocus;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: f ? _C.blue : _C.borderStrong, width: f ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Icon(RegIcons.search, size: 18, color: f ? _C.blue : _C.textSec),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              focusNode: _focus,
              onChanged: widget.onChanged,
              style: const TextStyle(fontSize: 14, color: _C.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: widget.hint,
                hintStyle: const TextStyle(fontSize: 14, color: _C.textMuted),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kitufe kidogo cha bluu.
/// square = true  -> mraba mdogo wenye kona laini (Endelea), urefu 32.
/// square = false -> umbo la duara kamili (Najisajili), urefu 32.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? leading;
  final IconData? trailing;
  final bool loading;
  final bool square;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    this.leading,
    this.trailing,
    this.loading = false,
    this.square = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ShapeBorder shape = square
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
        : const StadiumBorder();
    return Material(
      color: _C.blue,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else if (leading != null)
                  Icon(leading, size: 16, color: Colors.white),
                if (loading || leading != null) const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Icon(trailing, size: 16, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
