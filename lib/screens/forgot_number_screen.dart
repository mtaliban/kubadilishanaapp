/// Skrini mbili za "Sahau Namba" — Tafuta kwa jina (SahauNambaScreen) na
/// Matokeo (NumberResultsScreen).
///
/// Muundo mfupi: maneno machache, kitufe kidogo kisicho na upana wote wa skrini.
/// Namba za simu zinaonyeshwa kamili (hazifichwi).
///
/// Mtiririko: Login → SahauNambaScreen (weka jina) → NumberResultsScreen
/// (chagua "Yangu") → namba inarudishwa kwenye Login na field inajazwa.
library;

import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey900 = Color(0xFF111827);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey300 = Color(0xFFD1D5DB);
const _kGrey200 = Color(0xFFE5E7EB);

// ───────────────────────── Model ─────────────────────────

class NatokeoNamba {
  final String simu; // 2557XXXXXXXX
  final String idara;
  const NatokeoNamba({required this.simu, required this.idara});
}

String simuSafi(String s) {
  final d = s.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('255')) {
    return '+255 ${d.substring(3, 6)} ${d.substring(6, 9)} ${d.substring(9)}';
  }
  return s;
}

String _categoryLabel(String? c) => c == 'health'
    ? 'Idara ya Afya'
    : c == 'education'
        ? 'Idara ya Elimu'
        : (c ?? '').trim();

// ───────────────────────── Skrini 1: Tafuta ─────────────────────────

class SahauNambaScreen extends StatefulWidget {
  const SahauNambaScreen({super.key});

  @override
  State<SahauNambaScreen> createState() => _SahauNambaScreenState();
}

class _SahauNambaScreenState extends State<SahauNambaScreen> {
  final _jina = TextEditingController();
  bool _inatafuta = false;
  String? _kosa;

  @override
  void dispose() {
    _jina.dispose();
    super.dispose();
  }

  Future<void> _tafuta() async {
    final jina = _jina.text.trim();
    if (jina.isEmpty) {
      setState(() => _kosa = 'Weka jina kwanza');
      return;
    }
    setState(() {
      _inatafuta = true;
      _kosa = null;
    });
    try {
      final r = await ApiService().lookupByName(jina);
      if (!mounted) return;
      final raw = r.data;
      final users = raw is List
          ? raw
          : (raw is Map ? (raw['users'] ?? raw['data'] ?? []) as List : <dynamic>[]);

      final matokeo = <NatokeoNamba>[];
      for (final u in users) {
        if (u is! Map) continue;
        final primary = (u['phone_primary'] ?? '').toString().trim();
        final alt = (u['phone_alt'] ?? '').toString().trim();
        final idara = _categoryLabel(u['category']?.toString());
        if (primary.isNotEmpty) matokeo.add(NatokeoNamba(simu: primary, idara: idara));
        if (alt.isNotEmpty && alt != primary) {
          matokeo.add(NatokeoNamba(simu: alt, idara: idara));
        }
      }

      setState(() => _inatafuta = false);
      final chosen = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => NumberResultsScreen(jina: jina, matokeo: matokeo),
      ));
      if (chosen != null && chosen.isNotEmpty && mounted) {
        Navigator.pop(context, chosen);
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'Imeshindwa kutafuta. Jaribu tena.';
      try {
        final d = (e as dynamic).response?.data?['detail'];
        if (d is String && d.isNotEmpty) msg = d;
      } catch (_) {}
      setState(() {
        _inatafuta = false;
        _kosa = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "< Rudi"
              InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 20, color: _kGrey900),
                      SizedBox(width: 8),
                      Text('Rudi',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _kGrey900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Sahau namba?',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700, color: _kGrey900)),
              const SizedBox(height: 4),
              const Text('Weka jina lako tulikutafutie.',
                  style: TextStyle(fontSize: 13, color: _kGrey500)),
              const SizedBox(height: 18),

              const Text('Jina kamili',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: _kGrey500)),
              const SizedBox(height: 5),
              TextField(
                controller: _jina,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _tafuta(),
                enabled: !_inatafuta,
                decoration: InputDecoration(
                  hintText: 'Amani Selemani',
                  hintStyle: const TextStyle(color: _kGrey400, fontSize: 14),
                  errorText: _kosa,
                  prefixIcon:
                      const Icon(Icons.person_outline, size: 20, color: _kGrey400),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kGrey300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kGrey300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),

              // Kitufe kidogo (si full-width)
              FilledButton(
                onPressed: _inatafuta ? null : _tafuta,
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kBlue.withValues(alpha: 0.55),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: _inatafuta
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Tafuta'),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: const Text('Rudi kwenye kuingia',
                    style: TextStyle(fontSize: 13, color: _kBlue)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Skrini 2: Matokeo ─────────────────────────

class NumberResultsScreen extends StatelessWidget {
  final String jina;
  final List<NatokeoNamba> matokeo;

  const NumberResultsScreen({super.key, required this.jina, required this.matokeo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "< Tafuta tena"
              InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 20, color: _kGrey900),
                      SizedBox(width: 8),
                      Text('Tafuta tena',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _kGrey900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Matokeo (${matokeo.length})',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: _kGrey900)),
              const SizedBox(height: 4),
              Text(
                matokeo.isEmpty ? 'Hakuna namba kwa jina hili.' : 'Chagua namba yako.',
                style: const TextStyle(fontSize: 13, color: _kGrey500),
              ),
              const SizedBox(height: 16),

              if (matokeo.isEmpty)
                OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGrey900,
                    side: const BorderSide(color: _kGrey300),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Tafuta tena'),
                )
              else
                for (final c in matokeo) _NambaKadi(c: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _NambaKadi extends StatelessWidget {
  final NatokeoNamba c;
  const _NambaKadi({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.phone_outlined, size: 20, color: _kBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(simuSafi(c.simu),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _kGrey900)),
              if (c.idara.isNotEmpty)
                Text(c.idara, style: const TextStyle(fontSize: 12, color: _kGrey500)),
            ],
          ),
        ),
        SizedBox(
          height: 32,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, c.simu),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kBlue,
              side: const BorderSide(color: _kGrey300),
              backgroundColor: _kBlue50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Text('Yangu'),
          ),
        ),
      ]),
    );
  }
}
