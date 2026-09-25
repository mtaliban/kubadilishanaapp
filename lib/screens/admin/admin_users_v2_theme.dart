import 'dart:math' as math;

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

// ═══════════════════════════════ Kadi ya mtumiaji — TICKET DESIGN ═══════════
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

  // ── Namba: "0778259957" -> "0778 259 957" ──
  static String _fmtLocal(String p) {
    final d = p.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10) {
      return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
    }
    if (d.length == 12 && d.startsWith('255')) {
      return '0${d.substring(3, 6)} ${d.substring(6, 9)} ${d.substring(9)}';
    }
    return p;
  }

  static Future<void> _launchWa(String phone) async {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = '255${d.substring(1)}';
    await v2Launch('https://wa.me/$d');
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = Theme.of(context).scaffoldBackgroundColor;

    final name = user['full_name'] as String? ?? '';
    final phone =
        user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final whatsapp = user['phone_alt'] as String? ?? '';
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

    // Rangi kulingana na idara
    final cat = '${user['category'] ?? ''}'.toLowerCase();
    final isHealth = cat == 'health';
    final tone = isHealth ? v2Success : v2Accent;
    final toneBg = isHealth ? v2SuccessBg : v2AccentBg;

    // Maeneo anayotaka kwenda
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

    final firstDest =
        dests.isEmpty ? '—' : dests.first.split(',').first.trim();
    final restDests = dests.length > 1 ? dests.sublist(1) : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: v2Border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── SEHEMU YA JUU ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Avatar + Jina + Menu ⋮
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(color: toneBg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initials,
                        style: TextStyle(
                            color: tone,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(v2TitleCase(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: v2TextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                  ),
                  InkWell(
                    onTap: onDotsTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F7),
                          borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: Icon(
                          PhosphorIcons.dotsThreeVertical(
                              PhosphorIconsStyle.bold),
                          size: 19,
                          color: v2TextSecondary),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),

                // 2. Idara pill + Kada plain text
                Row(children: [
                  _pill(deptName, deptIcon, toneBg, tone),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(cadre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: v2TextPrimary, fontSize: 13)),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 6),
                    _pill('Admin',
                        PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                        v2Accent, Colors.white),
                  ],
                ]),
                const SizedBox(height: 10),

                // 3. Simu + WhatsApp chips (pana, clickable)
                Row(children: [
                  Expanded(
                    child: _phoneChip(
                      PhosphorIcons.phone(),
                      _fmtLocal(phone),
                      v2AccentBg,
                      v2Accent,
                      () => v2Launch(
                          'tel:+${phone.replaceAll(RegExp(r'\D'), '')}'),
                    ),
                  ),
                  if (whatsapp.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _phoneChip(
                        PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                        _fmtLocal(whatsapp),
                        v2SuccessBg,
                        v2Success,
                        () => _launchWa(whatsapp),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),

          // ── MSTARI WA TIKETI (dashes + notch) ──
          _V2TicketCut(pageBg: pageBg),

          // ── ANATOKA → ANAELEKEA ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: _V2Place(
                      label: 'ANATOKA',
                      place: region.isEmpty ? '—' : region,
                      sub: district,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _V2DashedLine(width: 14, color: v2Accent),
                      const SizedBox(width: 2),
                      Icon(PhosphorIcons.airplaneTilt(), size: 18, color: v2Accent),
                      const SizedBox(width: 2),
                      _V2DashedLine(width: 14, color: v2Accent),
                    ]),
                  ),
                  Expanded(
                    child: _V2Place(
                      label: 'ANAELEKEA',
                      place: firstDest,
                      sub: restDests.isEmpty
                          ? ''
                          : '+ mikoa ${restDests.length} mingine',
                      alignEnd: true,
                    ),
                  ),
                ]),
                if (restDests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: restDests
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: v2AccentBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(t.split(',').first.trim(),
                                  style: const TextStyle(
                                      color: v2Accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          // ── HALI + MALIPO ──
          Container(height: 1, color: v2Border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              Expanded(
                child: _bigStatusPill(
                  icon: PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
                  label: isActive ? 'Hai' : 'Amesitishwa',
                  bg: isActive ? v2SuccessBg : const Color(0xFFF1F3F7),
                  fg: isActive ? v2Success : v2TextSecondary,
                  circleBg: isActive ? v2Success : v2TextSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _bigStatusPill(
                  icon: isPaid
                      ? PhosphorIcons.receipt(PhosphorIconsStyle.fill)
                      : PhosphorIcons.receiptX(PhosphorIconsStyle.fill),
                  label: isPaid ? 'Amelipa' : 'Hajalipa',
                  bg: isPaid ? v2SuccessBg : v2DangerBg,
                  fg: isPaid ? v2Success : v2Danger,
                  circleBg: isPaid ? v2Success : v2Danger,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Pill yenye radius 999 (idara, admin, hali, malipo) ──
  Widget _pill(String label, IconData? icon, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  // ── Pill kubwa ya hali (Hai/Amesitishwa, Amelipa/Hajalipa) ──
  Widget _bigStatusPill({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required Color circleBg,
  }) =>
      Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: circleBg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      );

  // ── Chip ya simu/WhatsApp (inabonyezwa) ──
  Widget _phoneChip(
      IconData icon, String number, Color bg, Color fg, VoidCallback onTap) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Sehemu ya kata tiketi (dashes + notch mbili) ──────────────────────────
class _V2TicketCut extends StatelessWidget {
  final Color pageBg;
  const _V2TicketCut({required this.pageBg});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: CustomPaint(
                painter: _V2DashPainter(
                    color: v2Border, dash: 6, gap: 5, stroke: 1.5),
              ),
            ),
          ),
          Positioned(left: -10, top: 0, child: _notch(pageBg)),
          Positioned(right: -10, top: 0, child: _notch(pageBg)),
        ],
      ),
    );
  }

  Widget _notch(Color bg) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      );
}

// ── Dashes za usawa (ANATOKA↔ANAELEKEA) ──────────────────────────────────
class _V2DashedLine extends StatelessWidget {
  final double width;
  final Color color;
  const _V2DashedLine({required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 2,
      child: CustomPaint(
        painter: _V2DashPainter(color: color, dash: 3, gap: 2, stroke: 1.5),
      ),
    );
  }
}

class _V2DashPainter extends CustomPainter {
  final Color color;
  final double dash, gap, stroke;
  const _V2DashPainter(
      {required this.color,
      required this.dash,
      required this.gap,
      required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _V2DashPainter old) =>
      old.color != color || old.dash != dash || old.gap != gap;
}

// ── Jina la mahali (ANATOKA / ANAELEKEA) ─────────────────────────────────
class _V2Place extends StatelessWidget {
  final String label, place, sub;
  final bool alignEnd;
  const _V2Place(
      {required this.label,
      required this.place,
      required this.sub,
      this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? TextAlign.right : TextAlign.left;
    final cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(label,
            textAlign: align,
            style: const TextStyle(
                color: v2TextMuted, fontSize: 11, letterSpacing: .3)),
        Text(place,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: v2TextPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                height: 1.25)),
        if (sub.isNotEmpty)
          Text(sub,
              textAlign: align,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: v2TextMuted, fontSize: 12)),
      ],
    );
  }
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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              bar(double.infinity, 14),
              const SizedBox(height: 9),
              bar(double.infinity, 11),
            ]),
          ),
          const SizedBox(width: 13),
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

// ═══════════════════════════════ Icon Picker Sheet ═══════════════════════════════
Future<String?> showV2IconPicker(
  BuildContext context, {
  required String title,
  required List<({String value, String label, IconData icon, Color iconBg, Color iconFg})> items,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _V2IconPickerSheet(title: title, items: items, selected: selected),
  );
}

class _V2IconPickerSheet extends StatelessWidget {
  final String title;
  final List<({String value, String label, IconData icon, Color iconBg, Color iconFg})> items;
  final String? selected;
  const _V2IconPickerSheet({required this.title, required this.items, this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: v2Surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: v2Border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: v2TextPrimary)),
            const SizedBox(height: 12),
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _row(context, items[i]),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ({String value, String label, IconData icon, Color iconBg, Color iconFg}) item) {
    final isSel = selected == item.value;
    return InkWell(
      onTap: () => Navigator.pop(context, item.value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSel ? v2AccentBg : v2Surface,
          border: Border.all(color: isSel ? v2Accent : v2Border, width: isSel ? 1.5 : 1.0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: isSel ? v2AccentBg : item.iconBg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(item.icon, size: 19, color: isSel ? v2Accent : item.iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item.label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: isSel ? v2Accent : v2TextPrimary))),
          if (isSel) Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 18, color: v2Accent),
        ]),
      ),
    );
  }
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
