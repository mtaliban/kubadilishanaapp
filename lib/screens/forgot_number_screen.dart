/// "Sahau namba?" — ukurasa mmoja (SahauNambaScreen).
///
/// Kadi moja inabadilika ndani kwa AnimatedSwitcher:
///   search  → fomu ya jina (default)
///   found   → "Namba imepatikana" + namba + Jina/Kada + "Tafuta tena" | "Ingia →"
///   notFound → kadi ya "Hatukupata"
///
/// "Ingia →" inarudisha namba kwa Navigator.pop(context, phone) — LoginScreen
/// inaikaribisha na kujaza field ya simu moja kwa moja.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

class SahauNambaColors {
  static const primary = Color(0xFF1E40AF);
  static const primarySoft = Color(0xFFF5F7FF);
  static const primaryBorder = Color(0xFFE0E7FF);
  static const text = Color(0xFF111827);
  static const label = Color(0xFF374151);
  static const muted = Color(0xFF6B7280);
  static const hint = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const inputBorder = Color(0xFFD1D5DB);
  static const divider = Color(0xFFF0F1F3);
  static const page = Color(0xFFF9FAFB);
  static const success = Color(0xFF047857);
  static const successSoft = Color(0xFFECFDF5);
  static const successBorder = Color(0xFFA7F3D0);
  static const copyBorder = Color(0xFFC7D2FE);
  static const error = Color(0xFFB91C1C);
}

/// Matokeo ya utafutaji kwa mtumiaji mmoja
class _FoundUser {
  final String phone;
  final String fullName;
  final String cadre;
  const _FoundUser({required this.phone, required this.fullName, required this.cadre});
}

enum _CardState { search, loading, found, notFound, error }

/// +255763795805  ->  +255 763 795 805
String formatPhone(String phone) {
  final d = phone.replaceAll(' ', '');
  if (d.startsWith('+255') && d.length == 13) {
    return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7, 10)} ${d.substring(10)}';
  }
  return phone;
}

String _categoryLabel(String? c) => c == 'health'
    ? 'Idara ya Afya'
    : c == 'education'
        ? 'Idara ya Elimu'
        : (c ?? '').trim();

String _cadreOf(Map u) {
  final cadre = (u['cadre_display'] ?? '').toString().trim();
  if (cadre.isNotEmpty) return cadre;
  return _categoryLabel(u['category']?.toString());
}

class SahauNambaScreen extends StatefulWidget {
  const SahauNambaScreen({super.key, this.onBackToLogin});

  final VoidCallback? onBackToLogin;

  @override
  State<SahauNambaScreen> createState() => _SahauNambaScreenState();
}

class _SahauNambaScreenState extends State<SahauNambaScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  _CardState _state = _CardState.search;
  String? _errorMsg;
  _FoundUser? _found;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _copyTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  Future<void> _onSearch() async {
    FocusScope.of(context).unfocus();
    final name = _ctrl.text.trim();
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    if (words.length < 2) {
      setState(() {
        _state = _CardState.error;
        _errorMsg = 'Weka jina la kwanza na la mwisho.';
      });
      return;
    }

    setState(() {
      _state = _CardState.loading;
      _errorMsg = null;
      _found = null;
      _copied = false;
    });

    try {
      final r = await ApiService().lookupByName(name);
      if (!mounted) return;

      final raw = r.data;
      final users = raw is List
          ? raw
          : (raw is Map ? (raw['users'] ?? raw['data'] ?? []) as List : <dynamic>[]);

      if (users.isEmpty) {
        setState(() => _state = _CardState.notFound);
        return;
      }

      final u = users.first as Map;
      final phone = (u['phone_primary'] ?? u['phone'] ?? '').toString().trim();
      final fullName = (u['full_name'] ?? '').toString().trim();
      final cadre = _cadreOf(u);

      if (phone.isEmpty) {
        setState(() => _state = _CardState.notFound);
        return;
      }

      setState(() {
        _found = _FoundUser(phone: phone, fullName: fullName, cadre: cadre);
        _state = _CardState.found;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        setState(() => _state = _CardState.notFound);
      } else {
        String msg = 'Imeshindikana kutafuta. Jaribu tena.';
        final d = e.response?.data;
        if (d is Map && d['detail'] is String && (d['detail'] as String).isNotEmpty) {
          msg = d['detail'] as String;
        }
        setState(() {
          _state = _CardState.error;
          _errorMsg = msg;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _CardState.error;
        _errorMsg = 'Imeshindikana kutafuta. Jaribu tena.';
      });
    }
  }

  void _searchAgain() {
    setState(() {
      _state = _CardState.search;
      _errorMsg = null;
      _found = null;
      _copied = false;
    });
    _ctrl.clear();
    _focus.requestFocus();
  }

  Future<void> _copy() async {
    final phone = _found?.phone;
    if (phone == null) return;
    await Clipboard.setData(ClipboardData(text: phone));
    _copyTimer?.cancel();
    setState(() => _copied = true);
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _login() {
    final phone = _found?.phone ?? '';
    if (widget.onBackToLogin != null) {
      Navigator.maybePop(context, phone);
    } else {
      Navigator.maybePop(context, phone);
    }
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SahauNambaColors.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 28),
                  _buildCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/app_icon.png',
        height: 96,
        fit: BoxFit.contain,
        errorBuilder: (context2, err, st) => Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: SahauNambaColors.primarySoft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SahauNambaColors.primaryBorder),
          ),
          child: const Icon(Icons.apps_rounded,
              size: 44, color: SahauNambaColors.primary),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SahauNambaColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          child: _state == _CardState.found || _state == _CardState.notFound
              ? _FoundContent(
                  key: const ValueKey('found'),
                  state: _state,
                  found: _found,
                  copied: _copied,
                  onCopy: _copy,
                  onSearchAgain: _searchAgain,
                  onLogin: _state == _CardState.found ? _login : null,
                )
              : _SearchContent(
                  key: const ValueKey('search'),
                  ctrl: _ctrl,
                  focus: _focus,
                  loading: _state == _CardState.loading,
                  error: _errorMsg,
                  onSearch: _onSearch,
                  onClearError: () => setState(() => _errorMsg = null),
                  onBackToLogin: widget.onBackToLogin ?? () => Navigator.maybePop(context),
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// Search content — fomu ya jina
// =============================================================================
class _SearchContent extends StatelessWidget {
  const _SearchContent({
    super.key,
    required this.ctrl,
    required this.focus,
    required this.loading,
    required this.error,
    required this.onSearch,
    required this.onClearError,
    required this.onBackToLogin,
  });

  final TextEditingController ctrl;
  final FocusNode focus;
  final bool loading;
  final String? error;
  final VoidCallback onSearch;
  final VoidCallback onClearError;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: Icons.person_search_outlined, soft: SahauNambaColors.primarySoft, border: SahauNambaColors.primaryBorder, color: SahauNambaColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Sahau namba?',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: SahauNambaColors.text),
          ),
          const SizedBox(height: 4),
          const Text(
            'Weka jina lako tulikutafutie.',
            style: TextStyle(fontSize: 14, color: SahauNambaColors.muted),
          ),
          const SizedBox(height: 22),
          const Text(
            'Jina kamili',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: SahauNambaColors.label),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            focusNode: focus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            onChanged: (_) { if (error != null) onClearError(); },
            style: const TextStyle(fontSize: 15, color: SahauNambaColors.text),
            decoration: InputDecoration(
              hintText: 'Amani Selemani',
              hintStyle: const TextStyle(color: SahauNambaColors.hint),
              prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: SahauNambaColors.hint),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: border(hasError ? SahauNambaColors.error : SahauNambaColors.inputBorder),
              focusedBorder: border(hasError ? SahauNambaColors.error : SahauNambaColors.primary, 1.5),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                hasError ? Icons.error_outline : Icons.verified_user_outlined,
                size: 14,
                color: hasError ? SahauNambaColors.error : SahauNambaColors.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  error ?? 'Jina kama lilivyosajiliwa.',
                  style: TextStyle(fontSize: 12, color: hasError ? SahauNambaColors.error : SahauNambaColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: SahauNambaColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onBackToLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: SahauNambaColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 44),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Rudi kwenye kuingia'),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: loading ? null : onSearch,
                  style: FilledButton.styleFrom(
                    backgroundColor: SahauNambaColors.primary,
                    disabledBackgroundColor: const Color(0xFF6B82CF),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Tafuta'),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 17),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Found / not-found content — matokeo ndani ya kadi ile ile
// =============================================================================
class _FoundContent extends StatelessWidget {
  const _FoundContent({
    super.key,
    required this.state,
    required this.found,
    required this.copied,
    required this.onCopy,
    required this.onSearchAgain,
    required this.onLogin,
  });

  final _CardState state;
  final _FoundUser? found;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onSearchAgain;
  final VoidCallback? onLogin;

  bool get _isFound => state == _CardState.found && found != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(
            icon: _isFound ? Icons.check_rounded : Icons.search_off_rounded,
            soft: _isFound ? SahauNambaColors.successSoft : const Color(0xFFF3F4F6),
            border: _isFound ? SahauNambaColors.successBorder : const Color(0xFFE5E7EB),
            color: _isFound ? SahauNambaColors.success : SahauNambaColors.muted,
          ),
          const SizedBox(height: 16),
          Text(
            _isFound ? 'Namba imepatikana' : 'Hatukupata',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: SahauNambaColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            _isFound
                ? 'Hii ndiyo namba uliyojisajili nayo.'
                : 'Hatukupata namba kwa jina hilo.',
            style: const TextStyle(fontSize: 14, color: SahauNambaColors.muted),
          ),
          const SizedBox(height: 18),
          if (_isFound) ...[
            _phoneTile(found!.phone),
            const SizedBox(height: 14),
            _infoRow('Jina', found!.fullName),
            const SizedBox(height: 8),
            _infoRow('Kada', found!.cadre),
          ] else
            _emptyHint(),
          const SizedBox(height: 20),
          const Divider(height: 1, color: SahauNambaColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onSearchAgain,
                      style: TextButton.styleFrom(
                        foregroundColor: SahauNambaColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 44),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Tafuta tena'),
                    ),
                  ),
                ),
                if (onLogin != null)
                  FilledButton(
                    onPressed: onLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: SahauNambaColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ingia'),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneTile(String phone) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: copied ? SahauNambaColors.success : SahauNambaColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SahauNambaColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smartphone_rounded, size: 20, color: SahauNambaColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              formatPhone(phone),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SahauNambaColors.text),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: copied ? 'Imenakiliwa' : 'Nakili namba',
            child: Material(
              color: copied ? SahauNambaColors.success : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: copied ? SahauNambaColors.success : SahauNambaColors.copyBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onCopy,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 19,
                    color: copied ? Colors.white : SahauNambaColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: const TextStyle(fontSize: 13, color: SahauNambaColors.muted)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SahauNambaColors.text),
          ),
        ),
      ],
    );
  }

  Widget _emptyHint() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 14, color: SahauNambaColors.muted),
        SizedBox(width: 5),
        Expanded(
          child: Text(
            'Hakikisha jina limeandikwa kama lilivyosajiliwa, kisha tafuta tena.',
            style: TextStyle(fontSize: 12, color: SahauNambaColors.muted),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared helper
// =============================================================================
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.soft, required this.border, required this.color});
  final IconData icon;
  final Color soft;
  final Color border;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
