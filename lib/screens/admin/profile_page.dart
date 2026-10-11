// =====================================================================
//  UKURASA WA "WASIFU WANGU" — DESIGN MPYA (mockup code/profile_page.dart)
//  Timeline: avatar duara 72 + jina + role; nodes bluu (Jina/simu/WhatsApp/
//  Barua) zenye mistari ya timeline; edit mode na TextFields + Ghairi/Hifadhi.
//
//  DATA  → onSave inaitwa na AdminProfileScreenPage (API PATCH halisi);
//          simu + email ni ZILIZOFUNGWA (kama mockup — hazibadiliki hapa).
//  Fonts → MediaQuery textScaler ≤ 1.0 kama drawer (simu fonti kubwa
//          hazivunji layout).
// =====================================================================

import 'package:flutter/material.dart';
import 'admin_theme.dart';

// Rangi za design mpya (kama mockup — badilisha hapa tu)
Color _kBlue = Color(0xFF2563EB); // bluu kuu (nodes, Hifadhi, mistari)
Color _kBlueSoft = Color(0xFFE8F0FE); // bluu hafifu (avatar, round btns)
Color _kBlueBorder = Color(0xFFBFD4F8); // mpaka wa bluu hafifu
Color _kText = Color(0xFF111827);
Color _kTextMuted = Color(0xFF6B7280);
Color _kFieldBorder = Color(0xFFD1D5DB);
const Color _kFieldBgDark = Color(0xFF1E293B);
const Color _kTextDark = Color(0xFFE7ECF8);
const Color _kTextMutedDark = Color(0xFF9AA8C7);

class AdminProfile {
  final String fullName; // "Hamisi Selemani Hamisi"
  final String role; // "Administrator"
  final String phone; // "+255 763 795 801" (haibadilishwi hapa)
  final String? email; // null = haijawekwa (haibadilishwi hapa)
  final String? whatsapp; // "+255 712 345 678" au null
  const AdminProfile({
    required this.fullName,
    required this.role,
    required this.phone,
    this.email,
    this.whatsapp,
  });

  AdminProfile copyWith({String? fullName, String? whatsapp, bool clearWhatsapp = false}) =>
      AdminProfile(
        fullName: fullName ?? this.fullName,
        role: role,
        phone: phone,
        email: email,
        whatsapp: clearWhatsapp ? null : (whatsapp ?? this.whatsapp),
      );

  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class ProfilePage extends StatefulWidget {
  final AdminProfile profile;

  /// Hifadhi mabadiliko. Rudisha null kama imefanikiwa, au ujumbe wa kosa.
  final Future<String?> Function(String fullName, String? whatsapp) onSave;

  const ProfilePage({super.key, required this.profile, required this.onSave});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late AdminProfile _p = widget.profile;
  bool _editing = false;
  bool _saving = false;
  String? _formErr;

  final _name = TextEditingController();
  final _wa = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _wa.dispose();
    super.dispose();
  }

  // "+255 712 345 678" -> "712345678"
  String _waDigits(String? v) =>
      (v ?? '').replaceAll('+255', '').replaceAll(RegExp(r'\D'), '');

  // "712345678" -> "+255 712 345 678"
  String _formatWa(String d) =>
      '+255 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';

  bool get _changed =>
      _name.text.trim() != _p.fullName || _wa.text.trim() != _waDigits(_p.whatsapp);

  void _startEdit() {
    _name.text = _p.fullName;
    _wa.text = _waDigits(_p.whatsapp);
    setState(() {
      _editing = true;
      _formErr = null;
    });
  }

  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    final wa = _wa.text.trim();
    String? nameErr;
    String? waErr;
    if (name.split(RegExp(r'\s+')).length < 2) {
      nameErr = 'Andika majina mawili au zaidi';
    }
    if (wa.isNotEmpty && !RegExp(r'^[67]\d{8}$').hasMatch(wa)) {
      waErr = 'Andika tarakimu 9, mfano 712 345 678';
    }
    setState(() => _formErr = nameErr ?? waErr);
    if (_formErr != null) return;

    setState(() => _saving = true);
    final waFull = wa.isEmpty ? null : _formatWa(wa);
    final err = await widget.onSave(name, waFull);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (err != null) {
        _formErr = err;
      } else {
        _p = waFull == null
            ? _p.copyWith(fullName: name, clearWhatsapp: true)
            : _p.copyWith(fullName: name, whatsapp: waFull);
        _editing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? _kTextDark : Ad.ink(context);
    final muted = dark ? _kTextMutedDark : Ad.muted(context);

    final items = <_TimelineData>[
      _TimelineData(
        icon: Icons.person_outline,
        label: 'Jina kamili',
        controller: _name,
        keyboardType: TextInputType.name,
        valueBuilder: () => Text(_p.fullName,
            style: TextStyle(fontSize: 15, color: text)),
        autofocus: true,
      ),
      _TimelineData(
        icon: Icons.call_outlined,
        label: 'Namba ya simu',
        controller: null,
        keyboardType: TextInputType.phone,
        valueBuilder: () => Text(_p.phone,
            style: TextStyle(fontSize: 15, color: text)),
      ),
      _TimelineData(
        icon: Icons.chat_outlined,
        label: 'WhatsApp',
        controller: _wa,
        keyboardType: TextInputType.phone,
        valueBuilder: () => Text(_p.whatsapp ?? 'Haijawekwa',
            style: TextStyle(
                fontSize: 15,
                color: _p.whatsapp == null ? muted : text)),
      ),
      _TimelineData(
        icon: Icons.mail_outline,
        label: 'Barua pepe',
        controller: null,
        keyboardType: TextInputType.emailAddress,
        fieldFontSize: 14,
        valueBuilder: () => Text(_p.email ?? 'Haijawekwa',
            style: TextStyle(
                fontSize: 15,
                color: _p.email == null ? muted : text)),
      ),
    ];

    return Scaffold(
      backgroundColor: dark ? Color(0xFF0F172A) : Ad.card(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            children: [
              _buildTopBar(dark, text),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(text),
                        SizedBox(height: _editing ? 22 : 26),
                        for (int i = 0; i < items.length; i++)
                          _TimelineItem(
                            data: items[i],
                            editing: _editing,
                            isLast: i == items.length - 1,
                            dark: dark,
                          ),
                        if (_editing) ...[
                          if (_formErr != null) ...[
                            const SizedBox(height: 10),
                            Text(_formErr!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: dark
                                        ? const Color(0xFFF87171)
                                        : const Color(0xFFB3261E))),
                          ],
                          const SizedBox(height: 14),
                          _buildEditButtons(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool dark, Color text) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          InkResponse(
            onTap: () =>
                _editing ? _cancelEdit() : Navigator.maybePop(context),
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(_editing ? Icons.close : Icons.arrow_back,
                  size: 22, color: text),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _editing ? 'Hariri wasifu' : 'Wasifu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: text,
                ),
              ),
            ),
          ),
          _RoundIconButton(
            icon: _editing ? Icons.close : Icons.edit_outlined,
            onTap: _editing ? _cancelEdit : _startEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color text) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Ad.blueSoft(context),
            shape: BoxShape.circle,
            border: Border.all(color: Ad.borderStrong(context), width: 1.5),
          ),
          child: Text(
            _p.initials,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Ad.blue(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _p.fullName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: text,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _p.role,
          style: TextStyle(fontSize: 13, color: Ad.blue(context)),
        ),
      ],
    );
  }

  Widget _buildEditButtons() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SmallPillButton(
            icon: Icons.close,
            label: 'Ghairi',
            filled: false,
            onTap: _saving ? null : _cancelEdit,
          ),
          const SizedBox(width: 8),
          _SmallPillButton(
            icon: Icons.check,
            label: 'Hifadhi',
            filled: true,
            loading: _saving,
            onTap: !_changed ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _TimelineData {
  final IconData icon;
  final String label;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool autofocus;
  final double fieldFontSize;
  final Widget Function() valueBuilder; // read-mode: value ya sasa

  const _TimelineData({
    required this.icon,
    required this.label,
    required this.controller,
    required this.keyboardType,
    required this.valueBuilder,
    this.autofocus = false,
    this.fieldFontSize = 15,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TimelineData data;
  final bool editing;
  final bool isLast;
  final bool dark;

  const _TimelineItem({
    required this.data,
    required this.editing,
    required this.isLast,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final bottomGap = isLast ? 0.0 : (editing ? 16.0 : 20.0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Ad.blue(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, size: 14, color: Ad.card(context)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: Ad.borderStrong(context)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: dark ? _kTextMutedDark : Ad.muted(context)),
                  ),
                  SizedBox(height: editing ? 4 : 0),
                  // Simu na email zinakataza edit hapa (locked fields).
                  // Jina + WhatsApp tu ndizo zinaharirika (kama design).
                  (editing && data.controller != null)
                      ? SizedBox(
                          height: 42,
                          child: TextField(
                            controller: data.controller,
                            keyboardType: data.keyboardType,
                            autofocus: data.autofocus,
                            style: TextStyle(
                              fontSize: data.fieldFontSize,
                              color: dark ? _kTextDark : Ad.ink(context),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: dark ? _kFieldBgDark : Ad.card(context),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Ad.borderStrong(context),
                                  width: 0.8,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Ad.blue(context),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        )
                      : data.valueBuilder(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ad.blueSoft(context),
      shape: CircleBorder(
        side: BorderSide(color: Ad.borderStrong(context), width: 0.8),
      ),
      child: InkWell(
        customBorder: CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 17, color: Ad.blue(context)),
        ),
      ),
    );
  }
}

class _SmallPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  const _SmallPillButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : Ad.ink(context);

    return Material(
      color: filled ? Ad.blue(context) : Colors.transparent,
      shape: StadiumBorder(
        side: filled
            ? BorderSide.none
            : BorderSide(color: Ad.muted2(context), width: 0.8),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Ad.card(context),
                  ),
                )
              else
                Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
