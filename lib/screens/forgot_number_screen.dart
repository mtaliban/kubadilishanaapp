/// Skrini ya "Sahau Namba yako?" — mtumiaji anaweka jina lake kamili,
/// mfumo unatafuta kwenye DB (`/auth/lookup-by-name`) na kuonyesha namba
/// zake zilizosajiliwa. Akichagua namba, inarudishwa kwenye Login
/// (`Navigator.pop(context, phone)`) na login field inajazwa papo hapo.
import 'package:flutter/material.dart';
import '../services/api_service.dart';

const accentBlue = Color(0xFF378ADD);

class SahauNambaScreen extends StatefulWidget {
  const SahauNambaScreen({super.key});

  @override
  State<SahauNambaScreen> createState() => _SahauNambaScreenState();
}

class _SahauNambaScreenState extends State<SahauNambaScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController jinaController = TextEditingController();
  bool isLoading = false;
  String? _error;
  List<dynamic> _results = [];

  @override
  void dispose() {
    jinaController.dispose();
    super.dispose();
  }

  Future<void> _tafutaNamba() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { isLoading = true; _error = null; _results = []; });
    try {
      final r = await ApiService().lookupByName(jinaController.text.trim());
      if (!mounted) return;
      final raw = r.data;
      setState(() => _results = raw is List ? raw : (raw['users'] ?? raw['data'] ?? []));
    } catch (e) {
      if (!mounted) return;
      String msg = 'Imeshindikana kutafuta. Jaribu tena.';
      try {
        final d = (e as dynamic).response?.data?['detail'];
        if (d is String) msg = d;
      } catch (_) {}
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Mtu akichagua namba — rudi kwenye Login na uijaze kwenye field
  void _chagua(String phone) => Navigator.pop(context, phone);

  String _fmtPhone(String p) {
    final d = p.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('255')) {
      return '+255 ${d.substring(3, 6)} ${d.substring(6, 9)} ${d.substring(9)}';
    }
    return p;
  }

  String _categoryLabel(String? c) =>
      c == 'health' ? 'Afya' : c == 'education' ? 'Elimu' : (c ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kichwa cha juu: "< Rudi"
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 20, color: Colors.black87),
                        SizedBox(width: 8),
                        Text(
                          'Rudi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Icon ya duara na search
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: accentBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.search, size: 30, color: accentBlue),
                  ),
                ),

                const SizedBox(height: 20),

                const Center(
                  child: Text(
                    'Sahau Namba yako?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Text(
                    'Weka jina lako kamili tutakuonyesha namba zako zilizosajiliwa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                  ),
                ),

                const SizedBox(height: 24),

                // Lebo ya JINA KAMILI
                const Text(
                  'JINA KAMILI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: jinaController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _tafutaNamba(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: 'Jina lako kamili kama ulilosajilia',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: accentBlue, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: accentBlue, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Tafadhali weka jina lako kamili';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Kitufe cha bluu, chembamba
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _tafutaNamba,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Tafuta Namba Zangu',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text(
                      'Rudi kwenye kuingia',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accentBlue,
                      ),
                    ),
                  ),
                ),

                // ── Makosa ──
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626), height: 1.4)),
                  ),
                ],

                // ── Matokeo ya utafutaji ──
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Namba ${_results.length} zilizopatikana',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                  const SizedBox(height: 10),
                  for (final u in _results) _userCard(u as Map),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Kadi ya mtumiaji aliyepatikana — namba + kitufe cha kuchagua ──
  Widget _userCard(Map u) {
    final name = u['full_name']?.toString() ?? '';
    final primary = u['phone_primary']?.toString() ?? '';
    final alt = u['phone_alt']?.toString() ?? '';
    final cadre = u['cadre_display']?.toString() ?? u['cadre_code']?.toString() ?? '';
    final cat = _categoryLabel(u['category']?.toString());
    final init = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Widget phoneRow(String phone) => Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentBlue.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.phone_iphone_rounded, size: 16, color: accentBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_fmtPhone(phone),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accentBlue)),
        ),
        GestureDetector(
          onTap: () => _chagua(phone),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: accentBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Tumia namba hii',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: accentBlue.withOpacity(0.1),
            child: Text(init,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accentBlue)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.black87)),
            if (cadre.isNotEmpty || cat.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text([if (cat.isNotEmpty) cat, if (cadre.isNotEmpty) cadre].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ])),
        ]),
        if (primary.isNotEmpty) phoneRow(primary),
        if (alt.isNotEmpty && alt != primary) phoneRow(alt),
      ]),
    );
  }
}
