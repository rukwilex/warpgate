import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/widgets/host_field_label.dart';

class HostDropdown<T> extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.error,
    this.empty,
    super.key,
  });

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final String? error;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: context.radii.mdAll,
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HostFieldLabel(label),
        DropdownButtonFormField<T>(
          initialValue: items.any((item) => item.$1 == value) ? value : null,
          isExpanded: true,
          style: context.type.body,
          dropdownColor: colors.surface,
          icon: Icon(
            WgIcons.chevronDown,
            size: context.sizes.icon,
            color: colors.textMuted,
          ),
          hint: Text(
            empty ?? 'Choose',
            style: context.type.body.copyWith(color: colors.textMuted),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: colors.raised,
            errorText: error,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.space.md,
              vertical: context.space.sm,
            ),
            border: border(colors.hairline),
            enabledBorder: border(colors.hairline),
            focusedBorder: border(colors.focusRing),
          ),
          items: [
            for (final (itemValue, text) in items)
              DropdownMenuItem<T>(
                value: itemValue,
                child: Text(text, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (next) => onChanged(next as T),
        ),
      ],
    );
  }
}
