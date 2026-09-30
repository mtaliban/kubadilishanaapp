// =====================================================================
//  UKURASA WA "UMESAHAU NAMBA?"  —  ESSTRANSFER
//  Kadi MOJA yenye hatua 2 (AnimatedSwitcher ndani ya kadi ile ile):
//    Hatua 1: fomu ya jina
//    Hatua 2: namba imepatikana
//
//  SahauNambaScreen — inaunganisha ForgotNumberPage na API + Navigator.
//  Login screen inapata namba kwa Navigator.pop(context, phone).
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

// ---- helpers -------------------------------------------------------

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

Future<FoundUser?> _doSearch(String name) async {
  try {
    final res = await ApiService().lookupByName(name);
    final raw = res.data;
    final users = raw is List
        ? raw
        : (raw is Map
            ? ((raw as Map<dynamic, dynamic>)['users'] ??
                    raw['data'] ??
                    []) as List
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

// ---- SahauNambaScreen (public API inayotumika na routes + tests) ---

class SahauNambaScreen extends StatelessWidget {
  const SahauNambaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ForgotNumberPage(
      onSearch: _doSearch,
      onBackToLogin: () => Navigator.of(context).maybePop(),
      onLogin: (phone) => Navigator.of(context).pop(phone),
    );
  }
}

// =====================================================================

// ------------------------- RANGI -------------------------
class _C {
  static const pageBg      = Color(0xFFF7F7F5);
  static const cardBorder  = Color(0xFFEDEDED);
  static const primary     = Color(0xFF2878D6);
  static const primaryDark = Color(0xFF1B4F9C);
  static const text        = Color(0xFF111111);
  static const body        = Color(0xFF555555);
  static const hint        = Color(0xFF8A8A8A);
  static const line        = Color(0xFFE6E6E6);
  static const inputBorder = Color(0xFF8AB6EC);
  static const copyBorder  = Color(0xFFDADADA);
  static const okBg        = Color(0xFFE3F4E1);
  static const ok          = Color(0xFF1B6B1B);
  static const error       = Color(0xFFB91C1C);
  static const logoDash    = Color(0xFFB5C9E6);
  static const logoText    = Color(0xFF6B8AB8);
}

// ------------------------- LOGO -------------------------
const String kLogoAsset  = 'assets/images/app_icon.png';
const double kLogoHeight = 120;

class FoundUser {
  final String phone;
  final String fullName;
  final String cadre;
  const FoundUser({required this.phone, required this.fullName, required this.cadre});
}

// ================= UKURASA MZIMA =================
class ForgotNumberPage extends StatelessWidget {
  final Future<FoundUser?> Function(String name) onSearch;
  final VoidCallback onBackToLogin;
  final void Function(String phone) onLogin;

  const ForgotNumberPage({
    super.key,
    required this.onSearch,
    required this.onBackToLogin,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ForgotNumberCard(
                onSearch: onSearch,
                onBackToLogin: onBackToLogin,
                onLogin: onLogin,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= KADI =================
class ForgotNumberCard extends StatefulWidget {
  final Future<FoundUser?> Function(String name) onSearch;
  final VoidCallback onBackToLogin;
  final void Function(String phone) onLogin;

  const ForgotNumberCard({
    super.key,
    required this.onSearch,
    required this.onBackToLogin,
    required this.onLogin,
  });

  @override
  State<ForgotNumberCard> createState() => _ForgotNumberCardState();
}

class _ForgotNumberCardState extends State<ForgotNumberCard> {
  final _name = TextEditingController();
  bool _loading = false;
  String? _error;
  FoundUser? _found;
  bool _copied = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Weka jina lako kamili kwanza');
      return;
    }
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length < 2) {
      setState(() => _error = 'Weka jina la kwanza na la mwisho.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final user = await widget.onSearch(name);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (user == null) {
          _error = 'Jina halijapatikana. Liandike kama lilivyosajiliwa';
        } else {
          _found = user;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Imeshindikana kutafuta. Angalia mtandao ujaribu tena';
      });
    }
  }

  void _searchAgain() => setState(() {
        _found = null;
        _copied = false;
        _error = null;
        _name.clear();
      });

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _found!.phone.replaceAll(' ', '')));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final step2 = _found != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: _AppLogo()),
          const SizedBox(height: 20),
          _StepBar(step2: step2),
          const SizedBox(height: 22),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: step2 ? _resultView(_found!) : _formView(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- HATUA 1: FOMU ----------------
  Widget _formView() {
    final hasError = _error != null;
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Umesahau namba?'),
        const SizedBox(height: 6),
        _subtitle('Andika jina lako kamili tukutafutie namba uliyosajili nayo.'),
        const SizedBox(height: 20),
        _fieldLabel(TablerIcons.userSquareRounded, 'Jina kamili'),
        const SizedBox(height: 7),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: const TextStyle(fontSize: 15, color: _C.text, height: 1.2),
          decoration: InputDecoration(
            hintText: 'Mfano: Amani Selemani',
            hintStyle: const TextStyle(fontSize: 15, color: _C.hint, height: 1.2),
            prefixIcon: const Icon(TablerIcons.userCircle, size: 20, color: _C.primaryDark),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            contentPadding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
            enabledBorder: _border(hasError ? _C.error : _C.inputBorder),
            focusedBorder: _border(hasError ? _C.error : _C.primary),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(TablerIcons.alertCircle, size: 15, color: _C.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(fontSize: 12.5, color: _C.error, height: 1.3)),
              ),
            ],
          ),
        ],
        _footer(
          left: _textLink(TablerIcons.arrowLeft, 'Rudi kuingia', widget.onBackToLogin),
          right: _primaryButton('Tafuta', _loading ? null : _search, loading: _loading),
        ),
      ],
    );
  }

  // ---------------- HATUA 2: MATOKEO ----------------
  Widget _resultView(FoundUser u) {
    return Column(
      key: const ValueKey('result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _C.okBg, borderRadius: BorderRadius.circular(6)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(TablerIcons.circleCheck, size: 15, color: _C.ok),
            SizedBox(width: 5),
            Text('Imepatikana',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.ok)),
          ]),
        ),
        const SizedBox(height: 10),
        _title('Namba yako'),
        const SizedBox(height: 6),
        _subtitle('Hii ndiyo namba uliyojisajili nayo.'),
        const SizedBox(height: 20),

        _fieldLabel(TablerIcons.deviceMobile, 'Namba ya simu'),
        Container(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _C.line, width: 1.5)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 23),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(u.phone,
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          color: _C.text)),
                ),
              ),
              const SizedBox(width: 10),
              _copyButton(),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _infoBlock(TablerIcons.user, 'Jina', u.fullName),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, thickness: 1, color: _C.line),
        ),
        _infoBlock(TablerIcons.briefcase2, 'Kada', u.cadre),

        _footer(
          left: _textLink(TablerIcons.refresh, 'Tafuta tena', _searchAgain),
          right: _primaryButton('Ingia', () => widget.onLogin(u.phone)),
        ),
      ],
    );
  }

  // ---------------- VIPANDE ----------------
  Widget _title(String t) => Text(t,
      style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900, color: _C.text, height: 1.2));

  Widget _subtitle(String t) =>
      Text(t, style: const TextStyle(fontSize: 14.5, color: _C.body, height: 1.45));

  Widget _fieldLabel(IconData icon, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Row(children: [
          Icon(icon, size: 17, color: _C.primaryDark),
          const SizedBox(width: 6),
          Text(t,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.text)),
        ]),
      );

  Widget _infoBlock(IconData icon, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: _C.primaryDark),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, color: _C.hint)),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(value,
                softWrap: true,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _C.text, height: 1.35)),
          ),
        ],
      );

  Widget _copyButton() {
    final c = _copied ? _C.ok : _C.primaryDark;
    return Material(
      color: _copied ? _C.okBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _copied ? _C.okBg : _C.copyBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _copied ? null : _copy,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Row(
                key: ValueKey(_copied),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_copied ? TablerIcons.check : TablerIcons.copy,
                      size: 15, color: c),
                  const SizedBox(width: 5),
                  Text(_copied ? 'Imenakiliwa' : 'Nakili',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: c)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer({required Widget left, required Widget right}) => Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.only(top: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _C.line)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Flexible(child: left), right],
        ),
      );

  Widget _textLink(IconData icon, String t, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: _C.primaryDark),
            const SizedBox(width: 6),
            Flexible(
              child: Text(t,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _C.primaryDark)),
            ),
          ]),
        ),
      );

  Widget _primaryButton(String t, VoidCallback? onTap, {bool loading = false}) =>
      SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.primary,
            disabledBackgroundColor: _C.primary.withValues(alpha: 0.75),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  const Icon(TablerIcons.arrowRight, size: 16),
                ]),
        ),
      );

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}

// ================= LOGO =================
class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_icon.png',
      height: 110,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const _LogoPlaceholder(),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: _C.logoDash, radius: 18),
      child: const SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Text('Logo\nyako',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _C.logoText, height: 1.2)),
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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}

// ================= MISTARI YA HATUA =================
class _StepBar extends StatelessWidget {
  final bool step2;
  const _StepBar({required this.step2});

  @override
  Widget build(BuildContext context) {
    Widget bar(bool on) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 5,
            decoration: BoxDecoration(
              color: on ? _C.primary : _C.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
    return Row(children: [bar(true), const SizedBox(width: 8), bar(step2)]);
  }
}
