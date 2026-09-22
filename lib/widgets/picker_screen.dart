import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/theme.dart';

typedef PickOption = ({String? id, String name});

Future<PickOption?> openPickerScreen(
  BuildContext context, {
  required String title,
  String? subtitle,
  String allLabel = 'Yote',
  required IconData icon,
  required List<PickOption> options,
  String? selectedId,
}) {
  return Navigator.of(context).push<PickOption>(
    MaterialPageRoute(
      builder: (_) => _AppPickerScreen(
        title: title,
        subtitle: subtitle,
        icon: icon,
        allLabel: allLabel,
        options: options,
        selectedId: selectedId,
      ),
    ),
  );
}

class _AppPickerScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String allLabel;
  final List<PickOption> options;
  final String? selectedId;

  const _AppPickerScreen({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.allLabel,
    required this.options,
    this.selectedId,
  });

  @override
  State<_AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<_AppPickerScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: widget.options.length > 5,
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tafuta...',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(PhosphorIcons.magnifyingGlass(),
                      size: 16, color: AppColors.textLight),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 0),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _PickerItem(
                  icon: PhosphorIcons.globe(),
                  iconBg: AppColors.grey100,
                  iconColor: AppColors.textSecondary,
                  label: widget.allLabel,
                  isSelected: widget.selectedId == null,
                  onTap: () =>
                      Navigator.pop(context, (id: null, name: '')),
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Hakuna kilichopatikana',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textLight)),
                    ),
                  )
                else
                  for (final o in filtered)
                    _PickerItem(
                      icon: widget.icon,
                      iconBg: AppColors.blue50,
                      iconColor: AppColors.primary,
                      label: o.name,
                      isSelected: widget.selectedId == o.id,
                      onTap: () => Navigator.pop(context, o),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue50 : iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: isSelected ? AppColors.primary : iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              color: AppColors.primary, size: 20)
          : null,
    );
  }
}
