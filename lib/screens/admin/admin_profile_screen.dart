import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';

class AdminProfileData {
  final String jina;
  final String barua;
  final bool baruaImethibitishwa;
  final String simu;
  final String whatsapp;

  const AdminProfileData({
    required this.jina,
    required this.barua,
    required this.simu,
    required this.whatsapp,
    this.baruaImethibitishwa = true,
  });

  AdminProfileData copyWith({String? jina, String? simu, String? whatsapp}) =>
      AdminProfileData(
        jina: jina ?? this.jina,
        barua: barua,
        baruaImethibitishwa: baruaImethibitishwa,
        simu: simu ?? this.simu,
        whatsapp: whatsapp ?? this.whatsapp,
      );
}

class AdminProfileScreen extends StatefulWidget {
  final AdminProfileData admin;
  final ValueChanged<AdminProfileData>? onSaved;

  const AdminProfileScreen({super.key, required this.admin, this.onSaved});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late AdminProfileData _data = widget.admin;
  bool _inaHariri = false;

  late final _jinaCtrl = TextEditingController(text: _data.jina);
  late final _whatsappCtrl = TextEditingController(text: _data.whatsapp);

  String get _initials {
    final parts = _data.jina.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  void _hifadhi() {
    final mpya = _data.copyWith(
        jina: _jinaCtrl.text.trim(), whatsapp: _whatsappCtrl.text.trim());
    setState(() {
      _data = mpya;
      _inaHariri = false;
    });
    widget.onSaved?.call(mpya);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wasifu umehifadhiwa')),
    );
  }

  void _ghairi() {
    setState(() {
      _jinaCtrl.text = _data.jina;
      _whatsappCtrl.text = _data.whatsapp;
      _inaHariri = false;
    });
  }

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imenakiliwa'), duration: Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _jinaCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _inaHariri ? _formHariri() : _viewAngalia(),
            ),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────
  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        InkWell(
          onTap: () {
            if (_inaHariri) {
              _ghairi();
            } else {
              Navigator.of(context).maybePop();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(PhosphorIcons.arrowLeft(),
                size: 20, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _inaHariri ? 'Hariri Wasifu' : 'Wasifu wa Admin',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
        ),
        if (!_inaHariri)
          InkWell(
            onTap: () => setState(() => _inaHariri = true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(PhosphorIcons.pencilSimple(),
                    size: 13, color: AppColors.accent),
                const SizedBox(width: 5),
                Text('Hariri',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent)),
              ]),
            ),
          ),
      ]),
    );
  }

  // ── VIEW MODE ────────────────────────────────────────────────────────────
  Widget _viewAngalia() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Identity card ──
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(_initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(_data.jina,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIcons.shieldCheck(),
                      size: 12, color: AppColors.accent),
                  const SizedBox(width: 5),
                  const Text('Administrator',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ]),
      ),

      const SizedBox(height: 14),

      // ── Contact card ──
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          _contactTile(
            icon: PhosphorIcons.envelope(),
            label: 'Barua pepe',
            value: _data.barua,
            chip: _data.baruaImethibitishwa
                ? 'Imethibitishwa'
                : null,
            onTap: () => _launch('mailto:${_data.barua}'),
            trailing: InkWell(
              onTap: () => _copyToClipboard(_data.barua),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(PhosphorIcons.copy(),
                    size: 16, color: AppColors.textLight),
              ),
            ),
          ),
          _divider(),
          _contactTile(
            icon: PhosphorIcons.phone(),
            label: 'Namba ya simu',
            value: '+255 ${_data.simu}',
            onTap: () => _launch('tel:${_data.simu}'),
            actionIcon: PhosphorIcons.phone(),
            actionColor: AppColors.accent,
            actionBg: AppColors.blue50,
          ),
          _divider(),
          _contactTile(
            icon: PhosphorIcons.chatCircle(),
            iconBg: const Color(0xFFDCFCE7),
            iconColor: AppColors.success,
            label: 'WhatsApp / Simu ya pili',
            value: '+255 ${_data.whatsapp}',
            onTap: () => _launch(
                'https://wa.me/255${_data.whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}'),
            actionIcon: PhosphorIcons.chatCircle(),
            actionColor: Colors.white,
            actionBg: AppColors.success,
          ),
        ]),
      ),

      const SizedBox(height: 12),

      // ── Note ──
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(PhosphorIcons.info(),
              size: 13, color: AppColors.textLight),
          const SizedBox(width: 7),
          const Expanded(
            child: Text(
              'Barua pepe haiwezi kubadilishwa hapa — wasiliana na admin mwenza.',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.textLight, height: 1.4),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border);

  Widget _contactTile({
    required IconData icon,
    required String label,
    required String value,
    Color? iconBg,
    Color? iconColor,
    String? chip,
    Widget? trailing,
    VoidCallback? onTap,
    IconData? actionIcon,
    Color? actionColor,
    Color? actionBg,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: iconBg ?? AppColors.blue50,
                borderRadius: BorderRadius.circular(11)),
            child:
                Icon(icon, size: 18, color: iconColor ?? AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
                if (chip != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(chip,
                        style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
          ),
          if (trailing != null) trailing,
          if (actionIcon != null)
            Container(
              width: 32,
              height: 32,
              decoration:
                  BoxDecoration(color: actionBg, shape: BoxShape.circle),
              child: Icon(actionIcon, size: 15, color: actionColor),
            ),
        ]),
      ),
    );
  }

  // ── EDIT FORM ────────────────────────────────────────────────────────────
  Widget _formHariri() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Form card ──
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Taarifa za msingi',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 18),

          // Jina
          _fieldLabel('Jina kamili'),
          const SizedBox(height: 7),
          _inputField(
            controller: _jinaCtrl,
            hint: 'Andika jina kamili',
            icon: PhosphorIcons.user(),
          ),
          const SizedBox(height: 16),

          // WhatsApp
          _fieldLabel('WhatsApp / Simu ya pili'),
          const SizedBox(height: 7),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                border: Border.all(color: const Color(0xFFD0D7E2)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('+255',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _inputField(
                controller: _whatsappCtrl,
                hint: '7xxxxxxxx',
                keyboardType: TextInputType.phone,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Email (read-only)
          _fieldLabel('Barua pepe'),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(PhosphorIcons.lock(),
                  size: 15, color: AppColors.textLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_data.barua,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textLight)),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(PhosphorIcons.info(),
                size: 13, color: AppColors.textLight),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Barua pepe haiwezi kubadilishwa — wasiliana na admin mwenza.',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textLight, height: 1.4),
              ),
            ),
          ]),
        ]),
      ),

      const SizedBox(height: 16),

      // ── Action buttons ──
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        OutlinedButton(
          onPressed: _ghairi,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9)),
            textStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          child: const Text('Ghairi'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _hifadhi,
          icon: Icon(PhosphorIcons.floppyDisk(), size: 14),
          label: const Text('Hifadhi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9)),
            textStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    ]);
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary));

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w400),
        prefixIcon: icon != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(icon, size: 16, color: AppColors.textLight),
              )
            : null,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFFD0D7E2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFFD0D7E2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: AppColors.accent, width: 1.6)),
      ),
    );
  }
}
