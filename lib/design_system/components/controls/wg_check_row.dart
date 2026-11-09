import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/controls/wg_checkbox.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgCheckRow extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: context.radii.smAll,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Row(
          children: [
            WgCheckbox(value: value, onChanged: onChanged, label: label),
            Expanded(child: Text(label, style: context.type.body)),
          ],
        ),
      ),
    );
  }
}
