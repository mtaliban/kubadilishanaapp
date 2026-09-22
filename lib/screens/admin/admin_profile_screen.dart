import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/theme.dart';

/// Wasifu wa Admin — screen moja yenye hali mbili: Angalia na Hariri.
/// Tumia: Navigator.push(MaterialPageRoute(builder: (_) => AdminProfileScreen(admin: currentAdmin)))
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

  @override
  void dispose() {
    _jinaCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Widget _oneLine(String text, TextStyle style) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: SingleChildScrollView(
                    child: _inaHariri ? _formHariri() : _viewAngalia(),
                  ),
                ),
                if (_inaHariri) _footerHariri(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(PhosphorIcons.arrowLeft(), size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(11)),
            child: Icon(PhosphorIcons.user(), size: 19, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wasifu wa Admin',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('Taarifa za akaunti yako',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textLight)),
              ],
            ),
          ),
          if (!_inaHariri)
            TextButton(
              onPressed: () => setState(() => _inaHariri = true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              ),
              child: const Text('Hariri',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ── ANGALIA ──
  Widget _viewAngalia() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.blue50,
                        blurRadius: 0,
                        spreadRadius: 6)
                  ],
                ),
                alignment: Alignment.center,
                child: Text(_initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: _oneLine(_data.jina,
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIcons.shieldCheck(),
                      size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  const Text('Administrator',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5)),
                ]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mawasiliano',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _contactRow(
                  icon: PhosphorIcons.envelope(),
                  label: 'Barua pepe',
                  value: _data.barua,
                  verified: _data.baruaImethibitishwa,
                  trailing: Icon(PhosphorIcons.copy(),
                      size: 17, color: AppColors.textLight),
                ),
                const Divider(height: 28, color: AppColors.border),
                _contactRow(
                  icon: PhosphorIcons.phone(),
                  label: 'Namba ya simu',
                  value: '+255 ${_data.simu}',
                  actionIcon: PhosphorIcons.phone(),
                  actionColor: AppColors.accent,
                  actionBg: AppColors.blue50,
                ),
                const Divider(height: 28, color: AppColors.border),
                _contactRow(
                  icon: PhosphorIcons.chatCircle(),
                  label: 'WhatsApp / Simu ya pili',
                  value: '+255 ${_data.whatsapp}',
                  iconBg: const Color(0xFFDCFCE7),
                  iconColor: AppColors.success,
                  actionIcon: PhosphorIcons.chatCircle(),
                  actionColor: Colors.white,
                  actionBg: AppColors.success,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(PhosphorIcons.info(), size: 15, color: AppColors.textLight),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Barua pepe haiwezi kubadilishwa hapa — wasiliana na admin mwenza.',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textLight, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    bool verified = false,
    Color? iconBg,
    Color? iconColor,
    Widget? trailing,
    IconData? actionIcon,
    Color? actionColor,
    Color? actionBg,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: iconBg ?? AppColors.blue50,
              borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 19, color: iconColor ?? AppColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textLight)),
                  if (verified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('● Imethibitishwa',
                          style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              _oneLine(value,
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        if (trailing != null) trailing,
        if (actionIcon != null)
          Container(
            width: 34,
            height: 34,
            decoration:
                BoxDecoration(color: actionBg, shape: BoxShape.circle),
            child: Icon(actionIcon, size: 16, color: actionColor),
          ),
      ],
    );
  }

  // ── HARIRI ──
  Widget _formHariri() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(_initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 22),
          const Text('Taarifa za msingi',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('Jina kamili',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent)),
          const SizedBox(height: 7),
          TextField(
            controller: _jinaCtrl,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon:
                  Icon(PhosphorIcons.user(), size: 18, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Namba ya simu (Pili / WhatsApp)',
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('+255',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _whatsappCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Barua pepe',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                  child: _oneLine(
                      _data.barua,
                      const TextStyle(
                          fontSize: 12.5, color: AppColors.textLight))),
              const SizedBox(width: 8),
              Icon(PhosphorIcons.lock(),
                  size: 15, color: AppColors.textLight),
            ]),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(PhosphorIcons.info(),
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Barua pepe haiwezi kubadilishwa hapa — wasiliana na admin mwenza.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textLight,
                      height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _footerHariri() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _ghairi,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
              textStyle: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            child: const Text('Ghairi'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _hifadhi,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
              textStyle: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            child: const Text('Hifadhi'),
          ),
        ],
      ),
    );
  }
}
