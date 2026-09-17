import 'package:flutter/material.dart';
import '../config/theme.dart';

const double _kItemH = 40;

// ── Generic select bottom sheet — modern picker (web parity) ──────────────────
Future<T?> showSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label, String? subtitle})> items,
  required T? selected,
  bool searchable = false,
}) async {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => SelectSheet<T>(
      title: title,
      items: items,
      selected: selected,
      searchable: searchable,
    ),
  );
}

class SelectSheet<T> extends StatefulWidget {
  final String title;
  final List<({T value, String label, String? subtitle})> items;
  final T? selected;
  final bool searchable;
  const SelectSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selected,
    this.searchable = false,
  });
  @override
  State<SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<SelectSheet<T>> {
  String _q = '';
  final _ctrl = TextEditingController();
  bool _jumped = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<({T value, String label, String? subtitle})> get _filtered {
    if (_q.trim().isEmpty) return widget.items;
    final q = _q.trim().toLowerCase();
    return widget.items
        .where((e) =>
            e.label.toLowerCase().contains(q) ||
            (e.subtitle ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final selIdx = list.indexWhere((e) => e.value == widget.selected);

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, scrollCtrl) {
        // Ruka moja kwa moja kwenye kitu kilichochaguliwa (orodha ndefu).
        if (!_jumped && selIdx > 2 && scrollCtrl.hasClients) {
          _jumped = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!scrollCtrl.hasClients) return;
            final target = ((selIdx - 1) * _kItemH)
                .clamp(0.0, scrollCtrl.position.maxScrollExtent);
            scrollCtrl.jumpTo(target);
          });
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 44, height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header — title kubwa + X mviringo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
              child: Row(children: [
                Expanded(
                  child: Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.grey100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.grey700),
                  ),
                ),
              ]),
            ),

            // Search
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Tafuta...',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textLight),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 44, minHeight: 0),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.6)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),

            // Items — kila moja kadi yake (kama picha)
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Hakuna kilichopatikana',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textLight)),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final item = list[i];
                        final isSel = item.value == widget.selected;
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, item.value),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: isSel
                                ? BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                      width: 1.5,
                                    ),
                                  )
                                : null,
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(item.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSel
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: isSel
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        )),
                                    if (item.subtitle != null &&
                                        item.subtitle!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(item.subtitle!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textLight)),
                                    ],
                                  ],
                                ),
                              ),
                              if (isSel) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.check_rounded,
                                    size: 22,
                                    color: AppColors.primary),
                              ],
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Tappable select field (fake dropdown) — kisasa, rounded-xl ───────────────
class SelectField extends StatelessWidget {
  final String hint;
  final String? value;
  final bool disabled;
  final VoidCallback? onTap;
  final Widget? leading;
  const SelectField({
    super.key,
    required this.hint,
    this.value,
    this.disabled = false,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.grey300),
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              hasValue ? value! : hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                color: hasValue ? AppColors.textPrimary : const Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: hasValue ? AppColors.primary : const Color(0xFF374151),
          ),
        ]),
      ),
    );
  }
}
