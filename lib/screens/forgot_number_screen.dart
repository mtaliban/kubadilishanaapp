/// "Umesahau namba?" — skrini mbili:
///   1. SahauNambaScreen  — fomu ya jina (hatua 1/2)
///   2. NambaImepatikanaScreen — matokeo (hatua 2/2)
///
/// Login screen inangoja matokeo: Navigator.pushNamed('/forgot-number')
/// "Ingia →" inarudisha namba kwa Navigator.pop(context, phone)
/// "Tafuta tena" inarudisha null → field inafutwa kwa utafutaji mpya
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

// ── Rangi ──────────────────────────────────────────────────────────────────────

class _C {
  static const accent       = Color(0xFF2952E3);
  static const accentBg     = Color(0xFFEAEFFF);
  static const success      = Color(0xFF12B76A);
  static const successBg    = Color(0xFFE9F9F0);
  static const errorColor   = Color(0xFFD92D20);
  static const errorBg      = Color(0xFFFFF1F0);
  static const errorBorder  = Color(0xFFFFCCC7);
  static const border       = Color(0xFFE4E7EC);
  static const textPrimary  = Color(0xFF101828);
  static const textSecondary = Color(0xFF667085);
  static const textMuted    = Color(0xFF98A2B3);
  static const bg           = Color(0xFFF5F7FA);
}

// ── Helpers ────────────────────────────────────────────────────────────────────

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

// ── BrandHeader ────────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _C.accent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => const Icon(
                Icons.sync_alt_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _C.textPrimary,
            ),
            children: [
              TextSpan(text: 'ESS'),
              TextSpan(
                text: 'TRANSFER',
                style: TextStyle(color: _C.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'CONNECT · MATCH · TRANSFER',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.5,
            color: _C.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── StepProgress ───────────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int activeSteps;
  const _StepProgress(this.activeSteps);

  @override
  Widget build(BuildContext context) {
    Widget seg(bool on) => Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: on ? _C.accent : _C.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
    return Row(children: [seg(activeSteps >= 1), seg(activeSteps >= 2)]);
  }
}

// ── FormCard ───────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: child,
    );
  }
}

// ── InfoRow (inayotumiwa kwenye NambaImepatikanaScreen) ────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool topBorder;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.topBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: topBorder
          ? const BoxDecoration(
              border: Border(
                  top: BorderSide(color: _C.border, width: 0.5)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: _C.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(fontSize: 12, color: _C.textMuted)),
          ]),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _C.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SKRINI 1 — Fomu ya jina (hatua 1/2)
// =============================================================================

class SahauNambaScreen extends StatefulWidget {
  const SahauNambaScreen({super.key});

  @override
  State<SahauNambaScreen> createState() => _SahauNambaScreenState();
}

class _SahauNambaScreenState extends State<SahauNambaScreen> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool    _loading  = false;
  String? _error;
  bool    _notFound = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _tafuta() async {
    final name  = _ctrl.text.trim();
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    if (words.length < 2) {
      setState(() {
        _error    = 'Weka jina la kwanza na la mwisho.';
        _notFound = false;
      });
      return;
    }

    setState(() { _loading = true; _error = null; _notFound = false; });
    FocusScope.of(context).unfocus();

    try {
      final res = await ApiService().lookupByName(name);
      if (!mounted) return;

      final raw   = res.data;
      final users = raw is List
          ? raw
          : (raw is Map ? (raw['users'] ?? raw['data'] ?? []) as List : <dynamic>[]);

      if (users.isEmpty) {
        setState(() { _loading = false; _notFound = true; });
        return;
      }

      final u     = users.first as Map;
      final phone = (u['phone_primary'] ?? u['phone'] ?? '').toString().trim();

      if (phone.isEmpty) {
        setState(() { _loading = false; _notFound = true; });
        return;
      }

      final jina = (u['full_name'] ?? '').toString().trim().toUpperCase();
      final kada = _cadreOf(u);
      setState(() => _loading = false);

      // Piga push; result ni namba (Ingia) au null (Tafuta tena)
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => NambaImepatikanaScreen(
            jina: jina,
            kada: kada,
            namba: phone,
          ),
        ),
      );
      if (!mounted) return;

      if (result != null) {
        // Mtumiaji alitap "Ingia" — rudisha namba kwa login screen
        Navigator.of(context).pop(result);
      } else {
        // Mtumiaji alitap "Tafuta tena" — futa field, rudisha focus
        _ctrl.clear();
        _focus.requestFocus();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        setState(() { _loading = false; _notFound = true; });
      } else {
        String msg = 'Imeshindikana kutafuta. Jaribu tena.';
        final d = e.response?.data;
        if (d is Map && d['detail'] is String &&
            (d['detail'] as String).isNotEmpty) {
          msg = d['detail'] as String;
        }
        setState(() { _loading = false; _error = msg; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = 'Imeshindikana kutafuta. Jaribu tena.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 20),
                  const _StepProgress(1),
                  const SizedBox(height: 22),

                  // ── Ikoni ya hatua ──
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _C.accentBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.person_search_rounded,
                        color: _C.accent, size: 20),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Umesahau namba?',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: _C.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Andika jina lako kamili tukutafutie namba uliyosajili nayo.',
                    style: TextStyle(
                      fontSize: 13, color: _C.textSecondary, height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text(
                    'Jina kamili',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _C.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),

                  // ── Input field ──
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: hasError ? _C.errorColor : _C.accent,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 16,
                            color: hasError ? _C.errorColor : _C.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _loading ? null : _tafuta(),
                            onChanged: (_) {
                              if (_error != null || _notFound) {
                                setState(() {
                                  _error    = null;
                                  _notFound = false;
                                });
                              }
                            },
                            style: const TextStyle(
                                fontSize: 13, color: _C.textPrimary),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Mfano: Amani Selemani',
                              hintStyle: TextStyle(
                                  fontSize: 13, color: _C.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 7),

                  // ── Hint / error chini ya field ──
                  if (hasError)
                    Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 12, color: _C.errorColor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 11, color: _C.errorColor)),
                      ),
                    ])
                  else
                    const Row(children: [
                      Icon(Icons.verified_rounded,
                          size: 12, color: _C.success),
                      SizedBox(width: 5),
                      Text('Andika jina kama lilivyosajiliwa',
                          style: TextStyle(
                              fontSize: 11, color: _C.textMuted)),
                    ]),

                  // ── "Hatukupata" inline card ──
                  if (_notFound) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _C.errorBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _C.errorBorder, width: 0.5),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hatukupata',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _C.errorColor,
                              )),
                          SizedBox(height: 3),
                          Text('Hatukupata namba kwa jina hilo.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _C.textSecondary)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  const Divider(height: 0.5, color: _C.border),
                  const SizedBox(height: 16),

                  // ── Footer: Rudi | Tafuta ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, size: 14),
                        label: const Text('Rudi kuingia'),
                        style: TextButton.styleFrom(
                          foregroundColor: _C.accent,
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _tafuta,
                        icon: _loading
                            ? const SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.arrow_forward, size: 14),
                        label: const Text('Tafuta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF8AAAF5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SKRINI 2 — Matokeo (hatua 2/2)
// =============================================================================

class NambaImepatikanaScreen extends StatelessWidget {
  final String jina;
  final String kada;
  final String namba;

  const NambaImepatikanaScreen({
    super.key,
    required this.jina,
    required this.kada,
    required this.namba,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 20),
                  const _StepProgress(2),
                  const SizedBox(height: 22),

                  // ── Ikoni ya mafanikio ──
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _C.successBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: _C.success, size: 20),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Namba imepatikana',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: _C.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hii ndiyo namba uliyojisajili nayo.',
                    style: TextStyle(
                        fontSize: 13, color: _C.textSecondary),
                  ),

                  const SizedBox(height: 16),

                  // ── Tile ya namba + nakili ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border.all(color: _C.accent, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.smartphone_rounded,
                            size: 17, color: _C.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _fmtPhone(namba),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _C.textPrimary,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(7),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: namba));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Namba imenakiliwa: ${_fmtPhone(namba)}'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            );
                          },
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: _C.border, width: 0.5),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.copy_rounded,
                                size: 14, color: _C.accent),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Jina',
                    value: jina,
                    topBorder: false,
                  ),
                  _InfoRow(
                    icon: Icons.work_outline_rounded,
                    label: 'Kada',
                    value: kada,
                    topBorder: true,
                  ),

                  const SizedBox(height: 18),
                  const Divider(height: 0.5, color: _C.border),
                  const SizedBox(height: 16),

                  // ── Footer: Tafuta tena | Ingia ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        // null → SahauNambaScreen itafuta field
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Tafuta tena'),
                        style: TextButton.styleFrom(
                          foregroundColor: _C.accent,
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      ElevatedButton.icon(
                        // namba → login screen inajaza field
                        onPressed: () =>
                            Navigator.of(context).pop(namba),
                        icon: const Icon(Icons.arrow_forward, size: 14),
                        label: const Text('Ingia'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
