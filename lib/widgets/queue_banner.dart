/// Banner ndogo ya hali ya foleni ya offline.
///
/// Hali 3:
///  • Pending/Processing — #FEF3C7/#92400E, saa icon, "Vitendo N vinasubiri"
///  • Sending           — #E0E7FF/#1E3A8A, sync icon, "Inatuma vitendo…"
///  • Failed            — #FEE2E2/#B91C1C, kosa icon, kitufe "Jaribu tena"
///
/// Haionyeshwi kama foleni ni tupu.
library;

import 'package:flutter/material.dart';
import '../services/offline_queue.dart';

class QueueBanner extends StatelessWidget {
  const QueueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineQueue(),
      builder: (context, _) {
        final q       = OfflineQueue();
        final pending = q.pendingCount;
        final proc    = q.processingCount;
        final failed  = q.failedCount;

        if (pending == 0 && proc == 0 && failed == 0) {
          return const SizedBox.shrink();
        }

        late Color   bg, fg;
        late IconData icon;
        late String  label;
        Widget?      trailing;

        if (failed > 0 && pending == 0 && proc == 0) {
          // Vitendo vilivyoshindwa
          bg   = const Color(0xFFFEE2E2);
          fg   = const Color(0xFFB91C1C);
          icon = Icons.error_outline_rounded;
          label = 'Vitendo $failed havikutumwa';
          trailing = GestureDetector(
            onTap: () => OfflineQueue().retryFailed(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Jaribu tena',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
            ),
          );
        } else if (proc > 0) {
          // Inatuma sasa hivi
          bg   = const Color(0xFFE0E7FF);
          fg   = const Color(0xFF1E3A8A);
          icon = Icons.sync_rounded;
          label = 'Inatuma vitendo…';
        } else {
          // Inasubiri mtandao (pending)
          final n = pending + failed;
          bg   = const Color(0xFFFEF3C7);
          fg   = const Color(0xFF92400E);
          icon = Icons.schedule_rounded;
          label = 'Vitendo $n vinasubiri mtandao';
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            color: bg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        height: 1.2)),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ]),
          ),
        );
      },
    );
  }
}
