import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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

    if (auth.pendingAdminEmail != null) {
      // Admin 2FA — button inabadilika kuwa OTP input
      setState(() => _twoFAEmail = auth.pendingAdminEmail);
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
    final ok = await auth.adminLoginOtp(_twoFAEmail!, code);
    if (mounted) {
      setState(() => _otpLoading = false);
      if (ok) {
        Navigator.pushReplacementNamed(context, '/admin');
      } else if (auth.error != null) {
        setState(() { _error = auth.error!; _errorIsNetwork = auth.errorIsNetwork; });
      }
    }
  }

  // ── Cancel OTP — X button, rudi kwenye "Ingia" ──
  void _cancelOtp() {
    setState(() { _twoFAEmail = null; _otpCtrl.clear(); _error = null; _errorIsNetwork = false; });
    context.read<AuthProvider>().pendingAdminEmail = null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loading = auth.loading || _otpLoading;
    final isAdminEmail = _identifierCtrl.text.contains('@');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // body bg-grey-50
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
                    Container(
                      width: double.infinity,
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

                          // ── text-center mb-6 — logo + title + subtitle ──
                          Column(
                            children: [
                              // img: h-20=80px rounded-xl=12px shadow-md mx-auto mb-4
                              Container(
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
                                    height: 80, // h-20
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16), // mb-4

                              // h1: text-2xl=24px font-bold text-brand-grey-900=#111827
                              const Text(
                                'Karibu Tena',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827), // text-brand-grey-900
                                ),
                              ),
                              const SizedBox(height: 4), // mt-1

                              // p: text-sm=14px text-brand-grey-500=#6B7280
                              const Text(
                                'Ingia kwenye akaunti yako.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280), // text-brand-grey-500
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24), // mb-6

                          // ════════ FORM — space-y-3.5 (14px kati ya kila element) ════════

                          // ── label — .label = text-sm font-semibold text-brand-grey-700 mb-1.5 ──
                          Text(
                            isAdminEmail ? 'Email ya Admin' : 'Namba ya Simu',
                            style: const TextStyle(
                              fontSize: 14, // text-sm
                              fontWeight: FontWeight.w600, // font-semibold
                              color: Color(0xFF374151), // text-brand-grey-700
                            ),
                          ),
                          const SizedBox(height: 6), // mb-1.5

                          // ── input.pl-9 — .input rounded-md border-grey-300 py-1.5 text-xs ──
                          // Disabled wakati wa 2FA (kama web: disabled={!!twoFA})
                          TextField(
                            controller: _identifierCtrl,
                            keyboardType: TextInputType.text, // type="text" → '@' inawezekana
                            autocorrect: false,
                            enabled: _twoFAEmail == null,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _twoFAEmail == null ? _submit() : null,
                            style: const TextStyle(
                              fontSize: 12, // text-xs
                              color: Color(0xFF111827), // text-brand-grey-900
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: isAdminEmail ? 'admin@kubadilishana.go.tz' : '0712345678',
                              hintStyle: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280), // placeholder-brand-grey-500
                              ),
                              // Phone icon — left-3=12px from left, size=16, text-grey-400
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 8),
                                child: Icon(Icons.phone, size: 16, color: Color(0xFF9CA3AF)),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                              // .input borders
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Color(0xFFD1D5DB)), // border-brand-grey-300
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2), // focus:ring-brand-blue
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              filled: true,
                              fillColor: Colors.white, // bg-white
                              isDense: true,
                              // Web: pl-9(36px) = prefixIcon(left12+icon16+right8=36) + contentLeft(0)
                              // Flutter: prefixIcon=36px → contentPadding.left=0 ili text ianze 36px kama web
                              contentPadding: const EdgeInsets.only(top: 6, bottom: 6, right: 10), // py-1.5, pr-2.5
                            ),
                          ),
                          const SizedBox(height: 14), // space-y-3.5

                          // ── ErrorAlert — flex items-start gap-2.5 bg-red-50 border-red-100
                          //                text-red text-xs font-medium rounded-xl p-3
                          //                Icon: WifiOff (network) | AlertCircle (validation) ──
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12), // p-3
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2), // bg-brand-red-50
                                borderRadius: BorderRadius.circular(12), // rounded-xl
                                border: Border.all(color: const Color(0xFFFEE2E2)), // border-brand-red-100
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2), // mt-0.5 = 2px
                                    child: Icon(
                                      _errorIsNetwork ? Icons.wifi_off : Icons.error_outline,
                                      size: 16, // size={16}
                                      color: const Color(0xFFDC2626), // text-brand-red
                                    ),
                                  ),
                                  const SizedBox(width: 10), // gap-2.5
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        fontSize: 12, // text-xs
                                        fontWeight: FontWeight.w500, // font-medium
                                        color: Color(0xFFDC2626), // text-brand-red
                                        height: 1.5, // leading-relaxed
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14), // space-y-3.5
                          ],

                          // ── 2FA green box — flex items-center gap-2 bg-green-50 text-green-700
                          //                   text-xs font-semibold rounded-xl px-3 py-2 border-green-200
                          //                   AlertCircle(14) text-green-500 + bold email ──
                          if (_twoFAEmail != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // px-3 py-2
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4), // bg-green-50
                                borderRadius: BorderRadius.circular(12), // rounded-xl
                                border: Border.all(color: const Color(0xFFBBF7D0)), // border-green-200
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, size: 14, color: Color(0xFF22C55E)), // AlertCircle text-green-500
                                  const SizedBox(width: 8), // gap-2
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          fontSize: 12, // text-xs
                                          fontWeight: FontWeight.w600, // font-semibold
                                          color: Color(0xFF15803D), // text-green-700
                                        ),
                                        children: [
                                          const TextSpan(text: 'Code ya tarakimu 6 imetumwa kwa '),
                                          TextSpan(
                                            text: _twoFAEmail,
                                            style: const TextStyle(fontWeight: FontWeight.bold), // <strong>
                                          ),
                                          const TextSpan(text: ' — angalia email yako'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14), // space-y-3.5
                          ],

                          // ═══════════════════════════════════════════════════════
                          // SEHEMU MOJA: btn-primary "Ingia" AU OTP input — pale pale
                          // Kama web: {!twoFA ? <button> : <div class="relative">input+X+spinner</div>}
                          // ═══════════════════════════════════════════════════════
                          if (_twoFAEmail == null)
                            // ── btn-primary w-full — bg-brand-blue rounded-md px-3 py-1 text-[11px] font-bold ──
                            SizedBox(
                              width: double.infinity,
                              height: 28, // py-1(4px)+text-[11px](line-height 1rem=16px)+py-1(4px)=28px
                              child: ElevatedButton(
                                onPressed: loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E40AF), // bg-brand-blue
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF1E40AF).withValues(alpha: 0.5), // disabled:opacity-50
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12), // py-1 px-3
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), // rounded-md
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), // text-[11px] font-bold
                                  elevation: 0,
                                ),
                                child: loading
                                    // spinner + "Inaingia..." — flex items-center justify-center gap-2
                                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                                        SizedBox(width: 20, height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                        SizedBox(width: 8), // gap-2
                                        Text('Inaingia...'),
                                      ])
                                    : const Text('Ingia'),
                              ),
                            )
                          else
                            // ── OTP — div.relative: input text-center text-xl tracking-[0.5em] font-mono pr-10
                            //         X button: absolute right-2.5 top-1/2 (NDANI ya input → suffixIcon)
                            //         Spinner: absolute centered (pointer-events-none overlay) ──
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                TextField(
                                  controller: _otpCtrl,
                                  keyboardType: TextInputType.number,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  autofocus: true,
                                  enabled: !_otpLoading,
                                  style: const TextStyle(
                                    fontSize: 20, // text-xl
                                    letterSpacing: 10, // tracking-[0.5em] (0.5 × 20px = 10px)
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace', // font-mono
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '000000',
                                    counterText: '',
                                    hintStyle: const TextStyle(
                                      fontSize: 20, letterSpacing: 10,
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    // pr-10 (40px right) — nafasi ya X button ndani
                                    contentPadding: const EdgeInsets.only(top: 10, bottom: 10, left: 12, right: 40),
                                    // X button — absolute right-2.5 top-1/2 (kama web) → suffixIcon
                                    suffixIcon: GestureDetector(
                                      onTap: _cancelOtp,
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 10), // right-2.5 = 10px
                                        child: Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                                      ),
                                    ),
                                    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                  ),
                                  onChanged: (v) {
                                    final code = v.replaceAll(RegExp(r'\D'), '');
                                    // Auto-submit mara 6 tarakimu — kama web onTwoFAChange
                                    if (code.length == 6) _submitOtp(code);
                                  },
                                ),
                                // Spinner — absolute centered, pointer-events-none kama web
                                // Web: hakuna overlay, spinner tu katikati (pointer-events-none)
                                if (_otpLoading)
                                  const IgnorePointer(
                                    child: Center(
                                      child: SizedBox(width: 20, height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E40AF))),
                                    ),
                                  ),
                              ],
                            ),

                          // ── "Sahau namba yako?" — NDANI ya card, mt-3, text-center text-xs text-grey-500 ──
                          const SizedBox(height: 12), // mt-3
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/forgot-password'),
                              child: const Text(
                                'Sahau namba yako?',
                                style: TextStyle(
                                  fontSize: 12, // text-xs
                                  color: Color(0xFF1E40AF), // text-brand-blue hover:underline
                                  fontWeight: FontWeight.w500, // font-medium
                                ),
                              ),
                            ),
                          ),

                          // ── Register button — NDANI ya card, mt-4
                          // Style: btn-primary transparent bg, color=brand-blue, border=2px brand-blue/0.3 ──
                          const SizedBox(height: 16), // mt-4
                          SizedBox(
                            width: double.infinity,
                            height: 28, // same height as btn-primary: py-1+text+py-1=28px
                            child: OutlinedButton(
                              onPressed: () => Navigator.pushNamed(context, '/register'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: const Color(0xFF1E40AF), // color: brand-blue
                                side: BorderSide(
                                  color: const Color(0xFF1E40AF).withValues(alpha: 0.3), // 2px solid brand-blue/0.3
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), // rounded-md
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Jisajili sasa'),
                            ),
                          ),
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
    );
  }
}
