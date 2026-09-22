import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/app_shell.dart';
import '../utils/safe_cast.dart';

// ── Brand colors (kama web globals.css) ─────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF); // brand-blue
const _kGrey900 = Color(0xFF111827); // brand-grey-900
const _kGrey700 = Color(0xFF374151); // brand-grey-700
const _kGrey500 = Color(0xFF6B7280); // brand-grey-500
const _kGrey300 = Color(0xFFD1D5DB); // brand-grey-300
const _kGrey200 = Color(0xFFE5E7EB); // border-grey-200
const _kGrey50  = Color(0xFFF9FAFB); // brand-grey-50
const _kGrey100 = Color(0xFFF3F4F6); // brand-grey-100
const _kGrey400 = Color(0xFF9CA3AF); // brand-grey-400
const _kRed     = Color(0xFFDC2626); // brand-red
const _kGreen   = Color(0xFF16A34A); // brand-green
const _kGold200 = Color(0xFFFDE68A); // brand-gold-200 (amber-200)
const _kAmber   = Color(0xFFF59E0B); // amber-500
const _kAmberLight = Color(0xFFFBBF24); // amber-400

// .card = bg-white rounded-2xl(16px) p-6(24) border-grey-100 shadow-soft
BoxDecoration _cardDec({Color? borderColor}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: borderColor ?? _kGrey100),
  boxShadow: const [
    BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 4)), // shadow-soft
  ],
);

InputDecoration _inputDec({String? hint, bool disabled = false}) => InputDecoration(
  hintText: hint,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
  hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
  filled: true,
  fillColor: Colors.white,
);

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
);

// btn-primary — text-sm=14px px-4 py-2 rounded-lg font-bold brand-blue full-width
// btn-outline — text-xs=12px px-3=12px py-1.5=6px rounded-md border-grey-300 text-grey-700
ButtonStyle _btnOutline() => OutlinedButton.styleFrom(
  foregroundColor: _kGrey700,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  side: const BorderSide(color: _kGrey300),
  minimumSize: const Size(0, 0),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

// btn-primary small (for app bar area)
ButtonStyle _btnPrimarySmall() => ElevatedButton.styleFrom(
  backgroundColor: _kBlue,
  foregroundColor: Colors.white,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  minimumSize: const Size(0, 0),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  elevation: 0,
);

/// "255763795801" / "0763795801" -> "+255 763 795 801"
String _fmtPhone(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('255')) {
    return '+255 ${d.substring(3, 6)} ${d.substring(6, 9)} ${d.substring(9)}';
  }
  if (d.length == 10 && d.startsWith('0')) {
    return '+255 ${d.substring(1, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
  }
  return p.isEmpty ? '' : '+$d';
}

/// "0763795801" / "+255763795801" -> "763795801" (kwa field yenye prefix +255)
String _strip255(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('255')) return d.substring(3);
  if (d.length == 10 && d.startsWith('0')) return d.substring(1);
  return d;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _editing = false;
  String? _message;

  void _onAdminUpdate(dynamic _) => _load();

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('user.updated_by_admin', _onAdminUpdate);
  }

  @override
  void dispose() {
    WebSocketService().off('user.updated_by_admin', _onAdminUpdate);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMyProfile();
      if (mounted) setState(() => _profile = asMapOrNull(res.data));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _onSaved(Map<String, dynamic> p) {
    setState(() { _profile = p; _editing = false; _message = 'Imehifadhiwa!'; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _message = null); });
  }

  @override
  Widget build(BuildContext context) {
    final authIsAdmin = context.read<AuthProvider>().isAdmin;
    final isAdmin = authIsAdmin || (_profile?['is_admin'] == true);

    final content = _loading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E40AF))),
                SizedBox(height: 8),
                Text('Inapakia...', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
              ]),
            ),
          )
        : _profile == null
          ? const Center(child: Text('Imeshindikana kupakia'))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                // ── PAGE HEADER ──────────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Icon(Icons.person_outline_rounded, size: 22, color: _kBlue)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(
                        isAdmin ? 'Wasifu wa Admin' : 'Wasifu Wangu',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _kGrey900, height: 1.2),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF1FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('Admin',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kBlue)),
                        ),
                      ],
                    ]),
                    const Text('Taarifa za akaunti yako', style: TextStyle(fontSize: 13, color: _kGrey500)),
                  ])),
                  const SizedBox(width: 8),
                  if (!_editing)
                    GestureDetector(
                      onTap: () => setState(() => _editing = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kGrey300, width: 0.8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.pencilSimple(), size: 14, color: _kGrey700),
                          const SizedBox(width: 5),
                          const Text('Hariri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kGrey700)),
                        ]),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _editing = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kGrey300, width: 0.8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.x(), size: 14, color: _kGrey700),
                          const SizedBox(width: 5),
                          const Text('Ghairi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kGrey700)),
                        ]),
                      ),
                    ),
                ]),

                // ── Success message ──
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_message!, style: const TextStyle(color: _kBlue, fontSize: 14)),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Content: view or edit ──
                if (_editing)
                  isAdmin
                    ? _EditAdminProfile(profile: _profile!, onSaved: _onSaved)
                    : _EditProfile(profile: _profile!, onSaved: _onSaved)
                else
                  isAdmin ? _ViewAdmin(profile: _profile!) : _ViewUser(profile: _profile!),
              ]),
            );

    if (isAdmin) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(children: [
                Material(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.maybePop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(PhosphorIcons.caretLeft(), size: 18,
                          color: const Color(0xFF374151)),
                    ),
                  ),
                ),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            Expanded(child: content),
          ]),
        ),
      );
    }

    return AppShell(
      tabIndex: 3,
      child: content,
    );
  }
}

// ── View: Admin ───────────────────────────────────────────────────────────────
// Design mpya: avatar kubwa + badge ya nafasi + kadi ya "Mawasiliano"
// yenye vitufe vya kitendo (nakili / piga / WhatsApp).
class _ViewAdmin extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ViewAdmin({required this.profile});

  String get _name => profile['full_name']?.toString() ?? '';
  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String get _phoneAlt => (profile['phone_alt'] ?? '').toString();

  static const _accent = Color(0xFF2A3EB1);
  static const _accentMuted = Color(0xFFEDEFFA);
  static const _success = Color(0xFF1E9E5A);
  static const _successBg = Color(0xFFE7F7EE);
  static const _surface1 = Color(0xFFF5F6FA);
  static const _surface2 = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E6EE);
  static const _textPrimary = Color(0xFF1A1D29);
  static const _textSecondary = Color(0xFF5C6072);
  static const _textMuted = Color(0xFF9297A8);

  Widget _contactRow({
    required IconData leadingIcon,
    required Color leadingColor,
    required Color leadingBg,
    required String label,
    required String value,
    Widget? statusBadge,
    required IconData trailingIcon,
    required Color trailingColor,
    required Color trailingBg,
    required VoidCallback onTrailingTap,
  }) {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: leadingBg, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Icon(leadingIcon, color: leadingColor, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 13, color: _textMuted)),
            if (statusBadge != null) statusBadge!,
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
        ]),
      ),
      const SizedBox(width: 8),
      InkWell(
        onTap: onTrailingTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: trailingBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(trailingIcon, color: trailingColor, size: 18),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final emailVerified = profile['email_verified'] == true;
    final email = profile['email']?.toString() ?? '';
    final phone = profile['phone_primary']?.toString() ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          // ── Avatar + jina + badge ya nafasi ──
          Center(
            child: Column(children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent,
                  border: Border.all(color: _accentMuted, width: 6),
                ),
                alignment: Alignment.center,
                child: Text(_initials,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 14),
              Text(_name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _accentMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield_outlined, size: 16, color: _accent),
                  SizedBox(width: 6),
                  Text('Administrator',
                      style: TextStyle(
                          color: _accent, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Kadi ya Mawasiliano ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 0.6),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mawasiliano',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _contactRow(
                leadingIcon: Icons.email_outlined,
                leadingColor: _accent,
                leadingBg: _accentMuted,
                label: 'Barua pepe',
                value: email,
                statusBadge: emailVerified
                    ? const _AdminStatusBadge(
                        label: 'Imethibitishwa', color: _success, background: _successBg)
                    : null,
                trailingIcon: Icons.copy_outlined,
                trailingColor: _textSecondary,
                trailingBg: _surface1,
                onTrailingTap: () {
                  Clipboard.setData(ClipboardData(text: email));
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('Barua pepe imenakiliwa')));
                },
              ),
              const Divider(height: 26, color: _border),
              _contactRow(
                leadingIcon: Icons.call_outlined,
                leadingColor: _accent,
                leadingBg: _accentMuted,
                label: 'Namba ya simu',
                value: phone.isNotEmpty ? _fmtPhone(phone) : '—',
                trailingIcon: Icons.call,
                trailingColor: _accent,
                trailingBg: _accentMuted,
                onTrailingTap: () async {
                  final digits = phone.replaceAll(RegExp(r'\D'), '');
                  if (digits.isEmpty) return;
                  final ok = await launchUrl(Uri.parse('tel:+$digits'),
                      mode: LaunchMode.externalApplication);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('Imeshindikana kupiga simu.')));
                  }
                },
              ),
              if (_phoneAlt.isNotEmpty) ...[
                const Divider(height: 26, color: _border),
                _contactRow(
                  leadingIcon: Icons.chat_bubble_outline,
                  leadingColor: _success,
                  leadingBg: _successBg,
                  label: 'WhatsApp / Simu ya pili',
                  value: _fmtPhone(_phoneAlt),
                  trailingIcon: Icons.chat_bubble,
                  trailingColor: Colors.white,
                  trailingBg: _success,
                  onTrailingTap: () async {
                    final digits = _phoneAlt.replaceAll(RegExp(r'\D'), '');
                    var intl = digits.startsWith('0')
                        ? '255${digits.substring(1)}'
                        : (digits.startsWith('255') ? digits : digits);
                    final wa = Uri.parse('https://wa.me/$intl');
                    final ok = await launchUrl(wa, mode: LaunchMode.externalApplication);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Imeshindikana kufungua WhatsApp.')));
                    }
                  },
                ),
              ],
            ]),
          ),

          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.info_outline, size: 18, color: _textMuted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Barua pepe haiwezi kubadilishwa hapa — wasiliana na admin mwenza.',
                style: const TextStyle(fontSize: 13, color: _textMuted, height: 1.35),
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 60),
    ]);
  }
}

class _AdminStatusBadge extends StatelessWidget {
  const _AdminStatusBadge({required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── View: Regular User ────────────────────────────────────────────────────────
class _ViewUser extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ViewUser({required this.profile});
  @override
  Widget build(BuildContext context) {
    final cs = profile['current_station'] as Map? ?? {};
    final dests = profile['desired_destinations'] as List? ?? [];
    final subjects = profile['subjects'] as List? ?? [];
    final cat = profile['category'] ?? '';
    final sector = profile['employment_sector'] ?? '';
    final name = profile['full_name']?.toString() ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

      // Card 1: Identity
      _InfoCard(title: 'Utambulisho', rows: [
        _InfoRow('Jina Kamili', profile['full_name']),
        _InfoRow('Namba ya Simu', profile['phone_primary']),
        if ((profile['phone_alt'] ?? '').toString().isNotEmpty)
          _InfoRow('Namba ya Pili', profile['phone_alt']),
        _InfoRow('Idara', cat == 'health' ? 'Afya' : cat == 'education' ? 'Elimu' : cat),
        if (cat == 'health' && sector.toString().isNotEmpty)
          _InfoRow('Sehemu ya Ajira', sector == 'wizara_afya' ? 'Wizara ya Afya' : 'TAMISEMI'),
        _InfoRow('Kada', profile['cadre_display'] ?? profile['cadre_code'] ?? ''),
        if (subjects.isNotEmpty) _InfoRow('Masomo', subjects.join(', ')),
      ]),
      const SizedBox(height: 16),

      // Card 2: Station
      _InfoCard(title: 'Kituo cha Sasa', rows: [
        _InfoRow('Mkoa', cs['region_name']),
        _InfoRow('Wilaya', cs['district_name']),
        _InfoRow('Kituo', cs['facility_name'] ?? '(Hakuna)'),
      ]),
      const SizedBox(height: 16),

      // Card 3: Destinations
      _InfoCard(title: 'Ninataka Kwenda', children: [
        if (dests.isEmpty)
          const Text('Hakuna lengo', style: TextStyle(fontSize: 12, color: _kGrey500))
        else
          ...dests.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 20,
                  child: Text('${i + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kBlue)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['region_name'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _kGrey900)),
                  const SizedBox(height: 2),
                  Text(
                    '${d['district_name'] ?? 'Wilaya yoyote'}${d['facility_name'] != null ? ' • ${d['facility_name']}' : ''}',
                    style: const TextStyle(fontSize: 12, color: _kGrey500)),
                ])),
              ]),
            );
          }),
      ]),
      const SizedBox(height: 60),
    ]);
  }
}

// ── Edit: Admin ───────────────────────────────────────────────────────────────
// Design mpya: header ya avatar + badge, kadi ya "Taarifa za msingi"
// (jina, namba ya pili yenye +255 prefix, barua pepe imefungwa),
// na kitufe cha Hifadhi/Ghairi chini.
class _EditAdminProfile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final void Function(Map<String, dynamic>) onSaved;
  const _EditAdminProfile({required this.profile, required this.onSaved});
  @override
  State<_EditAdminProfile> createState() => _EditAdminProfileState();
}

class _EditAdminProfileState extends State<_EditAdminProfile> {
  late TextEditingController _nameCtrl, _altCtrl;
  bool _saving = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  static const _accent = Color(0xFF2A3EB1);
  static const _accentMuted = Color(0xFFEDEFFA);
  static const _success = Color(0xFF1E9E5A);
  static const _surface1 = Color(0xFFF5F6FA);
  static const _surface2 = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E6EE);
  static const _textPrimary = Color(0xFF1A1D29);
  static const _textSecondary = Color(0xFF5C6072);
  static const _textMuted = Color(0xFF9297A8);

  String get _name => widget.profile['full_name']?.toString() ?? '';
  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile['full_name'] ?? '');
    _altCtrl  = TextEditingController(text: _strip255(widget.profile['phone_alt']?.toString() ?? ''));
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _altCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_alt': _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
      });
      final res = await ApiService().getMyProfile();
      widget.onSaved(asMap(res.data));
    } catch (e) {
      setState(() { _saving = false; _error = _parseErr(e); });
    }
  }

  InputDecoration _inputDec(IconData? icon) => InputDecoration(
        prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _textMuted),
        filled: true,
        fillColor: _surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accent, width: 1.6)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border)),
      );

  @override
  Widget build(BuildContext context) {
    final email = widget.profile['email']?.toString() ?? '';

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null) _ErrBox(_error!),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header: avatar + jina + badge ──
            Row(children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _accent),
                alignment: Alignment.center,
                child: Text(_initials,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shield_outlined, size: 14, color: _accent),
                      SizedBox(width: 5),
                      Text('Administrator',
                          style: TextStyle(
                              color: _accent, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Taarifa za msingi ──
            const Text('Taarifa za msingi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),

            const Text('Jina kamili',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 15, color: _textPrimary),
              decoration: _inputDec(Icons.person_outline),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Weka jina kamili' : null,
            ),

            const SizedBox(height: 18),
            const Text('Namba ya simu (Pili / WhatsApp)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: const BoxDecoration(
                    color: _surface1,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                  child: const Text('+255',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textPrimary)),
                ),
                Container(width: 1, height: 24, color: _border),
                Expanded(
                  child: TextFormField(
                    controller: _altCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 15, color: _textPrimary),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    validator: (v) =>
                        (v != null && v.trim().isNotEmpty && v.trim().length < 9)
                            ? 'Namba si sahihi'
                            : null,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chat_bubble, color: _success, size: 20),
                ),
              ]),
            ),

            const SizedBox(height: 18),
            const Text('Barua pepe',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: _surface1,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.email_outlined, size: 20, color: _textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(email,
                      style: const TextStyle(fontSize: 15, color: _textMuted)),
                ),
                const Icon(Icons.lock_outline, size: 18, color: _textMuted),
              ]),
            ),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline, size: 16, color: _textMuted),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Barua pepe haiwezi kubadilishwa hapa — wasiliana na admin mwenza.',
                  style: TextStyle(fontSize: 12, color: _textMuted, height: 1.35),
                ),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 24),

        // ── Ghairi / Hifadhi chini (kama reference) ──
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                side: const BorderSide(color: _border),
                foregroundColor: _textPrimary,
              ),
              child: const Text('Ghairi', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 15, height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi mabadiliko',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 60),
      ]),
    );
  }
}

// ── Edit: Regular User ────────────────────────────────────────────────────────
class _EditProfile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final void Function(Map<String, dynamic>) onSaved;
  const _EditProfile({required this.profile, required this.onSaved});
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late TextEditingController _nameCtrl, _phoneCtrl, _altCtrl;

  String _cadreCode = '';
  List<dynamic> _cadres = [];
  List<dynamic> _availSubjects = [];
  List<String> _subjects = [];
  bool _loadingSubjects = false;

  int? _stationRegionId;
  int? _stationDistrictId;
  String? _stationFacilityId;
  List<dynamic> _regions = [];
  List<dynamic> _stationDistricts = [];
  List<dynamic> _stationFacilities = [];

  List<Map<String, dynamic>> _destinations = [];
  Map<int, List<dynamic>> _destDistricts = {};
  final Map<int, List<dynamic>> _destFacilities = {};

  bool _saving = false;
  String? _error;

  String get _category => widget.profile['category'] as String? ?? '';

  String? get _subjectLevel {
    if (_cadreCode.isEmpty || _cadres.isEmpty) return null;
    final cadre = _cadres.firstWhere((c) => c['code'] == _cadreCode, orElse: () => null);
    final level = cadre?['level'] as String? ?? '';
    if (level == 'Secondary') return 'Secondary';
    if (level == 'Primary') return 'Primary';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.profile['full_name'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile['phone_primary'] ?? '');
    _altCtrl   = TextEditingController(text: widget.profile['phone_alt'] ?? '');

    _cadreCode = widget.profile['cadre_code'] as String? ?? '';
    _subjects = (widget.profile['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];

    final cs = widget.profile['current_station'] as Map? ?? {};
    _stationRegionId = cs['region_id'] as int?;
    _stationDistrictId = cs['district_id'] as int?;
    _stationFacilityId = cs['facility_id']?.toString();

    _destinations = (widget.profile['desired_destinations'] as List? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();

    _loadInitialData();
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) return (data['items'] ?? data['results'] ?? []) as List;
    return [];
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        ApiService().getRegions().then((r) => r.data),
        ApiService().getCadres(category: _category).then((r) => r.data),
      ]);
      if (!mounted) return;
      setState(() {
        _regions = _asList(results[0]);
        _cadres = _asList(results[1]);
      });
    } catch (_) {}

    if (_subjectLevel != null) _loadSubjects(_subjectLevel!);

    if (_stationRegionId != null) {
      try {
        final r = await ApiService().getDistricts(_stationRegionId!);
        if (mounted) setState(() => _stationDistricts = _asList(r.data));
      } catch (_) {}
    }
    if (_stationDistrictId != null) {
      try {
        final r = await ApiService().getFacilities(_stationDistrictId!, category: _category);
        if (mounted) setState(() => _stationFacilities = _asList(r.data));
      } catch (_) {}
    }

    final destWithRegion = _destinations.where((d) => (d['region_id'] as int? ?? 0) > 0).toList();
    if (destWithRegion.isNotEmpty) {
      try {
        final pairs = await Future.wait(
          destWithRegion.map((d) => ApiService().getDistricts(d['region_id'] as int)
              .then((r) => MapEntry(d['region_id'] as int, _asList(r.data)))));
        if (mounted) setState(() => _destDistricts = Map.fromEntries(pairs));
      } catch (_) {}
    }
  }

  Future<void> _loadSubjects(String level) async {
    if (!mounted) return;
    setState(() { _loadingSubjects = true; _availSubjects = []; });
    try {
      final r = await ApiService().getSubjects(level: level);
      if (mounted) setState(() => _availSubjects = _asList(r.data));
    } catch (_) {}
    if (mounted) setState(() => _loadingSubjects = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _altCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final region = _regions.firstWhere((r) => r['id'] == _stationRegionId, orElse: () => null);
      final district = _stationDistricts.firstWhere((d) => d['id'] == _stationDistrictId, orElse: () => null);
      final facility = (_stationFacilityId?.isNotEmpty == true)
          ? _stationFacilities.firstWhere((f) => (f['id'] ?? f['code']).toString() == _stationFacilityId, orElse: () => null)
          : null;

      Map<String, dynamic>? station;
      if (region != null && district != null) {
        station = {
          'region_id': region['id'],
          'region_name': region['name'],
          'district_id': district['id'],
          'district_name': district['name'],
          'facility_id': facility != null ? (facility['id'] ?? facility['code']).toString() : null,
          'facility_name': facility?['name'],
        };
      }

      final dests = _destinations.map((d) {
        final rid = d['region_id'] as int? ?? 0;
        final did = d['district_id'] as int?;
        final distList = _destDistricts[rid] ?? [];
        final dd = did != null ? distList.firstWhere((x) => x['id'] == did, orElse: () => null) : null;
        return {
          'region_id': rid,
          'region_name': d['region_name'],
          'district_id': did,
          'district_name': dd?['name'] ?? d['district_name'],
          'facility_id': d['facility_id'],
          'facility_name': d['facility_name'],
        };
      }).where((d) => (d['region_id'] as int? ?? 0) > 0).toList();

      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_primary': _phoneCtrl.text.trim(),
        'phone_alt': _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
        'cadre_code': _cadreCode.isEmpty ? null : _cadreCode,
        'subjects': _subjects,
        'current_station': ?station,
        'desired_destinations': dests,
      });
      final res = await ApiService().getMyProfile();
      widget.onSaved(asMap(res.data));
    } catch (e) {
      setState(() { _saving = false; _error = _parseErr(e); });
    }
  }

  void _addDest() => setState(() => _destinations.add({
    'region_id': 0, 'region_name': '', 'district_id': null, 'district_name': null,
    'facility_id': null, 'facility_name': null,
  }));

  void _delDest(int i) => setState(() => _destinations.removeAt(i));

  void _updateDest(int i, Map<String, dynamic> patch) {
    setState(() => _destinations[i] = {..._destinations[i], ...patch});
    if (patch.containsKey('region_id')) {
      final rid = patch['region_id'] as int? ?? 0;
      if (rid > 0 && !_destDistricts.containsKey(rid)) {
        ApiService().getDistricts(rid).then((r) {
          if (mounted) setState(() => _destDistricts[rid] = _asList(r.data));
        }).catchError((_) {});
      }
    }
    if (patch.containsKey('district_id') && patch['district_id'] != null) {
      final did = patch['district_id'] as int;
      if (!_destFacilities.containsKey(did)) {
        ApiService().getFacilities(did, category: _category).then((r) {
          if (mounted) setState(() => _destFacilities[did] = _asList(r.data));
        }).catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) _ErrBox(_error!),

      // ── Card 1: Identity + Cadre + Subjects ──
      _InfoCard(title: 'Utambulisho', children: [
        // Jina
        _label('Jina Kamili'),
        TextField(controller: _nameCtrl, style: const TextStyle(fontSize: 12), decoration: _inputDec()),
        const SizedBox(height: 20),

        // Simu ya kawaida
        _label('Namba ya Simu (Normal)'),
        TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 12), decoration: _inputDec()),
        const SizedBox(height: 20),

        // WhatsApp
        _label('🟢 Namba ya WhatsApp *'),
        TextField(controller: _altCtrl, keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 12), decoration: _inputDec(hint: '0623456789')),

        // Kada
        if (_cadres.isNotEmpty) ...[
          const SizedBox(height: 20),
          _label('Kada'),
          _PickerField<String>(
            title: 'Chagua Kada',
            value: _cadres.any((c) => c['code'] == _cadreCode) ? _cadreCode : null,
            hint: '— Chagua Kada —',
            items: _cadres.map((c) => _PickItem<String>(
              value: c['code'] as String,
              label: (c['display_name'] ?? c['code'] ?? '').toString())).toList(),
            onChanged: (v) {
              setState(() { _cadreCode = v ?? ''; _subjects = []; _availSubjects = []; });
              if (_subjectLevel != null) _loadSubjects(_subjectLevel!);
            },
          ),
        ],

        // Masomo (kama kada ina level)
        if (_subjectLevel != null) ...[
          const SizedBox(height: 20),
          _label('Masomo (${_subjectLevel == 'Primary' ? 'Elimu ya Msingi' : 'Elimu ya Sekondari'})'),
          if (_loadingSubjects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kGrey500)),
                SizedBox(width: 8),
                Text('Inapakia...', style: TextStyle(fontSize: 14, color: _kGrey500)),
              ]),
            )
          else
            Wrap(spacing: 6, runSpacing: 6, children: _availSubjects.map((s) {
              final code = (s['code'] ?? s['name'] ?? '').toString();
              final name = (s['name'] ?? code).toString();
              final selected = _subjects.contains(code);
              return GestureDetector(
                onTap: () => setState(() => selected ? _subjects.remove(code) : _subjects.add(code)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? _kBlue : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? _kBlue : _kGrey300),
                  ),
                  child: Text(name, style: TextStyle(
                    fontSize: 12, // text-xs
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : _kGrey700,
                  )),
                ),
              );
            }).toList()),
        ],
      ]),
      const SizedBox(height: 16),

      // ── Card 2: Station ──
      _InfoCard(title: 'Kituo cha Sasa', children: [
        _label('Mkoa'),
        _PickerField<int>(
          title: 'Chagua Mkoa',
          value: _regions.any((r) => r['id'] == _stationRegionId) ? _stationRegionId : null,
          hint: '— Chagua Mkoa —',
          items: _regions.map((r) => _PickItem<int>(
            value: r['id'] as int,
            label: (r['name'] ?? '').toString())).toList(),
          onChanged: (v) {
            setState(() { _stationRegionId = v; _stationDistrictId = null; _stationFacilityId = null; _stationDistricts = []; _stationFacilities = []; });
            if (v != null) ApiService().getDistricts(v).then((r) { if (mounted) setState(() => _stationDistricts = _asList(r.data)); }).catchError((_) {});
          },
        ),
        const SizedBox(height: 20),

        _label('Wilaya'),
        _PickerField<int>(
          title: 'Chagua Wilaya',
          value: _stationDistricts.any((d) => d['id'] == _stationDistrictId) ? _stationDistrictId : null,
          hint: '— Chagua Wilaya —',
          items: _stationDistricts.map((d) => _PickItem<int>(
            value: d['id'] as int,
            label: (d['name'] ?? '').toString())).toList(),
          onChanged: (v) {
            setState(() { _stationDistrictId = v; _stationFacilityId = null; _stationFacilities = []; });
            if (v != null) ApiService().getFacilities(v, category: _category).then((r) { if (mounted) setState(() => _stationFacilities = _asList(r.data)); }).catchError((_) {});
          },
        ),
        const SizedBox(height: 20),

        _label(_category == 'health' ? 'Hospitali/Kituo (hiari)' : 'Shule (hiari)'),
        _PickerField<String>(
          title: _category == 'health' ? 'Chagua Hospitali/Kituo' : 'Chagua Shule',
          value: (_stationFacilityId?.isNotEmpty == true && _stationFacilities.any((f) => (f['id'] ?? f['code']).toString() == _stationFacilityId)) ? _stationFacilityId : null,
          hint: _category == 'health' ? 'Hospitali/Kituo chote cha wilaya hii' : 'Shule zote za wilaya hii',
          enabled: _stationDistrictId != null,
          items: _stationFacilities.map((f) {
            final id = (f['id'] ?? f['code']).toString();
            final name = f['name'] as String? ?? id;
            final type = f['type'] as String? ?? '';
            return _PickItem<String>(value: id, label: type.isNotEmpty ? '$name ($type)' : name);
          }).toList(),
          onChanged: _stationDistrictId == null ? null : (v) => setState(() => _stationFacilityId = v),
        ),
      ]),
      const SizedBox(height: 16),

      // ── Card 3: Destinations ──
      _InfoCard(
        title: 'Ninataka Kwenda',
        trailing: GestureDetector(
          onTap: _addDest,
          child: const Text('+ Ongeza', style: TextStyle(fontSize: 14, color: _kBlue)),
        ),
        children: [
          if (_destinations.isEmpty)
            const Text('Bonyeza "+ Ongeza" kuongeza eneo la lengo',
                style: TextStyle(fontSize: 12, color: _kGrey500))
          else
            for (int i = 0; i < _destinations.length; i++) _buildDestRow(i),
        ],
      ),
      const SizedBox(height: 16),

      // ── Save button ──
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kBlue,
              disabledForegroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _saving
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 8),
                    Text('Inatuma...', style: TextStyle(fontSize: 12)),
                  ])
                : const Text('Hifadhi Mabadiliko'),
          ),
        ],
      ),
      const SizedBox(height: 60),
    ]);
  }

  Widget _buildDestRow(int i) {
    final d = _destinations[i];
    final regionId = d['region_id'] as int? ?? 0;
    final districtId = d['district_id'] as int?;
    final facilityId = d['facility_id'] as String?;
    final districtList = _destDistricts[regionId] ?? [];
    final facilityList = districtId != null ? (_destFacilities[districtId] ?? []) : <dynamic>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Region select + delete button
        Row(children: [
          Expanded(
            child: _PickerField<int>(
              title: 'Chagua Mkoa wa Lengo',
              value: regionId == 0 ? null : (_regions.any((r) => r['id'] == regionId) ? regionId : null),
              hint: '— Chagua Mkoa —',
              items: _regions.map((r) => _PickItem<int>(
                value: r['id'] as int,
                label: (r['name'] ?? '').toString())).toList(),
              onChanged: (v) {
                if (v == null) return;
                final r = _regions.firstWhere((r) => r['id'] == v, orElse: () => null);
                _updateDest(i, {'region_id': v, 'region_name': r?['name'] ?? '', 'district_id': null, 'district_name': null, 'facility_id': null, 'facility_name': null});
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _delDest(i),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close_rounded, color: _kRed, size: 16),
            ),
          ),
        ]),

        // Wilaya select
        if (regionId > 0) ...[
          const SizedBox(height: 10),
          _PickerField<int>(
            title: 'Chagua Wilaya ya Lengo',
            value: districtId != null && districtList.any((x) => x['id'] == districtId) ? districtId : null,
            hint: 'Wilaya yoyote',
            items: districtList.map((x) => _PickItem<int>(
              value: x['id'] as int,
              label: (x['name'] ?? '').toString())).toList(),
            onChanged: (v) => _updateDest(i, {
              'district_id': v,
              'district_name': v != null ? (districtList.firstWhere((x) => x['id'] == v, orElse: () => null)?['name']) : null,
              'facility_id': null,
              'facility_name': null,
            }),
          ),
        ],

        // Facility select
        if (districtId != null && facilityList.isNotEmpty) ...[
          const SizedBox(height: 10),
          _PickerField<String>(
            title: _category == 'health' ? 'Chagua Hospitali/Kituo' : 'Chagua Shule',
            value: facilityId != null && facilityList.any((f) => (f['id'] ?? f['code']).toString() == facilityId) ? facilityId : null,
            hint: _category == 'health' ? 'Hospitali/Kituo chote' : 'Shule zote',
            items: facilityList.map((f) {
              final fid = (f['id'] ?? f['code']).toString();
              final fname = f['name'] as String? ?? fid;
              final ftype = f['type'] as String? ?? '';
              return _PickItem<String>(value: fid, label: ftype.isNotEmpty ? '$fname ($ftype)' : fname);
            }).toList(),
            onChanged: (v) {
              final fac = v != null ? facilityList.firstWhere((f) => (f['id'] ?? f['code']).toString() == v, orElse: () => null) : null;
              _updateDest(i, {'facility_id': v, 'facility_name': fac?['name']});
            },
          ),
        ],
      ]),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

// .card = bg-white rounded-2xl p-6 border-grey-100 shadow-soft
class _InfoCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget>? children;
  final List<_InfoRow>? rows;
  final Color? borderColor;
  const _InfoCard({required this.title, this.trailing, this.children, this.rows, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24), // p-6=24px
      decoration: _cardDec(borderColor: borderColor),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kGrey900))),
          ?trailing,
        ]),
        const SizedBox(height: 12),
        if (rows != null) ...rows!.where((r) {
          final v = r.value?.toString() ?? '';
          return v.isNotEmpty;
        })
        else ...?children,
      ]),
    );
  }
}

// Row: label=grey-500 text-sm=14, value=font-semibold(600) grey-900 text-sm, hakuna divider (kama web)
class _InfoRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final v = value?.toString() ?? '';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6), // py-0.5 kidogo
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 2,
          child: Text('$label:', style: const TextStyle(fontSize: 14, color: _kGrey500)),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(v,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey900)),
        ),
      ]),
    );
  }
}

// Error box: bg-red-50 text-brand-red text-sm rounded-lg p-3
class _ErrBox extends StatelessWidget {
  final String message;
  const _ErrBox(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: _kRed, fontSize: 14)),
    );
  }
}

// ── Custom bottom-sheet picker — replaces old DropdownButtonFormField ─────────

class _PickItem<T> {
  final T value;
  final String label;
  const _PickItem({required this.value, required this.label});
}

class _PickerField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final String title;
  final List<_PickItem<T>> items;
  final void Function(T?)? onChanged;
  final bool enabled;

  const _PickerField({
    required this.hint,
    required this.title,
    required this.items,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  String get _label {
    if (value == null) return '';
    try { return items.firstWhere((i) => i.value == value).label; } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final lbl = _label;
    final has = lbl.isNotEmpty;
    return GestureDetector(
      onTap: (enabled && onChanged != null) ? () => _open(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kGrey200),
        ),
        child: Row(children: [
          Expanded(child: Text(
            has ? lbl : hint,
            style: TextStyle(
              fontSize: 12,
              color: has ? _kGrey900 : _kGrey400,
              fontWeight: has ? FontWeight.w500 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          )),
          if (has && enabled && onChanged != null)
            GestureDetector(
              onTap: () => onChanged!(null),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close_rounded, size: 16, color: _kGrey400),
              ),
            )
          else
            Icon(Icons.keyboard_arrow_down_rounded, size: 20,
              color: enabled ? _kGrey500 : _kGrey300),
        ]),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet<T>(title: title, items: items, selected: value),
    );
    if (result != null) onChanged!(result);
  }
}

class _PickerSheet<T> extends StatefulWidget {
  final String title;
  final List<_PickItem<T>> items;
  final T? selected;
  const _PickerSheet({required this.title, required this.items, this.selected});
  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? widget.items
        : widget.items.where((i) => i.label.toLowerCase().contains(_q.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: _kGrey300, borderRadius: BorderRadius.circular(2)),
          ),
          // Title + close
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(children: [
              Expanded(child: Text(widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900))),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.close_rounded, size: 18, color: _kGrey700)),
                ),
              ),
            ]),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(fontSize: 14, color: _kGrey900),
              decoration: InputDecoration(
                hintText: 'Tafuta...',
                hintStyle: const TextStyle(color: _kGrey400, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kGrey400),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kGrey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kGrey200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              ),
            ),
          ),
          // Items list
          Expanded(
            child: ListView.builder(
              controller: sc,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                final sel = item.value == widget.selected;
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, item.value),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(item.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          color: sel ? _kBlue : _kGrey900,
                        ))),
                      if (sel) const Icon(Icons.check_rounded, size: 18, color: _kBlue),
                    ]),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ]),
      ),
    );
  }
}

String _parseErr(dynamic e) {
  try { final d = (e as dynamic).response?.data?['detail']; if (d is String) return d; } catch (_) {}
  return 'Imeshindikana';
}
