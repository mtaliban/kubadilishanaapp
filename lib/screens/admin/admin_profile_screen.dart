import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/* ============================================================
   MODEL
   ============================================================ */
class AdminProfile {
  final String name;
  final String role;
  final String email;
  final bool emailVerified;
  final String phone;
  final String? whatsapp;

  const AdminProfile({
    required this.name,
    this.role = 'Administrator',
    required this.email,
    this.emailVerified = true,
    required this.phone,
    this.whatsapp,
  });

  AdminProfile copyWith({String? name, String? whatsapp, bool clearWhatsapp = false}) {
    return AdminProfile(
      name: name ?? this.name,
      role: role,
      email: email,
      emailVerified: emailVerified,
      phone: phone,
      whatsapp: clearWhatsapp ? null : (whatsapp ?? this.whatsapp),
    );
  }
}

// Backward-compat alias used by admin_shell.dart
typedef AdminProfileData = AdminProfile;

/* ============================================================
   RANGI (light + dark)
   ============================================================ */
class ProfileColors {
  final Color page, card, soft, border, borderStrong, text, muted, faint;
  final Color blue, blueBg, blueRing, green, danger, dangerBg;

  const ProfileColors({
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
    required this.blueRing,
    required this.green,
    required this.danger,
    required this.dangerBg,
  });

  static const light = ProfileColors(
    page: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFCFD5DF),
    text: Color(0xFF141A24),
    muted: Color(0xFF667085),
    faint: Color(0xFF98A2B3),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    blueRing: Color(0xFFBBD2F8),
    green: Color(0xFF0F7A52),
    danger: Color(0xFFB3261E),
    dangerBg: Color(0xFFFCE9E8),
  );

  static const dark = ProfileColors(
    page: Color(0xFF0F1319),
    card: Color(0xFF181D26),
    soft: Color(0xFF212833),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF3A4454),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFF9AA4B5),
    faint: Color(0xFF6B7587),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    blueRing: Color(0xFF2B4270),
    green: Color(0xFF5FD49A),
    danger: Color(0xFFF2B8B5),
    dangerBg: Color(0xFF3A2224),
  );

  static ProfileColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/* ============================================================
   MSASAIDIZI
   ============================================================ */
String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Tarakimu za mitaa (bila 0 wala 255 mwanzoni).
String _local9(String phone) {
  var d = _digits(phone);
  if (d.startsWith('255')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  return d;
}

String _group9(String d) =>
    d.length == 9 ? '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}' : d;

String _pretty(String phone) => '+255 ${_group9(_local9(phone))}';
String _intl(String phone) => '+255${_local9(phone)}';

String _titleCase(String s) => s
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Herufi za mwanzo za jina (mf. "Amani Selemani" -> "AS").
String _herufi(String jina) {
  final p = jina.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
}

/// Tarakimu 9 (bila 0 wala 255 mwanzoni) au null kama si sahihi.
String? _tarakimuTisa(String ingizo) {
  var d = _digits(ingizo);
  if (d.startsWith('255')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  return RegExp(r'^[67]\d{8}$').hasMatch(d) ? d : null;
}

/* ============================================================
   SKRINI 1: MAELEZO YA WASIFU
   ============================================================ */
class AdminProfilePage extends StatefulWidget {
  final AdminProfile profile;

  /// Inaitwa ukibonyeza Hifadhi. Ikipokea profile mpya; irudishe true
  /// kama imehifadhiwa (exception au false = imeshindikana).
  final Future<bool> Function(AdminProfile updated) onSave;

  const AdminProfilePage({super.key, required this.profile, required this.onSave});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

// Backward-compat alias used by admin_shell.dart
typedef AdminProfileScreen = AdminProfilePage;

class _AdminProfilePageState extends State<AdminProfilePage> {
  late AdminProfile p;

  @override
  void initState() {
    super.initState();
    p = widget.profile;
  }

  /* ---------- Vitendo ---------- */
  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _hariri() async {
    final mpya = await Navigator.of(context).push<AdminProfile>(
      MaterialPageRoute(
        builder: (_) => _ProfileEditScreen(profile: p, onSave: widget.onSave),
      ),
    );
    if (mpya != null && mounted) {
      setState(() => p = mpya);
      _toast('Mabadiliko yamehifadhiwa');
    }
  }

  Future<void> _piga() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: _intl(p.phone)));
    } catch (_) {
      if (mounted) _toast('Imeshindwa kufungua simu');
    }
  }

  Future<void> _nakili(String namba) async {
    await Clipboard.setData(ClipboardData(text: namba));
    if (mounted) _toast('Namba imenakiliwa');
  }

  Future<void> _whatsapp() async {
    if (!_hasWa) return;
    try {
      await launchUrl(
        Uri.parse('https://wa.me/255${_local9(p.whatsapp!)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (mounted) _toast('Imeshindwa kufungua WhatsApp');
    }
  }

  bool get _hasWa => _digits(p.whatsapp ?? '').isNotEmpty;
  bool get _hasEmail => p.email.trim().isNotEmpty;

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = ProfileColors.of(context);
    final name = _titleCase(p.name);
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                _SquareButton(
                  icon: PhosphorIcons.arrowLeft(),
                  c: c,
                  tooltip: 'Rudi',
                  onTap: () => Navigator.maybePop(context),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _hariri,
                  icon: Icon(PhosphorIcons.pencilSimple(), size: 18),
                  label: const Text('Hariri'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: c.blueBg,
                child: Text(
                  _herufi(name),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: c.blue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.text, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Center(child: _RolePill(role: p.role, c: c)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: PhosphorIcons.phoneCall(),
                    label: 'Piga simu',
                    c: c,
                    onTap: _piga,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: PhosphorIcons.copy(),
                    label: 'Nakili namba',
                    c: c,
                    onTap: () => _nakili(_intl(p.phone)),
                  ),
                ),
              ],
            ),
            _SectionTitle('Taarifa binafsi', c: c),
            _Card(c: c, children: [
              _ViewRow(
                c: c,
                icon: PhosphorIcons.user(),
                label: 'Jina kamili',
                value: name,
              ),
            ]),
            _SectionTitle('Mawasiliano', c: c),
            _Card(c: c, children: [
              _ViewRow(
                c: c,
                icon: PhosphorIcons.envelopeSimple(),
                label: 'Barua pepe',
                value: _hasEmail ? p.email : 'Haijawekwa',
                empty: !_hasEmail,
                onOngeza: _hasEmail ? null : _hariri,
              ),
              _ViewRow(
                c: c,
                icon: PhosphorIcons.phone(),
                label: 'Namba ya simu',
                value: _pretty(p.phone),
                trailing: IconButton(
                  tooltip: 'Nakili',
                  icon: Icon(PhosphorIcons.copy(), size: 20, color: c.muted),
                  onPressed: () => _nakili(_intl(p.phone)),
                ),
              ),
              _ViewRow(
                c: c,
                icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                label: 'WhatsApp / simu ya pili',
                value: _hasWa ? _pretty(p.whatsapp!) : 'Haijawekwa',
                empty: !_hasWa,
                onOngeza: _hasWa ? null : _hariri,
                trailing: _hasWa
                    ? IconButton(
                        tooltip: 'Fungua WhatsApp',
                        icon: Icon(PhosphorIcons.whatsappLogo(
                            PhosphorIconsStyle.fill),
                            size: 20,
                            color: c.green),
                        onPressed: _whatsapp,
                      )
                    : null,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   SKRINI 2: HARIRI WASIFU
   ============================================================ */
class _ProfileEditScreen extends StatefulWidget {
  final AdminProfile profile;
  final Future<bool> Function(AdminProfile updated) onSave;

  const _ProfileEditScreen({required this.profile, required this.onSave});

  @override
  State<_ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<_ProfileEditScreen> {
  late final nameCtrl =
      TextEditingController(text: _titleCase(widget.profile.name));
  late final waCtrl = TextEditingController(
      text: widget.profile.whatsapp == null
          ? ''
          : _local9(widget.profile.whatsapp!));
  bool saving = false;
  String? kosa;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(_onChange);
    waCtrl.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    waCtrl.dispose();
    super.dispose();
  }

  /* ---------- Hali ---------- */
  String get _jinaSafi => nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  bool get _waTupu => waCtrl.text.trim().isEmpty;
  String? get _waTisa => _waTupu ? null : _tarakimuTisa(waCtrl.text);

  String? get _kosaJina => _jinaSafi.isEmpty ? 'Weka jina kamili' : null;
  String? get _kosaWa =>
      (!_waTupu && _waTisa == null) ? 'Weka namba sahihi, mfano 712 345 678' : null;

  bool get _imebadilika {
    final waAsili =
        widget.profile.whatsapp == null ? null : _local9(widget.profile.whatsapp!);
    final waMpya = _waTupu ? null : (_waTisa ?? _digits(waCtrl.text));
    return _jinaSafi != _titleCase(widget.profile.name) || waMpya != waAsili;
  }

  bool get _inaweza =>
      _imebadilika && _kosaJina == null && _kosaWa == null && !saving;

  /* ---------- Vitendo ---------- */
  Future<bool> _thibitishaKutoka() async {
    if (!_imebadilika || saving) return true;
    final toka = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toka bila kuhifadhi?'),
        content: const Text('Mabadiliko uliyofanya yatapotea.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Endelea kuhariri')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Toka')),
        ],
      ),
    );
    return toka == true;
  }

  Future<void> _hifadhi() async {
    if (!_inaweza) return;
    final tisa = _waTisa;
    final mpya = tisa == null
        ? widget.profile.copyWith(name: _jinaSafi, clearWhatsapp: true)
        : widget.profile.copyWith(name: _jinaSafi, whatsapp: '0$tisa');

    setState(() {
      saving = true;
      kosa = null;
    });
    try {
      final ok = await widget.onSave(mpya);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, mpya);
      } else {
        setState(() {
          saving = false;
          kosa = 'Imeshindwa kuhifadhi. Jaribu tena.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          kosa = 'Imeshindwa kuhifadhi. Angalia mtandao kisha ujaribu tena.';
        });
      }
    }
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = ProfileColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _thibitishaKutoka()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _SquareButton(
                      icon: PhosphorIcons.x(),
                      c: c,
                      tooltip: 'Funga',
                      onTap: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Text('Hariri wasifu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: c.blueBg,
                          child: Text(
                            _herufi(_jinaSafi.isEmpty
                                ? _titleCase(widget.profile.name)
                                : _jinaSafi),
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                color: c.blue),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _jinaSafi.isEmpty
                                    ? _titleCase(widget.profile.name)
                                    : _jinaSafi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: c.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(widget.profile.role,
                                  style:
                                      TextStyle(color: c.blue, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _SectionTitle('Unaweza kubadilisha',
                        c: c, icon: PhosphorIcons.pencilSimple()),
                    _Card(
                      c: c,
                      padding: const EdgeInsets.all(14),
                      children: [
                        _FieldLabel('Jina kamili', c: c),
                        TextField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: c.text, fontSize: 16),
                          cursorColor: c.blue,
                          decoration: _mapambo(
                            c,
                            ikoni: PhosphorIcons.user(),
                            kosa: _imebadilika ? _kosaJina : null,
                            futa: nameCtrl.text.isEmpty
                                ? null
                                : () => nameCtrl.clear(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel('WhatsApp / simu ya pili',
                            c: c, trailing: 'hiari'),
                        TextField(
                          controller: waCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
                          ],
                          style: TextStyle(color: c.text, fontSize: 16),
                          cursorColor: c.blue,
                          decoration: _mapambo(
                            c,
                            ikoni: PhosphorIcons.whatsappLogo(
                                PhosphorIconsStyle.fill),
                            kiambishi: '+255',
                            hint: '712 345 678',
                            kosa: _kosaWa,
                          ),
                        ),
                        if (_kosaWa == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 2),
                            child: Text('Acha wazi kama huna namba ya pili.',
                                style: TextStyle(color: c.muted, fontSize: 12)),
                          ),
                      ],
                    ),
                    _SectionTitle('Haziwezi kubadilishwa',
                        c: c, icon: PhosphorIcons.lockSimple()),
                    Container(
                      decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _LockedRow(
                              c: c,
                              icon: PhosphorIcons.envelopeSimple(),
                              text: _hasEmail
                                  ? widget.profile.email
                                  : 'Haijawekwa'),
                          Divider(height: 1, thickness: 1, color: c.border),
                          _LockedRow(
                              c: c,
                              icon: PhosphorIcons.phone(),
                              text: _pretty(widget.profile.phone)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                          'Kubadilisha hizi, wasiliana na admin mwenzako.',
                          style: TextStyle(color: c.muted, fontSize: 12)),
                    ),
                    if (kosa != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.dangerBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.warning(PhosphorIconsStyle.fill),
                                size: 18, color: c.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(kosa!,
                                  style: TextStyle(
                                      color: c.danger, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              _editFooter(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editFooter(ProfileColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _imebadilika ? 'Una mabadiliko' : 'Hakuna mabadiliko',
              style: TextStyle(
                  color: _imebadilika ? c.blue : c.muted,
                  fontSize: 13,
                  fontWeight:
                      _imebadilika ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
          OutlinedButton(
            onPressed: saving ? null : () => Navigator.maybePop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.text,
              side: BorderSide(color: c.borderStrong),
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text('Ghairi'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _inaweza ? _hifadhi : null,
            icon: saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Icon(PhosphorIcons.floppyDisk(), size: 18),
            label: const Text('Hifadhi'),
            style: FilledButton.styleFrom(
              backgroundColor: c.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _mapambo(
    ProfileColors c, {
    required IconData ikoni,
    String? kiambishi,
    String? hint,
    String? kosa,
    VoidCallback? futa,
  }) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: col, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.faint, fontSize: 16),
      errorText: kosa,
      errorStyle: TextStyle(color: c.blue, fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      prefixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 12),
          Icon(ikoni, size: 20, color: c.muted),
          if (kiambishi != null) ...[
            const SizedBox(width: 8),
            Text(kiambishi, style: TextStyle(color: c.text, fontSize: 16)),
            const SizedBox(width: 8),
            Container(width: 1, height: 22, color: c.border),
          ],
          const SizedBox(width: 10),
        ],
      ),
      prefixIconConstraints: const BoxConstraints(minHeight: 48),
      suffixIcon: futa == null
          ? null
          : IconButton(
              tooltip: 'Futa',
              icon: Icon(PhosphorIcons.x(), size: 18, color: c.muted),
              onPressed: futa,
            ),
      border: b(c.borderStrong),
      enabledBorder: b(c.borderStrong),
      focusedBorder: b(c.blue, 1.5),
      errorBorder: b(c.blue),
      focusedErrorBorder: b(c.blue, 1.5),
    );
  }

  bool get _hasEmail => widget.profile.email.trim().isNotEmpty;
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _SquareButton extends StatelessWidget {
  final IconData icon;
  final ProfileColors c;
  final String tooltip;
  final VoidCallback onTap;

  const _SquareButton({
    required this.icon,
    required this.c,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: c.text),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ProfileColors c;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: c.text),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.borderStrong),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  final ProfileColors c;
  const _RolePill({required this.role, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: c.blueBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.shieldCheck(), size: 16, color: c.blue),
          const SizedBox(width: 6),
          Text(role,
              style: TextStyle(
                  color: c.blue, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final ProfileColors c;
  final IconData? icon;
  const _SectionTitle(this.text, {required this.c, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 0, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: c.muted),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final ProfileColors c;
  final List<Widget> children;
  final EdgeInsets padding;

  const _Card({
    required this.c,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && padding == EdgeInsets.zero) {
        items.add(Divider(height: 1, thickness: 1, color: c.border));
      }
      items.add(children[i]);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

class _ViewRow extends StatelessWidget {
  final ProfileColors c;
  final IconData icon;
  final String label;
  final String value;
  final bool empty;
  final Widget? trailing;
  final VoidCallback? onOngeza;

  const _ViewRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    this.empty = false,
    this.trailing,
    this.onOngeza,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: empty ? c.soft : c.blueBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 19, color: empty ? c.muted : c.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.muted, fontSize: 12)),
                const SizedBox(height: 1),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: empty ? c.muted : c.text,
                        fontSize: 15,
                        fontWeight:
                            empty ? FontWeight.w400 : FontWeight.w600)),
              ],
            ),
          ),
          if (empty && onOngeza != null)
            TextButton(
              onPressed: onOngeza,
              style: TextButton.styleFrom(
                foregroundColor: c.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: const Text('Ongeza'),
            )
          else if (!empty && trailing != null)
            trailing!,
        ],
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  final ProfileColors c;
  final IconData icon;
  final String text;

  const _LockedRow({required this.c, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: c.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 14)),
          ),
          Icon(PhosphorIcons.lockSimple(), size: 17, color: c.muted),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final ProfileColors c;
  final String? trailing;
  const _FieldLabel(this.text, {required this.c, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (trailing != null)
            Text(trailing!, style: TextStyle(color: c.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
