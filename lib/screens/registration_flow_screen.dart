import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import '../services/api_service.dart';

// =============================================================================
//  EssTransfer - Skrini ya Usajili ("Jaza Taarifa Zako")
//
//  Imenakiliwa kutoka kwenye mokap uliyokubali, bila mabadiliko:
//   - Elimu  : Taarifa > Idara > Kada (masomo 2) > Eneo la Sasa > Maeneo ya Lengo
//   - Afya / Kilimo / Watumishi wa Umma :
//       Taarifa > Idara > Wizara > Kada / Cheo > (TAMISEMI: Mkoa, Wilaya, Kituo)
//                                              (Wizara ya Afya: Hospitali tu)
//                                              > Mkoa Unakotakwa Kwenda
//
//  Matumizi:
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => RegistrationFlowScreen(
//        onSubmit: (data) { /* tuma kwa API */ },
//        onLogin: () { /* nenda kwenye login */ },
//      ),
//    ));
// =============================================================================

// ----------------------------------------------------------------------------
//  Rangi
// ----------------------------------------------------------------------------
class AppColors {
  static const blue = Color(0xFF1E3FAE);
  static const light = Color(0xFFEEF2FF);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFF0FDF4);
  static const red = Color(0xFFDC2626);
  static const text = Color(0xFF111827);
  static const gray = Color(0xFF6B7280);
  static const darkGray = Color(0xFF4B5563);
  static const lightGray = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const line = Color(0xFFD1D5DB);
  static const faint = Color(0xFFF3F4F6);
  static const softBlueBorder = Color(0xFFDBE4FF);
  static const cardBlueBorder = Color(0xFFC7D4FF);
}

// ----------------------------------------------------------------------------
//  Icons - kila icon ya mokap ina jina lake hapa.
//  Zimewekwa Material Icons ili ikae bila package ya ziada. Ukitumia package
//  ya Tabler/Lucide kwenye app yako, badilisha hapa tu mahali pamoja.
// ----------------------------------------------------------------------------
class AppIcons {
  // NOTE: topics za Tabler (tabler_icons_plus — vendor'd kwenye repo) —
  // lucide_icons 0.257.0 haifanyi kazi kwenye Flutter mpya (IconData 'final'
  // hayakubaliwa extend). Tabler ina icons zilezile.
  static const IconData user = TablerIcons.user; // user
  static const IconData phone = TablerIcons.phoneCall; // phone-call
  static const IconData whatsapp = TablerIcons.messageCircle; // whatsapp/chat
  static const IconData firstAid = TablerIcons.cross; // first-aid-kit
  static const IconData school = TablerIcons.school; // school
  static const IconData plant = TablerIcons.plant; // plant-2
  static const IconData users = TablerIcons.users; // users (watumishi wa umma)
  static const IconData backpack = TablerIcons.backpack; // backpack
  static const IconData flask = TablerIcons.flask; // flask
  static const IconData hospital = TablerIcons.cross; // building-hospital
  static const IconData stethoscope = TablerIcons.stethoscope; // stethoscope
  static const IconData bank = TablerIcons.buildingBank; // building-bank
  static const IconData community = TablerIcons.buildingCommunity; // building-community
  static const IconData mapPin = TablerIcons.mapPin; // map-pin
  static const IconData building = TablerIcons.building; // building
  static const IconData idBadge = TablerIcons.idBadge2; // id-badge-2
  static const IconData briefcase = TablerIcons.briefcase; // briefcase
  static const IconData one = TablerIcons.circleDot; // number-1 (generic)
  static const IconData two = TablerIcons.circleDot; // number-2
  static const IconData three = TablerIcons.circleDot; // number-3
  static const IconData search = TablerIcons.search; // search
  static const IconData chevronDown = TablerIcons.chevronDown; // chevron-down
  static const IconData chevronUp = TablerIcons.chevronUp; // chevron-up
  static const IconData checkCircleFilled = TablerIcons.circleCheckFilled; // circle-check-filled
  static const IconData checkFilled = TablerIcons.circleCheckFilled; // circle-check-filled
  static const IconData arrowLeft = TablerIcons.arrowLeft; // arrow-left
  static const IconData arrowRight = TablerIcons.arrowRight; // arrow-right
  static const IconData plus = TablerIcons.plus; // plus
  static const IconData trash = TablerIcons.trash; // trash
  static const IconData alert = TablerIcons.alertCircle; // alert-circle
  static const IconData check = TablerIcons.check; // check
}

// ----------------------------------------------------------------------------
//  Data
// ----------------------------------------------------------------------------
class Option {
  final String label;
  final IconData icon;
  const Option(this.label, this.icon);
}

class _IdaraConfig {
  final String unit;
  final IconData icon;
  final List<String> units;
  final List<Option> wizara;
  final List<String> kada;
  final IconData kadaIcon;
  const _IdaraConfig({
    required this.unit,
    required this.icon,
    required this.units,
    this.wizara = const [],
    this.kada = const [],
    this.kadaIcon = AppIcons.idBadge,
  });
}

const String kAny = 'Wilaya yeyote';
const String kNoSchool = 'Bila Kituo (Hiari)';

const List<Option> kIdara = [
  Option('Afya', AppIcons.firstAid),
  Option('Elimu', AppIcons.school),
  Option('Kilimo na ufugaji', AppIcons.plant),
  Option('Watumishi wa Umma', AppIcons.users),
];

const List<String> kSubjectsSekondari = [
  'Business Studies', 'Agriculture', 'Biology', 'Book Keeping', 'Chemistry',
  'Civics', 'Commerce', 'English', 'Geography', 'History',
  'Information & Computer Studies', 'Mathematics', 'Physics',
  'Sports / Physical Education', 'Economics', 'Kiswahili',
];

const List<String> kSubjectsMsingi = [
  'Kiswahili', 'English', 'Hisabati', 'Sayansi na Teknolojia',
  'Maarifa ya Jamii', 'Uraia na Maadili', 'Stadi za Kazi',
  'Haiba na Michezo', 'TEHAMA', 'Kifaransa', 'Kiarabu',
];

const List<String> kHealthCadres = [
  'Afisa Afya na Mazingira', 'Afisa Ustawi wa Jamii Msaidizi',
  'Assistant Clinical Officer', 'Assistant Environmental Health Officer II',
  'Assistant Medical Officer', 'Assistant Nursing Officer (ANO)',
  'Assistant Pharmacist II', 'Assistant Technician',
  'Assistant Technologist II', 'Biomedical Engineer II',
  'Nursing Officer (NO)', 'Occupational Therapist II', 'Opthalmic Optician II',
  'Pharmaceutical Assistant', 'Pharmaceutical Technician', 'Pharmacist II',
  'Physiotherapist Assistant II', 'Physiotherapist II', 'Radiographer II',
  'Registered Nurse (RN)', 'Senior Laboratory Assistant I',
];

/// Vituo vya TAMISEMI (zahanati / kituo cha afya) - hufuata Mkoa > Wilaya.
const List<String> kFacilitiesTamisemi = [
  'AFYA NJEMA (Dispensary)',
  'BAHEBE HEALTH LABORATORY (Level IA2 (Dispensary Laboratory))',
  'BAKWATA SHAMSIYA (Dispensary)',
  'BRASONITY (Level IA2 (Dispensary Laboratory))',
  'BUGWEIGO (Dispensary)',
  'BUPANDWAMPULI (Dispensary)',
  'BUSAKA (Dispensary)',
  'BUSALALA (Dispensary)',
  'BUSERESERE (Dispensary)',
  'BUTARAMA (Health Center)',
];

/// Hospitali za Wizara ya Afya - orodha moja, bila Mkoa wala Wilaya.
const List<String> kHospitalsWizara = [
  'BURHANI CHARITABLE (Hospital at Regional Level)',
  'CARDINAL RUGAMBWA (Hospital at Regional Level)',
  'CARE AND CURE (Hospital at Regional Level)',
  'DIRECT AID (Hospital at Regional Level)',
  'ELIDAD (Hospital at Regional Level)',
  'EM (Hospital at Regional Level)',
  'EPIPHANY (Hospital at Regional Level)',
  'JAKAYA KIKWETE CARDIAC INSTITUTE (National Super Specialized Hospital)',
  'KINONDONI (Hospital at Regional Level)',
];

const List<String> kSchools = [
  'ABC CAPITAL PRIMARY SCHOOL', 'ALGEBRA ISLAMIC PRIMARY SCHOOL',
  'AMKA PRIMARY SCHOOL', 'Aboud Jumbe', 'BETHANIA PRIMARY SCHOOL',
  'BRISBANE PRIMARY SCHOOL', 'Bohari', 'Buyuni I',
];

const Map<String, _IdaraConfig> kConfigs = {
  'Elimu': _IdaraConfig(
    unit: 'Shule',
    icon: AppIcons.school,
    units: kSchools,
  ),
  'Afya': _IdaraConfig(
    unit: 'Kituo (kituo cha afya)',
    icon: AppIcons.hospital,
    units: kFacilitiesTamisemi,
    wizara: [
      Option('Wizara ya Afya', AppIcons.bank),
      Option('TAMISEMI', AppIcons.community),
    ],
    kada: kHealthCadres,
    kadaIcon: AppIcons.stethoscope,
  ),
  // Orodha za mfano - badilisha na za kweli.
  'Kilimo na ufugaji': _IdaraConfig(
    unit: 'Kituo cha Kazi',
    icon: AppIcons.building,
    units: ['Ofisi ya Wilaya', 'Ofisi ya Kata', 'Kituo cha Utafiti'],
    wizara: [
      Option('Wizara ya Kilimo', AppIcons.bank),
      Option('Wizara ya Mifugo na Uvuvi', AppIcons.bank),
      Option('TAMISEMI', AppIcons.community),
    ],
    kada: ['Afisa Kilimo', 'Afisa Mifugo', 'Afisa Ugani'],
  ),
  'Watumishi wa Umma': _IdaraConfig(
    unit: 'Kituo cha Kazi',
    icon: AppIcons.building,
    units: ['Ofisi ya Wilaya', 'Ofisi ya Mkoa', 'Wizarani'],
    wizara: [
      Option('Ofisi ya Rais - Utumishi', AppIcons.bank),
      Option('TAMISEMI', AppIcons.community),
    ],
    kada: ['Afisa Utumishi', 'Katibu Muhtasi', 'Mhasibu'],
  ),
};

const List<String> kMikoa = [
  'Arusha', 'Dar Es Salaam', 'Dodoma', 'Geita', 'Iringa', 'Kagera', 'Katavi',
  'Kigoma', 'Kilimanjaro', 'Lindi', 'Manyara', 'Mara', 'Mbeya',
  'Mjini Magharibi', 'Morogoro', 'Mtwara', 'Mwanza', 'Njombe',
  'Pemba Kaskazini', 'Pemba Kusini', 'Pwani', 'Rukwa', 'Ruvuma', 'Shinyanga',
  'Simiyu', 'Singida', 'Songwe', 'Tabora', 'Tanga', 'Unguja Kaskazini',
  'Unguja Kusini',
];

const Map<String, List<String>> kWilaya = {
  'Dar Es Salaam': [
    'Ilala Mc', 'Kigamboni Mc', 'Kinondoni Mc', 'Temeke Mc', 'Ubungo Mc',
  ],
  'Arusha': [
    'Arusha Dc', 'Arusha Mc', 'Karatu Dc', 'Longido Dc', 'Meru Dc',
    'Monduli Dc', 'Ngorongoro Dc',
  ],
  'Dodoma': [
    'Bahi Dc', 'Chamwino Dc', 'Chemba Dc', 'Dodoma Mc', 'Kondoa Dc',
    'Kongwa Dc', 'Mpwapwa Dc',
  ],
  'Mwanza': [
    'Ilemela Mc', 'Nyamagana Mc', 'Magu Dc', 'Misungwi Dc', 'Kwimba Dc',
    'Sengerema Dc', 'Ukerewe Dc',
  ],
  'Geita': [
    'Bukombe Dc', 'Chato Dc', 'Geita Dc', 'Geita Mc', 'Mbogwe Dc',
    "Nyang'hwale Dc",
  ],
};

const List<String> kWilayaFallback = [
  'Wilaya ya Kati', 'Wilaya ya Kaskazini', 'Wilaya ya Kusini',
];

const List<Option> kMiaka = [
  Option('1 mwaka', AppIcons.one),
  Option('2 miaka', AppIcons.two),
  Option('3+ (miaka 3 au zaidi)', AppIcons.three),
];

List<String> wilayaOf(String mkoa) => kWilaya[mkoa] ?? kWilayaFallback;

// ----------------------------------------------------------------------------
//  Data inayotoka kwenye skrini
// ----------------------------------------------------------------------------
class TargetArea {
  String mkoa = '';
  List<String> wilaya = [kAny];
  List<String> shule = [kNoSchool];
  // Afya-Wizara: hospitali ya rufaa ya lengo kwenye mkoa huu (single-select)
  String hospitali = '';

  // ── IDs halisi (API) — adapter inatumia kutuma payload sahihi ──
  int? mkoaId;
  List<int> wilayaIds = [];
  Map<String, String> shuleIds = {}; // jina -> facility_id
  String? hospitaliId;
}

class RegistrationData {
  final String name, phone, whatsapp, idara, wizara, kada;
  final List<String> masomo;
  final String mkoa, wilaya, kituo, miaka;
  final List<TargetArea> targets;
  // ── Codes / IDs halisi (API) — adapter haitaji kupachika majina tena ──
  final String? categoryCode;
  final String? employmentSector;
  final String? cadreCode;
  final List<String> subjectCodes;
  final int? mkoaId;
  final int? wilayaId;
  final String? kituoId;
  final String? kituoType;
  final int? yearsOfService;
  const RegistrationData({
    required this.name,
    required this.phone,
    required this.whatsapp,
    required this.idara,
    required this.wizara,
    required this.kada,
    required this.masomo,
    required this.mkoa,
    required this.wilaya,
    required this.kituo,
    required this.miaka,
    required this.targets,
    this.categoryCode,
    this.employmentSector,
    this.cadreCode,
    this.subjectCodes = const [],
    this.mkoaId,
    this.wilayaId,
    this.kituoId,
    this.kituoType,
    this.yearsOfService,
  });
}

enum StepId { taarifa, idara, wizara, kada, eneo, maeneo }

const Map<StepId, String> _stepLabel = {
  StepId.taarifa: 'Taarifa',
  StepId.idara: 'Idara',
  StepId.wizara: 'Wizara',
  StepId.kada: 'Kada',
  StepId.eneo: 'Eneo',
  StepId.maeneo: 'Maeneo',
};

// ----------------------------------------------------------------------------
//  Vifaa vidogo vinavyotumika kote
// ----------------------------------------------------------------------------
TextStyle _ts(double size,
        {FontWeight w = FontWeight.w400, Color c = AppColors.text, double? h}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, height: h);

Widget _iconBox(IconData icon, Color color, Color bg, double size) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: size * 0.62, color: color),
    );

Widget _ring(bool on) => on
    ? Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.blue, width: 2),
        ),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
              color: AppColors.blue, shape: BoxShape.circle),
        ),
      )
    : Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lightGray, width: 2),
        ),
      );

/// Kitufe / eneo la kubonyeza lenye ripple (click animation).
Widget _pressable({
  required Widget child,
  required VoidCallback? onTap,
  double radius = 12,
  Color? color,
  BorderSide side = BorderSide.none,
}) =>
    Material(
      color: color ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: child,
      ),
    );

// ----------------------------------------------------------------------------
//  Dropdown inayofunguka chini ya sehemu yenyewe
// ----------------------------------------------------------------------------
class _Dd {
  final List<Option> items;
  final bool search;
  final bool multi;
  final List<String> Function() selected;
  final void Function(String) pick;
  _Dd({
    required this.items,
    required this.selected,
    required this.pick,
    this.search = false,
    this.multi = false,
  });
}

class _DropdownPanel extends StatefulWidget {
  final _Dd cfg;
  final void Function(String) onPick;
  final VoidCallback onDone;
  const _DropdownPanel({
    super.key,
    required this.cfg,
    required this.onPick,
    required this.onDone,
  });

  @override
  State<_DropdownPanel> createState() => _DropdownPanelState();
}

class _DropdownPanelState extends State<_DropdownPanel> {
  String q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.2,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.cfg.selected();
    final items = widget.cfg.items
        .where((o) => q.isEmpty || o.label.toLowerCase().contains(q))
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.cfg.search)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.faint)),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.search, size: 16, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => q = v.toLowerCase()),
                      style: _ts(13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Tafuta...',
                        hintStyle: _ts(13, c: AppColors.lightGray),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // CHAGUO LA RADIO — HAKUNA SCROLL NDANI YA PANEL: orodha yote
          // inaonekana wazi (kama Masomo). Kama orodha ni ndefu, page yenyewe
          // (SingleChildScrollView ya juu) inasogeza — hakuna scroll ndani ndani.
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child:
                    Text('Hakuna matokeo', style: _ts(13, c: AppColors.lightGray)),
              ),
            )
          else
            // GRIDI 2-COL kama MASOMO: mikoa/wilaya/vituo — display flex mbili
            // mbili, isionekane ndefu. Single-select: ukibonyeza, inajifunga
            // (onPick inafunga panel kwenye _pick).
            if (widget.cfg.multi)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in items) _row(o, sel.contains(o.label)),
                ],
              )
            else
              _twoColPanel(items, sel),
          if (widget.cfg.multi)
            Padding(
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                width: double.infinity,
                child: _pressable(
                  radius: 10,
                  color: AppColors.blue,
                  onTap: widget.onDone,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text('Sawa',
                          style: _ts(13.5, w: FontWeight.w500, c: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Gridi ya radio 2-col (kama Masomo) kwa single-select panels.
  Widget _twoColPanel(List<Option> items, List<String> sel) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _gridCell(items[i].label,
                  sel.contains(items[i].label), () => widget.onPick(items[i].label))),
          const SizedBox(width: 16),
          Expanded(
            child: i + 1 < items.length
                ? _gridCell(items[i + 1].label,
                    sel.contains(items[i + 1].label),
                    () => widget.onPick(items[i + 1].label))
                : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _gridCell(String t, bool on, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.faint)),
          ),
          child: Row(
            children: [
              _ring(on),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(12.5,
                        w: on ? FontWeight.w500 : FontWeight.w400,
                        c: on ? AppColors.blue : AppColors.text,
                        h: 1.25)),
              ),
            ],
          ),
        ),
      );

  Widget _row(Option o, bool on) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: _pressable(
          radius: 10,
          color: on ? AppColors.light : Colors.transparent,
          onTap: () => widget.onPick(o.label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Radio-button widget — duara la bluu kwenye kipengele
                // kilichochaguliwa, duara tupu kwenye zisizochaguliwa.
                _ring(on),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    o.label,
                    style: _ts(13,
                        w: on ? FontWeight.w500 : FontWeight.w400,
                        c: on ? AppColors.blue : AppColors.text,
                        h: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ----------------------------------------------------------------------------
//  Skrini yenyewe
// ----------------------------------------------------------------------------
class RegistrationFlowScreen extends StatefulWidget {
  final void Function(RegistrationData data)? onSubmit;
  final VoidCallback? onLogin;
  const RegistrationFlowScreen({super.key, this.onSubmit, this.onLogin});

  @override
  State<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends State<RegistrationFlowScreen> {
  int step = 1;
  bool done = false;
  bool showErr = false;

  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final waC = TextEditingController();

  String idara = '';
  String kada = 'Sekondari'; // Msingi / Sekondari (Elimu)
  List<String> masomo = [];
  String wizara = '';
  String kadaH = ''; // kada / cheo (njia zisizo za Elimu)
  String mkoa = '';
  String cw = ''; // wilaya ya sasa
  String cs = ''; // kituo / shule / hospitali ya sasa
  String miaka = '';
  List<TargetArea> targets = [TargetArea()];
  String? openDd;

  // ── Data halisi (API) — orodha tuli hapo juu ni BACKUP (offline-safe) ──
  final _api = ApiService();
  List<String> _mikoaLive = [];
  final Map<String, int> _regionIds = {};            // jina la mkoa -> id
  final Map<String, List<String>> _wilayaCache = {}; // mkoa jina -> wilaya majina
  final Map<String, int> _districtIds = {};          // 'Mkoa/Wilaya' -> id
  final Map<int, List<String>> _facilityCache = {};  // districtId -> vituo (majina)
  final Map<String, String> _facilityIdOf = {};      // 'districtId|jina' -> facility_id
  final Map<String, String> _facilityTypes = {};     // 'districtId|jina' -> type
  // Hospitali za Wizara ya Afya (regio zote — mkoa hauombwi kwenye UI)
  List<String> _hospitalLive = [];
  bool _hospitalLoading = false;
  final Map<String, String> _hospitalIds = {};
  final Map<String, int> _hospitalRegionIds = {};
  final Map<String, int?> _hospitalDistrictIds = {};
  final Map<String, String> _hospitalDistrictNames = {};
  final Map<String, String> _hospitalTypes = {};

  /// Hospitali za rufaa za mkoa fulani (Afya-Wizara) — kwa radio widget
  List<String> _hospitalsOfRegion(String regionName) {
    final rid = _regionIds[regionName];
    if (rid == null) return const [];
    return [
      for (final h in _hospitalLive)
        if (_hospitalRegionIds[h] == rid) h,
    ];
  }

  // Kada / Masomo halisi
  final Map<String, String> _cadreNameToCode = {};   // health: jina -> code
  List<String> _cadresLiveHealth = [];
  List<Map<String, dynamic>> _eduCadresRaw = [];
  List<Map<String, dynamic>> _subjectsRawMs = [];
  List<Map<String, dynamic>> _subjectsRawSek = [];
  // Idara (departments) halisi — jina -> category code
  Map<String, String> _deptNameToCode = {};

  //Status ya namba ya simu (API: /auth/check-phone) — imetumiaka au la
  String? _phoneCheckMsg; // null = bado kucheck / kimepita
  bool _phoneChecking = false;

  // IDs za current station (kwa API payload)
  int? _mkoaIdC;
  int? _cwIdC;
  String? _csIdC;
  String? _csType;
  // Current station ukiwa Wizara ya Afya (hospitali inabeba mkoa/wilaya zake)
  int? _hospRegionIdC;
  int? _hospDistrictIdC;
  String? _hospDistrictNameC;

  @override
  void initState() {
    super.initState();
    for (final c in [nameC, phoneC, waC]) {
      c.addListener(() => setState(() {}));
    }
    phoneC.addListener(_onPhoneChanged);
    _loadRegions();
    _loadReferenceData();
  }

  // ── Uthibitisho wa namba ya simu (API) — inaitika kila kubadiliko ──
  Timer? _phoneDebounce;

  void _onPhoneChanged() {
    _phoneCheckMsg = null;
    _phoneDebounce?.cancel();
    final v = phoneC.text.trim();
    if (v.length < 9) {
      if (mounted) setState(() {});
      return;
    }
    _phoneDebounce = Timer(const Duration(milliseconds: 700), _checkPhone);
  }

  Future<void> _checkPhone() async {
    final v = phoneC.text.trim();
    if (v.length < 9 || _phoneChecking) return;
    _phoneChecking = true;
    try {
      final res = await _api.checkPhone(v);
      final d = res.data as Map? ?? {};
      // API: {available: bool, reason: 'invalid_format'|nig, phone_normalized}
      final available = d['available'] != false;
      final invalid = d['reason'] == 'invalid_format';
      if (mounted) {
        setState(() => _phoneCheckMsg = invalid
            ? 'Namba si sahihi — tumia mfano 0712345678'
            : (!available
                ? 'Namba hii imetumiwa — ingia au tumia namba nyingine'
                : null));
      }
    } catch (_) {
      // Silent — API haipatikani: usizuie mtumiaji
    } finally {
      _phoneChecking = false;
    }
  }

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    nameC.dispose();
    phoneC.dispose();
    waC.dispose();
    super.dispose();
  }

  // ── Kupakia data halisi (silent-fail: orodha tuli inabaki backup) ──
  Future<void> _loadRegions() async {
    try {
      final res = await _api.getRegions();
      final list = res.data as List? ?? [];
      final names = <String>[];
      for (final r in list) {
        final name = '${r['name'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        names.add(name);
        _regionIds[name] = r['id'] as int;
      }
      if (names.isNotEmpty && mounted) setState(() => _mikoaLive = names);
    } catch (_) {}
  }

  Future<void> _loadReferenceData() async {
    // Kada (afya) — code halisi kwa payload
    try {
      final res = await _api.getCadres(category: 'health');
      final list = res.data as List? ?? [];
      final names = <String>[];
      for (final c in list) {
        final name = '${c['display_name'] ?? c['name'] ?? c['code']}'.trim();
        final code = '${c['code'] ?? ''}'.trim();
        if (name.isEmpty || code.isEmpty) continue;
        names.add(name);
        _cadreNameToCode[name] = code;
      }
      if (names.isNotEmpty && mounted) setState(() => _cadresLiveHealth = names);
    } catch (_) {}

    // Masomo (msingi + sekondari) — majina ya kuonyesha, codes kwa payload
    for (final level in ['Primary', 'Secondary']) {
      try {
        final res = await _api.getSubjects(level: level);
        final list = res.data as List? ?? [];
        if (level == 'Primary') _subjectsRawMs = list.cast<Map<String, dynamic>>();
        if (level == 'Secondary') _subjectsRawSek = list.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    if (mounted) setState(() {});

    // Departments (idara) — jina -> category code
    try {
      final res = await _api.getDepartments();
      final list = res.data as List? ?? [];
      final m = <String, String>{};
      for (final d in list) {
        final name = '${d['name'] ?? d['code'] ?? ''}'.trim();
        final code = '${d['code'] ?? ''}'.trim();
        if (name.isEmpty || code.isEmpty) continue;
        m[name] = code;
      }
      if (m.isNotEmpty && mounted) setState(() => _deptNameToCode = m);
    } catch (_) {}
  }

  Future<void> _ensureWilaya(String mkoaName) async {
    if (_wilayaCache.containsKey(mkoaName)) return;
    final rid = _regionIds[mkoaName];
    if (rid == null) return; // hakuna region id — fallback orodha tuli
    try {
      final res = await _api.getDistricts(rid);
      final list = res.data as List? ?? [];
      final names = <String>[];
      for (final d in list) {
        final name = '${d['name'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        names.add(name);
        _districtIds['$mkoaName/$name'] = d['id'] as int;
      }
      _wilayaCache[mkoaName] = names;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _ensureFacilities(int districtId) async {
    if (_facilityCache.containsKey(districtId)) return;
    final cat = _deptNameToCode[idara] ?? 'health';
    try {
      final res = await _api.getFacilities(districtId, category: cat);
      final list = res.data as List? ?? [];
      final names = <String>[];
      for (final f in list) {
        final name = '${f['name'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        names.add(name);
        final key = '$districtId|$name';
        _facilityIdOf[key] = '${f['id'] ?? f['code'] ?? ''}';
        _facilityTypes[key] = '${f['type'] ?? f['type_category'] ?? ''}';
      }
      _facilityCache[districtId] = names;
      if (mounted) setState(() {});
    } catch (_) {
      _facilityCache[districtId] = [];
    }
  }

  Future<void> _ensureHospitals() async {
    if (_hospitalLoading || _hospitalLive.isNotEmpty) return;
    _hospitalLoading = true;
    try {
      // Hospitali za wizara — kwa mkoa mmoja (Dar) kama reference; API ina
      // filter employment_sector=wizara_afya per-region. Ili kupata orodha
      // kamili, tunazunguka mikoa yote — lakini hii ni ghali; tunatumia
      // regions 3 za kwanza kwa speed, na ku-add mikoa mingine kwa background
      // (UI ina search — mtumiaji ataona hospitali zinazoonekana).
      final regions = _mikoaLive.take(3).toList();
      final all = <String>[];
      for (final r in regions) {
        final rid = _regionIds[r];
        if (rid == null) continue;
        try {
          final res = await _api.getFacilitiesByRegion(rid,
              category: 'health', employmentSector: 'wizara_afya');
          final list = res.data as List? ?? [];
          for (final f in list) {
            final name = '${f['name'] ?? ''}'.trim();
            if (name.isEmpty) continue;
            if (!all.contains(name)) all.add(name);
            _hospitalIds[name] = '${f['id'] ?? f['code'] ?? ''}';
            _hospitalRegionIds[name] = rid;
            _hospitalDistrictIds[name] = f['district_id'] as int?;
            _hospitalDistrictNames[name] = '${f['district'] ?? ''}';
            _hospitalTypes[name] = '${f['type'] ?? ''}';
          }
        } catch (_) {}
      }
      if (all.isNotEmpty && mounted) setState(() => _hospitalLive = all);
    } finally {
      _hospitalLoading = false;
    }
  }

  // ---- hali ya njia ----
  bool get isEdu => idara.isEmpty || idara == 'Elimu';
  bool get isAfyaW => idara == 'Afya' && wizara == 'Wizara ya Afya';
  bool get isSek => kada == 'Sekondari';
  _IdaraConfig get cfg => kConfigs[idara.isEmpty ? 'Elimu' : idara]!;
  List<String> get mikoaLive =>
      _mikoaLive.isNotEmpty ? _mikoaLive : kMikoa; // fallback static
  List<String> get units {
    if (isAfyaW) {
      return _hospitalLive.isNotEmpty ? _hospitalLive : kHospitalsWizara;
    }
    // Elimu/afya-TAMISEMI: vituo vya wilaya ya sasa (API), fallback static
    final did = _cwIdC;
    if (did != null) {
      final live = _facilityCache[did];
      if (live != null && live.isNotEmpty) return live;
    }
    return cfg.units;
  }

  String get unitName => isAfyaW ? 'Hospitali' : cfg.unit;

  List<String> get subjectNames {
    final raw = isSek ? _subjectsRawSek : _subjectsRawMs;
    if (raw.isNotEmpty) {
      return [
        for (final s in raw) '${s['name'] ?? s['code'] ?? ''}'.trim(),
      ].where((n) => n.isNotEmpty).toList();
    }
    return isSek ? kSubjectsSekondari : kSubjectsMsingi;
  }

  String _subjectCode(String name) {
    final raw = isSek ? _subjectsRawSek : _subjectsRawMs;
    for (final s in raw) {
      if ('${s['name'] ?? s['code'] ?? ''}'.trim() == name) {
        return '${s['code'] ?? name}';
      }
    }
    return name; // fallback — jina lenyewe
  }

  List<String> get kadaHealthNames =>
      _cadresLiveHealth.isNotEmpty ? _cadresLiveHealth : kHealthCadres;

  List<StepId> get flow => isEdu
      ? [StepId.taarifa, StepId.idara, StepId.kada, StepId.eneo, StepId.maeneo]
      : [
          StepId.taarifa,
          StepId.idara,
          StepId.wizara,
          StepId.kada,
          StepId.eneo,
          StepId.maeneo
        ];
  StepId get cur => flow[step - 1];

  bool get valid {
    switch (cur) {
      case StepId.taarifa:
        return nameC.text.trim().isNotEmpty &&
            phoneC.text.trim().isNotEmpty &&
            waC.text.trim().isNotEmpty &&
            _phoneCheckMsg == null; // namba imetumiwa → si valid
      case StepId.idara:
        return idara.isNotEmpty;
      case StepId.wizara:
        return wizara.isNotEmpty;
      case StepId.kada:
        if (isEdu) return masomo.length == 2;
        // Idara isiyo na kada (backend inakubali cadre_code="") — ruhusu kuendelea
        if (isAfyaW) return kadaH.isNotEmpty;
        return kadaHealthNames.isEmpty ? true : kadaH.isNotEmpty;
      case StepId.eneo:
        return isAfyaW
            ? (mkoa.isNotEmpty && cs.isNotEmpty) // mkoa + hospitali ya rufaa
            : (mkoa.isNotEmpty && cw.isNotEmpty && cs.isNotEmpty);
      case StepId.maeneo:
        if (isAfyaW) {
          return miaka.isNotEmpty && targets.isNotEmpty && targets.first.mkoa.isNotEmpty;
        }
        return miaka.isNotEmpty && targets.every((t) => t.mkoa.isNotEmpty);
    }
  }

  String get msg {
    switch (cur) {
      case StepId.taarifa:
        return _phoneCheckMsg ?? 'Jaza taarifa zote ili kuendelea';
      case StepId.idara:
        return 'Chagua idara ili kuendelea';
      case StepId.wizara:
        return 'Chagua wizara ili kuendelea';
      case StepId.kada:
        return isEdu
            ? 'Chagua masomo 2 ili kuendelea'
            : 'Chagua kada yako ili kuendelea';
      case StepId.eneo:
        return isAfyaW
            ? (mkoa.isEmpty ? 'Chagua mkoa ili kuendelea' : 'Chagua hospitali ya rufaa ili kuendelea')
            : 'Chagua mkoa, wilaya na ${unitName.toLowerCase()} ili kuendelea';
      case StepId.maeneo:
        return miaka.isEmpty
            ? 'Chagua miaka ya kazi ili kujisajili'
            : 'Chagua mkoa wa lengo ili kujisajili';
    }
  }

  // ---- vitendo ----
  void _go(int d) {
    if (done) return;
    FocusScope.of(context).unfocus();
    if (d > 0 && !valid) {
      setState(() {
        openDd = null;
        showErr = true;
      });
      return;
    }
    if (d > 0 && step == flow.length) {
      setState(() {
        openDd = null;
        showErr = false;
        done = true;
      });
      widget.onSubmit?.call(_data());
      return;
    }
    final n = (step + d).clamp(1, flow.length).toInt();
    setState(() {
      openDd = null;
      showErr = false;
      step = n;
    });
  }

  void _restart() => setState(() {
        done = false;
        step = 1;
        showErr = false;
        openDd = null;
      });

  RegistrationData _data() => RegistrationData(
        name: nameC.text.trim(),
        phone: phoneC.text.trim(),
        whatsapp: waC.text.trim(),
        idara: idara,
        wizara: wizara,
        kada: isEdu ? kada : kadaH,
        masomo: List.of(masomo),
        mkoa: mkoa,
        wilaya: cw,
        kituo: cs,
        miaka: miaka,
        targets: targets,
        categoryCode: _deptNameToCode[idara] ??
            (isEdu ? 'education' : 'health'),
        employmentSector: idara == 'Afya'
            ? (wizara == 'Wizara ya Afya' ? 'wizara_afya' : 'tamisemi')
            : (idara.startsWith('Watumishi') ? 'raisi_utumishi' : null),
        cadreCode: isEdu ? '' : (_cadreNameToCode[kadaH] ?? ''),
        subjectCodes: isEdu
            ? [for (final s in masomo) _subjectCode(s)]
            : const [],
        mkoaId: _mkoaIdC,
        wilayaId: _cwIdC,
        kituoId: cs.isNotEmpty ? _csIdC : null,
        kituoType: _csType,
        // miaka "3+ (miaka 3 au zaidi)" → 3; "2 miaka" → 2; "1 mwaka" → 1
        yearsOfService:
            miaka.startsWith('1') ? 1 : (miaka.startsWith('2') ? 2 : 3),
      );

  void _setIdara(String v) => setState(() {
        if (idara != v) {
          idara = v;
          wizara = '';
          kadaH = '';
          masomo = [];
          mkoa = '';
          cw = '';
          cs = '';
          _mkoaIdC = null;
          _cwIdC = null;
          _csIdC = null;
          _csType = null;
          _hospRegionIdC = null;
          _hospDistrictIdC = null;
          _hospDistrictNameC = null;
          for (final t in targets) {
            t.shule = [kNoSchool];
            t.shuleIds = {};
            t.mkoaId = null;
            t.wilayaIds = [];
          }
        }
      });

  void _setKada(String v) => setState(() {
        if (kada != v) {
          kada = v;
          masomo = [];
        }
      });

  void _togSubject(String v) => setState(() {
        if (masomo.contains(v)) {
          masomo.remove(v);
        } else if (masomo.length < 2) {
          masomo.add(v);
        }
      });

  // Kada ya Elimu (Msingi/Sekondari) — level kwa API
  String get _eduLevel => isSek ? 'Secondary' : 'Primary';

  void _togWilaya(TargetArea t, String v) => setState(() {
        if (v == kAny) {
          t.wilaya = [kAny];
          t.wilayaIds = [];
          return;
        }
        t.wilaya.remove(kAny);
        if (t.wilaya.contains(v)) {
          t.wilaya.remove(v);
          t.wilayaIds.remove(_districtIds['${t.mkoa}/$v']);
        } else {
          t.wilaya.add(v);
          final did = _districtIds['${t.mkoa}/$v'];
          if (did != null) t.wilayaIds.add(did);
        }
        if (t.wilaya.isEmpty) {
          t.wilaya = [kAny];
          t.wilayaIds = [];
        }
      });

  void _addTarget() => setState(() {
        openDd = null;
        targets.add(TargetArea());
      });

  void _delTarget(int k) => setState(() {
        openDd = null;
        targets.removeAt(k);
      });

  void _toggleDd(String id) => setState(() {
        // CHAGUO LA RADION na OPEN-CLOSE kwa utaratibu (ni kwa promise) —
        // inafunguka muda wa kubadikie; ikichagulisha kipengele ina-FUNGA
        // (single-select pekee; multi bado inabaki wazi).
        openDd = openDd == id ? null : id;
      });

  void _pick(String id, String label) {
    final c = _cfgFor(id)!;
    setState(() {
      c.pick(label);
      if (!c.multi) openDd = null;
    });
  }

  // ---- mipangilio ya kila dropdown ----
  _Dd? _cfgFor(String id) {
    final c = cfg;
    switch (id) {
      case 'wizara':
        return _Dd(
          items: c.wizara,
          selected: () => [wizara],
          pick: (v) {
            if (wizara != v) {
              wizara = v;
              mkoa = '';
              cw = '';
              cs = '';
              _mkoaIdC = null;
              _cwIdC = null;
              _csIdC = null;
              _csType = null;
              _hospRegionIdC = null;
              _hospDistrictIdC = null;
              _hospDistrictNameC = null;
              for (final t in targets) {
                t.shule = [kNoSchool];
                t.shuleIds = {};
              }
              if (v == 'Wizara ya Afya') _ensureHospitals();
            }
          },
        );
      case 'kadaH':
        return _Dd(
          search: true,
          items: [for (final e in kadaHealthNames) Option(e, c.kadaIcon)],
          selected: () => [kadaH],
          pick: (v) => kadaH = v,
        );
      case 'mkoaC':
        return _Dd(
          search: true,
          items: [for (final m in mikoaLive) Option(m, AppIcons.mapPin)],
          selected: () => [mkoa],
          pick: (v) {
            mkoa = v;
            cw = '';
            cs = '';
            _mkoaIdC = _regionIds[v];
            _cwIdC = null;
            _csIdC = null;
            _csType = null;
            _hospRegionIdC = null;
            _hospDistrictIdC = null;
            _hospDistrictNameC = null;
            if (_mkoaIdC != null) _ensureWilaya(v);
          },
        );
      case 'cw':
        return _Dd(
          search: true,
          items: [
            for (final w in (_wilayaCache[mkoa] ?? wilayaOf(mkoa)))
              Option(w, AppIcons.building)
          ],
          selected: () => [cw],
          pick: (v) {
            cw = v;
            cs = '';
            _csIdC = null;
            _csType = null;
            _cwIdC = _districtIds['$mkoa/$v'];
            if (_cwIdC != null) _ensureFacilities(_cwIdC!);
          },
        );
      case 'cs':
        if (isAfyaW) {
          return _Dd(
            search: true,
            items: [for (final u in units) Option(u, c.icon)],
            selected: () => [cs],
            pick: (v) {
              cs = v;
              _csIdC = _hospitalIds[v];
              _csType = _hospitalTypes[v];
              _hospRegionIdC = _hospitalRegionIds[v];
              _hospDistrictIdC = _hospitalDistrictIds[v];
              _hospDistrictNameC = _hospitalDistrictNames[v];
              _ensureHospitals();
            },
          );
        }
        return _Dd(
          search: true,
          items: [for (final u in units) Option(u, c.icon)],
          selected: () => [cs],
          pick: (v) {
            cs = v;
            final did = _cwIdC;
            _csIdC = did != null ? _facilityIdOf['$did|$v'] : null;
            _csType = did != null ? _facilityTypes['$did|$v'] : null;
          },
        );
      case 'miaka':
        return _Dd(
          items: kMiaka,
          selected: () => [miaka],
          pick: (v) => miaka = v,
        );
      default:
        break;
    }
    if (id.startsWith('mkoaT')) {
      final k = int.parse(id.substring(5));
      return _Dd(
        search: true,
        items: [for (final m in mikoaLive) Option(m, AppIcons.mapPin)],
        selected: () => [targets[k].mkoa],
        pick: (v) {
          targets[k].mkoa = v;
          targets[k].wilaya = [kAny];
          targets[k].shule = [kNoSchool];
          targets[k].mkoaId = _regionIds[v];
          targets[k].wilayaIds = [];
          targets[k].shuleIds = {};
          if (targets[k].mkoaId != null) _ensureWilaya(v);
        },
      );
    }
    if (id.startsWith('shT')) {
      final k = int.parse(id.substring(3));
      final t = targets[k];
      // Vituo vya target — kwa wilaya zilizochaguliwa (au zote za mkoa kama "yeyote")
      final dids = t.wilaya.contains(kAny)
          ? <int>[]
          : [for (final w in t.wilaya) _districtIds['${t.mkoa}/$w']].whereType<int>().toList();
      final opts = <String>[kNoSchool];
      if (dids.isEmpty) {
        opts.addAll(units);
      } else {
        for (final did in dids) {
          opts.addAll(_facilityCache[did] ?? const <String>[]);
        }
      }
      return _Dd(
        search: true,
        multi: true,
        items: [for (final u in opts) Option(u, c.icon)],
        selected: () => t.shule,
        pick: (v) {
          final a = t.shule;
          if (v == kNoSchool) {
            t.shule = [kNoSchool];
            t.shuleIds = {};
            return;
          }
          a.remove(kNoSchool);
          if (a.contains(v)) {
            a.remove(v);
            t.shuleIds.remove(v);
          } else {
            a.add(v);
            // Tafuta facility_id yake (kwenye wilaya zilizochaguliwa)
            String? fid;
            for (final did in dids) {
              fid = _facilityIdOf['$did|$v'];
              if (fid != null && fid.isNotEmpty) break;
              fid = null;
            }
            if (fid != null) t.shuleIds[v] = fid;
          }
          if (a.isEmpty) {
            t.shule = [kNoSchool];
            t.shuleIds = {};
          }
        },
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  //  UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              // Maudhui yakae KATI-KATI YA SKRINI (vertical center) yakifiwa
              // muda mfupi kuliko skrini — hasa hatua ya 1 na Idara. Yakikua
              // kuliko skrini, scroll ya kawaida inaendelea bila overflow.
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!done) _topHeader(),
                    const SizedBox(height: 10),
                    Expanded(child: Center(child: _card())),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topHeader() => Column(
        children: [
          // "Rudi" ya JUU imeondolewa — "Rudi" ya CHINI (footer) inatosha.
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.softBlueBorder),
            ),
            child: Text('Usajili',
                style: _ts(12, w: FontWeight.w500, c: AppColors.blue)),
          ),
          const SizedBox(height: 6),
          Text('Jaza Taarifa Zako', style: _ts(22, w: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('Hatua 4 rahisi. Utamaliza chini ya dakika 3.',
              style: _ts(12.5, c: AppColors.gray)),
        ],
      );

  Widget _card() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: .5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!done) _header(),
            _bodyContent(),
            _foot(),
          ],
        ),
      );

  Widget _header() {
    final f = flow;
    final n = f.length;
    final p = (step / n * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(_stepLabel[cur]!,
                style: _ts(13, w: FontWeight.w500, c: AppColors.blue)),
            const SizedBox(width: 6),
            Text('Hatua $step ya $n', style: _ts(13, c: AppColors.gray)),
            const Spacer(),
            Text('$p%', style: _ts(13, w: FontWeight.w500, c: AppColors.blue)),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            for (var i = 1; i <= n; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.blue : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < n) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 1; i <= n; i++)
              Expanded(
                child: Text(
                  _stepLabel[f[i - 1]]!,
                  textAlign: i == 1
                      ? TextAlign.left
                      : (i == n ? TextAlign.right : TextAlign.center),
                  style: _ts(10,
                      w: i == step ? FontWeight.w500 : FontWeight.w400,
                      c: i == step ? AppColors.blue : AppColors.lightGray),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---- vipande vya pamoja ----
  Widget _title(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: _ts(19, w: FontWeight.w500)),
            if (sub != null) Text(sub, style: _ts(12.5, c: AppColors.gray)),
          ],
        ),
      );

  Widget _label(String t, {bool req = false}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Text.rich(
          TextSpan(
            text: t,
            style: _ts(13.5, w: FontWeight.w500),
            children: [
              if (req)
                TextSpan(
                    text: ' *',
                    style: _ts(13.5, w: FontWeight.w500, c: AppColors.red)),
            ],
          ),
        ),
      );

  Widget _input(IconData icon, TextEditingController c, String hint) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line, width: 1.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: c,
                keyboardType: icon == AppIcons.user
                    ? TextInputType.name
                    : TextInputType.phone,
                style: _ts(13.5),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: hint,
                  hintStyle: _ts(13.5, c: AppColors.lightGray),
                  contentPadding: const EdgeInsets.symmetric(vertical: 3),
                ),
              ),
            ),
          ],
        ),
      );

  // ── SELECTION YA RADIO-STYLE (inline) — kwa mkoa/wilaya/kituo wa sasa ──
  // Upru: bila search, bila scroll ndani — orodha yote ignaonekana; page
  // ya juu inasogeza. Single-select: ukibonyeza kipengele unachagua + inafunga.
  Widget _selectBlock(String label, String id, String value,
      List<String> items, void Function(String) onPick) {
    final open = openDd == id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, req: true),
        InkWell(
          onTap: () => _toggleDd(id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color:
                      (showErr && value.isEmpty) ? AppColors.red : AppColors.line,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(id.startsWith('mkoa')
                    ? AppIcons.mapPin
                    : AppIcons.building,
                    size: 19, color: AppColors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Chagua $label' : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(13.5,
                        c: value.isNotEmpty
                            ? AppColors.text
                            : AppColors.lightGray),
                  ),
                ),
                Icon(open ? AppIcons.chevronUp : AppIcons.chevronDown,
                    size: 18, color: AppColors.blue),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 4),
                  padding: const EdgeInsets.all(4),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 14,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final it in items)
                        _selectRow(
                            it, value == it, () {
                          onPick(it);
                          // SINGLE-select: ukichagua, panel ina-FUNGA
                          // (kama Masomo radio widget — mtumiaji haambiwi
                          // kuscroll au kufunga kitufe).
                          setState(() => openDd = null);
                        }),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Radio-row ya IN-LINE (AfyaW hospitali za rufaa; miaka) — ile ile
  /// radio widget ya Masomo/_cell: duara la bluu + jina.
  Widget _radioRow(String t, bool on, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: on ? AppColors.light : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _ring(on),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t,
                    style: _ts(13,
                        w: on ? FontWeight.w500 : FontWeight.w400,
                        c: on ? AppColors.blue : AppColors.text,
                        h: 1.25)),
              ),
            ],
          ),
        ),
      );

  Widget _selectRow(String t, bool on, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: on ? AppColors.light : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _ring(on),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t,
                    style: _ts(13,
                        w: on ? FontWeight.w500 : FontWeight.w400,
                        c: on ? AppColors.blue : AppColors.text,
                        h: 1.25)),
              ),
            ],
          ),
        ),
      );

  Widget _ddField({
    required String id,
    required IconData icon,
    required String value,
    required String placeholder,
    bool bad = false,
    bool disabled = false,
    VoidCallback? onOpen,
  }) {
    final open = openDd == id;
    final has = value.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: disabled ? .45 : 1,
          child: InkWell(
            onTap: disabled
                ? null
                : () {
                    onOpen?.call();
                    _toggleDd(id);
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: bad
                        ? AppColors.red
                        : (open ? AppColors.blue : AppColors.line),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: AppColors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      has ? value : placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(13.5,
                          c: has ? AppColors.text : AppColors.lightGray),
                    ),
                  ),
                  Icon(open ? AppIcons.chevronUp : AppIcons.chevronDown,
                      size: 18, color: AppColors.blue),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? _DropdownPanel(
                  key: ValueKey(id),
                  cfg: _cfgFor(id)!,
                  onPick: (v) => _pick(id, v),
                  onDone: () => setState(() => openDd = null),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Gridi ya safu 2 yenye radio za duara (Masomo na Wilaya).
  Widget _twoCol(List<String> items, bool Function(String) isOn,
      void Function(String) onTap, double vPad) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _cell(items[i], isOn, onTap, vPad)),
          const SizedBox(width: 16),
          Expanded(
            child: i + 1 < items.length
                ? _cell(items[i + 1], isOn, onTap, vPad)
                : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _cell(String t, bool Function(String) isOn, void Function(String) onTap,
      double vPad) {
    final on = isOn(t);
    return InkWell(
      onTap: () => onTap(t),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.faint)),
        ),
        child: Row(
          children: [
            _ring(on),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t,
                style: _ts(12.5,
                    w: on ? FontWeight.w500 : FontWeight.w400,
                    c: on ? AppColors.blue : AppColors.text,
                    h: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kadaToggle(String t, IconData icon, bool on) => Expanded(
        child: _pressable(
          radius: 12,
          onTap: () => _setKada(t),
          color: on ? Colors.white : Colors.transparent,
          side: BorderSide(
              color: on ? AppColors.softBlueBorder : Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18, color: on ? AppColors.blue : AppColors.gray),
                const SizedBox(width: 8),
                Text(t,
                    style: _ts(13.5,
                        w: on ? FontWeight.w500 : FontWeight.w400,
                        c: on ? AppColors.blue : AppColors.gray)),
              ],
            ),
          ),
        ),
      );

  // ---- hatua ----
  Widget _bodyContent() {
    if (done) return _doneView();
    switch (cur) {
      case StepId.taarifa:
        return _stepTaarifa();
      case StepId.idara:
        return _stepIdara();
      case StepId.wizara:
        return _stepWizara();
      case StepId.kada:
        return isEdu ? _stepKadaElimu() : _stepKadaCheo();
      case StepId.eneo:
        return _stepEneo();
      case StepId.maeneo:
        return _stepMaeneo();
    }
  }

  Widget _doneView() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: AppColors.greenSoft, shape: BoxShape.circle),
                child: const Icon(AppIcons.check,
                    size: 30, color: AppColors.green),
              ),
              const SizedBox(height: 12),
              Text('Umefanikiwa kujisajili', style: _ts(19, w: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Karibu EssTransfer', style: _ts(13, c: AppColors.gray)),
            ],
          ),
        ),
      );

  Widget _stepTaarifa() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Jaza taarifa zako', 'Hatua 4 rahisi, chini ya dakika 3.'),
          _label('Jina kamili'),
          _input(AppIcons.user, nameC, 'Jina la kwanza na la ukoo'),
          _label('Namba ya simu'),
          _input(AppIcons.phone, phoneC, '0712345678'),
          // Uthibitisho wa namba (API) — ngumu ya kioo chini ya ya simu field
          if (_phoneCheckMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(AppIcons.alert, size: 14, color: AppColors.red),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(_phoneCheckMsg!,
                          style:
                              _ts(12, c: AppColors.red))),
                ],
              ),
            )
          else if (_phoneChecking)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                  const SizedBox(width: 6),
                  Text('Tunathibitisha namba...',
                      style: _ts(11.5, c: AppColors.gray)),
                ],
              ),
            ),
          _label('Namba ya WhatsApp'),
          _input(AppIcons.whatsapp, waC, '0623456789'),
        ],
      );

  Widget _stepIdara() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Idara', 'Unafanya kazi katika idara gani?'),
          const SizedBox(height: 10),
          for (final o in kIdara) _idaraCard(o),
        ],
      );

  Widget _idaraCard(Option o) {
    final on = idara == o.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _pressable(
        radius: 14,
        color: on ? AppColors.light : Colors.white,
        side: BorderSide(
            color: on ? AppColors.cardBlueBorder : AppColors.border),
        onTap: () => _setIdara(o.label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              _iconBox(o.icon, AppColors.blue,
                  on ? Colors.white : AppColors.light, 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(o.label,
                    style: _ts(13.5,
                        w: on ? FontWeight.w500 : FontWeight.w400,
                        c: on ? AppColors.blue : AppColors.text)),
              ),
              _ring(on),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepWizara() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Wizara', 'Je, unafanya kazi chini ya taasisi gani?'),
          _label('Wizara', req: true),
          _ddField(
            id: 'wizara',
            icon: cfg.wizara
                .firstWhere((o) => o.label == wizara,
                    orElse: () => const Option('', AppIcons.bank))
                .icon,
            value: wizara,
            placeholder: '-- Chagua --',
            bad: showErr && wizara.isEmpty,
          ),
        ],
      );

  Widget _stepKadaCheo() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Kada / Cheo Chako'),
          _label('Kada / Cheo Chako', req: true),
          _ddField(
            id: 'kadaH',
            icon: cfg.kadaIcon,
            value: kadaH,
            placeholder: 'Chagua kada yako',
            bad: showErr && kadaH.isEmpty,
          ),
        ],
      );

  Widget _stepKadaElimu() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            child: Text('Kada', style: _ts(19, w: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.faint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _kadaToggle('Msingi', AppIcons.backpack, !isSek),
                const SizedBox(width: 3),
                _kadaToggle('Sekondari', AppIcons.flask, isSek),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text.rich(TextSpan(
                  text: 'Masomo ya $kada',
                  style: _ts(14, w: FontWeight.w500),
                  children: [
                    TextSpan(
                        text: ' *',
                        style:
                            _ts(14, w: FontWeight.w500, c: AppColors.red)),
                  ],
                )),
                const SizedBox(width: 6),
                Text('(lazima somo 2)', style: _ts(12, c: AppColors.lightGray)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('Chagua somo unalofundisha',
                style: _ts(12, c: AppColors.gray)),
          ),
          _twoCol(subjectNames, (s) => masomo.contains(s), _togSubject, 9),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Umepata: ${masomo.length} somo',
              style: _ts(
                13,
                c: masomo.length == 2
                    ? AppColors.green
                    : (showErr ? AppColors.red : AppColors.gray),
              ),
            ),
          ),
        ],
      );

  Widget _stepEneo() {
    if (isAfyaW) {
      // Hospitali za wizara — pakia mara mtumiaji anapofikia hatua hii
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureHospitals());
      // MTIRIRIKO: MKOA (radio) → HOSPITALI ZA RUFAAA za mkoa huo (radio).
      final hospitals = _hospitalsOfRegion(mkoa);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Eneo la Sasa', 'Mkoa na hospitali unayofanya kazi'),
          _selectBlock('Mkoa', 'mkoaC', mkoa, mikoaLive, (v) {
            mkoa = v;
            cs = '';
            _mkoaIdC = _regionIds[v];
            _hospDistrictIdC = null;
            _hospDistrictNameC = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }),
          if (mkoa.isNotEmpty) ...[
            // HOSPITALI RUFAAA za mkoa huo — radio button widget (bila dropdown)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              child: Text('HOSPITALI RUFAAA ZA MKOA',
                  style: _ts(10.5, c: AppColors.gray)
                      .copyWith(letterSpacing: .5)),
            ),
            if (_hospitalLoading && hospitals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.8)),
                  const SizedBox(width: 8),
                  Text('Inapakia hospitali...', style: _ts(12.5, c: AppColors.gray)),
                ]),
              )
            else if (hospitals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Hakuna hospitali za mkoa huu kwenye mfumo — chagua mkoa mwingine',
                    style: _ts(12.5, c: AppColors.gray)),
              )
            else
              ...[
                for (final h in hospitals)
                  _radioRow(h, cs == h, () => setState(() {
                        cs = h;
                        _csIdC = _hospitalIds[h];
                        _csType = _hospitalTypes[h];
                        _hospDistrictIdC = _hospitalDistrictIds[h];
                        _hospDistrictNameC = _hospitalDistrictNames[h];
                      })),
              ],
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(isEdu ? 'Eneo la Sasa' : 'Kituo Chako cha Sasa',
            isEdu ? 'Unafanya kazi wapi sasa?' : null),
        // MIKOA — radio-style inline panel (bila dropdown, hakuna scroll;
        // ukichagua, panel inajifunga na WILAYA inatokea).
        _selectBlock('Mkoa', 'mkoaC', mkoa, mikoaLive, (v) {
          mkoa = v;
          cw = '';
          cs = '';
          _mkoaIdC = _regionIds[v];
          _cwIdC = null;
          _csIdC = null;
          _csType = null;
          if (_mkoaIdC != null) {
            _ensureWilaya(v);
            // Wilaya zinapopakiwa, panel ya WILAYA inafunguka moja kwa moja
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => openDd = _wilayaCache.isEmpty ? null : 'cw');
            });
          }
        }),
        if (mkoa.isNotEmpty) ...[
          // WILAYA — ile ile radio-style panel kwa mkoa uliochaguliwa.
          _selectBlock('Wilaya', 'cw', cw,
              _wilayaCache[mkoa] ?? wilayaOf(mkoa), (v) {
            cw = v;
            cs = '';
            _csIdC = null;
            _csType = null;
            _cwIdC = _districtIds['$mkoa/$v'];
            if (_cwIdC != null) {
              _ensureFacilities(_cwIdC!);
              // VITUO zinapopakiwa, panel ya VITUO inafunguka moja kwa moja
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => openDd = 'cs');
              });
            }
          }),
          if (cw.isNotEmpty)
            _selectBlock(unitName, 'cs', cs, units, (v) {
              cs = v;
              final did = _cwIdC;
              _csIdC = did != null ? _facilityIdOf['$did|$v'] : null;
              _csType = did != null ? _facilityTypes['$did|$v'] : null;
            }),
        ],
      ],
    );
  }

  Widget _stepMaeneo() {
    if (isAfyaW) {
      // WIZARA YA AFYA: MKOA WA LENGO (radio) → HOSPITALI YA LENGO (radio).
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureHospitals());
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Maeneo ya Lengo', 'Unataka kwenda mkoa gani?'),
          _selectBlock('Mkoa wa Lengo', 'mkoaT0', targets[0].mkoa, mikoaLive, (v) {
            targets[0].mkoa = v;
            targets[0].hospitali = '';
            targets[0].mkoaId = _regionIds[v];
            targets[0].hospitaliId = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }),
          if (targets[0].mkoa.isNotEmpty)
            Builder(builder: (_) {
              final hs = _hospitalsOfRegion(targets[0].mkoa);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 2),
                    child: Text('HOSPITALI YA RUFAA YA MCOKA (HIARI)',
                        style: _ts(10.5, c: AppColors.gray)
                            .copyWith(letterSpacing: .5)),
                  ),
                  if (hs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('Hakuna hospitali za mkoa huu — wasijisajili kwa mkoa tu',
                          style: _ts(12.5, c: AppColors.gray)),
                    )
                  else ...[
                    _radioRow('Bila Hospitali (Hiari)', targets[0].hospitali.isEmpty,
                        () => setState(() {
                              targets[0].hospitali = '';
                              targets[0].hospitaliId = null;
                            })),
                    for (final h in hs)
                      _radioRow(h, targets[0].hospitali == h, () => setState(() {
                            targets[0].hospitali = h;
                            final hid = _hospitalIds[h] ?? '';
                            targets[0].hospitaliId = hid.isNotEmpty ? hid : null;
                          })),
                  ],
                ],
              );
            }),
          _label('Umefanya kazi kwa miaka mingapi?', req: true),
          _ddField(
            id: 'miaka',
            icon: kMiaka
                .firstWhere((o) => o.label == miaka,
                    orElse: () => const Option('', AppIcons.briefcase))
                .icon,
            value: miaka,
            placeholder: 'Chagua miaka ya kazi',
            bad: showErr && miaka.isEmpty,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(isEdu ? 'Maeneo ya Lengo' : 'Mkoa Unakotakwa Kwenda',
            'Unataka kwenda mkoa/wilaya gani?'),
        for (var k = 0; k < targets.length; k++) _targetCard(k),
        if (targets.length < 3)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: InkWell(
              onTap: _addTarget,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.plus, size: 18, color: AppColors.blue),
                  const SizedBox(width: 6),
                  Text('Ongeza Mkoa Mwingine',
                      style:
                          _ts(13.5, w: FontWeight.w500, c: AppColors.blue)),
                ],
              ),
            ),
          ),
        _label('Umefanya kazi kwa miaka mingapi?', req: true),
        _ddField(
          id: 'miaka',
          icon: kMiaka
              .firstWhere((o) => o.label == miaka,
                  orElse: () => const Option('', AppIcons.briefcase))
              .icon,
          value: miaka,
          placeholder: 'Chagua miaka ya kazi',
          bad: showErr && miaka.isEmpty,
        ),
      ],
    );
  }

  Widget _targetCard(int k) {
    final t = targets[k];
    final wl = [kAny, ...(_wilayaCache[t.mkoa] ?? wilayaOf(t.mkoa))];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mkoa wa Lengo ${k + 1}',
                  style: _ts(13, w: FontWeight.w500, c: AppColors.blue)),
              const Spacer(),
              if (k > 0)
                InkWell(
                  onTap: () => _delTarget(k),
                  child: const Icon(AppIcons.trash,
                      size: 16, color: AppColors.lightGray),
                ),
            ],
          ),
          // MIKOA YA LENGO — radio-style panel (bila dropdown). Ukichagua
          // mkoa mmoja, panel inajifunga na WILAYA ZAKE zinatokea (radio 2-col).
          _selectBlock('Mkoa wa Lengo', 'mkoaT$k', t.mkoa, mikoaLive, (v) {
            targets[k].mkoa = v;
            targets[k].wilaya = [kAny];
            targets[k].shule = [kNoSchool];
            targets[k].mkoaId = _regionIds[v];
            targets[k].wilayaIds = [];
            targets[k].shuleIds = {};
            if (targets[k].mkoaId != null) {
              _ensureWilaya(v);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() {});
              });
            }
          }),
          if (t.mkoa.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 2),
              child: Text('WILAYA ZA LENGO',
                  style:
                      _ts(10.5, c: AppColors.gray).copyWith(letterSpacing: .5)),
            ),
            // WILAYA ZA LENGO — radio widget ya safu 2 (KAMA MASOMO).
            _twoCol(wl, (w) => t.wilaya.contains(w), (w) {
              _togWilaya(t, w);
              // Vituo vya wilaya mpya — pakia silent
              final did = _districtIds['${t.mkoa}/$w'];
              if (did != null) _ensureFacilities(did);
            }, 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _ddField(
                id: 'shT$k',
                icon: cfg.icon,
                value: t.shule.join(', '),
                placeholder: 'Chagua $unitName (hiari)',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- footer ----
  Widget _foot() {
    if (done) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          width: double.infinity,
          child: _pressable(
            radius: 12,
            onTap: _restart,
            side: const BorderSide(color: AppColors.line),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Center(
                  child: Text('Anza upya', style: _ts(14, w: FontWeight.w500))),
            ),
          ),
        ),
      );
    }
    final ok = valid;
    final last = step == flow.length;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          if (showErr && !ok)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(AppIcons.alert, size: 16, color: AppColors.red),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(msg, style: _ts(12.5, c: AppColors.red))),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (step == 1)
                GestureDetector(
                  onTap: widget.onLogin,
                  child: Text.rich(TextSpan(
                    text: 'Una akaunti? ',
                    style: _ts(13, c: AppColors.gray),
                    children: [
                      TextSpan(
                          text: 'Ingia',
                          style: _ts(13, w: FontWeight.w500,
                              c: AppColors.blue)),
                    ],
                  )),
                )
              else
                InkWell(
                  onTap: () => _go(-1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.arrowLeft,
                          size: 16, color: AppColors.blue),
                      const SizedBox(width: 4),
                      Text('Rudi', style: _ts(13.5, c: AppColors.blue)),
                    ],
                  ),
                ),
              // Endelea — bluu KILA WAKATI, na NDGO NDIOGO (ukubwa mdogo).
              Opacity(
                opacity: ok ? 1 : .55,
                child: _pressable(
                  radius: 9,
                  onTap: ok ? () => _go(1) : () => setState(() => showErr = true),
                  color: AppColors.blue,
                  side: BorderSide.none,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: last ? 12 : 14, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(last ? 'Najisajili' : 'Endelea',
                            style:
                                _ts(12.5, w: FontWeight.w500, c: Colors.white)),
                        if (!last) ...[
                          const SizedBox(width: 5),
                          const Icon(AppIcons.arrowRight,
                              size: 13, color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
