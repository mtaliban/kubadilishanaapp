import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/* ============================================================
   IDARA NA SAFU ZA FAILI
   ============================================================ */
enum _Tone { blue, green, amber }

class _Idara {
  final String key, title, subtitle;
  final IconData icon;
  final _Tone tone;
  const _Idara(this.key, this.title, this.subtitle, this.icon, this.tone);
}

const _idara = [
  _Idara('afya', 'Afya', 'Watumishi wa afya', TablerIcons.heartRateMonitor, _Tone.green),
  _Idara('elimu', 'Elimu', 'Walimu', TablerIcons.school, _Tone.blue),
  _Idara('kilimo', 'Kilimo na ufugaji', 'Maafisa ugani na mifugo', TablerIcons.plant2, _Tone.green),
  _Idara('umma', 'Watumishi wa umma', 'Utawala na idara nyingine', TablerIcons.buildingBank, _Tone.amber),
];

class ImportColumn {
  final String name;
  final bool required;
  final bool isPhone;
  const ImportColumn(this.name, {this.required = false, this.isPhone = false});
}

List<ImportColumn> importColumnsFor(String idara) => [
      const ImportColumn('Jina kamili', required: true),
      const ImportColumn('Simu', required: true, isPhone: true),
      const ImportColumn('WhatsApp', isPhone: true),
      const ImportColumn('Kada', required: true),
      const ImportColumn('Kiwango'),
      if (idara == 'elimu') ...[
        const ImportColumn('Somo 1'),
        const ImportColumn('Somo 2'),
      ],
      const ImportColumn('Mkoa', required: true),
      const ImportColumn('Wilaya', required: true),
      const ImportColumn('Shule/Kituo'),
      const ImportColumn('Mkoa wa lengo 1', required: true),
    ];

/* ============================================================
   MATOKEO YA KUSOMA FAILI
   ============================================================ */
class _RowError {
  final int row; // namba ya safu kwenye Excel
  final String reason;
  const _RowError(this.row, this.reason);
}

class _ParsedFile {
  final String name;
  final int bytes;
  final List<Map<String, String>> valid;
  final List<_RowError> errors;
  const _ParsedFile(this.name, this.bytes, this.valid, this.errors);
  int get total => valid.length + errors.length;
}

/* ============================================================
   UKURASA
   ============================================================ */
class ImportUsersPage extends StatefulWidget {
  /// Inaitwa ukibonyeza "Pakua": bytes za kiolezo cha Excel na jina la faili.
  /// Hifadhi au shiriki faili hapa (mf. kwa share_plus au path_provider).
  final Future<void> Function(Uint8List bytes, String fileName)? onTemplateReady;

  /// Inaitwa ukibonyeza "Import": idara na safu zilizo sahihi tu.
  /// Kila safu ni Map: jina la safu -> thamani (mf. {'Jina kamili': 'Juma Ally', ...}).
  final Future<void> Function(String idara, List<Map<String, String>> rows)?
      onImport;

  const ImportUsersPage({super.key, this.onTemplateReady, this.onImport});

  @override
  State<ImportUsersPage> createState() => _ImportUsersPageState();
}

class _ImportUsersPageState extends State<ImportUsersPage> {
  String idara = 'elimu';
  bool ddOpen = false;
  bool templateDone = false;
  bool reading = false;
  bool importing = false;
  _ParsedFile? file;

  static const _maxBytes = 5 * 1024 * 1024; // MB 5

  _Idara get _cur => _idara.firstWhere((d) => d.key == idara);
  List<ImportColumn> get _cols => importColumnsFor(idara);

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ---------- Kiolezo ---------- */
  Future<void> _downloadTemplate() async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];
    sheet.appendRow(_cols.map((c) => TextCellValue(c.name)).toList());
    final bytes = excel.encode();
    if (bytes == null) return _toast('Imeshindikana kutengeneza kiolezo');

    final name = 'kiolezo_$idara.xlsx';
    try {
      if (widget.onTemplateReady != null) {
        await widget.onTemplateReady!(Uint8List.fromList(bytes), name);
      }
      if (!mounted) return;
      setState(() => templateDone = true);
    } catch (e) {
      if (mounted) _toast('Imeshindikana kupakua: $e');
    }
  }

  /* ---------- Kuchagua na kusoma faili ---------- */
  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    if (f.bytes == null) return _toast('Imeshindikana kusoma faili');
    if (f.size > _maxBytes) return _toast('Faili ni kubwa kuliko MB 5');

    setState(() => reading = true);
    try {
      final parsed = _parse(f.name, f.size, f.bytes!);
      if (!mounted) return;
      setState(() => file = parsed);
      if (parsed.total == 0) _toast('Faili halina safu za watumiaji');
    } catch (e) {
      if (mounted) _toast('Faili si sahihi. Tumia kiolezo cha Excel (.xlsx)');
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  // Inarudisha namba kwa mfumo 0XXXXXXXXX au null kama si sahihi
  static String? _normPhone(String raw) {
    var d = _digits(raw);
    if (d.startsWith('255')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d.length == 9 ? '0$d' : null;
  }

  _ParsedFile _parse(String name, int size, Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return _ParsedFile(name, size, const [], const []);
    final rows = excel.tables.values.first.rows;
    final cols = _cols;
    final valid = <Map<String, String>>[];
    final errors = <_RowError>[];

    // Safu ya kwanza ni vichwa — tunaanza safu ya pili
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      String cell(int j) {
        if (j >= r.length) return '';
        final v = r[j]?.value;
        return v == null ? '' : v.toString().trim();
      }

      // ruka safu tupu kabisa
      if (List.generate(cols.length, cell).every((v) => v.isEmpty)) continue;

      final map = <String, String>{};
      String? reason;
      for (var j = 0; j < cols.length; j++) {
        final col = cols[j];
        var v = cell(j);
        if (col.required && v.isEmpty) {
          reason ??= '${col.name} haijajazwa';
        }
        if (col.isPhone && v.isNotEmpty) {
          final p = _normPhone(v);
          if (p == null) {
            reason ??= '${col.name.toLowerCase()} haijakamilika';
          } else {
            v = p;
          }
        }
        map[col.name] = v;
      }

      final excelRow = i + 1;
      if (reason != null) {
        errors.add(_RowError(excelRow, reason));
      } else {
        valid.add(map);
      }
    }
    return _ParsedFile(name, size, valid, errors);
  }

  /* ---------- Import ---------- */
  Future<void> _import() async {
    final f = file;
    if (f == null || f.valid.isEmpty) return;
    setState(() => importing = true);
    try {
      await widget.onImport?.call(idara, f.valid);
      if (!mounted) return;
      _toast('Watumiaji ${f.valid.length} wameongezwa');
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) _toast('Imeshindikana ku-import: $e');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  static String _size(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = _IColors.of(context);
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
                    _Step(
                      c: c,
                      number: 1,
                      done: true,
                      title: 'Chagua idara',
                      child: _idaraDropdown(c),
                    ),
                    _Step(
                      c: c,
                      number: 2,
                      done: templateDone,
                      title: 'Andaa faili',
                      child: _prepare(c),
                    ),
                    _Step(
                      c: c,
                      number: 3,
                      done: file != null,
                      last: true,
                      title: 'Pakia faili',
                      child: _upload(c),
                    ),
                    _footer(c),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(_IColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
      decoration: BoxDecoration(
        color: c.page,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(TablerIcons.arrowLeft, size: 21, color: c.text),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import watumiaji',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                Text('Ongeza watumiaji wengi kwa faili la Excel',
                    style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ----- Hatua 1: dropdown ya idara ----- */
  Widget _idaraDropdown(_IColors c) {
    final cur = _cur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: c.page,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => setState(() => ddOpen = !ddOpen),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: ddOpen ? c.blue : c.borderStrong,
                    width: ddOpen ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  _IconTile(icon: cur.icon, tone: cur.tone, c: c, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(cur.title,
                        style: TextStyle(color: c.text, fontSize: 15)),
                  ),
                  Icon(
                      ddOpen ? TablerIcons.chevronUp : TablerIcons.chevronDown,
                      size: 18,
                      color: c.muted),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          child: !ddOpen
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: c.page,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderStrong),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < _idara.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: c.border),
                        _idaraOption(c, _idara[i]),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _idaraOption(_IColors c, _Idara d) {
    final sel = d.key == idara;
    return Material(
      color: sel ? c.blueBg : c.page,
      child: InkWell(
        onTap: () => setState(() {
          if (idara != d.key) {
            file = null; // safu zinabadilika — faili la zamani halifai
            templateDone = false;
          }
          idara = d.key;
          ddOpen = false;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _IconTile(icon: d.icon, tone: d.tone, c: c),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        style: TextStyle(
                            color: c.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(d.subtitle,
                        style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (sel) Icon(TablerIcons.check, size: 18, color: c.blue),
            ],
          ),
        ),
      ),
    );
  }

  /* ----- Hatua 2: safu + kiolezo ----- */
  Widget _prepare(_IColors c) {
    final cols = _cols;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(color: c.muted, fontSize: 12),
            children: [
              TextSpan(
                  text:
                      'Faili liwe na safu hizi ${cols.length}, kwa mpangilio huu. '),
              TextSpan(text: '*', style: TextStyle(color: c.red)),
              const TextSpan(text: ' ni lazima.'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < cols.length; i++)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.borderStrong),
                ),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: c.text, fontSize: 12),
                    children: [
                      TextSpan(
                          text: '${i + 1} ',
                          style: TextStyle(
                              color: c.blue, fontWeight: FontWeight.w600)),
                      TextSpan(text: cols[i].name),
                      if (cols[i].required)
                        TextSpan(text: '*', style: TextStyle(color: c.red)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _FileCard(
          c: c,
          title: 'Kiolezo cha ${_cur.title}',
          subtitle: 'Excel (.xlsx) · safu tayari',
          trailing: _TonalButton(
            c: c,
            icon: templateDone ? TablerIcons.check : TablerIcons.download,
            label: templateDone ? 'Imepakuliwa' : 'Pakua',
            onTap: _downloadTemplate,
          ),
        ),
      ],
    );
  }

  /* ----- Hatua 3: pakia faili ----- */
  Widget _upload(_IColors c) {
    final f = file;
    if (f == null) {
      return InkWell(
        onTap: reading ? null : _pickFile,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedRRectPainter(color: c.blue, radius: 14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            child: Column(
              children: [
                if (reading)
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: c.blue),
                  )
                else
                  Icon(TablerIcons.cloudUpload, size: 30, color: c.blue),
                const SizedBox(height: 6),
                Text(reading ? 'Inasoma faili…' : 'Gusa kuchagua faili',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('.xlsx · hadi MB 5',
                    style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    final errs = f.errors;
    final sample = errs.take(3).map((e) => 'safu ${e.row}: ${e.reason}').join('; ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FileCard(
          c: c,
          title: f.name,
          subtitle: '${_size(f.bytes)} · safu ${f.total}',
          trailing: IconButton(
            onPressed: () => setState(() => file = null),
            tooltip: 'Ondoa faili',
            icon: Icon(TablerIcons.x, size: 18, color: c.muted),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Stat(c: c, value: f.valid.length, label: 'Tayari', color: c.green),
            const SizedBox(width: 8),
            _Stat(c: c, value: errs.length, label: 'Zina makosa', color: c.red),
            const SizedBox(width: 8),
            _Stat(c: c, value: f.total, label: 'Jumla', color: c.text),
          ],
        ),
        if (errs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.redBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(TablerIcons.alertTriangle, size: 16, color: c.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Safu ${errs.length} zina makosa ($sample'
                    '${errs.length > 3 ? '…' : ''}). Zitarukwa.',
                    style: TextStyle(color: c.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer(_IColors c) {
    final f = file;
    final canImport = f != null && f.valid.isNotEmpty && !importing;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 30,
            child: TextButton(
              onPressed: importing ? null : () => Navigator.maybePop(context),
              style: TextButton.styleFrom(
                foregroundColor: c.muted,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
              child: const Text('Ghairi'),
            ),
          ),
          const SizedBox(width: 6),
          Opacity(
            opacity: canImport || importing ? 1 : .45,
            child: _TonalButton(
              c: c,
              icon: TablerIcons.databaseImport,
              label: f == null || f.valid.isEmpty
                  ? 'Import'
                  : 'Import watumiaji ${f.valid.length}',
              loading: importing,
              onTap: canImport ? _import : null,
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _Step extends StatelessWidget {
  final _IColors c;
  final int number;
  final bool done;
  final bool last;
  final String title;
  final Widget child;

  const _Step({
    required this.c,
    required this.number,
    required this.done,
    required this.title,
    required this.child,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? c.green : c.blue,
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(TablerIcons.check,
                          size: 15, color: Colors.white)
                      : Text('$number',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: c.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    child: Text(title,
                        style: TextStyle(
                            color: c.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final _Tone tone;
  final _IColors c;
  final double size;

  const _IconTile(
      {required this.icon, required this.tone, required this.c, this.size = 34});

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

class _FileCard extends StatelessWidget {
  final _IColors c;
  final String title, subtitle;
  final Widget trailing;

  const _FileCard({
    required this.c,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderStrong),
      ),
      child: Row(
        children: [
          _IconTile(
              icon: TablerIcons.fileSpreadsheet, tone: _Tone.green, c: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _TonalButton extends StatelessWidget {
  final _IColors c;
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _TonalButton({
    required this.c,
    required this.icon,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: c.blueBg,
          foregroundColor: c.blue,
          disabledBackgroundColor: c.blueBg,
          disabledForegroundColor: c.blue,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        child: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.blue),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14),
                  const SizedBox(width: 5),
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final _IColors c;
  final int value;
  final String label;
  final Color color;

  const _Stat({
    required this.c,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.borderStrong),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w600)),
            Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
          ],
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
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

/* ============================================================
   RANGI
   ============================================================ */
class _IColors {
  final Color page, border, borderStrong, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg, red, redBg;

  const _IColors({
    required this.page,
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

  static const light = _IColors(
    page: Color(0xFFFFFFFF),
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

  static const dark = _IColors(
    page: Color(0xFF12161D),
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

  static _IColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) => switch (t) {
        _Tone.blue => (blue, blueBg),
        _Tone.green => (green, greenBg),
        _Tone.amber => (amber, amberBg),
      };
}
