/// Kibanda kidogo cha hali ya mtandao — kinaonekana chini ya TopBar.
///
/// Hali 3:
///  • Offline  — #FEF3C7 / #92400E, wifi-off, muda wa data ya mwisho, kitufe "Jaribu"
///  • Checking — #E0E7FF / #1E3A8A, wifi-find, "Inaunganisha…"
///  • Online   — #DCFCE7 / #166534, wifi, "Umeunganishwa · data imesasishwa"
///               (kinapotea chenyewe baada ya sekunde 2)
///
/// AnimatedSize inashughulikia mpito wa kushuka/kupanda bila Flutter animation
/// controller — rahisi, reliable.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/network_service.dart';

class NetworkBanner extends StatefulWidget {
  const NetworkBanner({super.key});
  @override
  State<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<NetworkBanner> {
  NetStatus _prev = NetStatus.unknown;
  bool      _showOnlineFlash = false;
  Timer?    _flashTimer;

  @override
  void initState() {
    super.initState();
    _prev = NetworkService().status;
    NetworkService().addListener(_onStatusChange);
  }

  @override
  void dispose() {
    NetworkService().removeListener(_onStatusChange);
    _flashTimer?.cancel();
    super.dispose();
  }

  void _onStatusChange() {
    final s = NetworkService().status;
    if (s == NetStatus.online &&
        (_prev == NetStatus.offline || _prev == NetStatus.checking)) {
      // Imetoka offline → online: onyesha kijani kwa sekunde 2
      setState(() => _showOnlineFlash = true);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showOnlineFlash = false);
      });
    } else if (s == NetStatus.offline) {
      _showOnlineFlash = false;
      _flashTimer?.cancel();
      if (mounted) setState(() {});
    } else {
      if (mounted) setState(() {});
    }
    _prev = s;
  }

  bool get _visible {
    final s = NetworkService().status;
    return s == NetStatus.offline || s == NetStatus.checking || _showOnlineFlash;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _visible ? _buildBar() : const SizedBox.shrink(),
    );
  }

  Widget _buildBar() {
    final s    = NetworkService().status;
    final last = NetworkService().lastOnline;

    late Color  bg, fg;
    late IconData icon;
    late String label;
    bool showRetry = false;

    if (_showOnlineFlash) {
      bg   = const Color(0xFFDCFCE7);
      fg   = const Color(0xFF166534);
      icon = Icons.wifi_rounded;
      label = 'Umeunganishwa · data imesasishwa';
    } else if (s == NetStatus.checking) {
      bg   = const Color(0xFFE0E7FF);
      fg   = const Color(0xFF1E3A8A);
      icon = Icons.wifi_find_rounded;
      label = 'Inaunganisha…';
    } else {
      // offline
      bg   = const Color(0xFFFEF3C7);
      fg   = const Color(0xFF92400E);
      icon = Icons.wifi_off_rounded;
      final timeStr = last != null
          ? '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}'
          : '--:--';
      label     = 'Hakuna mtandao · data ya $timeStr';
      showRetry = true;
    }

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
              height: 1.2,
            ),
          ),
        ),
        if (showRetry) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => NetworkService().retry(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Jaribu',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
