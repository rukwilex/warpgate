import 'package:flutter/material.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgSwitch extends StatelessWidget {
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
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: colors.onAccent,
        activeTrackColor: colors.accent,
        inactiveThumbColor: colors.textSecondary,
        inactiveTrackColor: colors.raised,
        trackOutlineColor: WidgetStatePropertyAll(colors.hairlineStrong),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
