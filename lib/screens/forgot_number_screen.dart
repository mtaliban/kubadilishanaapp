/// "Sahau namba?" — ukurasa mmoja (SahauNambaScreen).
///
/// Muundo: logo ya app juu, kadi ya fomu ya jina katikati, na ukibonyeza
/// "Tafuta" matokeo yanatokea CHINI ya fomu (AnimatedSize) bila kuhamia
/// ukurasa mwingine — ukurasa unashuka yenyewe hadi kwenye matokeo.
/// "Tafuta tena" inafuta matokeo na kurudisha kishale kwenye sehemu ya jina.
///
/// API: POST /auth/lookup-by-name (ApiService.lookupByName) — namba hutafutwa
/// kwa jina; namba za watumiaji wasiothibitishwa hutoka zikifichwa (***).
/// Namba husahihishwa ili +255XXXXXXXXX ionekane +255 XXX XXX XXX.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

/// Rangi za ukurasa huu (zile zile za fomu ya awali).
/// (Jina ni SahauNambaColors kuepuka mgongano na AppColors ya config/theme.dart
/// — rangi zote ni zilezile za design ya mtumiaji.)
class SahauNambaColors {
  static const primary = Color(0xFF1E40AF);
  static const primarySoft = Color(0xFFF5F7FF);
  static const primaryBorder = Color(0xFFE0E7FF);
  static const primaryChip = Color(0xFFEEF2FF);
  static const copyBorder = Color(0xFFC7D2FE);
  static const text = Color(0xFF111827);
  static const label = Color(0xFF374151);
  static const muted = Color(0xFF6B7280);
  static const hint = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const inputBorder = Color(0xFFD1D5DB);
  static const divider = Color(0xFFF0F1F3);
  static const page = Color(0xFFF9FAFB);
  static const success = Color(0xFF047857);
  static const error = Color(0xFFB91C1C);
}

/// Tokeo moja la utafutaji
class NumberResult {
  final String phone; // mfano: +255763795805
  final String department; // mfano: Idara ya Elimu

  const NumberResult({required this.phone, required this.department});
}

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

/// Idara inayoonyeshwa chini ya namba: kada halisi (k.m. "Mwuguzi") au idara.
String _departmentOf(Map u) {
  final cadre = (u['cadre_display'] ?? '').toString().trim();
  if (cadre.isNotEmpty) return cadre;
  return _categoryLabel(u['category']?.toString());
}

/// Ukurasa mmoja: logo juu, fomu ya jina, na matokeo yanatokea chini
/// ya fomu bila kuhamia ukurasa mwingine.
class SahauNambaScreen extends StatefulWidget {
  const SahauNambaScreen({super.key, this.onBackToLogin});

  /// Kinachofanyika ukibonyeza "Rudi kwenye kuingia".
  /// Kisipowekwa, ukurasa unafungwa (Navigator.maybePop).
  final VoidCallback? onBackToLogin;

  @override
  State<SahauNambaScreen> createState() => _SahauNambaScreenState();
}

class _SahauNambaScreenState extends State<SahauNambaScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _resultsKey = GlobalKey();

  bool _loading = false;
  String? _error;
  List<NumberResult>? _results;
  int? _copiedIndex;
  Timer? _copyTimer;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _copyTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // API halisi: POST /auth/lookup-by-name — tafuta namba kwa jina.
  // 404 (hakuna mtumiaji) inarudisha orodha tupu; makosa mengine hupanda.
  // ---------------------------------------------------------------------------
  Future<List<NumberResult>> _searchByName(String name) async {
    final r = await ApiService().lookupByName(name);
    final raw = r.data;
    final users = raw is List
        ? raw
        : (raw is Map ? (raw['users'] ?? raw['data'] ?? []) as List : <dynamic>[]);

    final out = <NumberResult>[];
    for (final u in users) {
      if (u is! Map) continue;
      final primary = (u['phone_primary'] ?? '').toString().trim();
      final alt = (u['phone_alt'] ?? '').toString().trim();
      final dept = _departmentOf(u);
      if (primary.isNotEmpty) out.add(NumberResult(phone: primary, department: dept));
      if (alt.isNotEmpty && alt != primary) {
        out.add(NumberResult(phone: alt, department: dept));
      }
    }
    return out;
  }

  Future<void> _onSearch() async {
    FocusScope.of(context).unfocus();
    final name = _controller.text.trim();
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    if (words.length < 2) {
      setState(() => _error = 'Weka jina la kwanza na la mwisho.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = null;
      _copiedIndex = null;
    });

    try {
      final results = await _searchByName(name);
      if (!mounted) return;
      setState(() => _results = results);

      // Shuka hadi kwenye matokeo yakishatokea
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _resultsKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        // Hakuna mtumiaji kwa jina hili — onyesha kadi ya matokeo mapesi.
        setState(() => _results = const []);
      } else {
        String msg = 'Imeshindikana kutafuta. Jaribu tena.';
        final d = e.response?.data;
        if (d is Map && d['detail'] is String && (d['detail'] as String).isNotEmpty) {
          msg = d['detail'] as String;
        }
        setState(() => _error = msg);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Imeshindikana kutafuta. Jaribu tena.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchAgain() {
    setState(() {
      _results = null;
      _copiedIndex = null;
      _error = null;
    });
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _copy(int index, String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    _copyTimer?.cancel();
    setState(() => _copiedIndex = index);
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedIndex = null);
    });
  }

  // ---------------------------------------------------------------------------
  // UI
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
                  _buildFormCard(),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _results == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            key: _resultsKey,
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildResultsCard(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Logo ya app juu ya fomu. Weka picha yako: assets/images/app_icon.png
  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/app_icon.png',
        height: 96,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
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

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SahauNambaColors.border),
      );

  ButtonStyle get _linkStyle => TextButton.styleFrom(
        foregroundColor: SahauNambaColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  Widget _iconBadge(IconData icon) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: SahauNambaColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SahauNambaColors.primaryBorder),
        ),
        child: Icon(icon, color: SahauNambaColors.primary, size: 22),
      );

  // ---------------- Fomu ya jina ----------------
  Widget _buildFormCard() {
    final hasError = _error != null;

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 6),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBadge(Icons.person_search_outlined),
          const SizedBox(height: 16),
          const Text(
            'Sahau namba?',
            style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: SahauNambaColors.text),
          ),
          const SizedBox(height: 4),
          const Text(
            'Weka jina lako tulikutafutie.',
            style: TextStyle(fontSize: 14, color: SahauNambaColors.muted),
          ),
          const SizedBox(height: 22),
          const Text(
            'Jina kamili',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: SahauNambaColors.label),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _onSearch(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: const TextStyle(fontSize: 15, color: SahauNambaColors.text),
            decoration: InputDecoration(
              hintText: 'Amani Selemani',
              hintStyle: const TextStyle(color: SahauNambaColors.hint),
              prefixIcon: const Icon(Icons.badge_outlined,
                  size: 20, color: SahauNambaColors.hint),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              filled: true,
              fillColor: Colors.white,
              enabledBorder:
                  border(hasError ? SahauNambaColors.error : SahauNambaColors.inputBorder),
              focusedBorder: border(
                  hasError ? SahauNambaColors.error : SahauNambaColors.primary, 1.5),
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
                  _error ?? 'Jina kama lilivyosajiliwa.',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasError ? SahauNambaColors.error : SahauNambaColors.muted,
                  ),
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
                TextButton.icon(
                  onPressed: widget.onBackToLogin ??
                      () => Navigator.maybePop(context),
                  style: _linkStyle,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Rudi kwenye kuingia'),
                ),
                FilledButton(
                  onPressed: _loading ? null : _onSearch,
                  style: FilledButton.styleFrom(
                    backgroundColor: SahauNambaColors.primary,
                    disabledBackgroundColor: const Color(0xFF6B82CF),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
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

  // ---------------- Matokeo ----------------
  Widget _buildResultsCard() {
    final results = _results!;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.manage_search_rounded),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SahauNambaColors.primaryChip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${results.length} imepatikana',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SahauNambaColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Matokeo',
            style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: SahauNambaColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            results.isEmpty
                ? 'Hatukupata namba kwa jina hilo.'
                : 'Nakili namba yako.',
            style: const TextStyle(fontSize: 14, color: SahauNambaColors.muted),
          ),
          const SizedBox(height: 18),
          if (results.isEmpty)
            _emptyHint()
          else ...[
            for (var i = 0; i < results.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _resultTile(i, results[i]),
              ),
            _copyHint(),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: SahauNambaColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: _searchAgain,
              style: _linkStyle,
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text('Tafuta tena'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultTile(int index, NumberResult r) {
    final copied = _copiedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: copied ? SahauNambaColors.success : SahauNambaColors.border),
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
            child: const Icon(Icons.smartphone_rounded,
                size: 20, color: SahauNambaColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPhone(r.phone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SahauNambaColors.text),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.account_balance_outlined,
                        size: 13, color: SahauNambaColors.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        r.department,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: SahauNambaColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Nakili namba',
            child: Material(
              color: copied ? SahauNambaColors.success : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: copied ? SahauNambaColors.success : SahauNambaColors.copyBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _copy(index, r.phone),
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

  Widget _copyHint() {
    final copied = _copiedIndex != null;
    return Row(
      children: [
        Icon(
          copied ? Icons.check_circle_outline : Icons.info_outline,
          size: 14,
          color: copied ? SahauNambaColors.success : SahauNambaColors.muted,
        ),
        const SizedBox(width: 5),
        Text(
          copied ? 'Namba imenakiliwa.' : 'Bonyeza kitufe kunakili namba.',
          style: TextStyle(
            fontSize: 12,
            color: copied ? SahauNambaColors.success : SahauNambaColors.muted,
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
