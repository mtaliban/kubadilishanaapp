// profile_screen.dart
// Skrini ya Wasifu (admin) — nakala kamili ya muundo uliokubaliwa:
// ring ya % umekamilika, kadi 4 (Administrator / Namba ya simu / WhatsApp /
// Barua pepe), Hariri (wote), Ongeza (mtaala mmoja), Ghairi/Hifadhi.
// Faili moja. Hakuna package ya ziada. Inahitaji Flutter 3.10+ (Dart 3).
//
// MATUMIZI:
//   ProfileScreen(name: ..., phone: ..., whatsapp: ..., email: ..., onSave: ...)
//
// KUUNGANISHA NA API: pisha [onSave] — inapokea values zote 4 baada ya
//   validation ya mockup (jina lazima, simu +255XXXXXXXXX, email si lazima).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart' show AppToast, friendlyError;

const _blue = Color(0xFF185FA5);
const _blueDark = Color(0xFF0C447C);
const _blueSoft = Color(0xFFE6F1FB);
const _blueLine = Color(0xFF85B7EB);
const _ring = Color(0xFF378ADD);
const _green = Color(0xFF3B6D11);
const _red = Color(0xFFA32D2D);
const _redSoft = Color(0xFFFCEBEB);
const _redLine = Color(0xFFF09595);

class ProfileScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String whatsapp;
  final String email;
  final void Function(Map<String, String> values)? onSave;

  const ProfileScreen({
    super.key,
    this.name = 'Hamisi Selemani Hamisi',
    this.phone = '+255763795801',
    this.whatsapp = '',
    this.email = '',
    this.onSave,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Map<String, String> _values;
  final Map<String, TextEditingController> _ctrl = {};
  final Set<String> _open = {};
  Map<String, String> _errors = {};
  bool _editAll = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _values = {
      'name': widget.name,
      'phone': widget.phone,
      'whatsapp': widget.whatsapp,
      'email': widget.email,
    };
    for (final k in _values.keys) {
      _ctrl[k] = TextEditingController(text: _values[k]);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isOpen(String k) => _editAll || _open.contains(k);
  bool get _anyOpen => _editAll || _open.isNotEmpty;

  int get _percent =>
      (_values.values.where((v) => v.isNotEmpty).length / 4 * 100).round();

  void _resetControllers() {
    for (final k in _values.keys) {
      _ctrl[k]!.text = _values[k]!;
    }
  }

  void _toggleEditAll() {
    setState(() {
      _saved = false;
      _errors = {};
      if (_editAll) {
        _cancel();
      } else {
        _resetControllers();
        _editAll = true;
      }
    });
  }

  void _openField(String k) {
    setState(() {
      _saved = false;
      _ctrl[k]!.text = _values[k]!;
      _open.add(k);
    });
  }

  void _cancel() {
    _editAll = false;
    _open.clear();
    _errors = {};
    _resetControllers();
  }

  String _normalizePhone(String v) {
    v = v.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^0\d{9}$').hasMatch(v)) return '+255${v.substring(1)}';
    if (RegExp(r'^255\d{9}$').hasMatch(v)) return '+$v';
    return v;
  }

  void _save() {
    final next = Map<String, String>.from(_values);
    final errors = <String, String>{};

    for (final k in _values.keys) {
      if (!_isOpen(k)) continue;
      var v = _ctrl[k]!.text.trim();

      if (k == 'name') {
        if (v.isEmpty) errors[k] = 'Andika jina kamili kwanza';
      } else if (k == 'email') {
        if (v.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
          errors[k] = 'Barua pepe si sahihi. Mfano: name@company.com';
        }
      } else {
        v = v.isEmpty ? '' : _normalizePhone(v);
        if (v.isNotEmpty && !RegExp(r'^\+255\d{9}$').hasMatch(v)) {
          errors[k] = 'Namba si sahihi. Mfano: 0712345678';
        }
        if (k == 'phone' && v.isEmpty) {
          errors[k] = 'Namba ya simu inahitajika';
        }
      }
      next[k] = v;
    }

    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    setState(() {
      _values
        ..clear()
        ..addAll(next);
      _editAll = false;
      _open.clear();
      _errors = {};
      _saved = true;
      _resetControllers();
    });
    widget.onSave?.call(Map<String, String>.from(_values));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _topBar(),
                const SizedBox(height: 8),
                Center(child: _ringView()),
                const SizedBox(height: 16),
                if (_saved && !_anyOpen)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Mabadiliko yamehifadhiwa',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _green),
                    ),
                  ),
                _InfoCard(
                  icon: Icons.account_circle_outlined,
                  tileBg: const Color(0xFFCECBF6),
                  tileFg: const Color(0xFF3C3489),
                  label: 'Administrator',
                  value: _values['name']!,
                  placeholder: '',
                  isOpen: _isOpen('name'),
                  controller: _ctrl['name']!,
                  error: _errors['name'],
                  valueIsPrimary: true,
                ),
                _field('phone', 'Namba ya simu', Icons.phone_outlined,
                    const Color(0xFFC0DD97), const Color(0xFF27500A),
                    '+255 7XX XXX XXX', TextInputType.phone),
                _field('whatsapp', 'WhatsApp', Icons.chat_outlined,
                    const Color(0xFFB5D4F4), _blueDark,
                    '+255 7XX XXX XXX', TextInputType.phone),
                _field('email', 'Barua pepe', Icons.mail_outline,
                    const Color(0xFFB5D4F4), _blueDark,
                    'name@company.com', TextInputType.emailAddress),
                if (_anyOpen) _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        InkWell(
          onTap: _toggleEditAll,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _blueLine, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _editAll ? Icons.close : Icons.manage_accounts_outlined,
                  size: 17,
                  color: _blueDark,
                ),
                const SizedBox(width: 6),
                Text(
                  _editAll ? 'Funga' : 'Hariri',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _blueDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ringView() {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(132, 132),
            painter: _RingPainter(_percent / 100),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_percent%',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w500, height: 1.1)),
              const Text('umekamilika',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String key, String label, IconData icon, Color bg, Color fg,
      String placeholder, TextInputType type) {
    final value = _values[key]!;
    return _InfoCard(
      icon: icon,
      tileBg: bg,
      tileFg: fg,
      label: label,
      value: value,
      placeholder: placeholder,
      isOpen: _isOpen(key),
      controller: _ctrl[key]!,
      error: _errors[key],
      keyboardType: type,
      onAdd: value.isEmpty ? () => _openField(key) : null,
      showCheck: value.isNotEmpty,
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(_cancel),
            icon: const Icon(Icons.highlight_off, size: 19),
            label: const Text('Ghairi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _red,
              backgroundColor: _redSoft,
              side: const BorderSide(color: _redLine, width: 0.5),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline, size: 19),
            label: const Text('Hifadhi'),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color tileBg;
  final Color tileFg;
  final String label;
  final String value;
  final String placeholder;
  final bool isOpen;
  final TextEditingController controller;
  final String? error;
  final TextInputType? keyboardType;
  final VoidCallback? onAdd;
  final bool showCheck;
  final bool valueIsPrimary;

  const _InfoCard({
    required this.icon,
    required this.tileBg,
    required this.tileFg,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.isOpen,
    required this.controller,
    this.error,
    this.keyboardType,
    this.onAdd,
    this.showCheck = false,
    this.valueIsPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty && !isOpen && !valueIsPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: empty ? _blueLine : Colors.black26,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: tileFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                if (isOpen)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: placeholder,
                        errorText: error,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    value.isEmpty ? 'Bado haijawekwa' : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: valueIsPrimary ? 14 : 13,
                      color: valueIsPrimary ? Colors.black : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          if (!isOpen && showCheck) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_outline, size: 22, color: _green),
          ],
          if (!isOpen && onAdd != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _blueLine, width: 0.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: _blueDark),
                    SizedBox(width: 4),
                    Text('Ongeza',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _blueDark)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE6E6E6);
    final bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = _ring;

    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, bar);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

// ============================================================================
// INTEGRATION LAYER — API halisi ya backend (Kubadilishana / EssTransfer)
//
//   DATA   → GET /users/me (getMyProfile) kwa majibu ya HARAKA, kisha
//            AuthProvider.user kama fallback (jina/simu zinajulikana login).
//   SAVE   → PATCH /users/me (updateProfile):
//              {full_name, phone_alt (WhatsApp), email}
//            Phone ya login HAIBADILISHWI kwenye backend (ni kitambulisho
//            cha akaunti) — kwenye backend ya sasa PATCH ya phone haiungi
//            mkono; kwa hiyo namba ya simu inaonyeshwa/kuhaririwa lakini
//            save inapuuza mabadiliko yake (kama ukurasa wa zamani).
//   RING   → % = fields 4 zilizojazwa / 4 (kama mockup).
// ============================================================================

/// Ukurasa wa "Wasifu wangu" kwenye AdminShell — data halisi + save ya API.
class AdminProfileScreenPage extends StatefulWidget {
  const AdminProfileScreenPage({super.key});

  @override
  State<AdminProfileScreenPage> createState() => _AdminProfileScreenPageState();
}

class _AdminProfileScreenPageState extends State<AdminProfileScreenPage> {
  String _name = '';
  String _phone = '';
  String _whatsapp = '';
  String _email = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _seedFromAuth();
    _load();
  }

  void _seedFromAuth() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    setState(() {
      _name = user?.fullName ?? '';
      _phone = user?.phone ?? '';
      _whatsapp = user?.phoneAlt ?? '';
      _email = user?.email ?? '';
      _loaded = true;
    });
  }

  /// GET /users/me — jibu la kwanza linashinda (thamani mpya zaidi kuliko auth).
  Future<void> _load() async {
    try {
      final res = await ApiService().getMyProfile();
      if (!mounted) return;
      final m = asMap(res.data);
      final user = asMap(m['user'] ?? m);
      final me = <String, String>{
        'name': (user['full_name'] ?? user['name'] ?? _name).toString(),
        'phone': (user['phone_primary'] ?? user['phone'] ?? _phone).toString(),
        'whatsapp': (user['phone_alt'] ?? _whatsapp).toString(),
        'email': (user['email'] ?? _email).toString(),
      };
      setState(() {
        _name = me['name']!;
        _phone = me['phone']!;
        _whatsapp = me['whatsapp']!;
        _email = me['email']!;
      });
    } catch (_) {
      // Data ya AuthProvider inatoshi — hakuna kosa la kuzuia skrini.
    }
  }

  Future<void> _save(Map<String, String> values) async {
    try {
      await ApiService().updateProfile({
        'full_name': values['name'] ?? '',
        'phone_alt': values['whatsapp'] ?? '',
        if ((values['email'] ?? '').isNotEmpty || _email.isNotEmpty)
          'email': values['email'] ?? '',
      });
      // Sasisha AuthProvider (jina la drawer linaonekana papo hapo).
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final u = auth.user;
      if (u != null) {
        auth.updateUser(AuthUser(
          userId: u.userId,
          fullName: values['name'] ?? u.fullName,
          phone: u.phone,
          phoneAlt: values['whatsapp'] ?? u.phoneAlt,
          email: (values['email'] ?? '').isNotEmpty ? values['email'] : u.email,
          category: u.category,
          cadreCode: u.cadreCode,
          cadreDisplay: u.cadreDisplay,
          employmentSector: u.employmentSector,
          isAdmin: u.isAdmin,
          isVerified: u.isVerified,
          contactEnabled: u.contactEnabled,
          currentStation: u.currentStation,
          subjects: u.subjects,
          wantedRegions: u.wantedRegions,
        ));
      }
    } catch (e) {
      AppToast.error(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ProfileScreen(
      name: _name,
      phone: _phone,
      whatsapp: _whatsapp,
      email: _email,
      onSave: _save,
    );
  }
}
