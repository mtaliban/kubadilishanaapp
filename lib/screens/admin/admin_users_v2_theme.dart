import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WATUMIAJI V2 — theme + shared widgets (Phosphor, kadi pana nyeupe)
// ═══════════════════════════════════════════════════════════════════════════
const v2Accent = Color(0xFF1E6FE0);
const v2AccentBg = Color(0xFFE6F1FB);
const v2Surface = Color(0xFFFFFFFF);
const v2SurfaceMuted = Color(0xFFF6F6F3); // neutral grey — siyo bluu
const v2Border = Color(0xFFE8E7E3); // neutral border
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

String v2Initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ═══════════════════════════════ StatusBadge ═══════════════════════════════
class V2StatusBadge extends StatelessWidget {
  final bool active;
  const V2StatusBadge({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: active ? v2SuccessBg : v2DangerBg,
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: active ? v2Success : v2Danger, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(active ? 'Hai' : 'Amesitishwa',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? v2Success : v2Danger)),
      ]),
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
    final district = station['district_name'] as String? ?? '';
    final st = '${user['status'] ?? 'active'}'.toLowerCase();
    final isActive = st == 'active';
    final isPaid = (user['is_verified'] as bool?) ?? false;
    final isAdmin = user['is_admin'] as bool? ?? false;
    final initials = v2Initials(name);

    final rawDests =
        ((user['desired_destinations'] ?? user['destinations']) as List?) ?? [];
    final dests = rawDests
        .where((d) => d is Map)
        .map((d) {
          final m = d as Map;
          final dn = m['district_name']?.toString() ?? '';
          final rn =
              m['region_name']?.toString() ?? m['region']?.toString() ?? '';
          return dn.isNotEmpty ? '$dn, $rn' : rn;
        })
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: v2Surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: v2Border, width: 0.8),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER: avatar (2 herufi + dot kubwa) + jina + simu clickable + dots ──
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                      color: v2AccentBg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: v2Accent)),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isActive ? v2Success : v2Danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v2TitleCase(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            color: v2TextPrimary)),
                    const SizedBox(height: 3),
                    if (phone.isNotEmpty)
                      GestureDetector(
                        onTap: () => v2Launch(
                            'tel:+${phone.replaceAll(RegExp(r'\D'), '')}'),
                        child: Row(children: [
                          Icon(PhosphorIcons.phone(),
                              size: 12, color: v2Accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(v2FmtPhone(phone),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: v2Accent,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      )
                    else if (cadre.isNotEmpty)
                      Text(cadre,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: v2TextSecondary,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDotsTap,
                icon: Icon(PhosphorIcons.dotsThreeVertical(), size: 18),
                color: v2TextMuted,
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const SizedBox(height: 13),

            // ── BOX: IDARA | ANATOKA ──
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: v2SurfaceMuted,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('IDARA',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                                color: v2TextMuted)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(deptIcon, size: 14, color: v2Accent),
                          const SizedBox(width: 5),
                          Flexible(
                              child: Text(
                            deptName.isEmpty ? '—' : deptName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: v2TextPrimary),
                          )),
                        ]),
                      ]),
                ),
                Container(
                    width: 1,
                    height: 34,
                    color: v2Border,
                    margin: const EdgeInsets.symmetric(horizontal: 12)),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ANATOKA',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                                color: v2TextMuted)),
                        const SizedBox(height: 4),
                        Text(
                          region.isEmpty ? '—' : region,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: v2TextPrimary),
                        ),
                        if (district.isNotEmpty)
                          Text(district,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: v2TextSecondary)),
                      ]),
                ),
              ]),
            ),

            // ── ANAELEKEA (destinations, kama zipo) ──
            if (dests.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text('ANAELEKEA',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .5,
                          color: v2TextMuted)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(spacing: 5, runSpacing: 4, children: [
                    for (final d in dests)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: v2AccentBg,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.flag(PhosphorIconsStyle.fill),
                              size: 10, color: v2Accent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(d,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: v2Accent),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ]),
            ],
            const SizedBox(height: 11),

            // ── CHIPS: hali + kada + malipo + admin ──
            Wrap(spacing: 7, runSpacing: 7, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isActive ? v2SuccessBg : v2DangerBg,
                    borderRadius: BorderRadius.circular(9)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: isActive ? v2Success : v2Danger,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(isActive ? 'Hai' : 'Amesitishwa',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive ? v2Success : v2Danger)),
                ]),
              ),
              if (cadre.isNotEmpty)
                _tag(cadre, PhosphorIcons.bookOpen(), v2AccentBg, v2Accent),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isPaid ? v2SuccessBg : v2DangerBg,
                    borderRadius: BorderRadius.circular(9)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      isPaid
                          ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                          : PhosphorIcons.warningCircle(
                              PhosphorIconsStyle.fill),
                      size: 12,
                      color: isPaid ? v2Success : v2Danger),
                  const SizedBox(width: 4),
                  Text(isPaid ? 'Amelipa' : 'Hajalipa',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPaid ? v2Success : v2Danger)),
                ]),
              ),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: v2Accent,
                      borderRadius: BorderRadius.circular(9)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    const Text('Admin',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                ),
            ]),

            // ── STRIP YA TAHADHARI (hajalipa) ──
            if (!isPaid) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: v2WarningBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(PhosphorIcons.warning(PhosphorIconsStyle.fill),
                      size: 13, color: v2Warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Hajalipa — Haoni namba za wengine',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: v2Warning),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, IconData icon, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: fg, fontSize: 11, fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: v2Surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: v2Border, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                  color: v2SurfaceMuted, shape: BoxShape.circle)),
          const SizedBox(width: 13),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            bar(150, 14),
            const SizedBox(height: 9),
            bar(110, 11),
          ]),
          const Spacer(),
          bar(70, 22),
        ]),
        const SizedBox(height: 13),
        Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
              color: v2SurfaceMuted, borderRadius: BorderRadius.circular(13)),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: [
          bar(80, 22),
          bar(90, 22),
          bar(70, 22),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
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
          const SizedBox(height: 18),
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: v2AccentBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(PhosphorIcons.plus(), size: 17, color: v2Accent),
            ),
            const SizedBox(width: 10),
            const Text('Ongeza',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          _addOption(ctx, PhosphorIcons.userPlus(), 'Mtumiaji Mpya',
              'Mwalimu, afisa afya au mtumishi mwingine',
              V2AddOption.mtumiajiMpya, v2AccentBg, v2Accent),
          const SizedBox(height: 8),
          _addOption(ctx, PhosphorIcons.shieldCheck(), 'Ongeza Admin',
              'Anaingia kwa email, hana idara', V2AddOption.ongezaAdmin,
              const Color(0xFFF3E8FF), const Color(0xFF7C3AED)),
          const SizedBox(height: 8),
          _addOption(ctx, PhosphorIcons.microsoftExcelLogo(), 'Import Watumiaji',
              'Pakia wengi kwa mara moja (.xlsx)',
              V2AddOption.importWatumiaji, v2SuccessBg, v2Success),
        ],
      ),
    ),
  );
}

Widget _addOption(BuildContext ctx, IconData icon, String title, String subtitle,
    V2AddOption value, Color iconBg, Color iconColor) {
  return InkWell(
    onTap: () => Navigator.of(ctx).pop(value),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: v2Surface,
          border: Border.all(color: v2Border, width: 0.8),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11.5, color: v2TextMuted)),
            ],
          ),
        ),
        Icon(PhosphorIcons.caretRight(), size: 14, color: v2TextMuted),
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
