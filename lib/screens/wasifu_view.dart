import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/* ============================================================
   MODELS
   ============================================================ */
class Destination {
  final String mkoa;
  final String? wilaya; // null = wilaya yoyote
  const Destination({required this.mkoa, this.wilaya});
}

class UserProfile {
  final String name;
  final String idara; // afya / elimu / ... (au health / education)
  final String kada;
  final List<String> subjects; // walimu tu
  final String phone;
  final String whatsapp;
  final String mkoa;
  final String wilaya;
  final String? kituo;
  final List<Destination> destinations;

  const UserProfile({
    required this.name,
    required this.idara,
    required this.kada,
    this.subjects = const [],
    required this.phone,
    required this.whatsapp,
    required this.mkoa,
    required this.wilaya,
    this.kituo,
    this.destinations = const [],
  });

  UserProfile copyWith({
    String? name,
    String? kada,
    List<String>? subjects,
    String? phone,
    String? whatsapp,
    String? mkoa,
    String? wilaya,
    String? kituo,
    bool clearKituo = false,
    List<Destination>? destinations,
  }) =>
      UserProfile(
        name: name ?? this.name,
        idara: idara,
        kada: kada ?? this.kada,
        subjects: subjects ?? this.subjects,
        phone: phone ?? this.phone,
        whatsapp: whatsapp ?? this.whatsapp,
        mkoa: mkoa ?? this.mkoa,
        wilaya: wilaya ?? this.wilaya,
        kituo: clearKituo ? null : (kituo ?? this.kituo),
        destinations: destinations ?? this.destinations,
      );
}

/* ============================================================
   UKURASA WA WASIFU
   Weka ndani ya Scaffold yako (body). Menyu ya chini inabaki yako.
   ============================================================ */
class WasifuView extends StatefulWidget {
  final UserProfile profile;

  /// Orodha za kuchagua
  final List<String> kadaOptions;
  final List<String> mikoa;
  final List<String> Function(String mkoa) wilayaOf;
  final List<String> Function(String wilaya) vituoOf;
  final List<String> subjectOptions; // walimu tu (acha tupu kwa wengine)

  /// Inaitwa ukibonyeza "Hifadhi". Tuma kwenye API yako.
  final Future<void> Function(UserProfile updated)? onSave;

  /// Umbali wa toast kutoka chini (juu ya menyu yako ya chini)
  final double toastBottom;

  const WasifuView({
    super.key,
    required this.profile,
    required this.kadaOptions,
    required this.mikoa,
    required this.wilayaOf,
    required this.vituoOf,
    this.subjectOptions = const [],
    this.onSave,
    this.toastBottom = 16,
  });

  @override
  State<WasifuView> createState() => _WasifuViewState();
}

class _WasifuViewState extends State<WasifuView> {
  late UserProfile p = widget.profile;
  bool editing = false;
  bool saving = false;
  bool toast = false;
  Timer? _toastTimer;

  // Hali ya kuhariri
  late TextEditingController nameCtrl, phoneCtrl, waCtrl;
  late String kada, mkoa, wilaya;
  String? kituo;
  late List<String> subjects;
  late List<Destination?> dests; // null.mkoa = bado hajachagua

  @override
  void didUpdateWidget(covariant WasifuView old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile && !editing) p = widget.profile;
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    if (editing) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      waCtrl.dispose();
    }
    super.dispose();
  }

  /* ---------- Msaidizi ---------- */
  bool get _teacher => _idaraKey(p.idara) == 'elimu';

  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  static String _local9(String ph) {
    var d = _digits(ph);
    if (d.startsWith('255')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d;
  }

  static String _group9(String d) =>
      d.length == 9 ? '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}' : d;

  static String _pretty(String ph) => '+255 ${_group9(_local9(ph))}';

  /// "KARAGWE Dc" -> "Karagwe DC", "NYAKAGOYAGOYE (Dispensary)" -> "Nyakagoyagoye (Dispensary)"
  static String place(String s) {
    const upper = {'DC', 'TC', 'MC', 'CC', 'HC', 'DDH'};
    return s.trim().split(RegExp(r'\s+')).map((w) {
      final bare = w.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
      if (upper.contains(bare)) return w.toUpperCase();
      if (w.isEmpty) return w;
      final i = w.indexOf(RegExp(r'[A-Za-z]'));
      if (i < 0) return w;
      return w.substring(0, i) + w[i].toUpperCase() + w.substring(i + 1).toLowerCase();
    }).join(' ');
  }

  static String _titleName(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  /* ---------- Hali ---------- */
  void _startEdit() {
    nameCtrl = TextEditingController(text: _titleName(p.name));
    phoneCtrl = TextEditingController(text: _group9(_local9(p.phone)));
    waCtrl = TextEditingController(text: _group9(_local9(p.whatsapp)));
    kada = p.kada;
    mkoa = p.mkoa;
    wilaya = p.wilaya;
    kituo = p.kituo;
    subjects = List.of(p.subjects);
    dests = p.destinations.map<Destination?>((d) => d).toList();
    setState(() => editing = true);
  }

  void _cancel() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    waCtrl.dispose();
    setState(() => editing = false);
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final name = nameCtrl.text.trim();
    final ph = _local9(phoneCtrl.text);
    final wa = _local9(waCtrl.text);
    if (name.length < 3) return _snack('Andika jina kamili');
    if (ph.length != 9) return _snack('Namba ya simu iwe tarakimu 9 baada ya +255');
    if (wa.length != 9) return _snack('Namba ya WhatsApp iwe tarakimu 9 baada ya +255');
    final chosen = dests.whereType<Destination>().where((d) => d.mkoa.isNotEmpty).toList();
    if (chosen.isEmpty) return _snack('Chagua angalau sehemu moja unayotaka kwenda');

    final updated = p.copyWith(
      name: name,
      phone: '0$ph',
      whatsapp: '0$wa',
      kada: kada,
      mkoa: mkoa,
      wilaya: wilaya,
      kituo: kituo,
      clearKituo: kituo == null,
      subjects: subjects,
      destinations: chosen,
    );

    FocusScope.of(context).unfocus();
    setState(() => saving = true);
    try {
      await widget.onSave?.call(updated);
      if (!mounted) return;
      nameCtrl.dispose();
      phoneCtrl.dispose();
      waCtrl.dispose();
      setState(() {
        p = updated;
        editing = false;
      });
      _showToast();
    } catch (e) {
      if (mounted) _snack('Imeshindikana kuhifadhi: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showToast() {
    _toastTimer?.cancel();
    setState(() => toast = true);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => toast = false);
    });
  }

  /// Orodha ya kuchagua (bottom sheet yenye kutafuta)
  Future<String?> _pick({
    required String title,
    required IconData icon,
    required List<String> options,
    String? current,
    String? anyLabel,
  }) {
    final c = _WC.of(context);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _PickerSheet(
        c: c,
        title: title,
        icon: icon,
        options: options,
        current: current,
        anyLabel: anyLabel,
        labelOf: place,
      ),
    );
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = _WC.of(context);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _header(c),
            if (editing) ..._edit(c) else ..._view(c),
          ],
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: widget.toastBottom,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              offset: toast ? Offset.zero : const Offset(0, .6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: toast ? 1 : 0,
                child: _toastBox(c),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(_WC c) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.blueBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(editing ? TablerIcons.userEdit : TablerIcons.user, size: 21, color: c.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(editing ? 'Hariri wasifu' : 'Wasifu wangu',
                  style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
              Text(editing ? 'Badilisha kisha hifadhi' : 'Taarifa za akaunti yako',
                  style: TextStyle(color: c.muted, fontSize: 12)),
            ]),
          ),
          if (!editing) _TonalBtn(c: c, icon: TablerIcons.pencil, label: 'Hariri', onTap: _startEdit),
        ],
      );

  /* ================= KUANGALIA ================= */
  List<Widget> _view(_WC c) {
    final id = _idaraInfo(p.idara);
    final (fg, bg) = c.tone(id.tone);
    return [
      _Card(
        c: c,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Text(_initials(p.name),
                style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Text(_titleName(p.name),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(label: id.label, icon: id.icon, fg: fg, bg: bg),
              _Pill(label: p.kada, fg: c.muted, bg: c.soft),
            ],
          ),
        ]),
      ),
      _Section(c: c, title: 'MAWASILIANO', children: [
        _InfoRow(c: c, icon: TablerIcons.phone, label: 'Namba ya simu', value: _pretty(p.phone)),
        _InfoRow(
            c: c,
            icon: TablerIcons.brandWhatsapp,
            label: 'Namba ya WhatsApp',
            value: _pretty(p.whatsapp),
            fg: c.green,
            bg: c.greenBg),
      ]),
      if (_teacher && p.subjects.isNotEmpty)
        _Section(c: c, title: 'MASOMO', children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: p.subjects
                  .map((s) => _Pill(label: s, icon: TablerIcons.book, fg: c.blue, bg: c.blueBg))
                  .toList(),
            ),
          ),
        ]),
      _Section(c: c, title: 'KITUO CHA SASA', children: [
        _InfoRow(
            c: c,
            icon: TablerIcons.mapPin,
            label: 'Mkoa na wilaya',
            value: '${place(p.wilaya)}, ${place(p.mkoa)}'),
        if ((p.kituo ?? '').isNotEmpty)
          _InfoRow(
              c: c,
              icon: _teacher ? TablerIcons.school : TablerIcons.buildingHospital,
              label: _teacher ? 'Shule' : 'Hospitali / kituo',
              value: place(p.kituo!)),
      ]),
      _Section(c: c, title: 'NINATAKA KWENDA', children: [
        if (p.destinations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Bado hujachagua', style: TextStyle(color: c.muted, fontSize: 12)),
          )
        else
          for (var i = 0; i < p.destinations.length; i++)
            Container(
              margin: EdgeInsets.only(top: i == 0 ? 4 : 8, bottom: i == p.destinations.length - 1 ? 8 : 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _NumDot(c: c, n: i + 1),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(place(p.destinations[i].mkoa),
                        style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(
                        p.destinations[i].wilaya == null
                            ? 'Wilaya yoyote'
                            : place(p.destinations[i].wilaya!),
                        style: TextStyle(color: c.muted, fontSize: 12)),
                  ]),
                ),
                Icon(TablerIcons.mapPinFilled, size: 18, color: c.green),
              ]),
            ),
      ]),
    ];
  }

  /* ================= KUHARIRI ================= */
  List<Widget> _edit(_WC c) {
    final id = _idaraInfo(p.idara);
    return [
      _Section(c: c, title: 'UTAMBULISHO', pad: true, children: [
        _Label(c: c, text: 'Jina kamili', first: true),
        _TextBox(c: c, controller: nameCtrl, icon: TablerIcons.user, caps: true),
        _Label(c: c, text: 'Idara'),
        _SelectBox(c: c, icon: id.icon, value: id.label, locked: true),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Idara haibadilishwi. Wasiliana na admin.',
              style: TextStyle(color: c.muted, fontSize: 11)),
        ),
        _Label(c: c, text: 'Kada'),
        _SelectBox(
          c: c,
          icon: TablerIcons.stethoscope,
          value: kada,
          onTap: () async {
            final v = await _pick(
                title: 'Chagua kada',
                icon: TablerIcons.stethoscope,
                options: widget.kadaOptions,
                current: kada);
            if (v != null) setState(() => kada = v);
          },
        ),
        if (_teacher && widget.subjectOptions.isNotEmpty) ...[
          _Label(c: c, text: 'Masomo'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.subjectOptions.map((s) {
              final on = subjects.contains(s);
              return GestureDetector(
                onTap: () => setState(() => on ? subjects.remove(s) : subjects.add(s)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? c.blue : c.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: on ? c.blue : c.borderStrong),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (on) ...[
                      const Icon(TablerIcons.check, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(s, style: TextStyle(color: on ? Colors.white : c.text, fontSize: 13)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ]),
      _Section(c: c, title: 'MAWASILIANO', pad: true, children: [
        _Label(c: c, text: 'Namba ya simu', first: true),
        _TextBox(c: c, controller: phoneCtrl, icon: TablerIcons.phone, prefix: '+255', phone: true),
        _Label(c: c, text: 'Namba ya WhatsApp'),
        _TextBox(
            c: c, controller: waCtrl, icon: TablerIcons.brandWhatsapp, prefix: '+255', phone: true),
      ]),
      _Section(c: c, title: 'KITUO CHA SASA', pad: true, children: [
        _Label(c: c, text: 'Mkoa', first: true),
        _SelectBox(
          c: c,
          icon: TablerIcons.map2,
          value: place(mkoa),
          onTap: () async {
            final v = await _pick(
                title: 'Chagua mkoa', icon: TablerIcons.map2, options: widget.mikoa, current: mkoa);
            if (v != null && v != mkoa) {
              final w = widget.wilayaOf(v);
              setState(() {
                mkoa = v;
                wilaya = w.isNotEmpty ? w.first : '';
                kituo = null;
              });
            }
          },
        ),
        _Label(c: c, text: 'Wilaya'),
        _SelectBox(
          c: c,
          icon: TablerIcons.buildingCommunity,
          value: wilaya.isEmpty ? 'Chagua wilaya' : place(wilaya),
          placeholder: wilaya.isEmpty,
          onTap: () async {
            final v = await _pick(
                title: 'Chagua wilaya',
                icon: TablerIcons.buildingCommunity,
                options: widget.wilayaOf(mkoa),
                current: wilaya);
            if (v != null && v != wilaya) {
              setState(() {
                wilaya = v;
                kituo = null;
              });
            }
          },
        ),
        _Label(c: c, text: _teacher ? 'Shule' : 'Hospitali / kituo', optional: true),
        _SelectBox(
          c: c,
          icon: _teacher ? TablerIcons.school : TablerIcons.buildingHospital,
          value: kituo == null ? 'Chagua (hiari)' : place(kituo!),
          placeholder: kituo == null,
          onTap: () async {
            final v = await _pick(
                title: _teacher ? 'Chagua shule' : 'Chagua kituo',
                icon: _teacher ? TablerIcons.school : TablerIcons.buildingHospital,
                options: widget.vituoOf(wilaya),
                current: kituo);
            if (v != null) setState(() => kituo = v);
          },
        ),
      ]),
      _Section(
        c: c,
        title: 'NINATAKA KWENDA',
        pad: true,
        trailing: _TonalBtn(
          c: c,
          icon: TablerIcons.plus,
          label: 'Ongeza',
          height: 28,
          onTap: () => setState(() => dests.add(const Destination(mkoa: ''))),
        ),
        children: [
          if (dests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Bado hujachagua. Bonyeza Ongeza.',
                  textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
            ),
          for (var i = 0; i < dests.length; i++) _destEditor(c, i),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: saving ? null : _cancel,
            style: TextButton.styleFrom(
              foregroundColor: c.muted,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: const Text('Ghairi'),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: FilledButton(
              onPressed: saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: c.blue,
                disabledBackgroundColor: c.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(TablerIcons.deviceFloppy, size: 15),
                      SizedBox(width: 6),
                      Text('Hifadhi'),
                    ]),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _destEditor(_WC c, int i) {
    final d = dests[i] ?? const Destination(mkoa: '');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(children: [
        Row(children: [
          _NumDot(c: c, n: i + 1, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Chaguo la ${i + 1}',
                style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            height: 26,
            child: TextButton(
              onPressed: () => setState(() => dests.removeAt(i)),
              style: TextButton.styleFrom(
                backgroundColor: c.redBg,
                foregroundColor: c.red,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 26),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(TablerIcons.trash, size: 13),
                SizedBox(width: 4),
                Text('Ondoa'),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _SelectBox(
          c: c,
          icon: TablerIcons.map2,
          value: d.mkoa.isEmpty ? 'Chagua mkoa' : place(d.mkoa),
          placeholder: d.mkoa.isEmpty,
          onTap: () async {
            final v = await _pick(
                title: 'Unataka kwenda mkoa gani?',
                icon: TablerIcons.map2,
                options: widget.mikoa,
                current: d.mkoa);
            if (v != null) setState(() => dests[i] = Destination(mkoa: v));
          },
        ),
        const SizedBox(height: 8),
        _SelectBox(
          c: c,
          icon: TablerIcons.buildingCommunity,
          value: d.wilaya == null ? 'Wilaya yoyote' : place(d.wilaya!),
          placeholder: d.wilaya == null,
          disabled: d.mkoa.isEmpty,
          onTap: d.mkoa.isEmpty
              ? null
              : () async {
                  final v = await _pick(
                    title: 'Chagua wilaya',
                    icon: TablerIcons.buildingCommunity,
                    options: widget.wilayaOf(d.mkoa),
                    current: d.wilaya,
                    anyLabel: 'Wilaya yoyote',
                  );
                  if (v == null) return;
                  setState(() => dests[i] =
                      Destination(mkoa: d.mkoa, wilaya: v == _PickerSheet.any ? null : v));
                },
        ),
      ]),
    );
  }

  Widget _toastBox(_WC c) => Material(
        color: c.card,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.borderStrong, width: .5)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: c.greenBg, shape: BoxShape.circle),
              child: Icon(TablerIcons.check, size: 15, color: c.green),
            ),
            const SizedBox(width: 10),
            Text('Mabadiliko yamehifadhiwa',
                style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  static String _initials(String n) => n
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
}

/* ============================================================
   IDARA
   ============================================================ */
enum _Tone { blue, green, amber }

String _idaraKey(String raw) {
  final k = raw.trim().toLowerCase();
  if (k == 'health' || k == 'afya') return 'afya';
  if (k == 'education' || k == 'elimu') return 'elimu';
  if (k.contains('agri') || k.contains('kilimo')) return 'kilimo';
  if (k.contains('public') || k.contains('umma')) return 'umma';
  return k;
}

({String label, IconData icon, _Tone tone}) _idaraInfo(String raw) {
  switch (_idaraKey(raw)) {
    case 'afya':
      return (label: 'Afya', icon: TablerIcons.heartRateMonitor, tone: _Tone.green);
    case 'elimu':
      return (label: 'Elimu', icon: TablerIcons.school, tone: _Tone.blue);
    case 'kilimo':
      return (label: 'Kilimo na ufugaji', icon: TablerIcons.plant2, tone: _Tone.green);
    case 'umma':
      return (label: 'Watumishi wa umma', icon: TablerIcons.buildingBank, tone: _Tone.amber);
    default:
      return (label: raw, icon: TablerIcons.briefcase, tone: _Tone.blue);
  }
}

/* ============================================================
   ORODHA YA KUCHAGUA (bottom sheet)
   ============================================================ */
class _PickerSheet extends StatefulWidget {
  static const any = '__any__';
  final _WC c;
  final String title;
  final IconData icon;
  final List<String> options;
  final String? current;
  final String? anyLabel;
  final String Function(String) labelOf;

  const _PickerSheet({
    required this.c,
    required this.title,
    required this.icon,
    required this.options,
    required this.labelOf,
    this.current,
    this.anyLabel,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final list = widget.options
        .where((o) => o.toLowerCase().contains(q.toLowerCase()))
        .toList();
    final showSearch = widget.options.length > 8;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration:
                    BoxDecoration(color: c.borderStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(widget.title,
                  style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => q = v),
                  style: TextStyle(color: c.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tafuta…',
                    hintStyle: TextStyle(color: c.muted, fontSize: 14),
                    prefixIcon: Icon(TablerIcons.search, size: 18, color: c.muted),
                    isDense: true,
                    filled: true,
                    fillColor: c.soft,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (widget.anyLabel != null && q.isEmpty)
                    _tile(c, _PickerSheet.any, widget.anyLabel!, widget.current == null),
                  ...list.map((o) => _tile(c, o, widget.labelOf(o), o == widget.current)),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Hakuna kinacholingana',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.muted, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(_WC c, String value, String label, bool on) => InkWell(
        onTap: () => Navigator.pop(context, value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: on ? c.blueBg : null,
          child: Row(children: [
            Icon(widget.icon, size: 17, color: c.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
            ),
            if (on) Icon(TablerIcons.check, size: 17, color: c.blue),
          ]),
        ),
      );
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _Card extends StatelessWidget {
  final _WC c;
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.c, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: padding,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: child,
      );
}

class _Section extends StatelessWidget {
  final _WC c;
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final bool pad;
  const _Section({
    required this.c,
    required this.title,
    required this.children,
    this.trailing,
    this.pad = false,
  });

  @override
  Widget build(BuildContext context) => _Card(
        c: c,
        padding: EdgeInsets.fromLTRB(14, 4, 14, pad ? 14 : 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Row(children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: c.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8)),
                ),
                if (trailing != null) trailing!,
              ]),
            ),
            ...children,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final _WC c;
  final IconData icon;
  final String label, value;
  final Color? fg, bg;
  const _InfoRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    this.fg,
    this.bg,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bg ?? c.blueBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: fg ?? c.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
              Text(value, style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

class _Label extends StatelessWidget {
  final _WC c;
  final String text;
  final bool first;
  final bool optional;
  const _Label({required this.c, required this.text, this.first = false, this.optional = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: first ? 4 : 12, bottom: 6),
        child: Text.rich(TextSpan(
          style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600),
          children: [
            TextSpan(text: text),
            if (optional)
              const TextSpan(text: ' (hiari)', style: TextStyle(fontWeight: FontWeight.w400)),
          ],
        )),
      );
}

class _TextBox extends StatelessWidget {
  final _WC c;
  final TextEditingController controller;
  final IconData icon;
  final String? prefix;
  final bool phone;
  final bool caps;
  const _TextBox({
    required this.c,
    required this.controller,
    required this.icon,
    this.prefix,
    this.phone = false,
    this.caps = false,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: col, width: w));
    return TextField(
      controller: controller,
      keyboardType: phone ? TextInputType.phone : TextInputType.name,
      textCapitalization: caps ? TextCapitalization.words : TextCapitalization.none,
      inputFormatters: phone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(11)]
          : null,
      style: TextStyle(color: c.text, fontSize: 14),
      cursorColor: c.blue,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: c.blue),
            if (prefix != null) ...[
              const SizedBox(width: 10),
              Text(prefix!, style: TextStyle(color: c.text, fontSize: 14)),
              const SizedBox(width: 10),
              Container(width: 1, height: 20, color: c.borderStrong),
            ],
          ]),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  final _WC c;
  final IconData icon;
  final String value;
  final bool locked;
  final bool placeholder;
  final bool disabled;
  final VoidCallback? onTap;
  const _SelectBox({
    required this.c,
    required this.icon,
    required this.value,
    this.locked = false,
    this.placeholder = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = locked || placeholder || disabled;
    return Opacity(
      opacity: disabled ? .55 : 1,
      child: Material(
        color: locked ? c.soft : c.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: locked || disabled ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.borderStrong),
            ),
            child: Row(children: [
              Icon(icon, size: 17, color: locked ? c.muted : c.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted ? c.muted : c.text, fontSize: 14)),
              ),
              Icon(locked ? TablerIcons.lock : TablerIcons.chevronDown, size: 15, color: c.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TonalBtn extends StatelessWidget {
  final _WC c;
  final IconData icon;
  final String label;
  final double height;
  final VoidCallback onTap;
  const _TonalBtn({
    required this.c,
    required this.icon,
    required this.label,
    required this.onTap,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: c.blueBg,
            foregroundColor: c.blue,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: Size(0, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15),
            const SizedBox(width: 5),
            Text(label),
          ]),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg, bg;
  const _Pill({required this.label, required this.fg, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _NumDot extends StatelessWidget {
  final _WC c;
  final int n;
  final double size;
  const _NumDot({required this.c, required this.n, this.size = 24});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle),
        child: Text('$n',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/* ============================================================
   RANGI
   ============================================================ */
class _WC {
  final Color card, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg, red, redBg;

  const _WC({
    required this.card,
    required this.soft,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.blue,
    required this.blueBg,
    required this.green,
    required this.greenBg,
    required this.amber,
    required this.amberBg,
    required this.red,
    required this.redBg,
  });

  static const light = _WC(
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFC3CAD6),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6475),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    green: Color(0xFF0F7A52),
    greenBg: Color(0xFFE3F5EC),
    amber: Color(0xFF9A5B00),
    amberBg: Color(0xFFFFF1D6),
    red: Color(0xFFC62828),
    redBg: Color(0xFFFDECEC),
  );

  static const dark = _WC(
    card: Color(0xFF181D26),
    soft: Color(0xFF212833),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF465164),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFA8B1C1),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    green: Color(0xFF5FD49A),
    greenBg: Color(0xFF15302A),
    amber: Color(0xFFF0B35A),
    amberBg: Color(0xFF3A2C14),
    red: Color(0xFFFF8A8A),
    redBg: Color(0xFF3A1D1F),
  );

  static _WC of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) => switch (t) {
        _Tone.blue => (blue, blueBg),
        _Tone.green => (green, greenBg),
        _Tone.amber => (amber, amberBg),
      };
}
