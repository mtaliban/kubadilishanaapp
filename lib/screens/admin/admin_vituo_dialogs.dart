import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/* ============================================================
   MODEL
   ============================================================ */
class Kituo {
  final String id;           // from int or school_code
  final String name;
  final String type;         // 'dispensary'|'health_center'|'hospital'|'laboratory'|'clinic'|'Primary'|'Secondary'
  final String category;     // 'health' | 'education'
  final String regionId;
  final String regionName;
  final String districtId;
  final String districtName;
  final bool active;
  final int? staffCount;

  const Kituo({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.regionId,
    this.regionName = '',
    required this.districtId,
    this.districtName = '',
    this.active = true,
    this.staffCount,
  });

  Kituo copyWith({
    String? name,
    String? type,
    String? category,
    String? regionId,
    String? regionName,
    String? districtId,
    String? districtName,
    bool? active,
  }) =>
      Kituo(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        category: category ?? this.category,
        regionId: regionId ?? this.regionId,
        regionName: regionName ?? this.regionName,
        districtId: districtId ?? this.districtId,
        districtName: districtName ?? this.districtName,
        active: active ?? this.active,
        staffCount: staffCount,
      );
}

const _kHealthTypes = [
  'dispensary',
  'health_center',
  'hospital',
  'laboratory',
  'clinic',
];

const _kEduTypes = ['Primary', 'Secondary'];

/* ============================================================
   1. ANGALIA
   ============================================================ */
Future<void> showKituoViewDialog(
  BuildContext context,
  Kituo kituo, {
  VoidCallback? onEdit,
}) {
  return showDialog(
    context: context,
    builder: (ctx) {
      final c = _C.of(ctx);
      final isHealth = kituo.category == 'health';

      return _Shell(
        c: c,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              c: c,
              icon: isHealth ? PhosphorIcons.building() : PhosphorIcons.graduationCap(),
              iconFg: isHealth ? c.red : c.blue,
              iconBg: isHealth ? c.redBg : c.blueBg,
              title: kituo.name,
              onClose: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 14),
            _Table(c: c, children: [
              _ViewRow(
                c: c,
                label: 'ID',
                value: Text(kituo.id,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 13,
                        fontFamily: 'monospace')),
              ),
              _ViewRow(c: c, label: 'JINA', value: _val(c, kituo.name)),
              _ViewRow(
                c: c,
                label: 'AINA',
                value: _Pill(
                  label: kituo.type,
                  fg: c.amber,
                  bg: c.amberBg,
                ),
              ),
              _ViewRow(
                c: c,
                label: 'IDARA',
                value: isHealth
                    ? _Pill(label: kituo.category, fg: c.red, bg: c.redBg)
                    : _Pill(
                        label: kituo.category,
                        fg: c.blue,
                        bg: c.blueBg,
                      ),
              ),
              _ViewRow(
                c: c,
                label: 'MKOA',
                value: _val(
                    c,
                    kituo.regionName.isNotEmpty
                        ? kituo.regionName
                        : kituo.regionId),
              ),
              _ViewRow(
                c: c,
                label: 'WILAYA',
                value: _val(
                    c,
                    kituo.districtName.isNotEmpty
                        ? kituo.districtName
                        : kituo.districtId),
              ),
              _ViewRow(
                c: c,
                label: 'HALI',
                value: kituo.active
                    ? _Pill(label: '● Hai', fg: c.green, bg: c.greenBg)
                    : _Pill(label: '● Imezimwa', fg: c.muted, bg: c.soft),
              ),
              if (kituo.staffCount != null)
                _ViewRow(
                  c: c,
                  label: 'WAFANYAKAZI',
                  value: _val(c, _fmt(kituo.staffCount!), bold: true),
                ),
            ]),
            _Footer(
              c: c,
              children: [
                const Spacer(),
                _SmallBtn(
                    label: 'Ghairi',
                    fg: c.muted,
                    bg: c.soft,
                    onTap: () => Navigator.pop(ctx)),
                const SizedBox(width: 6),
                _SmallBtn(
                  label: 'Hariri',
                  icon: PhosphorIcons.pencil(),
                  fg: c.blue,
                  bg: c.blueBg,
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit?.call();
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/* ============================================================
   2. HARIRI (au ONGEZA ukipitisha kituo = null)
   ============================================================ */
Future<Kituo?> showKituoEditDialog(
  BuildContext context, {
  Kituo? kituo,
  required List<({String id, String name})> mikoa,
  required Future<List<({String id, String name})>> Function(String regionId)
      loadWilaya,
}) {
  return showDialog<Kituo>(
    context: context,
    builder: (_) => _EditDialog(
      original: kituo,
      mikoa: mikoa,
      loadWilaya: loadWilaya,
    ),
  );
}

class _EditDialog extends StatefulWidget {
  final Kituo? original;
  final List<({String id, String name})> mikoa;
  final Future<List<({String id, String name})>> Function(String regionId)
      loadWilaya;

  const _EditDialog({
    this.original,
    required this.mikoa,
    required this.loadWilaya,
  });

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final Kituo o = widget.original ??
      const Kituo(
          id: '',
          name: '',
          type: 'dispensary',
          category: 'health',
          regionId: '',
          districtId: '');
  late final nameCtrl = TextEditingController(text: o.name);
  late String type = o.type;
  late String category = o.category;
  late String regionId = o.regionId;
  late String regionName = o.regionName;
  late String districtId = o.districtId;
  late String districtName = o.districtName;
  late bool active = o.active;

  List<({String id, String name})> _wilaya = [];
  bool _loadingWilaya = false;

  bool get isNew => widget.original == null;

  int get changes =>
      (nameCtrl.text.trim() != o.name ? 1 : 0) +
      (type != o.type ? 1 : 0) +
      (category != o.category ? 1 : 0) +
      (regionId != o.regionId ? 1 : 0) +
      (districtId != o.districtId ? 1 : 0) +
      (active != o.active ? 1 : 0);

  bool get canSave =>
      changes > 0 &&
      nameCtrl.text.trim().isNotEmpty &&
      regionId.isNotEmpty &&
      districtId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() => setState(() {}));
    // Pre-load wilaya if editing an existing kituo with a region
    if (regionId.isNotEmpty) {
      _loadWilayaFor(regionId);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWilayaFor(String rId) async {
    setState(() => _loadingWilaya = true);
    try {
      final list = await widget.loadWilaya(rId);
      if (mounted) setState(() { _wilaya = list; _loadingWilaya = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingWilaya = false);
    }
  }

  void _showPicker({
    required String title,
    required List<({String id, String name})> items,
    required void Function(String id, String name) onPick,
  }) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final c = _C.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final query = searchCtrl.text.toLowerCase();
            final filtered = query.isEmpty
                ? items
                : items
                    .where((e) => e.name.toLowerCase().contains(query))
                    .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (ctx, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.borderStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: TextStyle(
                                  color: c.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Material(
                          color: c.soft,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(PhosphorIcons.x(),
                                  size: 16, color: c.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        hintText: 'Tafuta...',
                        hintStyle: TextStyle(
                            color: c.muted.withValues(alpha: .7),
                            fontSize: 14),
                        isDense: true,
                        filled: true,
                        fillColor: c.soft,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                            size: 17, color: c.muted),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 40, minHeight: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: c.borderStrong),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: c.borderStrong),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: c.blue, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, thickness: 1, color: c.border),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: c.border),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            onPick(item.id, item.name);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            child: Text(item.name,
                                style: TextStyle(
                                    color: c.text, fontSize: 14)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _save() {
    Navigator.pop(
      context,
      o.copyWith(
        name: nameCtrl.text.trim(),
        type: type,
        category: category,
        regionId: regionId,
        regionName: regionName,
        districtId: districtId,
        districtName: districtName,
        active: active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final n = changes;
    final isHealth = category == 'health';
    final typeList = isHealth ? _kHealthTypes : _kEduTypes;

    return _Shell(
      c: c,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              c: c,
              icon: isHealth ? PhosphorIcons.building() : PhosphorIcons.graduationCap(),
              iconFg: isHealth ? c.red : c.blue,
              iconBg: isHealth ? c.redBg : c.blueBg,
              overline: isNew ? 'Ongeza kituo' : 'Hariri kituo',
              title:
                  nameCtrl.text.trim().isEmpty ? '—' : nameCtrl.text.trim(),
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 14),
            _Table(c: c, children: [
              _EditRow(
                c: c,
                label: 'JINA',
                child: _Field(
                  c: c,
                  controller: nameCtrl,
                  icon: PhosphorIcons.tag(),
                  hint: 'mf. Muhimbili Hospital',
                  capitalization: TextCapitalization.sentences,
                ),
              ),
              _EditRow(
                c: c,
                label: 'IDARA',
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _SegBtn(
                        c: c,
                        label: 'Afya',
                        icon: PhosphorIcons.heartbeat(),
                        iconColor: c.red,
                        on: category == 'health',
                        onTap: () => setState(() {
                          category = 'health';
                          type = 'dispensary';
                        }),
                      ),
                      _SegBtn(
                        c: c,
                        label: 'Elimu',
                        icon: PhosphorIcons.graduationCap(),
                        iconColor: c.blue,
                        on: category == 'education',
                        onTap: () => setState(() {
                          category = 'education';
                          type = 'Primary';
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              _EditRow(
                c: c,
                label: 'AINA',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: typeList.map((t) {
                    final on = t == type;
                    return GestureDetector(
                      onTap: () => setState(() => type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: on ? c.blue : c.borderStrong,
                            width: on ? 1.5 : 1,
                          ),
                          boxShadow: on
                              ? [BoxShadow(color: c.blueBg, spreadRadius: 3)]
                              : null,
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: on ? c.blue : c.text,
                            fontSize: 13,
                            fontWeight: on
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              _EditRow(
                c: c,
                label: 'MKOA',
                child: GestureDetector(
                  onTap: () => _showPicker(
                    title: 'Chagua Mkoa',
                    items: widget.mikoa,
                    onPick: (id, name) {
                      setState(() {
                        regionId = id;
                        regionName = name;
                        districtId = '';
                        districtName = '';
                        _wilaya = [];
                      });
                      _loadWilayaFor(id);
                    },
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.mapTrifold(), size: 17, color: c.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            regionName.isNotEmpty
                                ? regionName
                                : 'Chagua mkoa *',
                            style: TextStyle(
                              color: regionName.isNotEmpty
                                  ? c.text
                                  : c.muted.withValues(alpha: .7),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Icon(PhosphorIcons.caretDown(),
                            size: 16, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
              _EditRow(
                c: c,
                label: 'WILAYA',
                child: GestureDetector(
                  onTap: regionId.isEmpty
                      ? null
                      : () => _showPicker(
                            title: 'Chagua Wilaya',
                            items: _wilaya,
                            onPick: (id, name) => setState(() {
                              districtId = id;
                              districtName = name;
                            }),
                          ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: regionId.isEmpty ? c.soft : c.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.mapPin(),
                            size: 17,
                            color:
                                regionId.isEmpty ? c.muted : c.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _loadingWilaya
                              ? SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: c.blue,
                                  ),
                                )
                              : Text(
                                  regionId.isEmpty
                                      ? 'Chagua mkoa kwanza'
                                      : districtName.isNotEmpty
                                          ? districtName
                                          : 'Chagua wilaya *',
                                  style: TextStyle(
                                    color: (regionId.isEmpty ||
                                            districtName.isEmpty)
                                        ? c.muted.withValues(alpha: .7)
                                        : c.text,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                        Icon(PhosphorIcons.caretDown(),
                            size: 16, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
              _EditRow(
                c: c,
                label: 'HALI',
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _SegBtn(
                        c: c,
                        label: 'Hai',
                        icon: PhosphorIcons.checkCircle(),
                        iconColor: c.green,
                        on: active,
                        onTap: () => setState(() => active = true),
                      ),
                      _SegBtn(
                        c: c,
                        label: 'Imezimwa',
                        icon: PhosphorIcons.prohibit(),
                        iconColor: c.muted,
                        on: !active,
                        onTap: () => setState(() => active = false),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            _Footer(
              c: c,
              children: [
                Expanded(
                  child: Text(
                    n == 0 ? 'Hakuna mabadiliko' : 'Mabadiliko $n',
                    style: TextStyle(
                        color: n == 0 ? c.muted : c.blue, fontSize: 12),
                  ),
                ),
                _SmallBtn(
                    label: 'Ghairi',
                    fg: c.muted,
                    bg: c.soft,
                    onTap: () => Navigator.pop(context)),
                const SizedBox(width: 6),
                Opacity(
                  opacity: canSave ? 1 : .45,
                  child: _SmallBtn(
                    label: 'Hifadhi',
                    icon: PhosphorIcons.floppyDisk(),
                    fg: c.blue,
                    bg: c.blueBg,
                    onTap: canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   3. FUTA
   ============================================================ */
Future<bool> showKituoDeleteDialog(
    BuildContext context, Kituo kituo) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = _C.of(ctx);
      final isHealth = kituo.category == 'health';

      Widget btn(String label, Color f, Color b, bool v) => Expanded(
            child: _SmallBtn(
              label: label,
              fg: f,
              bg: b,
              expand: true,
              onTap: () => Navigator.pop(ctx, v),
            ),
          );

      return Dialog(
        backgroundColor: c.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 250,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isHealth ? c.redBg : c.blueBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isHealth
                              ? PhosphorIcons.building()
                              : PhosphorIcons.graduationCap(),
                          size: 22,
                          color: isHealth ? c.red : c.blue,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.card, width: 2),
                          ),
                          child: Icon(PhosphorIcons.trash(),
                              size: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: TextStyle(color: c.text, fontSize: 15),
                    children: [
                      const TextSpan(text: 'Futa '),
                      TextSpan(
                          text: kituo.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text('Haiwezi kutenduliwa',
                    style: TextStyle(color: c.muted, fontSize: 12)),
                const SizedBox(height: 14),
                Row(children: [
                  btn('Hapana', c.muted, c.soft, false),
                  const SizedBox(width: 6),
                  btn('Futa', c.red, c.redBg, true),
                ]),
              ],
            ),
          ),
        ),
      );
    },
  );
  return res ?? false;
}

/* ============================================================
   VIPANDE VINAVYOSHIRIKIWA
   ============================================================ */
String _fmt(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

Widget _val(_C c, String v, {bool bold = false}) => Text(v,
    textAlign: TextAlign.right,
    style: TextStyle(
        color: c.text,
        fontSize: 14,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400));

class _Shell extends StatelessWidget {
  final _C c;
  final Widget child;
  const _Shell({required this.c, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: c.card,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final _C c;
  final IconData icon;
  final Color iconFg;
  final Color iconBg;
  final String title;
  final String? overline;
  final VoidCallback onClose;

  const _Header({
    required this.c,
    required this.icon,
    required this.iconFg,
    required this.iconBg,
    required this.title,
    required this.onClose,
    this.overline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 21, color: iconFg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null)
                Text(overline!,
                    style: TextStyle(color: c.muted, fontSize: 12)),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.text,
                      fontSize: overline == null ? 18 : 17,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Material(
          color: c.soft,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(PhosphorIcons.x(), size: 16, color: c.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  final _C c;
  final List<Widget> children;
  const _Table({required this.c, required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, color: c.border));
      items.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

class _ViewRow extends StatelessWidget {
  final _C c;
  final String label;
  final Widget value;
  const _ViewRow(
      {required this.c, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: c.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3)),
          const SizedBox(width: 12),
          Expanded(
              child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final _C c;
  final String label;
  final Widget child;
  const _EditRow(
      {required this.c, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              style: TextStyle(
                  color: c.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final _C c;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool mono;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? formatters;

  const _Field({
    required this.c,
    required this.controller,
    required this.icon,
    required this.hint,
    this.mono = false,
    this.capitalization = TextCapitalization.none,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: col, width: w));
    return TextField(
      controller: controller,
      textCapitalization: capitalization,
      inputFormatters: formatters,
      autocorrect: !mono,
      style: TextStyle(
          color: c.text,
          fontSize: mono ? 13 : 14,
          fontFamily: mono ? 'monospace' : null),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: c.muted.withValues(alpha: .7), fontSize: 14),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: Icon(icon, size: 17, color: c.blue),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 0),
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final _C c;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool on;
  final VoidCallback onTap;

  const _SegBtn({
    required this.c,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 30,
          decoration: BoxDecoration(
            color: on ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                on ? Border.all(color: c.borderStrong, width: .5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: on ? c.text : c.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final _C c;
  final List<Widget> children;
  const _Footer({required this.c, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 12),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: c.border))),
      child: Row(children: children),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg, bg;
  final bool expand;
  final VoidCallback? onTap;

  const _SmallBtn({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.expand = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: expand ? double.infinity : null,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14),
              const SizedBox(width: 5)
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg, bg;
  const _Pill({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/* ============================================================
   RANGI
   ============================================================ */
class _C {
  final Color card, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg, red, redBg;

  const _C({
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

  static const light = _C(
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

  static const dark = _C(
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

  static _C of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
