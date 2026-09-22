import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WATUMIAJI V2 — theme + shared widgets (Phosphor, kadi pana nyeupe)
// ═══════════════════════════════════════════════════════════════════════════
const v2Accent = Color(0xFF1E6FE0);
const v2AccentBg = Color(0xFFE6F1FB);
const v2Surface = Color(0xFFFFFFFF);
const v2SurfaceMuted = Color(0xFFF3F6FB);
const v2Border = Color(0xFFE3E7EE);
const v2TextPrimary = Color(0xFF1B1D22);
const v2TextSecondary = Color(0xFF6B6F76);
const v2TextMuted = Color(0xFF9A9EA6);
const v2Success = Color(0xFF0F6E56);
const v2SuccessBg = Color(0xFFE1F5EE);
const v2Danger = Color(0xFF9A2626);
const v2DangerBg = Color(0xFFFCEBEB);
const v2Warning = Color(0xFF8A5A0B);
const v2WarningBg = Color(0xFFFAEEDA);

// ═══════════════════════════════ helpers ═══════════════════════════════
/// "255712345678" -> "+255 712 345 678"
String v2FmtPhone(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('255')) {
    return '+255 ${d.substring(3, 6)} ${d.substring(6, 9)} ${d.substring(9)}';
  }
  return p.isEmpty ? '' : '+$d';
}

/// 1096 -> "1,096"
String v2FmtNum(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// "ZUHURA labia" -> "Zuhura Labia"
String v2TitleCase(String v) => v
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Fungua URL ya nje (tel:/wa.me) bila kutupa
Future<void> v2Launch(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ═══════════════════════════════ StatusBadge ═══════════════════════════════
class V2StatusBadge extends StatelessWidget {
  final bool active;
  const V2StatusBadge({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: active ? v2SuccessBg : v2DangerBg,
          borderRadius: BorderRadius.circular(20)),
      child: Text(active ? 'Hai' : 'Amesitishwa',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: active ? v2Success : v2Danger)),
    );
  }
}

// ═══════════════════════════════ IconChip ═══════════════════════════════
class V2IconChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  const V2IconChip({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.onTap,
    this.tooltip,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(size * 0.28);
    final button = InkWell(
      onTap: onTap,
      borderRadius: shape,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, borderRadius: shape),
        child: Icon(icon, size: size * 0.46, color: color),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

// ═══════════════════════════════ Kadi ya mtumiaji (pana, nyeupe) ═══════════
class V2UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String timeText;
  final bool isNewest;
  final bool isLast;
  final String deptName;
  final IconData deptIcon;
  final VoidCallback onDotsTap;

  const V2UserCard({
    super.key,
    required this.user,
    required this.timeText,
    required this.isNewest,
    required this.isLast,
    required this.deptName,
    required this.deptIcon,
    required this.onDotsTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone =
        user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final cadre =
        user['cadre_display'] as String? ?? user['cadre_code'] as String? ?? '';
    final station =
        user['current_station'] as Map? ?? user['station'] as Map? ?? {};
    final region = station['region_name'] as String? ?? '';
    final st = '${user['status'] ?? 'active'}'.toLowerCase();
    final isActive = st == 'active';
    final isPaid = (user['is_verified'] as bool?) ?? false;
    final isAdmin = user['is_admin'] as bool? ?? false;
    final init = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Opacity(
      opacity: isActive ? 1.0 : 0.68,
      child: Container(
        // ── Kadi NZIMA: no timeline column — full width, clean padding ──
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: v2Surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: v2Border, width: 0.7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Muda (juu, ndogo, kama prototype) ──
            if (timeText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Text(timeText,
                    style: const TextStyle(
                        fontSize: 10.5, color: v2TextMuted)),
              ),
            // ── Avatar + jina + simu + hali + dots ──
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      color: v2AccentBg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(init,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: v2Accent)),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: isActive ? v2Success : v2Danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v2TitleCase(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: v2TextPrimary)),
                    const SizedBox(height: 1),
                    Text(
                      phone.isNotEmpty ? v2FmtPhone(phone) : cadre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          color:
                              phone.isNotEmpty ? v2Accent : v2TextSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              V2StatusBadge(active: isActive),
              const SizedBox(width: 2),
              IconButton(
                onPressed: onDotsTap,
                icon: Icon(PhosphorIcons.dotsThreeVertical(), size: 17),
                color: v2TextMuted,
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const SizedBox(height: 7),
            // ── Chips: kada/idara/mkoa + malipo + admin ──
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (cadre.isNotEmpty)
                _tag(cadre, PhosphorIcons.bookOpen(), v2AccentBg, v2Accent),
              if (deptName.isNotEmpty)
                _tag(deptName, deptIcon, v2SurfaceMuted, v2TextSecondary),
              if (region.isNotEmpty)
                _tag(region, PhosphorIcons.mapPin(), v2SurfaceMuted,
                    v2TextSecondary),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isPaid ? v2SuccessBg : v2DangerBg,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(isPaid ? 'Amelipa' : 'Hajalipa',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isPaid ? v2Success : v2Danger)),
              ),
              if (isAdmin)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: v2AccentBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.shieldCheck(),
                        size: 11, color: v2Accent),
                    const SizedBox(width: 3),
                    const Text('Admin',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: v2Accent)),
                  ]),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, IconData icon, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: fg, fontSize: 10.5, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

// ═══════════════════════════════ Skeleton ═══════════════════════════════
class V2SkeletonCard extends StatelessWidget {
  const V2SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: v2SurfaceMuted, borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: v2Surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: v2Border, width: 0.7),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                  color: v2SurfaceMuted, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            bar(140, 12),
            const SizedBox(height: 8),
            bar(100, 10),
          ]),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          bar(70, 18),
          bar(90, 18),
          bar(60, 18),
          bar(80, 18),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════ Sheet: vitendo vya kadi ═════════════════════
enum V2Action { angalia, hariri, ruhusu, funga, futa }

Future<V2Action?> showV2CardActionsSheet(
    BuildContext context, Map<String, dynamic> user) {
  final name = user['full_name'] as String? ?? '';
  final isActive =
      '${user['status'] ?? 'active'}'.toLowerCase() == 'active';
  final contact = (user['contact_enabled'] as bool?) ?? false;
  final isPaid = (user['is_verified'] as bool?) ?? false;
  final phone = user['phone_primary'] as String? ?? '';
  final isAdmin = user['is_admin'] as bool? ?? false;

  return showModalBottomSheet<V2Action>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: v2Surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                      color: v2Border, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(v2TitleCase(name),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          _actionRow(ctx, PhosphorIcons.eye(), 'Angalia', v2TextSecondary,
              V2Action.angalia),
          _actionRow(ctx, PhosphorIcons.pencilSimple(), 'Hariri', v2Accent,
              V2Action.hariri),
          // Piga simu — inaonekana tu kama ana namba na amelipa
          if (phone.isNotEmpty && isPaid)
            ListTile(
              dense: true,
              leading:
                  Icon(PhosphorIcons.phoneCall(), size: 19, color: v2Success),
              title: Text('Piga simu (${v2FmtPhone(phone)})',
                  style:
                      const TextStyle(fontSize: 13.5, color: v2Success)),
              onTap: () {
                Navigator.pop(ctx);
                v2Launch('tel:+${phone.replaceAll(RegExp(r'\D'), '')}');
              },
            ),
          if (!isAdmin && !isPaid)
            _actionRow(
                ctx,
                PhosphorIcons.phoneCall(),
                contact ? 'Ondoa haki ya kupiga simu' : 'Ruhusu mawasiliano',
                v2Success,
                V2Action.ruhusu),
          if (!isAdmin)
            _actionRow(
                ctx,
                isActive ? PhosphorIcons.prohibit() : PhosphorIcons.checkCircle(),
                isActive ? 'Funga akaunti' : 'Fungua akaunti',
                v2Warning,
                V2Action.funga),
          _actionRow(ctx, PhosphorIcons.trash(), 'Futa', v2Danger,
              V2Action.futa,
              isLast: true),
        ],
      ),
    ),
  );
}

Widget _actionRow(BuildContext ctx, IconData icon, String label, Color color,
    V2Action action,
    {bool isLast = false}) {
  return InkWell(
    onTap: () => Navigator.of(ctx).pop(action),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        border:
            isLast ? null : const Border(bottom: BorderSide(color: v2Border)),
      ),
      child: Row(children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 13.5, color: color)),
      ]),
    ),
  );
}

// ═══════════════════════════════ Sheet: Ongeza (+) ═══════════════════════════
enum V2AddOption { mtumiajiMpya, ongezaAdmin, importWatumiaji }

Future<V2AddOption?> showV2AddOptionsSheet(BuildContext context) {
  return showModalBottomSheet<V2AddOption>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: v2Surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                      color: v2Border, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 16),
          const Text('Ongeza',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _addOption(ctx, PhosphorIcons.userPlus(), 'Mtumiaji Mpya',
              'Ongeza mwalimu, afisa afya au mtumishi', V2AddOption.mtumiajiMpya,
              filled: true),
          const SizedBox(height: 10),
          _addOption(ctx, PhosphorIcons.shieldCheck(), 'Ongeza Admin',
              'Anaingia kwa email, hana idara', V2AddOption.ongezaAdmin),
          const SizedBox(height: 10),
          _addOption(ctx, PhosphorIcons.microsoftExcelLogo(), 'Import Watumiaji',
              'Pakia wengi kwa mara moja (.xlsx)', V2AddOption.importWatumiaji),
        ],
      ),
    ),
  );
}

Widget _addOption(BuildContext ctx, IconData icon, String title,
    String subtitle, V2AddOption value,
    {bool filled = false}) {
  return InkWell(
    onTap: () => Navigator.of(ctx).pop(value),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration:
          BoxDecoration(color: v2SurfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: filled ? v2AccentBg : v2Surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 18, color: filled ? v2Accent : v2TextSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: v2TextMuted)),
            ],
          ),
        ),
      ]),
    ),
  );
}

// ═══════════════════════════════ Delete dialog ═══════════════════════════════
Future<bool> v2ConfirmDelete(BuildContext context,
    {required String jina, required String simu}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: v2DangerBg, borderRadius: BorderRadius.circular(12)),
                child:
                    Icon(PhosphorIcons.trash(), color: v2Danger, size: 22),
              ),
              const SizedBox(height: 14),
              Text('Futa "${v2TitleCase(jina)}"?',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  'Akaunti ya $simu itaondolewa kabisa kwenye mfumo. Hatua hii haiwezi kutenduliwa.',
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: v2TextSecondary,
                      height: 1.45)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: v2Border),
                        foregroundColor: v2TextSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Ghairi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: v2Danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Futa'),
                  ),
                ),
              ]),
            ]),
      ),
    ),
  );
  return ok == true;
}
