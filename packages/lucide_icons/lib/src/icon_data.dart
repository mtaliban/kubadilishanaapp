import 'package:flutter/widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════
// VENDORED + PATCHED — lucide_icons 0.257.0
//
// Toleo la pub.dev (0.257.0) halijengi kwenye Flutter mpya kwa kuwa faili hii
// lilikuwa:
//
//   class LucideIconData extends IconData { ... }
//
// `IconData` ni `final class` kwenye Flutter mpya, hivyo haiwezi kurithiwa
// (Build ilifeli: "The class 'IconData' can't be extended outside of its
// library because it's a final class").
//
// PATCH: badala ya class, tunafanya `LucideIconData` kuwa typedef ya IconData
// HALISI yenye `fontFamily: 'Lucide'` na `fontPackage: 'lucide_icons'` —
// sawa kabisa na nilivyokuwa zikitengenezwa awali na class hii. API ya
// `LucideIcons.<jina>` haijabadilika, hivyo code ya app haikuguswa.
// ═══════════════════════════════════════════════════════════════════════════
typedef LucideIconData = IconData;

// function bila const — codepoints si constant expressions pale inahitajika
IconData lucideIconData(int codePoint) => IconData(
      codePoint,
      fontFamily: 'Lucide',
      fontPackage: 'lucide_icons',
    );
