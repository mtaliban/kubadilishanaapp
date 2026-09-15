import 'package:flutter/material.dart';
import '../config/theme.dart';

const double _kItemH = 56;

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
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 12, 10),
              child: Row(children: [
                Expanded(
                  child: Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 17, color: AppColors.grey700),
                  ),
                ),
              ]),
            ),

            // Search — kama web (rounded, grey-50, icon ya kutafuta)
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Tafuta...',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.grey50,
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textLight),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 40, minHeight: 0),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.6)),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),

            Container(height: 1, color: AppColors.borderLight),

            // Items
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Hakuna kilichopatikana',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textLight)),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final item = list[i];
                        final isSel = item.value == widget.selected;
                        return InkWell(
                          onTap: () => Navigator.pop(context, item.value),
                          child: Container(
                            height: _kItemH,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.blue50 : Colors.transparent,
                              border: const Border(
                                  bottom: BorderSide(
                                      color: AppColors.borderLight, width: 1)),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSel
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSel
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          )),
                                      if (item.subtitle != null &&
                                          item.subtitle!.isNotEmpty)
                                        Text(item.subtitle!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textLight)),
                                    ]),
                              ),
                              const SizedBox(width: 12),
                              // Duara la kuchagua — bluu ikichaguliwa (kama web)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSel
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSel
                                        ? AppColors.primary
                                        : AppColors.grey300,
                                    width: 2,
                                  ),
                                ),
                                child: isSel
                                    ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
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
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: disabled ? AppColors.grey100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled ? AppColors.grey200 : AppColors.border,
          ),
          boxShadow: disabled ? null : const [
            BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Text(
              hasValue ? value! : hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                color: hasValue ? AppColors.textPrimary : AppColors.textLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: hasValue ? AppColors.primary : AppColors.textLight,
          ),
        ]),
      ),
    );
  }
}
