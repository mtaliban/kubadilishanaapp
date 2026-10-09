import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const Color _blue = Color(0xFF1E40AF);
const Color _text = Color(0xFF111827);
const Color _hint = Color(0xFF9CA3AF);
const Color _fieldBorder = Color(0xFFDDDCF3);

/// Sehemu ya chini ya skrini ya kuingia:
/// kuanzia "Namba ya Simu" kushuka chini
/// (sehemu ya namba, kitufe cha Ingia, Sahau namba?, Jisajili sasa).
/// Nembo, "Karibu Tena" na maelezo ya juu hayamo humu.
class LoginFormSection extends StatelessWidget {
  const LoginFormSection({
    super.key,
    required this.phoneController,
    required this.onLogin,
    required this.onForgot,
    required this.onRegister,
    this.isLoading = false,
  });

  final TextEditingController phoneController;
  final VoidCallback onLogin;
  final VoidCallback onForgot;
  final VoidCallback onRegister;
  final bool isLoading;

  // Badilisha hapa kupunguza au kuongeza unene
  static const double fieldHeight = 32;
  static const double buttonHeight = 32;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Namba ya Simu',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _text,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: fieldHeight,
          child: TextField(
            controller: phoneController,
            // Keyboard ya MANENO (si namba tu) — wanaojulikana kwenye field
            // hii wanaweza kuingia email (admins). Namba ndizo kawaida, lakini
            // admin anaweza kuandika email yake hapa hapa; login inajua kutofautisha.
            keyboardType: TextInputType.text,
            style: const TextStyle(fontSize: 13, color: _text),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0712345678 / email yako',
              hintStyle: const TextStyle(fontSize: 13, color: _hint),
              prefixIcon: const PhosphorIcon(
                PhosphorIconsRegular.phone,
                size: 16,
                color: _blue,
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 34, minHeight: fieldHeight),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _blue, width: 1.2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onLogin,
            icon: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login, size: 16),
            label: const Text('Ingia'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.zero,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flexible — fonti kubwa (au Ahem ya tests) isivuruge Row hii
            // kwenye skrini ndogo (overflow guard, kama kwenye LoginScreen ya zamani).
            Flexible(
              child: _LinkButton(
                icon: PhosphorIconsRegular.key,
                label: 'Sahau namba?',
                onTap: onForgot,
              ),
            ),
            Flexible(
              child: _LinkButton(
                icon: PhosphorIconsRegular.userPlus,
                label: 'Jisajili sasa',
                onTap: onRegister,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _blue),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
