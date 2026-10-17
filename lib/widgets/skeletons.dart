// skeletons.dart
//
// Skeleton (kijivu kinachometameta) kinachonakili muundo halisi wa kila ukurasa,
// kama YouTube. Hakuna package ya nje inayohitajika.
//
// KANUNI:
//  - Kichwa cha app, vichupo vya juu na menyu ya chini VINABAKI halisi.
//  - Skeleton inachukua nafasi ya maudhui tu (chini ya kichwa/vichupo).
//  - Ikiwa kuna data iliyohifadhiwa (cache), onyesha data hiyo. Skeleton
//    inaonekana TU pale ambapo hakuna data kabisa bado.
//
// MATUMIZI:
//   SkeletonSwitcher(
//     loading: controller.data == null,          // hakuna cache wala data
//     skeleton: const DataListSkeleton(showChips: true),
//     child: DataListContent(...),               // ukurasa halisi
//   )
//
// Skeleton zilizomo:
//   Admin app : TakwimuSkeleton, WenzaoSkeleton, DataListSkeleton (Idara, Masomo,
//               Kada, Mikoa, Wilaya, Vituo), MalipoSkeleton, AdminWasifuSkeleton
//   User app  : DashibodiSkeleton, ChangiaSkeleton, MaoniSkeleton, WasifuSkeleton
//               (zimenakiliwa kutoka kwenye picha halisi za kurasa za user app)

import 'package:flutter/material.dart';

/* ═══════════════════════ MSINGI (shimmer) ═══════════════════════ */

/// Inaendesha uhuishaji mmoja kwa mifupa yote ya ukurasa (inasogea pamoja).
class SkeletonScope extends StatefulWidget {
  const SkeletonScope({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonAnim(animation: _c, child: widget.child);
}

class _SkeletonAnim extends InheritedWidget {
  const _SkeletonAnim({required this.animation, required super.child});
  final Animation<double> animation;

  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonAnim>()?.animation;

  @override
  bool updateShouldNotify(_SkeletonAnim old) => animation != old.animation;
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.slide);
  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0.0, 0.0);
}

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _base(BuildContext c) =>
    _isDark(c) ? const Color(0xFF2A2F3A) : const Color(0xFFE6E8EC);
Color _highlight(BuildContext c) =>
    _isDark(c) ? const Color(0xFF3A4150) : const Color(0xFFF3F4F6);
Color _border(BuildContext c) =>
    _isDark(c) ? const Color(0xFF2E3442) : const Color(0xFFDDE3F3);

/// Kipande kimoja cha kijivu (mstari, kisanduku, kidonge au duara).
class Bone extends StatelessWidget {
  const Bone({
    super.key,
    this.width,
    this.widthFactor,
    this.height = 12,
    this.radius = 8,
  });

  const Bone.circle(double size, {Key? key})
      : this(key: key, width: size, height: size, radius: size / 2);

  /// Upana kamili (px). Tumia double.infinity kujaza upana.
  final double? width;

  /// Sehemu ya upana wa mzazi (0..1). Inapuuza [width].
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final anim = _SkeletonAnim.of(context);
    final base = _base(context);
    final hi = _highlight(context);

    Widget box;
    if (anim == null) {
      box = Container(
        width: widthFactor != null ? null : width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    } else {
      box = AnimatedBuilder(
        animation: anim,
        builder: (context, _) => Container(
          width: widthFactor != null ? null : width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [base, hi, base],
              stops: const [0.1, 0.3, 0.4],
              transform: _SlideGradient(-1.0 + 2.0 * anim.value),
            ),
          ),
        ),
      );
    }

    if (widthFactor != null) {
      box = FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: box,
      );
    }
    return box;
  }
}

/// Kadi yenye mstari wa pembeni, kama kadi halisi za app.
class _SkCard extends StatelessWidget {
  const _SkCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border(context)),
        ),
        child: child,
      );
}

/// Mstari wa vitone (kama kwenye tiketi na kadi za watu).
class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) {
    final color = _border(context);
    return LayoutBuilder(
      builder: (context, c) {
        final n = (c.maxWidth / 10).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            n,
            (_) => Container(width: 5, height: 1.5, color: color),
          ),
        );
      },
    );
  }
}

/// Ukurasa wa skeleton: haubadiliki urefu, haupindi (hakuna overflow).
class _SkPage extends StatelessWidget {
  const _SkPage({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SkeletonScope(
        child: ClipRect(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      );
}

SizedBox _gh(double h) => SizedBox(height: h);
SizedBox _gw(double w) => SizedBox(width: w);

/// Hubadilisha kati ya skeleton na ukurasa halisi kwa uhuishaji laini.
class SkeletonSwitcher extends StatelessWidget {
  const SkeletonSwitcher({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: loading
            ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
            : KeyedSubtree(key: const ValueKey('content'), child: child),
      );
}

/* ═══════════════════════ ADMIN APP ═══════════════════════ */

/// Takwimu: kadi kubwa ya namba na grafu, kadi 4 ndogo, matukio ya karibuni.
class TakwimuSkeleton extends StatelessWidget {
  const TakwimuSkeleton({super.key});

  Widget _small() => const _SkCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Bone.circle(20),
              SizedBox(width: 8),
              Expanded(child: Bone(widthFactor: 0.7, height: 12)),
            ]),
            SizedBox(height: 14),
            Bone(width: 80, height: 28),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        const Bone(widthFactor: 0.9, height: 12),
        _gh(8),
        const Bone(widthFactor: 0.6, height: 12),
        _gh(16),
        _SkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Bone.circle(12),
                SizedBox(width: 8),
                Bone(width: 130, height: 12),
              ]),
              _gh(14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(width: 130, height: 40),
                        SizedBox(height: 14),
                        Bone(width: 150, height: 30, radius: 15),
                      ],
                    ),
                  ),
                  _gw(12),
                  const Bone(width: 120, height: 70, radius: 12),
                ],
              ),
            ],
          ),
        ),
        Row(children: [
          Expanded(child: _small()),
          _gw(12),
          Expanded(child: _small()),
        ]),
        _gh(12),
        Row(children: [
          Expanded(child: _small()),
          _gw(12),
          Expanded(child: _small()),
        ]),
        _gh(16),
        _SkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Bone(width: 44, height: 44, radius: 14),
                SizedBox(width: 12),
                Bone(width: 170, height: 18),
              ]),
              _gh(16),
              for (var i = 0; i < 3; i++) ...[
                const Row(children: [
                  Bone.circle(36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(widthFactor: 0.7, height: 13),
                        SizedBox(height: 6),
                        Bone(widthFactor: 0.4, height: 11),
                      ],
                    ),
                  ),
                ]),
                _gh(14),
              ],
            ],
          ),
        ),
      ]);
}

/// Waliopata wenzao: vichujio 2, kutafuta, kadi za watu zenye njia ya safari.
class WenzaoSkeleton extends StatelessWidget {
  const WenzaoSkeleton({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        const Row(children: [
          Expanded(child: Bone(height: 46, radius: 16)),
          SizedBox(width: 12),
          Expanded(child: Bone(height: 46, radius: 16)),
        ]),
        _gh(12),
        const Bone(width: double.infinity, height: 46, radius: 16),
        _gh(16),
        const Bone(width: 130, height: 12),
        _gh(14),
        for (var i = 0; i < count; i++)
          _SkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Bone.circle(48),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(widthFactor: 0.65, height: 16),
                        SizedBox(height: 8),
                        Bone(widthFactor: 0.5, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Bone(width: 80, height: 28, radius: 14),
                ]),
                _gh(14),
                const _Dashed(),
                _gh(14),
                const Row(children: [
                  Bone.circle(14),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(width: 60, height: 10),
                      SizedBox(height: 6),
                      Bone(width: 120, height: 18),
                      SizedBox(height: 6),
                      Bone(width: 90, height: 12),
                    ],
                  ),
                ]),
                _gh(12),
                const Row(children: [
                  Bone.circle(14),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(width: 80, height: 10),
                      SizedBox(height: 6),
                      Bone(width: 130, height: 18),
                      SizedBox(height: 6),
                      Bone(width: 90, height: 12),
                    ],
                  ),
                ]),
                _gh(14),
                const Bone(width: double.infinity, height: 42, radius: 14),
              ],
            ),
          ),
      ]);
}

/// Kurasa za Data: Idara, Masomo, Kada, Mikoa, Wilaya, Vituo.
/// [showChips] = true kwa Masomo (Primary/Secondary) na Vituo (aina za vituo).
class DataListSkeleton extends StatelessWidget {
  const DataListSkeleton({super.key, this.showChips = false, this.count = 7});
  final bool showChips;
  final int count;

  static const _titleFactors = [0.46, 0.34, 0.52, 0.4, 0.3, 0.5, 0.38];
  static const _subFactors = [0.3, 0.42, 0.26, 0.36, 0.34, 0.28, 0.4];

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        const Row(children: [
          Bone(width: 150, height: 14),
          Spacer(),
          Bone(width: 122, height: 42, radius: 21),
        ]),
        _gh(18),
        const Bone(width: double.infinity, height: 46, radius: 23),
        if (showChips) ...[
          _gh(12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                Bone(width: 82, height: 40, radius: 20),
                SizedBox(width: 10),
                Bone(width: 96, height: 40, radius: 20),
                SizedBox(width: 10),
                Bone(width: 110, height: 40, radius: 20),
                SizedBox(width: 10),
                Bone(width: 96, height: 40, radius: 20),
              ],
            ),
          ),
        ],
        _gh(16),
        for (var i = 0; i < count; i++)
          _SkCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Bone(width: 50, height: 50, radius: 14),
              _gw(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone(
                      widthFactor: _titleFactors[i % _titleFactors.length],
                      height: 15,
                    ),
                    _gh(9),
                    Bone(
                      widthFactor: _subFactors[i % _subFactors.length],
                      height: 12,
                    ),
                  ],
                ),
              ),
              _gw(10),
              const Bone(width: 38, height: 38, radius: 12),
              _gw(6),
              const Bone(width: 38, height: 38, radius: 12),
              _gw(6),
              const Bone(width: 38, height: 38, radius: 12),
            ]),
          ),
      ]);
}

/// Malipo: duara la asilimia, vigae 3, tiketi za malipo.
class MalipoSkeleton extends StatelessWidget {
  const MalipoSkeleton({super.key, this.count = 3});
  final int count;

  Widget _tile() => const _SkCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Bone(width: 70, height: 11),
            SizedBox(height: 10),
            Bone(width: 36, height: 24),
            SizedBox(height: 8),
            Bone(width: 60, height: 10),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return _SkPage(children: [
      Center(
        child: SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Bone.circle(190),
              Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Bone(width: 70, height: 11),
                  SizedBox(height: 8),
                  Bone(width: 44, height: 26),
                  SizedBox(height: 8),
                  Bone(width: 56, height: 11),
                ],
              ),
            ],
          ),
        ),
      ),
      _gh(22),
      Row(children: [
        Expanded(child: _tile()),
        _gw(10),
        Expanded(child: _tile()),
        _gw(10),
        Expanded(child: _tile()),
      ]),
      _gh(22),
      const Bone(width: 110, height: 12),
      _gh(12),
      for (var i = 0; i < count; i++)
        _SkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(widthFactor: 0.8, height: 17),
                        SizedBox(height: 9),
                        Bone(widthFactor: 0.55, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Bone(width: 82, height: 24),
                      SizedBox(height: 8),
                      Bone(width: 34, height: 10),
                    ],
                  ),
                ],
              ),
              _gh(14),
              const _Dashed(),
              _gh(14),
              // Mstari wa mlolongo wa tiketi — Bone wa kwanza ni Expanded:
              // upana kamili haikiidani na simu 320 (254px kwaunda).
              const Row(children: [
                Expanded(child: Bone(height: 16)),
                Bone.circle(38),
                SizedBox(width: 10),
                Bone.circle(38),
                SizedBox(width: 10),
                Bone(width: 104, height: 34, radius: 8),
              ]),
            ],
          ),
        ),
    ]);
  }
}

/// Wasifu wa admin: picha ya duara, jina, cheo, kadi ya taarifa 4.
class AdminWasifuSkeleton extends StatelessWidget {
  const AdminWasifuSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        _gh(8),
        const Center(child: Bone.circle(96)),
        _gh(16),
        const Center(child: Bone(width: 240, height: 20)),
        _gh(12),
        const Center(child: Bone(width: 110, height: 28, radius: 14)),
        _gh(24),
        _SkCard(
          child: Column(children: [
            for (var i = 0; i < 4; i++) ...[
              const Row(children: [
                Bone(width: 38, height: 38, radius: 12),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(width: 80, height: 11),
                      SizedBox(height: 8),
                      Bone(widthFactor: 0.75, height: 15),
                    ],
                  ),
                ),
              ]),
              if (i < 3) ...[
                _gh(14),
                Container(height: 1, color: _border(context)),
                _gh(14),
              ],
            ],
          ]),
        ),
      ]);
}

/* ═══════════════════════ USER APP ═══════════════════════ */

/// Dashibodi: kadi ya karibu, muhtasari wa Wakitokea -> Wanahamia, vichujio
/// (Wanakotoka, Wilaya, Shule, Masomo), kadi za watu, na kurasa (Iliyopita/
/// Inayofuata).
class DashibodiSkeleton extends StatelessWidget {
  const DashibodiSkeleton({super.key, this.count = 2});
  final int count;

  Widget _chips(List<double> widths) => SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final w in widths) ...[
              Bone(width: w, height: 42, radius: 21),
              const SizedBox(width: 10),
            ],
          ],
        ),
      );

  Widget _person() => const _SkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Bone.circle(52),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone(widthFactor: 0.62, height: 16),
                    SizedBox(height: 8),
                    Bone(widthFactor: 0.42, height: 12),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Bone(width: 84, height: 30, radius: 15),
            ]),
            SizedBox(height: 14),
            Row(children: [
              Bone(width: 78, height: 30, radius: 15),
              SizedBox(width: 10),
              Expanded(child: Bone(widthFactor: 0.72, height: 14)),
            ]),
            SizedBox(height: 14),
            _Dashed(),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(width: 60, height: 10),
                      SizedBox(height: 7),
                      Bone(width: 104, height: 20),
                      SizedBox(height: 7),
                      Bone(width: 80, height: 12),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 26),
                  child: Bone(width: 40, height: 12, radius: 6),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Bone(width: 60, height: 10),
                      SizedBox(height: 7),
                      Bone(width: 84, height: 20),
                      SizedBox(height: 7),
                      Bone(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(children: [
              Bone(width: 56, height: 12),
              SizedBox(width: 10),
              Bone(width: 52, height: 30, radius: 15),
              SizedBox(width: 8),
              Bone(width: 52, height: 30, radius: 15),
            ]),
            SizedBox(height: 10),
            Bone(width: 150, height: 28, radius: 14),
            SizedBox(height: 16),
            Row(children: [
              Expanded(child: Bone(height: 54, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: Bone(height: 54, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: Bone(height: 54, radius: 14)),
            ]),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        // Kadi ya karibu (picha, jina, hali ya malipo, cheo, mahali)
        const _SkCard(
          child: Row(children: [
            Bone.circle(64),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Bone(widthFactor: 0.8, height: 18)),
                    SizedBox(width: 8),
                    Bone(width: 76, height: 26, radius: 13),
                  ]),
                  SizedBox(height: 10),
                  Row(children: [
                    Bone.circle(14),
                    SizedBox(width: 8),
                    Expanded(child: Bone(widthFactor: 0.9, height: 13)),
                  ]),
                  SizedBox(height: 8),
                  Row(children: [
                    Bone.circle(14),
                    SizedBox(width: 8),
                    Bone(width: 120, height: 13),
                  ]),
                ],
              ),
            ),
          ]),
        ),
        // Muhtasari: Wakitokea -> idadi ya wenzako -> Wanahamia
        const _SkCard(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(width: 66, height: 10),
                  SizedBox(height: 8),
                  Row(children: [
                    Bone.circle(18),
                    SizedBox(width: 8),
                    Bone(width: 70, height: 18),
                  ]),
                ],
              ),
            ),
            Column(
              children: [
                Bone(width: 44, height: 24, radius: 12),
                SizedBox(height: 8),
                Bone(width: 56, height: 10, radius: 5),
                SizedBox(height: 8),
                Bone(width: 48, height: 10),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Bone(width: 76, height: 10),
                  SizedBox(height: 8),
                  Bone(width: 64, height: 18),
                ],
              ),
            ),
          ]),
        ),
        _gh(6),
        // Wanakotoka: vichupo vya mikoa + Wilaya/Shule
        const Bone(width: 110, height: 16),
        _gh(10),
        _chips(const [58, 92, 128, 90]),
        _gh(10),
        const Row(children: [
          Expanded(child: Bone(height: 46, radius: 16)),
          SizedBox(width: 12),
          Expanded(child: Bone(height: 46, radius: 16)),
        ]),
        _gh(16),
        // Masomo
        const Bone(width: 70, height: 16),
        _gh(10),
        _chips(const [56, 150, 104, 80]),
        _gh(16),
        for (var i = 0; i < count; i++) _person(),
        // Kurasa: Iliyopita / 1 / 5 / Inayofuata
        const Row(children: [
          Bone(width: 112, height: 44, radius: 22),
          Spacer(),
          Bone(width: 44, height: 14),
          Spacer(),
          Bone(width: 128, height: 44, radius: 22),
        ]),
      ]);
}

/// Changia: namba ya malipo, historia ya malipo, mawasiliano.
/// Sehemu ya fomu (KIASI, NAMBA ULIYOLIPIA, SMS) ni vidhibiti vya kuandika,
/// kwa hiyo [showForm] ikiwa false, hazionyeshwi kama mifupa.
class ChangiaSkeleton extends StatelessWidget {
  const ChangiaSkeleton({super.key, this.showForm = true});
  final bool showForm;

  Widget _field() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Bone(width: 90, height: 11),
          SizedBox(height: 8),
          Bone(width: double.infinity, height: 52, radius: 18),
          SizedBox(height: 16),
        ],
      );

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        _SkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Bone.circle(26),
                SizedBox(width: 10),
                Bone(width: 150, height: 16),
              ]),
              _gh(14),
              const Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(width: 110, height: 11),
                      SizedBox(height: 10),
                      Bone(width: 190, height: 26),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Bone(width: 84, height: 36, radius: 12),
              ]),
            ],
          ),
        ),
        if (showForm)
          _SkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Bone.circle(26),
                  SizedBox(width: 10),
                  Bone(width: 170, height: 16),
                ]),
                _gh(16),
                _field(),
                _field(),
                const Bone(width: 130, height: 11),
                _gh(8),
                const Bone(width: double.infinity, height: 100, radius: 18),
              ],
            ),
          ),
        _SkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Bone.circle(24),
                SizedBox(width: 10),
                Bone(width: 150, height: 16),
              ]),
              _gh(14),
              // Pills 3 za historia ya malipo — Expanded kila moja: zinaendana
              // na simu ndogo 320 (kuzubandika bone fixed 324 > 254px kwaunda).
              const Row(children: [
                Expanded(child: Bone(height: 44, radius: 22)),
                SizedBox(width: 10),
                Expanded(child: Bone(height: 44, radius: 22)),
                SizedBox(width: 10),
                Expanded(child: Bone(height: 44, radius: 22)),
              ]),
              _gh(16),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(width: 40, height: 40, radius: 12),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(widthFactor: 0.4, height: 17),
                        SizedBox(height: 8),
                        Bone(widthFactor: 0.8, height: 12),
                        SizedBox(height: 10),
                        Bone(widthFactor: 1, height: 38, radius: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _SkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Bone(width: 160, height: 11),
              _gh(14),
              for (var i = 0; i < 2; i++) ...[
                const Row(children: [
                  Bone(width: 48, height: 48, radius: 14),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(width: 90, height: 12),
                        SizedBox(height: 8),
                        Bone(width: 150, height: 17),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Bone(width: 8, height: 14, radius: 4),
                ]),
                if (i == 0) ...[
                  _gh(14),
                  Container(height: 1, color: _border(context)),
                  _gh(14),
                ],
              ],
            ],
          ),
        ),
      ]);
}

/// Maoni (user app): "Maoni yangu" na kadi za maoni zenye jibu la admin.
/// Kisanduku cha kuandika ni kidhibiti, kwa hiyo [showComposer] ikiwa false,
/// kinaachwa.
class MaoniSkeleton extends StatelessWidget {
  const MaoniSkeleton({super.key, this.count = 3, this.showComposer = true});
  final int count;
  final bool showComposer;

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        if (showComposer) ...[
          _SkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Bone.circle(20),
                  SizedBox(width: 10),
                  Bone(width: 120, height: 16),
                ]),
                _gh(14),
                const Bone(width: double.infinity, height: 110, radius: 18),
                _gh(14),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Bone(width: 150, height: 40, radius: 14),
                ),
              ],
            ),
          ),
          _gh(8),
        ],
        const Row(children: [
          Bone(width: 110, height: 18),
          Spacer(),
          Bone.circle(30),
        ]),
        _gh(14),
        for (var i = 0; i < count; i++)
          _SkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Flexible(child: Bone(width: 112, height: 28, radius: 14)),
                  Spacer(),
                  Flexible(child: Bone(width: 100, height: 12)),
                ]),
                _gh(14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Bone.circle(36),
                    _gw(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Bone(width: 44, height: 11),
                          _gh(8),
                          Bone(widthFactor: i.isEven ? 0.5 : 0.85, height: 15),
                        ],
                      ),
                    ),
                  ],
                ),
                _gh(14),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.circle(36),
                    SizedBox(width: 12),
                    Expanded(child: Bone(height: 66, radius: 14)),
                  ],
                ),
              ],
            ),
          ),
      ]);
}

/// Wasifu (user app): kadi ya picha na jina, Mawasiliano, Masomo,
/// Kituo cha sasa, Ninataka kwenda.
/// ═══════════════ WASIFU (USER APP) ═══════════════
/// Skeleton ya Wasifu = UTAMBO ULEULE wa WasifuView halisi (muundo na pimo):
/// header (icon 40 + "Wasifu wangu" + Hariri), kadi ya duara 64/jina/pills,
/// MAWASILIANO (mstari icon+lebo+thamani), KITUO CHA SASA,
/// na NINATAKA KWENDA (duara-namba + mkoa/wilaya) — upana/tu urefu uo vadilihinisha?
class WasifuSkeleton extends StatelessWidget {
  const WasifuSkeleton({super.key});

  // Kadi ya ukurasa (radius 16, pembeni — kama _Card ya WasifuView).
  Widget _card(BuildContext c, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: _isDark(c) ? const Color(0xFF181D26) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border(c)),
        ),
        child: child,
      );

  // Lebo ya sehemu ("MAWASILIANO" — herufi ndogo, ya juu-kushoto).
  Widget _sectionTitle(double w) => Bone(width: w, height: 9, radius: 4);

  // Mstari wa taarifa: icon 32×32 + lebo ndogo + thamani (kama _InfoRow).
  Widget _infoRow() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          const Bone(width: 32, height: 32, radius: 9),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 74, height: 10, radius: 5),
                SizedBox(height: 5),
                Bone(widthFactor: 0.62, height: 14),
              ],
            ),
          ),
        ]),
      );

  // Mstari wa KITUO (huenda Hospitali/kituo uka-pm). Habare hakuna duara-yamwisho.
  Widget _kituoRow() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          const Bone(width: 32, height: 32, radius: 9),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 86, height: 10, radius: 5),
                SizedBox(height: 5),
                Bone(widthFactor: 0.5, height: 14),
              ],
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => _SkPage(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // Header — "Wasifu wangu" + kitufe cha Hariri.
          const Row(children: [
            Bone(width: 40, height: 40, radius: 12),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(widthFactor: 0.34, height: 14),
                  SizedBox(height: 6),
                  Bone(widthFactor: 0.26, height: 10),
                ],
              ),
            ),
            Bone(width: 84, height: 32, radius: 8),
          ]),
          const SizedBox(height: 10),

          // Picha ya duara + jina + nguzo (idara na kada).
          _card(
            context,
            const Column(children: [
              Bone.circle(64),
              SizedBox(height: 8),
              Bone(width: 170, height: 17, radius: 8),
              SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  Bone(width: 78, height: 20, radius: 999),
                  Bone(width: 96, height: 20, radius: 999),
                ],
              ),
            ]),
          ),

          // MAWASILIANO
          _card(
            context,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(104),
              _infoRow(),
              _infoRow(),
            ]),
          ),

          // KITUO CHA SASA
          _card(
            context,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(130),
              _kituoRow(),
              _kituoRow(),
            ]),
          ),

          // NINATAKA KWENDA — kadi 2 za chaguo (mkoa/wilaya).
          _card(
            context,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(150),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isDark(context) ? const Color(0xFF212833) : const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(children: [
                  Bone.circle(24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(widthFactor: 0.42, height: 13),
                        SizedBox(height: 5),
                        Bone(widthFactor: 0.28, height: 11),
                      ],
                    ),
                  ),
                  Bone(width: 18, height: 18, radius: 6),
                ]),
              ),
            ]),
          ),
        ],
      );
}

/* ═══════════════ MWONGEZO WA ADMIN (wa kurasa nyingine) ═══════════════ */

class WatumiajiSkeleton extends StatelessWidget {
  const WatumiajiSkeleton({super.key, this.count = 4, this.showChips = false});
  final int count;
  final bool showChips;

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        const Row(children: [
          Expanded(child: Bone(height: 46, radius: 16)),
          SizedBox(width: 12),
          Bone(width: 46, height: 46, radius: 16),
        ]),
        _gh(12),
        const Bone(width: double.infinity, height: 46, radius: 23),
        if (showChips) ...[
          _gh(12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                Bone(width: 96, height: 40, radius: 20),
                SizedBox(width: 10),
                Bone(width: 110, height: 40, radius: 20),
                SizedBox(width: 10),
                Bone(width: 92, height: 40, radius: 20),
              ],
            ),
          ),
        ],
        _gh(16),
        const Bone(width: 130, height: 12),
        _gh(14),
        for (var i = 0; i < count; i++)
          _SkCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Bone.circle(48),
              _gw(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Bone(widthFactor: 0.6, height: 15),
                    _gh(8),
                    const Bone(widthFactor: 0.42, height: 12),
                  ],
                ),
              ),
              _gw(10),
              const Bone(width: 70, height: 28, radius: 14),
            ]),
          ),
      ]);
}

/// Matangazo: kadi zenye kichwa, tarehe/aina na ujumbe.
class MatangazoSkeleton extends StatelessWidget {
  const MatangazoSkeleton({super.key, this.count = 3, this.showFab = false});
  final int count;
  final bool showFab;

  @override
  Widget build(BuildContext context) => _SkPage(children: [
        const Row(children: [
          Bone(width: 110, height: 18),
          Spacer(),
          Bone(width: 96, height: 40, radius: 20),
        ]),
        _gh(14),
        for (var i = 0; i < count; i++)
          _SkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Bone(width: 60, height: 26, radius: 13),
                  SizedBox(width: 10),
                  Bone(width: 90, height: 12),
                  Spacer(),
                  Bone(width: 20, height: 20, radius: 6),
                ]),
                _gh(12),
                const Bone(widthFactor: 0.85, height: 16),
                _gh(10),
                const Bone(width: double.infinity, height: 12),
                _gh(8),
                const Bone(width: double.infinity, height: 12),
                _gh(8),
                const Bone(widthFactor: 0.5, height: 12),
              ],
            ),
          ),
      ]);
}
