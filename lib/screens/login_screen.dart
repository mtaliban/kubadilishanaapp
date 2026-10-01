import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_toast.dart';
import 'admin_otp_step.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LoginScreen — translation 100% ya web LoginContent.tsx
//
// Web structure:
//   min-h-screen flex flex-col items-center justify-center px-4 py-10 relative
//     [absolute top-4 left-4] back button
//     [w-full max-w-md]
//       .card p-4:
//         [text-center mb-6] logo + h1 + p
//         form.space-y-3.5:
//           label + input(phone icon)
//           [if error] ErrorAlert (WifiOff|AlertCircle)
//           [if twoFA] green info box
//           [if !twoFA] btn-primary "Ingia" | [if twoFA] OTP input + X cancel
//         [mt-3] "Sahau namba yako?" link
//         [mt-4] register outlined button
//
// Colors (light mode):
//   --brand-blue:       #1E40AF   (btn bg, links, focus ring)
//   --brand-blue-700:   #1D4ED8   (btn hover)
//   --brand-grey-900:   #111827   (title)
//   --brand-grey-700:   #374151   (label)
//   --brand-grey-600:   #4B5563   (back button)
//   --brand-grey-500:   #6B7280   (subtitle, placeholder)
//   --brand-grey-400:   #9CA3AF   (icon, X)
//   --brand-grey-300:   #D1D5DB   (border)
//   --brand-grey-100:   #F3F4F6   (card border)
//   --brand-red:        #DC2626   (error text/icon)
//   --brand-red-50:     #FEF2F2   (error bg)
//   --brand-red-100:    #FEE2E2   (error border)
//   green-50:           #F0FDF4   (2FA bg)
//   green-200:          #BBF7D0   (2FA border)
//   green-500:          #22C55E   (2FA icon)
//   green-700:          #15803D   (2FA text)
//
// Sizes (web):
//   .btn-primary: rounded-md(6px) px-3(12px) py-1(4px) text-[11px] font-bold → h≈28px
//   .input: rounded-md(6px) border-grey-300 px-2.5(10px) py-1.5(6px) text-xs(12px)
//   .label: text-sm(14px) font-semibold text-grey-700 mb-1.5(6px)
//   .card: bg-white rounded-2xl(16px) shadow border-grey-100 p-4(16px) mobile
//   space-y-3.5: 14px gap between form elements
// ══════════════════════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _twoFAEmail;
  bool _otpLoading = false;
  String? _error;
  bool _errorIsNetwork = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Submit — phone au email login ──
  Future<void> _submit() async {
    final val = _identifierCtrl.text.trim();
    if (val.isEmpty) return;
    final auth = context.read<AuthProvider>();
    setState(() { _error = null; _errorIsNetwork = false; });

    final ok = await auth.login(val);
    if (!mounted) return;

    if (auth.otpRequired || auth.pendingAdminEmail != null) {
      // 2FA — OTP box inaonekana (kwa sasa: admin email tu).
      setState(() { _twoFAEmail = auth.pendingAdminEmail; _otpCtrl.clear(); });
    } else if (ok) {
      Navigator.pushReplacementNamed(context, auth.isAdmin ? '/admin' : '/dashboard');
    } else if (auth.error != null) {
      setState(() { _error = auth.error!; _errorIsNetwork = auth.errorIsNetwork; });
    }
  }

  // ── Auto-submit OTP — mtu akiweka tarakimu 6 ──
  Future<void> _submitOtp(String code) async {
    if (code.length != 6 || _otpLoading) return;
    setState(() { _otpLoading = true; _error = null; _errorIsNetwork = false; });
    final auth = context.read<AuthProvider>();
    // 2FA ya ADMIN (email) pekee — users wanaingia kwa namba moja kwa moja.
    final identifier = _twoFAEmail;
    if (identifier == null) {
      setState(() => _otpLoading = false);
      return;
    }
    // Admin pekee — 2FA ya email.
    final ok = await auth.adminLoginOtp(identifier, code);
    if (mounted) {
      setState(() => _otpLoading = false);
      if (ok) {
        Navigator.pushReplacementNamed(context, auth.isAdmin ? '/admin' : '/dashboard');
      } else if (auth.error != null) {
        setState(() { _error = auth.error!; _errorIsNetwork = auth.errorIsNetwork; });
      }
    }
  }

  // ── Cancel OTP — X button, rudi kwenye "Ingia" ──
  void _cancelOtp() {
    final auth = context.read<AuthProvider>();
    setState(() { _twoFAEmail = null; _otpCtrl.clear(); _error = null; _errorIsNetwork = false; });
    auth.pendingAdminEmail = null;
    auth.pendingOtpPhone = null;
  }

  // ── Tuma tena code ya 2FA (admin email) ──
  Future<void> _resendOtp() async {
    final auth = context.read<AuthProvider>();
    final email = _twoFAEmail;
    if (email == null || _otpLoading) return;
    setState(() { _error = null; _errorIsNetwork = false; });
    await auth.login(email);
  }

  // ── AdminOtpStep callbacks ──
  Future<String?> _verifyAdminOtp(String code) async {
    final auth = context.read<AuthProvider>();
    final email = _twoFAEmail;
    if (email == null) return 'Hitilafu ya ndani';
    final ok = await auth.adminLoginOtp(email, code);
    if (!mounted) return 'Hitilafu ya ndani';
    if (ok) {
      Navigator.pushReplacementNamed(context, auth.isAdmin ? '/admin' : '/dashboard');
      return null;
    }
    return auth.error ?? 'Code si sahihi';
  }

  Future<String?> _resendAdminOtp() async {
    final auth = context.read<AuthProvider>();
    final email = _twoFAEmail;
    if (email == null) return 'Hitilafu ya ndani';
    await auth.login(email);
    if (!mounted) return 'Hitilafu ya ndani';
    if (auth.error != null) return auth.error;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loading = auth.loading || _otpLoading;
    final isAdminEmail = _identifierCtrl.text.contains('@');

    return ToastHost(
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [

            // ── Main content — flex flex-col items-center justify-center px-4 py-10 ──
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40), // py-10
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Card — .card p-4, bg-white rounded-2xl shadow border-grey-100 ──
                    // max-w-md (448px) kama web — kwenye simu kubwa/tablet inabaki
                    // center na haistanuki yote ya screen.
                    Container(
                      width: MediaQuery.of(context).size.width.clamp(0, 448).toDouble(),
                      padding: const EdgeInsets.all(16), // p-4
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16), // rounded-2xl
                        border: Border.all(color: const Color(0xFFF3F4F6)), // border-brand-grey-100
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000), // shadow-soft: rgba(0,0,0,0.06)
                            blurRadius: 20, // shadow-soft blur = 20px
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // ── Logo (inabaki daima juu ya kadi) ──
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4)),
                                  BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/logo.jpeg',
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                          // ══════════════════════════════════════════════════════
                          // HALI YA ADMIN OTP — AdminOtpStep inachukua nafasi yote
                          // chini ya logo (inabeba kichwa, barua pepe, visanduku 6,
                          // na vitufe vya Rudi/Ingia yenyewe).
                          // ══════════════════════════════════════════════════════
                          if (_twoFAEmail != null) ...[
                            const SizedBox(height: 16),
                            AdminOtpStep(
                              email: _twoFAEmail!,
                              onVerify: _verifyAdminOtp,
                              onResend: _resendAdminOtp,
                              onChangeEmail: _cancelOtp,
                              onBack: _cancelOtp,
                            ),
                          ] else ...[

                            // ── Karibu Tena (inaonekana kwenye hali ya kawaida tu) ──
                            const SizedBox(height: 16),
                            const Text(
                              'Karibu Tena',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ingia kwenye akaunti yako.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ════════ FORM ════════

                            Text(
                              isAdminEmail ? 'Email ya Admin' : 'Namba ya Simu',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),

                            TextField(
                              controller: _identifierCtrl,
                              keyboardType: TextInputType.text,
                              autocorrect: false,
                              enabled: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF111827),
                              ),
                              onChanged: (_) => setState(() {}),
                              contextMenuBuilder: (ctx, state) =>
                                  AdaptiveTextSelectionToolbar.buttonItems(
                                anchors: state.contextMenuAnchors,
                                buttonItems: state.contextMenuButtonItems,
                              ),
                              decoration: InputDecoration(
                                hintText: isAdminEmail ? 'admin@kubadilishana.go.tz' : '0712345678',
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 12, right: 8),
                                  child: Icon(
                                    isAdminEmail ? TablerIcons.mail : TablerIcons.phone,
                                    size: 20, color: const Color(0xFF1B4F9C)),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFEE2E2)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        _errorIsNetwork ? PhosphorIcons.wifiSlash() : PhosphorIcons.warningCircle(),
                                        size: 16,
                                        color: const Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFDC2626),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // ── Ingia button ──
                            SizedBox(
                              width: double.infinity,
                              height: 34,
                              child: ElevatedButton(
                                onPressed: loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E40AF),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF1E40AF),
                                  disabledForegroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  elevation: 0,
                                ),
                                child: loading
                                    ? const SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(TablerIcons.login, size: 20, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Ingia'),
                                      ]),
                              ),
                            ),

                            // ── Sahau namba + Jisajili — zinaficha kwa admin ──
                            if (!isAdminEmail) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: GestureDetector(
                                  onTap: () async {
                                    final phone = await Navigator.pushNamed(context, '/forgot-number');
                                    if (phone is String && phone.isNotEmpty && mounted) {
                                      _identifierCtrl.text = phone;
                                    }
                                  },
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(TablerIcons.help_circle, size: 18, color: Color(0xFF1E40AF)),
                                    SizedBox(width: 5),
                                    Text(
                                      'Sahau namba yako?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF1E40AF),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 28,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pushNamed(context, '/register'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: const Color(0xFF1E40AF),
                                    side: BorderSide(
                                      color: const Color(0xFF1E40AF).withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(TablerIcons.user_plus, size: 18, color: Color(0xFF1E40AF)),
                                    SizedBox(width: 6),
                                    Text('Jisajili sasa'),
                                  ]),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Back button removed — app hana previous page ya kurudi kwenye login

          ],
        ),
      ),
    ));
  }
}
