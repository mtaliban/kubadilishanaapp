import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════════════════════
class AdminProfileData {
  final String jina;
  final String jukumu;
  final String barua;
  final bool baruaImethibitishwa;
  final String simu;
  final String? whatsapp;

  const AdminProfileData({
    required this.jina,
    this.jukumu = 'Administrator',
    required this.barua,
    this.baruaImethibitishwa = true,
    required this.simu,
    this.whatsapp,
  });

  AdminProfileData copyWith({
    String? jina,
    String? whatsapp,
    bool clearWhatsapp = false,
  }) =>
      AdminProfileData(
        jina: jina ?? this.jina,
        jukumu: jukumu,
        barua: barua,
        baruaImethibitishwa: baruaImethibitishwa,
        simu: simu,
        whatsapp: clearWhatsapp ? null : (whatsapp ?? this.whatsapp),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// RANGI
// ═══════════════════════════════════════════════════════════════════════════════
const _kPage        = Color(0xFFF3F5F9);
const _kCard        = Color(0xFFFFFFFF);
const _kSoft        = Color(0xFFF1F3F7);
const _kBorder      = Color(0xFFE3E7EE);
const _kBorderStrong= Color(0xFFCFD5DF);
const _kText        = Color(0xFF141A24);
const _kMuted       = Color(0xFF667085);
const _kFaint       = Color(0xFF98A2B3);
const _kBlue        = Color(0xFF1E66E0);
const _kBlueBg      = Color(0xFFE8F0FD);
const _kGreen       = Color(0xFF0F7A52);

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class AdminProfileScreen extends StatefulWidget {
  final AdminProfileData admin;
  final Future<void> Function(AdminProfileData updated)? onSaved;

  const AdminProfileScreen({super.key, required this.admin, this.onSaved});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late AdminProfileData _data;
  bool _editing = false;
  bool _saving  = false;

  final _jinaCtrl = TextEditingController();
  final _waCtrl   = TextEditingController();
  bool _showWaField = false;

  @override
  void initState() {
    super.initState();
    _data = widget.admin;
    _jinaCtrl.addListener(() {
      if (_editing) setState(() {});
    });
  }

  @override
  void dispose() {
    _jinaCtrl.dispose();
    _waCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  // "0763795801" → "763 795 801"
  static String _local9(String phone) {
    var d = _digits(phone);
    if (d.startsWith('255')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 9) {
      return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
    }
    return d;
  }

  static String _pretty(String phone) => '+255 ${_local9(phone)}';
  static String _waIntl(String phone) => '255${_digits(_local9(phone))}';

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _startEdit() {
    _jinaCtrl.text = _data.jina;
    _waCtrl.text   = _data.whatsapp == null ? '' : _local9(_data.whatsapp!);
    _showWaField   = true;
    setState(() => _editing = true);
  }

  void _cancel() => setState(() => _editing = false);

  Future<void> _save() async {
    final name = _jinaCtrl.text.trim();
    final wa   = _digits(_waCtrl.text);
    if (name.isEmpty) return _toast('Andika jina kamili');
    if (wa.isNotEmpty && wa.length != 9) {
      return _toast('Namba ya WhatsApp iwe tarakimu 9 baada ya +255');
    }
    final updated = wa.isEmpty
        ? _data.copyWith(jina: name, clearWhatsapp: true)
        : _data.copyWith(jina: name, whatsapp: '0$wa');

    setState(() => _saving = true);
    try {
      await widget.onSaved?.call(updated);
      if (!mounted) return;
      setState(() {
        _data    = updated;
        _editing = false;
      });
      _toast('Mabadiliko yamehifadhiwa');
    } catch (e) {
      if (mounted) _toast('Imeshindikana kuhifadhi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(ClipboardData(text: _data.barua));
    _toast('Barua pepe imenakiliwa');
  }

  Future<void> _call() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: '+255${_local9(_data.simu).replaceAll(' ', '')}'));
    } catch (_) {}
  }

  Future<void> _openWa() async {
    if (_data.whatsapp == null) return;
    try {
      await launchUrl(
        Uri.parse('https://wa.me/${_waIntl(_data.whatsapp!)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final shownName = _editing
        ? (_jinaCtrl.text.trim().isEmpty ? '—' : _jinaCtrl.text.trim())
        : _data.jina;

    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) _cancel();
      },
      child: Scaffold(
        backgroundColor: _kPage,
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topBar(),
                    _headerSection(shownName),
                    _groupTitle('TAARIFA BINAFSI'),
                    _group([_nameRow()]),
                    _groupTitle('MAWASILIANO'),
                    _group([_emailRow(), _phoneRow(), _waRow()]),
                    if (_editing) _lockNote(),
                  ],
                ),
              ),
            ),
            if (_editing) _footer(),
          ]),
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────
  Widget _topBar() {
    return Row(children: [
      _squareBtn(
        icon: _editing ? PhosphorIcons.x() : PhosphorIcons.caretLeft(),
        onTap: _editing ? _cancel : () => Navigator.maybePop(context),
      ),
      const Spacer(),
      if (!_editing)
        SizedBox(
          height: 36,
          child: OutlinedButton.icon(
            onPressed: _startEdit,
            icon: Icon(PhosphorIcons.pencilSimple(), size: 15),
            label: const Text('Hariri'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kText,
              backgroundColor: _kCard,
              side: const BorderSide(color: _kBorderStrong),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kBlueBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIcons.pencilSimple(), size: 13, color: _kBlue),
            const SizedBox(width: 5),
            const Text('Unahariri',
                style: TextStyle(
                    color: _kBlue, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }

  // ── Header (jina kubwa + jukumu) ────────────────────────────────────────────
  Widget _headerSection(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: const TextStyle(
                color: _kText,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(PhosphorIcons.shieldCheck(), size: 14, color: _kMuted),
          const SizedBox(width: 5),
          Text(_data.jukumu,
              style: const TextStyle(color: _kMuted, fontSize: 12)),
        ]),
      ]),
    );
  }

  // ── Section title ────────────────────────────────────────────────────────────
  Widget _groupTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(text,
            style: const TextStyle(
                color: _kMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: .3)),
      );

  // ── Card group ───────────────────────────────────────────────────────────────
  Widget _group(List<Widget> rows) {
    final items = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      if (i > 0) {
        items.add(const Divider(height: 1, thickness: 1, color: _kBorder));
      }
      items.add(rows[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }

  // ── InfoRow universal ────────────────────────────────────────────────────────
  Widget _infoRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    Widget? labelExtra,
    required String value,
    Widget? editor,
    Widget? trailing,
    bool faded = false,
  }) {
    final hasEditor = editor != null;
    return Opacity(
      opacity: faded ? 0.55 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment:
              hasEditor ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: hasEditor ? 2 : 0),
              child: Icon(icon, size: 20, color: iconColor ?? _kMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _kMuted, fontSize: 12)),
                    ),
                    if (labelExtra != null) labelExtra!,
                  ]),
                  if (hasEditor)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: editor,
                    )
                  else
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _kText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  // ── Rows ─────────────────────────────────────────────────────────────────────

  Widget _nameRow() => _infoRow(
        icon: PhosphorIcons.user(),
        label: 'Jina kamili',
        value: _data.jina,
        editor: _editing ? _editField(controller: _jinaCtrl) : null,
      );

  Widget _emailRow() => _infoRow(
        icon: PhosphorIcons.envelope(),
        label: 'Barua pepe',
        labelExtra: _data.baruaImethibitishwa && !_editing
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 6),
                Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                    size: 13, color: _kGreen),
                const SizedBox(width: 3),
                const Text('Imethibitishwa',
                    style: TextStyle(
                        color: _kGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ])
            : null,
        value: _data.barua,
        faded: _editing,
        trailing: _editing
            ? Icon(PhosphorIcons.lockSimple(), size: 17, color: _kFaint)
            : _trailingBtn(
                icon: PhosphorIcons.copy(),
                color: _kFaint,
                onTap: _copyEmail,
              ),
      );

  Widget _phoneRow() => _infoRow(
        icon: PhosphorIcons.phone(),
        label: 'Namba ya simu',
        value: _pretty(_data.simu),
        faded: _editing,
        trailing: _editing
            ? Icon(PhosphorIcons.lockSimple(), size: 17, color: _kFaint)
            : _trailingBtn(
                icon: PhosphorIcons.phoneCall(),
                color: _kFaint,
                onTap: _call,
              ),
      );

  Widget _waRow() => _infoRow(
        icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
        iconColor: _kGreen,
        label: 'WhatsApp / simu ya pili',
        value: _data.whatsapp == null
            ? 'Haijawekwa'
            : _pretty(_data.whatsapp!),
        editor: _editing
            ? _editField(
                controller: _waCtrl,
                prefix255: true,
                keyboard: TextInputType.phone,
                hint: '712 345 678',
              )
            : null,
        trailing: !_editing && _data.whatsapp != null
            ? _trailingBtn(
                icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
                color: _kGreen,
                onTap: _openWa,
              )
            : null,
      );

  // ── Lock note (editing only) ──────────────────────────────────────────────
  Widget _lockNote() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(PhosphorIcons.lockSimple(), size: 15, color: _kMuted),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Barua pepe na namba ya simu kuu haziwezi kubadilishwa hapa. '
              'Wasiliana na admin mwenzako.',
              style: TextStyle(color: _kMuted, fontSize: 12, height: 1.5),
            ),
          ),
        ]),
      );

  // ── Footer (editing) ─────────────────────────────────────────────────────────
  Widget _footer() => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: _kCard,
          border: Border(top: BorderSide(color: _kBorder)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
            onPressed: _saving ? null : _cancel,
            child: const Text('Ghairi',
                style: TextStyle(
                    color: _kMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PhosphorIcons.floppyDisk(), size: 16),
                      const SizedBox(width: 6),
                      const Text('Hifadhi'),
                    ]),
            ),
          ),
        ]),
      );

  // ── Sub-widgets ──────────────────────────────────────────────────────────────

  Widget _squareBtn({required IconData icon, required VoidCallback onTap}) =>
      Material(
        color: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _kBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: _kText),
          ),
        ),
      );

  Widget _trailingBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20, color: color),
      );

  Widget _editField({
    required TextEditingController controller,
    bool prefix255 = false,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.words,
    String? hint,
  }) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: col, width: w),
        );
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        style: const TextStyle(color: _kText, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: _kFaint, fontSize: 14),
          isDense: true,
          filled: true,
          fillColor: _kSoft,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          prefixIcon: prefix255
              ? Padding(
                  padding: const EdgeInsets.only(left: 10, right: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('+255',
                        style:
                            TextStyle(color: _kMuted, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                        width: 1, height: 18, color: _kBorder),
                  ]),
                )
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: b(_kBorderStrong),
          enabledBorder: b(_kBorderStrong),
          focusedBorder: b(_kBlue, 1.5),
        ),
      ),
    );
  }
}
