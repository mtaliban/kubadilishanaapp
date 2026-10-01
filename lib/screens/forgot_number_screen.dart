// =====================================================================
//  UKURASA WA "UMESAHAU NAMBA?" — Kubadilishana
//  Skrini MOJA yenye hali 2 (AnimatedSwitcher):
//    1. Fomu ya kutafuta kwa jina
//    2. Namba imepatikana
//  SahauNambaScreen — entry point inayotumika na routes.
//  Login screen inapata namba kwa Navigator.pop(context, phone).
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtPhone(String phone) {
  final d = phone.replaceAll(' ', '');
  if (d.startsWith('+255') && d.length == 13) {
    return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7, 10)} ${d.substring(10)}';
  }
  return phone;
}

String _cadreOf(Map<dynamic, dynamic> u) {
  final cadre = (u['cadre_display'] ?? '').toString().trim();
  if (cadre.isNotEmpty) return cadre;
  final cat = u['category']?.toString();
  if (cat == 'health') return 'Idara ya Afya';
  if (cat == 'education') return 'Idara ya Elimu';
  return cat ?? '';
}

class FoundUser {
  final String phone;
  final String fullName;
  final String cadre;
  const FoundUser({required this.phone, required this.fullName, required this.cadre});
}

Future<FoundUser?> _doSearch(String name) async {
  try {
    final res = await ApiService().lookupByName(name);
    final raw = res.data;
    final users = raw is List
        ? raw
        : (raw is Map
            ? ((raw as Map<dynamic, dynamic>)['users'] ?? raw['data'] ?? []) as List
            : <dynamic>[]);
    if (users.isEmpty) return null;
    final u = users.first as Map;
    final phone = (u['phone_primary'] ?? u['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return null;
    return FoundUser(
      phone: _fmtPhone(phone),
      fullName: (u['full_name'] ?? '').toString().trim().toUpperCase(),
      cadre: _cadreOf(u),
    );
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
}

// ── Entry point (inayotumika na routes) ──────────────────────────────────────

class SahauNambaScreen extends StatelessWidget {
  const SahauNambaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SahauNambaFlowScreen(
      onSearch: _doSearch,
      onBackToLogin: () => Navigator.of(context).maybePop(),
      onLogin: (phone) => Navigator.of(context).pop(phone),
    );
  }
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kAccent  = Color(0xFF2F6FED);
const _kBg      = Colors.white;
const _kDark    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF6B6A64);
const _kHint    = Color(0xFF8C8B85);
const _kLine    = Color(0xFFE4E3DE);
const _kError   = Color(0xFFB91C1C);
const _kErrorBg = Color(0xFFFCEBEB);

// ── Logo ─────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/images/logo.jpeg',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
}

// ── Flow screen ───────────────────────────────────────────────────────────────

class _SahauNambaFlowScreen extends StatefulWidget {
  final Future<FoundUser?> Function(String name) onSearch;
  final VoidCallback onBackToLogin;
  final void Function(String phone) onLogin;

  const _SahauNambaFlowScreen({
    required this.onSearch,
    required this.onBackToLogin,
    required this.onLogin,
  });

  @override
  State<_SahauNambaFlowScreen> createState() => _SahauNambaFlowScreenState();
}

class _SahauNambaFlowScreenState extends State<_SahauNambaFlowScreen> {
  final _ctrl = TextEditingController();

  bool        _found    = false;
  bool        _loading  = false;
  bool        _copied   = false;
  FoundUser?  _user;
  String?     _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _tafuta() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.onSearch(name);
      if (!mounted) return;
      if (result == null) {
        setState(() { _loading = false; _error = 'Hakuna mtumiaji aliyepatikana kwa jina hilo.'; });
      } else {
        setState(() { _loading = false; _user = result; _found = true; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Imeshindikana. Jaribu tena.'; });
    }
  }

  void _tafutaTena() {
    setState(() { _found = false; _user = null; _error = null; _ctrl.clear(); });
  }

  Future<void> _nakili() async {
    final phone = _user?.phone ?? '';
    await Clipboard.setData(ClipboardData(text: phone.replaceAll(' ', '')));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenH * 0.88),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Center(child: const _Logo(size: 100)),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
                    ),
                    child: _found
                        ? _ResultView(
                            key: const ValueKey('result'),
                            user: _user!,
                            copied: _copied,
                            onNakili: _nakili,
                            onTafutaTena: _tafutaTena,
                            onIngia: () => widget.onLogin(_user!.phone),
                          )
                        : _SearchForm(
                            key: const ValueKey('form'),
                            ctrl: _ctrl,
                            loading: _loading,
                            error: _error,
                            onTafuta: _tafuta,
                            onBack: widget.onBackToLogin,
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fomu ya kutafuta ──────────────────────────────────────────────────────────

class _SearchForm extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final VoidCallback onTafuta;
  final VoidCallback onBack;

  const _SearchForm({
    super.key,
    required this.ctrl,
    required this.loading,
    required this.error,
    required this.onTafuta,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Umesahau namba?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _kDark)),
        const SizedBox(height: 6),
        const Text(
          'Andika jina lako kamili tukutafutie namba uliyosajili nayo.',
          style: TextStyle(fontSize: 14, color: _kMuted, height: 1.5),
        ),
        const SizedBox(height: 20),
        const Row(children: [
          Icon(TablerIcons.user, size: 17, color: _kDark),
          SizedBox(width: 6),
          Text('Jina kamili',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kDark)),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Mfano: Hamisi Selemani',
            hintStyle: const TextStyle(color: _kHint, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD5D4CE))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD5D4CE))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kAccent, width: 1.5)),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _kErrorBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(TablerIcons.alert_circle, size: 15, color: _kError),
              const SizedBox(width: 6),
              Flexible(
                child: Text(error!,
                    style: const TextStyle(fontSize: 13, color: _kError)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        // Footer
        Row(children: [
          Flexible(
            child: TextButton(
              onPressed: loading ? null : onBack,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(TablerIcons.arrow_left, size: 15, color: _kAccent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('Rudi kuingia',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _kAccent)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: loading ? null : onTafuta,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              disabledBackgroundColor: _kAccent.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Tafuta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(width: 6),
                    Icon(TablerIcons.arrow_right, size: 15),
                  ]),
          ),
        ]),
      ],
    );
  }
}

// ── Matokeo ───────────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final FoundUser user;
  final bool copied;
  final VoidCallback onNakili;
  final VoidCallback onTafutaTena;
  final VoidCallback onIngia;

  const _ResultView({
    super.key,
    required this.user,
    required this.copied,
    required this.onNakili,
    required this.onTafutaTena,
    required this.onIngia,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Namba yako',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _kDark)),
        const SizedBox(height: 6),
        const Text('Hii ndiyo namba uliyojisajili nayo.',
            style: TextStyle(fontSize: 14, color: _kMuted)),
        const SizedBox(height: 18),

        // Namba + Nakili
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kLine, width: 1))),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(TablerIcons.phone, size: 14, color: _kHint),
                    SizedBox(width: 4),
                    Text('Namba ya simu',
                        style: TextStyle(fontSize: 12, color: _kHint)),
                  ]),
                  const SizedBox(height: 2),
                  Text(user.phone,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600, color: _kDark)),
                ]),
              ),
              OutlinedButton(
                onPressed: onNakili,
                style: OutlinedButton.styleFrom(
                  foregroundColor: copied ? const Color(0xFF1B6B1B) : _kDark,
                  side: BorderSide(
                      color: copied ? const Color(0xFF1B6B1B) : const Color(0xFFBBBBBB)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(copied ? TablerIcons.check : TablerIcons.copy, size: 14),
                  const SizedBox(width: 4),
                  Text(copied ? 'Imenakiliwa' : 'Nakili',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
        ),

        _infoRow(TablerIcons.user, 'Jina', user.fullName),
        _infoRow(TablerIcons.briefcase, 'Kada', user.cadre),

        const SizedBox(height: 22),

        // Footer
        Row(children: [
          Flexible(
            child: TextButton(
              onPressed: onTafutaTena,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(TablerIcons.refresh, size: 15, color: _kAccent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('Tafuta tena',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _kAccent)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onIngia,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Ingia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(width: 6),
              Icon(TablerIcons.arrow_right, size: 15),
            ]),
          ),
        ]),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.only(top: 14),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _kLine, width: 1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: _kHint),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: _kHint)),
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _kDark)),
        ]),
      );
}
