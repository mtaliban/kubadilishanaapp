import 'package:flutter/material.dart';
// ── Generic select bottom sheet — radio-circle picker ─────────────────────────
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? widget.items
        : widget.items
            .where((e) => e.label.toLowerCase().contains(_q.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827))),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ]),
          ),

          // Search
          if (widget.searchable && widget.items.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _ctrl,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Tafuta...',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF1E40AF), width: 1.5)),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),

          const Divider(height: 1),

          // Items list
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                final isSel = item.value == widget.selected;
                return InkWell(
                  onTap: () => Navigator.pop(context, item.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFFEFF6FF)
                          : Colors.transparent,
                      border: const Border(
                          bottom: BorderSide(
                              color: Color(0xFFF3F4F6), width: 1)),
                    ),
                    child: Row(children: [
                      // Radio circle
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel
                              ? const Color(0xFF1E40AF)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF1E40AF)
                                : const Color(0xFFD1D5DB),
                            width: isSel ? 0 : 2,
                          ),
                        ),
                        child: isSel
                            ? const Icon(Icons.check,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSel
                                        ? const Color(0xFF1E40AF)
                                        : const Color(0xFF111827),
                                  )),
                              if (item.subtitle != null)
                                Text(item.subtitle!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF))),
                            ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Tappable select field (fake dropdown) ─────────────────────────────────────
class SelectField extends StatelessWidget {
  final String hint;
  final String? value;
  final bool disabled;
  final VoidCallback? onTap;
  const SelectField({
    super.key,
    required this.hint,
    this.value,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              hasValue ? value! : hint,
              style: TextStyle(
                fontSize: 13,
                color: hasValue
                    ? const Color(0xFF111827)
                    : disabled
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF9CA3AF),
                fontWeight:
                    hasValue ? FontWeight.w500 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: disabled
                ? const Color(0xFFD1D5DB)
                : const Color(0xFF6B7280),
          ),
        ]),
      ),
    );
  }
}
