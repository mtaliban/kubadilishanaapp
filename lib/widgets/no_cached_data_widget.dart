/// Widget MOYA ya hali "hakuna data iliyohifadhiwa" — inatumika kurusa zote.
///
/// Inaonekana TU kama CachedRepository haina data iliyohifadhiwa kabisa
/// kwenye diski kwa ukurasa huo (mtumiaji hajawahi kufungua ukurasa huu
/// mtandaoni). HAKUNA kitufe cha "Jaribu tena" — pull-to-refresh pekee.
///
/// Mtandao ukirudi (NetworkService online), widget inaitwa [onLoad] mara
/// moja — ukurasa unajipakia bila mtumiaji kubonyeza chochote. Data
/// ikitokea (CachedRepository revision inabadilika) widget inaacha
/// kuonyeshwa yenyewe (ukurasa unajenga maudhui halisi).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/network_service.dart';
import 'page_skeleton.dart';

class NoCachedDataWidget extends StatefulWidget {
  const NoCachedDataWidget({super.key, this.onLoad, this.hint});

  /// Pakia data (n.k. CachedRepository().refresh(...)) — inaitwa ndani ya
  /// initState kama mtandao upo (au mtandao ukirudi).
  final Future<void> Function()? onLoad;

  /// Maelezo madogo ya chaguo-lizuri (n.k. "Vuta chini kupakia").
  final String? hint;

  @override
  State<NoCachedDataWidget> createState() => _NoCachedDataWidgetState();
}

class _NoCachedDataWidgetState extends State<NoCachedDataWidget> {
  bool _loadedOnOpen = false;

  @override
  void initState() {
    super.initState();
    NetworkService().addOnlineListener(_onOnline);
    // Kama mtandao tayari upo — pakia mara moja (splash ya kwanza, offline
    // kabisa). Badilisha kila wakati data inaishia kwenye diski (revision
    // inabadilika) ukurasa unajenga maudhui halisi.
    if (NetworkService().isOnline && widget.onLoad != null) {
      _loadedOnOpen = true;
      unawaited(widget.onLoad!());
    }
  }

  @override
  void didUpdateWidget(covariant NoCachedDataWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onLoad != oldWidget.onLoad &&
        NetworkService().isOnline &&
        !_loadedOnOpen &&
        widget.onLoad != null) {
      _loadedOnOpen = true;
      unawaited(widget.onLoad!());
    }
  }

  @override
  void dispose() {
    NetworkService().removeOnlineListener(_onOnline);
    super.dispose();
  }

  void _onOnline() {
    if (widget.onLoad == null) return;
    _loadedOnOpen = true;
    unawaited(widget.onLoad!());
  }

  // KANUNI YA APP: KAMWE spinner — hata hii hali ya "haijapakuliwa".
  // Mtumiaji anaona kijivu (skeleton) + maandishi mafupi tu.
  // SingleChildScrollView (BILA LayoutBuilder — LayoutBuilder hairuhusu
  // intrinsic dimensions zinazohitajika na SliverFillRemaining/hasScrollBody).
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!NetworkService().isOnline) Icon(
              Icons.download_for_offline_outlined,
              size: 40,
              color: dark ? const Color(0xFF334155) : const Color(0xFF9AA7B8),
            ),
            const SizedBox(height: 12),
            Text(
              'Data haijapakuliwa bado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: dark ? const Color(0xFFE5E7EB) : const Color(0xFF33415C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.hint ??
                  'Vuta chini (pull-to-refresh) kupakia, au subiri '
                      'mtandao — data itaonekana mara itakapofika.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: dark ? const Color(0xFFA8B1C1) : const Color(0xFF7B8794),
              ),
            ),
            const SizedBox(height: 16),
            const PageSkeleton(rows: 2, scrollable: false),
          ],
        ),
      ),
    );
  }
}
