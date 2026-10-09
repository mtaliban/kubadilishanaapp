import 'package:flutter/material.dart';

/// Kichwa cha "Maoni na Malalamiko" — code kutoka kwa mwenye app (mockup C):
/// kichwa + LIVE badge + search (kinafunguka), na TABS za mstari chini
/// (Yote / Yasiyojibiwa / Yaliyojibiwa) zenye counts za duara.
class MaoniHeader extends StatefulWidget {
  final int selected; // 0 = Yote, 1 = Yasiyojibiwa, 2 = Yaliyojibiwa
  final int allCount;
  final int unansweredCount;
  final int answeredCount;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onSearch;

  const MaoniHeader({
    super.key,
    required this.selected,
    required this.allCount,
    required this.unansweredCount,
    required this.answeredCount,
    required this.onTabChanged,
    required this.onSearch,
  });

  @override
  State<MaoniHeader> createState() => _MaoniHeaderState();
}

class _MaoniHeaderState extends State<MaoniHeader> {
  static const blue = Color(0xFF1E40AF);
  bool _searching = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kichwa
          Row(
            children: [
              const Icon(Icons.chat_outlined, size: 20, color: blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Maoni na Malalamiko',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const _LiveBadge(),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _ctrl.clear();
                    widget.onSearch('');
                  }
                }),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant, width: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_searching ? Icons.close : Icons.search,
                      size: 17),
                ),
              ),
            ],
          ),

          // Kisanduku cha search (kinafunguka)
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            child: _searching
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        onChanged: widget.onSearch,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tafuta…',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 16),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 8),

          // Tabs za mstari
          Row(
            children: [
              _tab(0, 'Yote', widget.allCount,
                  const Color(0xFFDCFCE7), const Color(0xFF15803D)),
              _tab(1, 'Yasiyojibiwa', widget.unansweredCount,
                  const Color(0xFFDC2626), Colors.white),
              _tab(2, 'Yaliyojibiwa', widget.answeredCount,
                  const Color(0xFFDCFCE7), const Color(0xFF15803D)),
            ],
          ),
          Divider(height: 0.5, thickness: 0.5, color: cs.outlineVariant),
        ],
      ),
    );
  }

  Widget _tab(int i, String label, int count, Color bg, Color fg) {
    final active = widget.selected == i;
    return Expanded(
      child: InkWell(
        onTap: () => widget.onTabChanged(i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: active ? blue : Colors.transparent, width: 2.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? blue : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(9)),
                child: Text('$count',
                    style: TextStyle(fontSize: 10, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: Color(0xFF16A34A)),
          SizedBox(width: 5),
          Text('LIVE',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF15803D))),
        ],
      ),
    );
  }
}
