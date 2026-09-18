// ══════════════════════════════════════════════════════════════════════════
// VENDORED + PATCHED — phosphor_flutter 2.1.0
//
// Toleo la pub.dev (2.1.0, May 2024) halijengi kwenye Flutter ya sasa kwa
// sababu faili hii ilikuwa:
//
//   class PhosphorIconData extends IconData { ... }
//
// `IconData` ni `final class` kwenye Flutter mpya, hivyo haiwezi kurithiwa
// (Build ilifeli: "The class 'IconData' can't be extended outside of its
// library because it's a final class").
//
// PATCH: icons zote zinatengenezwa kama `IconData` HALISI zenye
// `fontFamily: 'Phosphor<Style>'` na `fontPackage: 'phosphor_flutter'` —
// sawa kabisa na nilivyokuwa zikitengenezwa awali na class hii. API ya
// `PhosphorIcons.<jina>(style)` na `PhosphorIconsStyle` haijabadilika,
// hivyo code ya app haikuguswa.
//
// Angalia: lib/src/phosphor_icons_*.dart (matengenezo), lib/src/phosphor_icon.dart
// ══════════════════════════════════════════════════════════════════════════
library phosphor_flutter;
