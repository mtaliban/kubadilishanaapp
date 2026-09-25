import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/* ============================================================
   DATA YA FOMU (inayorudishwa ukibonyeza Hifadhi)
   ============================================================ */
class NewUserData {
  final String name;
  final String phone; // mf. 0757590836
  final String? whatsapp;
  final String password;
  final String idara; // key: afya / elimu / kilimo / umma
  final String kada;
  final List<String> masomo;
  final String? mkoa;
  final String? wilaya;
  final String? kituo;
  final List<String> to;
  final bool active;
  final bool admin;
  final bool paid;

  NewUserData({
    required this.name,
    required this.phone,
    required this.whatsapp,
    required this.password,
    required this.idara,
    required this.kada,
    required this.masomo,
    required this.mkoa,
    required this.wilaya,
    required this.kituo,
    required this.to,
    required this.active,
    required this.admin,
    required this.paid,
  });
}

/* ============================================================
   ORODHA (badilisha na data kutoka API yako)
   ============================================================ */
enum _Tone { blue, green, amber }

class _Idara {
  final String key, title, subtitle;
  final IconData icon;
  final _Tone tone;
  const _Idara(this.key, this.title, this.subtitle, this.icon, this.tone);
}

final List<_Idara> kIdara = [
  _Idara('afya', 'Afya', 'Watumishi wa afya', PhosphorIcons.heartbeat(), _Tone.green),
  _Idara('elimu', 'Elimu', 'Walimu', PhosphorIcons.graduationCap(), _Tone.blue),
  _Idara('kilimo', 'Kilimo na ufugaji', 'Maafisa ugani na mifugo', PhosphorIcons.plant(), _Tone.green),
  _Idara('umma', 'Watumishi wa umma', 'Utawala na idara nyingine', PhosphorIcons.bank(), _Tone.amber),
];

// idara -> [ (kada, maelezo, icon) ]
final Map<String, List<(String, String, IconData)>> kKada = {
  'afya': [
    ('Clinical Officer', 'Afisa tabibu', PhosphorIcons.stethoscope()),
    ('Assistant Nursing Officer', 'Muuguzi msaidizi', PhosphorIcons.stethoscope()),
    ('Nutrition Officer II', 'Afisa lishe', PhosphorIcons.appleLogo()),
  ],
  'elimu': [
    ('Mwalimu wa Elimu ya Msingi', 'Shule ya msingi', PhosphorIcons.chalkboard()),
    ('Mwalimu wa Elimu ya Sekondari', 'Shule ya sekondari', PhosphorIcons.graduationCap()),
    ('Nutrition Officer II', 'Afisa lishe', PhosphorIcons.appleLogo()),
  ],
  'kilimo': [
    ('Afisa Kilimo', 'Mazao', PhosphorIcons.plant()),
    ('Afisa Mifugo', 'Mifugo', PhosphorIcons.pawPrint()),
  ],
  'umma': [
    ('Afisa Utumishi', 'Rasilimali watu', PhosphorIcons.users()),
    ('Mhasibu', 'Fedha', PhosphorIcons.calculator()),
  ],
};

const List<String> kMasomo = [
  'Arabic', 'Arts and Sports', 'Chinese', 'French', 'Hesabati',
  'Historia ya Tanzania na Maadili', 'Jiografia na Mazingira', 'Kiingereza',
  'Kiswahili', 'Maarifa ya Jamii', 'Religious Education', 'Sayansi',
  'Stadi za Kazi',
];

const List<String> kMikoa = [
  'Arusha', 'Dar es Salaam', 'Dodoma', 'Geita', 'Iringa', 'Kagera', 'Katavi',
  'Kigoma', 'Kilimanjaro', 'Lindi', 'Manyara', 'Mara', 'Mbeya', 'Morogoro',
  'Mtwara', 'Mwanza', 'Njombe', 'Pwani', 'Rukwa', 'Ruvuma', 'Shinyanga',
  'Simiyu', 'Singida', 'Songwe', 'Tabora', 'Tanga',
];

// Mfano tu — jaza zote kutoka API yako
const Map<String, List<String>> kWilaya = {
  'Kigoma': ['Kigoma MC', 'Kigoma DC', 'Kasulu DC', 'Kibondo DC', 'Uvinza DC'],
  'Manyara': ['Babati TC', 'Babati DC', 'Hanang DC', 'Kiteto DC', 'Mbulu DC', 'Simanjiro DC'],
  'Mara': ['Bunda DC', 'Musoma MC', 'Serengeti DC', 'Tarime DC'],
};

// wilaya -> vituo / shule (mfano tu)
const Map<String, List<String>> kVituo = {
  'Simanjiro DC': ['Orkesumet Sec', 'Mirerani Sec', 'Simanjiro Health Centre'],
  'Kigoma MC': ['Kigoma Sec', 'Maweni Hospital'],
};

bool _isHealth(String name) =>
    RegExp(r'health|hospital|zahanati|kituo cha afya', caseSensitive: false)
        .hasMatch(name);

/* ============================================================
   RANGI (nyeupe, zisizopauka)
   ============================================================ */
class FormColors {
  final Color page, card, soft, border, borderStrong, text, muted, faint;
  final Color blue, blueBg, green, greenBg, amber, amberBg, red;

  const FormColors({
    required this.page,
    required this.card,
    required this.soft,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.faint,
    required this.blue,
    required this.blueBg,
    required this.green,
    required this.greenBg,
    required this.amber,
    required this.amberBg,
    required this.red,
  });

  static const light = FormColors(
    page: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF4F6FA),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFC3CAD6),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6475),
    faint: Color(0xFF8A93A3),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    green: Color(0xFF0F7A52),
    greenBg: Color(0xFFE3F5EC),
    amber: Color(0xFF9A5B00),
    amberBg: Color(0xFFFFF1D6),
    red: Color(0xFFC62828),
  );

  static const dark = FormColors(
    page: Color(0xFF12161D),
    card: Color(0xFF12161D),
    soft: Color(0xFF1C222C),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF465164),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFA8B1C1),
    faint: Color(0xFF7C8699),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    green: Color(0xFF5FD49A),
    greenBg: Color(0xFF15302A),
    amber: Color(0xFFF0B35A),
    amberBg: Color(0xFF3A2C14),
    red: Color(0xFFFF8A8A),
  );

  static FormColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) => switch (t) {
        _Tone.blue => (blue, blueBg),
        _Tone.green => (green, greenBg),
        _Tone.amber => (amber, amberBg),
      };
}

/// Kipengele kimoja cha dropdown
class _Opt {
  final String value;
  final String title;
  final String? subtitle;
  final IconData icon;
  final _Tone tone;
  const _Opt(this.value, this.title, this.icon,
      {this.subtitle, this.tone = _Tone.blue});
}

/* ============================================================
   UKURASA WA FOMU
   ============================================================ */
class NewUserPage extends StatefulWidget {
  final Future<void> Function(NewUserData data)? onSave;
  const NewUserPage({super.key, this.onSave});

  @override
  State<NewUserPage> createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
  static const _titles = ['Taarifa binafsi', 'Kazi', 'Mahali na hali ya akaunti'];

  int step = 0;
  bool saving = false;
  String? openDd; // dropdown iliyo wazi

  // Hatua 1
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final waCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  bool sameAsPhone = false;
  bool showPw = false;

  // Hatua 2
  String? idara;
  String? kada;
  final Set<String> masomo = {};

  // Hatua 3
  String? mkoa;
  String? wilaya;
  String? kituo;
  final List<String> to = [];
  bool picking = false;
  bool active = true;
  bool admin = false;
  bool paid = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    waCtrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  /* ---------- Uhakiki ---------- */
  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  String? _validate() {
    if (step == 0) {
      if (nameCtrl.text.trim().isEmpty) return 'Andika jina kamili';
      if (_digits(phoneCtrl.text).length != 9) {
        return 'Namba ya simu iwe tarakimu 9 baada ya +255';
      }
      if (!sameAsPhone &&
          waCtrl.text.trim().isNotEmpty &&
          _digits(waCtrl.text).length != 9) {
        return 'Namba ya WhatsApp iwe tarakimu 9 baada ya +255';
      }
      if (pwCtrl.text.length < 6) return 'Nywila iwe angalau herufi 6';
    }
    if (step == 1) {
      if (idara == null) return 'Chagua idara';
      if (kada == null) return 'Chagua kada';
    }
    return null;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _next() async {
    final err = _validate();
    if (err != null) return _toast(err);
    if (step < 2) {
      setState(() {
        step++;
        openDd = null;
      });
      return;
    }
    await _save();
  }

  void _back() {
    if (step > 0) {
      setState(() {
        step--;
        openDd = null;
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _save() async {
    final phone = '0${_digits(phoneCtrl.text)}';
    final wa = _digits(waCtrl.text);
    final data = NewUserData(
      name: nameCtrl.text.trim(),
      phone: phone,
      whatsapp: sameAsPhone ? phone : (wa.isEmpty ? null : '0$wa'),
      password: pwCtrl.text,
      idara: idara!,
      kada: kada!,
      masomo: idara == 'elimu' ? masomo.toList() : [],
      mkoa: mkoa,
      wilaya: wilaya,
      kituo: kituo,
      to: List.of(to),
      active: active,
      admin: admin,
      paid: paid,
    );
    setState(() => saving = true);
    try {
      await widget.onSave?.call(data);
      if (!mounted) return;
      _toast('Mtumiaji amehifadhiwa');
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) _toast('Imeshindikana kuhifadhi: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _toggleDd(String id) => setState(() => openDd = openDd == id ? null : id);

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = FormColors.of(context);
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: [
            _header(c),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    [_step1, _step2, _step3][step](c),
                    _nav(c),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(FormColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 10),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: Icon(PhosphorIcons.arrowLeft(), size: 21, color: c.text),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mtumiaji mpya',
                        style: TextStyle(
                            color: c.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                    Text('Hatua ${step + 1} kati ya 3 · ${_titles[step]}',
                        style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i <= step ? c.blue : c.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(FormColors c) {
    final last = step == 2;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      // Wrap badala ya Row: vitufe vinashuka mstari chini kwenye skrini
      // ndogo badala ya kumwaga (overflow ya piksel 78 kwenye 320px).
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          if (step > 0)
            TextButton.icon(
              onPressed: _back,
              icon: Icon(PhosphorIcons.caretLeft(), size: 18, color: c.muted),
              label: Text('Rudi',
                  style: TextStyle(
                      color: c.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: saving ? null : _next,
              style: FilledButton.styleFrom(
                backgroundColor: c.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: last
                          ? [
                              Icon(PhosphorIcons.floppyDisk(), size: 18),
                              const SizedBox(width: 6),
                              const Text('Hifadhi'),
                            ]
                          : [
                              const Text('Endelea'),
                              const SizedBox(width: 6),
                              Icon(PhosphorIcons.arrowRight(), size: 18),
                            ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /* ================= HATUA 1 ================= */
  Widget _step1(FormColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(icon: PhosphorIcons.userCircle(), title: 'Taarifa binafsi', c: c),
        _Label('Jina kamili', required: true, c: c),
        _Input(
          c: c,
          controller: nameCtrl,
          icon: PhosphorIcons.user(),
          hint: 'mf. Juma Kiswili',
          capitalization: TextCapitalization.words,
        ),
        _Label('Namba ya simu', required: true, c: c),
        _Input(
          c: c,
          controller: phoneCtrl,
          icon: PhosphorIcons.phone(),
          hint: '712 345 678',
          prefix255: true,
          keyboard: TextInputType.phone,
        ),
        _Label('WhatsApp', c: c, trailing: 'hiari'),
        InkWell(
          onTap: () => setState(() => sameAsPhone = !sameAsPhone),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: sameAsPhone,
                    onChanged: (v) => setState(() => sameAsPhone = v ?? false),
                    activeColor: c.blue,
                    side: BorderSide(color: c.borderStrong, width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Expanded: maandishi yanafupishwa kwenye skrini ndogo
                  // badala ya kumwaga (overflow ya piksel 78 kwenye 320px).
                  child: Text('Ni sawa na namba ya simu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.text, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
        if (!sameAsPhone)
          _Input(
            c: c,
            controller: waCtrl,
            icon: PhosphorIcons.whatsappLogo(),
            iconColor: c.green,
            hint: '689 225 170',
            prefix255: true,
            keyboard: TextInputType.phone,
          ),
        _Label('Nywila', required: true, c: c),
        _Input(
          c: c,
          controller: pwCtrl,
          icon: PhosphorIcons.lock(),
          hint: 'Angalau herufi 6',
          obscure: !showPw,
          suffix: IconButton(
            onPressed: () => setState(() => showPw = !showPw),
            icon: Icon(showPw ? PhosphorIcons.eyeSlash() : PhosphorIcons.eye(),
                size: 19, color: c.muted),
          ),
        ),
      ],
    );
  }

  /* ================= HATUA 2 ================= */
  Widget _step2(FormColors c) {
    final idaraOpts = kIdara
        .map((d) => _Opt(d.key, d.title, d.icon,
            subtitle: d.subtitle, tone: d.tone))
        .toList();
    final tone = kIdara
        .firstWhere((d) => d.key == idara,
            orElse: () => kIdara[1])
        .tone;
    final kadaOpts = (kKada[idara] ?? const [])
        .map((k) => _Opt(k.$1, k.$1, k.$3, subtitle: k.$2, tone: tone))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(icon: PhosphorIcons.briefcaseMetal(), title: 'Kazi', c: c),
        _Label('Idara', required: true, c: c),
        _IconDropdown(
          c: c,
          icon: PhosphorIcons.buildings(),
          hint: 'Chagua idara',
          options: idaraOpts,
          value: idara,
          open: openDd == 'idara',
          onToggle: () => _toggleDd('idara'),
          onPick: (v) => setState(() {
            if (idara != v) {
              kada = null;
              masomo.clear();
            }
            idara = v;
            openDd = null;
          }),
        ),
        _Label('Kada', required: true, c: c),
        _IconDropdown(
          c: c,
          icon: PhosphorIcons.identificationBadge(),
          hint: 'Chagua kada',
          disabledHint: 'Chagua idara kwanza',
          enabled: idara != null,
          options: kadaOpts,
          value: kada,
          open: openDd == 'kada',
          onToggle: () => _toggleDd('kada'),
          onPick: (v) => setState(() {
            kada = v;
            openDd = null;
          }),
        ),
        if (idara == 'elimu') ...[
          _Label('Masomo anayofundisha',
              c: c,
              trailing: '${masomo.length} umechagua',
              trailingColor: c.blue),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kMasomo
                .map((m) => _Chip(
                      c: c,
                      label: m,
                      icon: masomo.contains(m)
                          ? PhosphorIcons.check()
                          : PhosphorIcons.bookOpen(),
                      selected: masomo.contains(m),
                      onTap: () => setState(() {
                        masomo.contains(m) ? masomo.remove(m) : masomo.add(m);
                      }),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  /* ================= HATUA 3 ================= */
  Widget _step3(FormColors c) {
    final mkoaOpts = kMikoa
        .map((m) => _Opt(m, m, PhosphorIcons.mapPin(), subtitle: 'Mkoa'))
        .toList();
    final wilayaOpts = (kWilaya[mkoa] ?? const <String>[])
        .map((w) => _Opt(w, w, PhosphorIcons.buildings(), subtitle: mkoa))
        .toList();
    final kituoOpts = (kVituo[wilaya] ?? const <String>[])
        .map((k) => _Opt(
              k,
              k,
              _isHealth(k) ? PhosphorIcons.hospital() : PhosphorIcons.graduationCap(),
              subtitle: wilaya,
              tone: _isHealth(k) ? _Tone.green : _Tone.blue,
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(icon: PhosphorIcons.mapTrifold(), title: 'Mahali anapofanyia kazi', c: c),
        _Label('Mkoa', c: c),
        _IconDropdown(
          c: c,
          icon: PhosphorIcons.mapPin(),
          hint: 'Chagua mkoa',
          options: mkoaOpts,
          value: mkoa,
          open: openDd == 'mkoa',
          onToggle: () => _toggleDd('mkoa'),
          onPick: (v) => setState(() {
            if (mkoa != v) {
              wilaya = null;
              kituo = null;
            }
            mkoa = v;
            to.remove(v);
            openDd = null;
          }),
        ),
        _Label('Wilaya', c: c),
        _IconDropdown(
          c: c,
          icon: PhosphorIcons.buildings(),
          hint: 'Chagua wilaya',
          disabledHint: 'Chagua mkoa kwanza',
          enabled: mkoa != null,
          emptyText: 'Hakuna wilaya zilizowekwa kwa mkoa huu',
          options: wilayaOpts,
          value: wilaya,
          open: openDd == 'wilaya',
          onToggle: () => _toggleDd('wilaya'),
          onPick: (v) => setState(() {
            if (wilaya != v) kituo = null;
            wilaya = v;
            openDd = null;
          }),
        ),
        _Label('Kituo / shule', c: c),
        _IconDropdown(
          c: c,
          icon: PhosphorIcons.building(),
          hint: 'Chagua kituo',
          disabledHint: 'Chagua wilaya kwanza',
          enabled: wilaya != null,
          emptyText: 'Hakuna vituo vilivyowekwa kwa wilaya hii',
          options: kituoOpts,
          value: kituo,
          open: openDd == 'kituo',
          onToggle: () => _toggleDd('kituo'),
          onPick: (v) => setState(() {
            kituo = v;
            openDd = null;
          }),
        ),

        // Anapotaka kwenda
        _Section(
          icon: PhosphorIcons.path(),
          title: 'Anapotaka kwenda',
          c: c,
          trailing: '${to.length} mikoa',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.borderStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (to.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Bado hujaongeza mkoa wowote.',
                      style: TextStyle(color: c.muted, fontSize: 13)),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: to
                        .map((m) => _DestChip(
                              c: c,
                              label: m,
                              onRemove: () => setState(() => to.remove(m)),
                            ))
                        .toList(),
                  ),
                ),
              if (picking) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Gusa mikoa anayotaka kwenda',
                      style: TextStyle(color: c.muted, fontSize: 12)),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kMikoa
                      .where((m) => m != mkoa)
                      .map((m) => _Chip(
                            c: c,
                            label: m,
                            icon: to.contains(m)
                                ? PhosphorIcons.check()
                                : PhosphorIcons.mapPin(),
                            selected: to.contains(m),
                            onTap: () => setState(() {
                              to.contains(m) ? to.remove(m) : to.add(m);
                            }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: () => setState(() => picking = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text,
                      side: BorderSide(color: c.borderStrong),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Maliza kuchagua',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else
                _DashedButton(
                  label: 'Ongeza mkoa',
                  c: c,
                  onTap: () => setState(() => picking = true),
                ),
            ],
          ),
        ),

        // Hali ya akaunti
        _Section(icon: PhosphorIcons.shield(), title: 'Hali ya akaunti', c: c),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.borderStrong),
          ),
          child: Column(
            children: [
              _ToggleRow(
                c: c,
                icon: PhosphorIcons.userCheck(),
                title: 'Akaunti hai',
                sub: 'Anaweza kuingia kwenye app',
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
              Divider(height: 1, color: c.border),
              _ToggleRow(
                c: c,
                icon: PhosphorIcons.shieldChevron(),
                title: 'Haki za admin',
                sub: 'Anaweza kusimamia watumiaji',
                value: admin,
                onChanged: (v) => setState(() => admin = v),
              ),
              Divider(height: 1, color: c.border),
              _ToggleRow(
                c: c,
                icon: PhosphorIcons.receipt(),
                title: 'Amelipa',
                sub: 'Malipo yamethibitishwa',
                value: paid,
                onChanged: (v) => setState(() => paid = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ============================================================
   DROPDOWN YENYE ICONS
   ============================================================ */
class _IconDropdown extends StatelessWidget {
  final FormColors c;
  final IconData icon;
  final String hint;
  final String? disabledHint;
  final String? emptyText;
  final bool enabled;
  final List<_Opt> options;
  final String? value;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onPick;

  const _IconDropdown({
    required this.c,
    required this.icon,
    required this.hint,
    required this.options,
    required this.value,
    required this.open,
    required this.onToggle,
    required this.onPick,
    this.disabledHint,
    this.emptyText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    _Opt? sel;
    for (final o in options) {
      if (o.value == value) sel = o;
    }
    final isOpen = open && enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kisanduku chenyewe
        Material(
          color: enabled ? c.card : c.soft,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onToggle : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOpen ? c.blue : c.borderStrong,
                  width: isOpen ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (sel != null)
                    _IconTile(icon: sel.icon, tone: sel.tone, c: c, size: 28)
                  else
                    Icon(icon, size: 20, color: c.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sel?.title ?? (enabled ? hint : (disabledHint ?? hint)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sel != null ? c.text : c.muted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(),
                    size: 18,
                    color: c.muted,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Orodha
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: !isOpen
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderStrong),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: options.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(emptyText ?? 'Hakuna data',
                              style: TextStyle(color: c.muted, fontSize: 13)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: c.border),
                          itemBuilder: (_, i) {
                            final o = options[i];
                            final picked = o.value == value;
                            return Material(
                              color: picked ? c.blueBg : c.card,
                              child: InkWell(
                                onTap: () => onPick(o.value),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      _IconTile(
                                          icon: o.icon, tone: o.tone, c: c),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(o.title,
                                                style: TextStyle(
                                                    color: c.text,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            if (o.subtitle != null)
                                              Text(o.subtitle!,
                                                  style: TextStyle(
                                                      color: c.muted,
                                                      fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      if (picked)
                                        Icon(PhosphorIcons.check(),
                                            size: 18, color: c.blue),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _IconTile extends StatelessWidget {
  final IconData icon;
  final _Tone tone;
  final FormColors c;
  final double size;

  const _IconTile(
      {required this.icon, required this.tone, required this.c, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = c.tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(icon, size: size * .5, color: fg),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final FormColors c;

  const _Section(
      {required this.icon, required this.title, required this.c, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          if (trailing != null)
            Flexible(
              child: Text(trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool required;
  final String? trailing;
  final Color? trailingColor;
  final FormColors c;

  const _Label(this.text,
      {required this.c,
      this.required = false,
      this.trailing,
      this.trailingColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: text,
                style: TextStyle(
                    color: c.text, fontSize: 13, fontWeight: FontWeight.w600),
                children: [
                  if (required)
                    TextSpan(text: ' *', style: TextStyle(color: c.red)),
                ],
              ),
            ),
          ),
          if (trailing != null)
            Flexible(
              child: Text(trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: trailingColor ?? c.muted,
                      fontSize: 12,
                      fontWeight: trailingColor != null
                          ? FontWeight.w600
                          : FontWeight.w400)),
            ),
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final FormColors c;
  final TextEditingController controller;
  final IconData icon;
  final Color? iconColor;
  final String hint;
  final bool prefix255;
  final bool obscure;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;
  final Widget? suffix;

  const _Input({
    required this.c,
    required this.controller,
    required this.icon,
    required this.hint,
    this.iconColor,
    this.prefix255 = false,
    this.obscure = false,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: col, width: w),
        );
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      style: TextStyle(color: c.text, fontSize: 15),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.faint, fontSize: 15),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: iconColor ?? c.blue),
              if (prefix255) ...[
                const SizedBox(width: 10),
                Text('+255', style: TextStyle(color: c.text, fontSize: 15)),
                const SizedBox(width: 10),
                Container(width: 1, height: 20, color: c.borderStrong),
              ],
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final FormColors c;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.c,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.blue : c.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? c.blue : c.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : c.blue),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : c.text, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _DestChip extends StatelessWidget {
  final FormColors c;
  final String label;
  final VoidCallback onRemove;

  const _DestChip(
      {required this.c, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.blueBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.mapPin(), size: 14, color: c.blue),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: c.blue, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(PhosphorIcons.x(), size: 13, color: c.blue),
          ],
        ),
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  final String label;
  final FormColors c;
  final VoidCallback onTap;

  const _DashedButton(
      {required this.label, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: CustomPaint(
        painter: _DashedRRectPainter(color: c.blue, radius: 10),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.plus(), size: 17, color: c.blue),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: c.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

class _ToggleRow extends StatelessWidget {
  final FormColors c;
  final IconData icon;
  final String title, sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.c,
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            _IconTile(icon: icon, tone: _Tone.blue, c: c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: c.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(sub, style: TextStyle(color: c.muted, fontSize: 12)),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: c.blue,
                inactiveTrackColor: c.borderStrong,
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                trackOutlineColor:
                    const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
