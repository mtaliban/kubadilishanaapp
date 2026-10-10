import 'package:flutter/material.dart';

// Rangi (badilisha hapa tu kama unataka bluu nyingine)
const Color _kBlue = Color(0xFF2563EB); // bluu kuu (nodes, Hifadhi, mistari ya focus)
const Color _kBlueSoft = Color(0xFFE8F0FE); // bluu hafifu (avatar, vitufe vya duara)
const Color _kBlueBorder = Color(0xFFBFD4F8); // mpaka wa bluu hafifu na mstari wa timeline
const Color _kText = Color(0xFF111827);
const Color _kTextMuted = Color(0xFF6B7280);
const Color _kFieldBorder = Color(0xFFD1D5DB);

class ProfilePage extends StatefulWidget {
  final String name;
  final String role;
  final String phone;
  final String whatsapp;
  final String email;

  /// Inaitwa mtu akibonyeza Hifadhi. Tuma data kwenye server hapa.
  final Future<void> Function(
    String name,
    String phone,
    String whatsapp,
    String email,
  )? onSave;

  const ProfilePage({
    super.key,
    required this.name,
    required this.role,
    required this.phone,
    required this.whatsapp,
    required this.email,
    this.onSave,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _name;
  late String _phone;
  late String _whatsapp;
  late String _email;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _emailCtrl;

  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _phone = widget.phone;
    _whatsapp = widget.whatsapp;
    _email = widget.email;
    _nameCtrl = TextEditingController(text: _name);
    _phoneCtrl = TextEditingController(text: _phone);
    _whatsappCtrl = TextEditingController(text: _whatsapp);
    _emailCtrl = TextEditingController(text: _email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final parts =
        _name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _startEdit() => setState(() => _editing = true);

  void _cancelEdit() {
    _nameCtrl.text = _name;
    _phoneCtrl.text = _phone;
    _whatsappCtrl.text = _whatsapp;
    _emailCtrl.text = _email;
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(
        _nameCtrl.text.trim(),
        _phoneCtrl.text.trim(),
        _whatsappCtrl.text.trim(),
        _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _name = _nameCtrl.text.trim();
        _phone = _phoneCtrl.text.trim();
        _whatsapp = _whatsappCtrl.text.trim();
        _email = _emailCtrl.text.trim();
        _editing = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imeshindikana kuhifadhi. Jaribu tena.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <_TimelineData>[
      _TimelineData(
        icon: Icons.person_outline,
        label: 'Jina kamili',
        value: _name,
        controller: _nameCtrl,
        keyboardType: TextInputType.name,
        autofocus: true,
      ),
      _TimelineData(
        icon: Icons.call_outlined,
        label: 'Namba ya simu',
        value: _phone,
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
      ),
      _TimelineData(
        icon: Icons.chat_outlined,
        label: 'WhatsApp',
        value: _whatsapp,
        controller: _whatsappCtrl,
        keyboardType: TextInputType.phone,
      ),
      _TimelineData(
        icon: Icons.mail_outline,
        label: 'Barua pepe',
        value: _email,
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        fieldFontSize: 14,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        SizedBox(height: _editing ? 22 : 26),
                        for (int i = 0; i < items.length; i++)
                          _TimelineItem(
                            data: items[i],
                            editing: _editing,
                            isLast: i == items.length - 1,
                          ),
                        if (_editing) ...[
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

  Widget _buildTopBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          InkResponse(
            onTap: () => Navigator.maybePop(context),
            radius: 24,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back, size: 22, color: _kText),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _editing ? 'Hariri wasifu' : 'Wasifu',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _kText,
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _kBlueSoft,
            shape: BoxShape.circle,
            border: Border.all(color: _kBlueBorder, width: 1.5),
          ),
          child: Text(
            _initials,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: _kBlue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: _kText,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.role,
          style: const TextStyle(fontSize: 13, color: _kBlue),
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
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _TimelineData {
  final IconData icon;
  final String label;
  final String value;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool autofocus;
  final double fieldFontSize;

  const _TimelineData({
    required this.icon,
    required this.label,
    required this.value,
    required this.controller,
    required this.keyboardType,
    this.autofocus = false,
    this.fieldFontSize = 15,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TimelineData data;
  final bool editing;
  final bool isLast;

  const _TimelineItem({
    required this.data,
    required this.editing,
    required this.isLast,
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
                  decoration: const BoxDecoration(
                    color: _kBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, size: 14, color: Colors.white),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: _kBlueBorder),
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
                    style: const TextStyle(fontSize: 12, color: _kTextMuted),
                  ),
                  SizedBox(height: editing ? 4 : 0),
                  editing
                      ? SizedBox(
                          height: 42,
                          child: TextField(
                            controller: data.controller,
                            keyboardType: data.keyboardType,
                            autofocus: data.autofocus,
                            style: TextStyle(
                              fontSize: data.fieldFontSize,
                              color: _kText,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _kFieldBorder,
                                  width: 0.8,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _kBlue,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          data.value,
                          style: const TextStyle(fontSize: 15, color: _kText),
                        ),
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
      color: _kBlueSoft,
      shape: const CircleBorder(
        side: BorderSide(color: _kBlueBorder, width: 0.8),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 17, color: _kBlue),
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
    final fg = filled ? Colors.white : _kText;

    return Material(
      color: filled ? _kBlue : Colors.transparent,
      shape: StadiumBorder(
        side: filled
            ? BorderSide.none
            : const BorderSide(color: Color(0xFF9CA3AF), width: 0.8),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Padding(
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
                      color: fg,
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
      ),
    );
  }
}
