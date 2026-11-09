import 'package:flutter/material.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgCheckbox extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: label,
      child: Checkbox(
        value: value,
        onChanged: onChanged == null ? null : (next) => onChanged!(next!),
        activeColor: colors.accent,
        checkColor: colors.onAccent,
        side: BorderSide(
          color: colors.hairlineStrong,
          width: context.sizes.stroke,
        ),
        shape: RoundedRectangleBorder(borderRadius: context.radii.xsAll),
      ),
    );
  }
}
