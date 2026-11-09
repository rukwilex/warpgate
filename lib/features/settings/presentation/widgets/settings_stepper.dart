import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class SettingsStepper extends StatelessWidget {
  const new({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    super.key,
    this.step = 1,
    this.unit = '',
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '$value $unit',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WgIconButton(
          icon: WgIcons.minus,
          label: 'Decrease $label',
          onPressed: value <= min
              ? null
              : () => onChanged((value - step).clamp(min, max)),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: context.sizes.metaColumn),
          child: Text(
            '$value${unit.isEmpty ? '' : ' $unit'}',
            textAlign: TextAlign.center,
            style: context.type.mono,
          ),
        ),
        WgIconButton(
          icon: WgIcons.plus,
          label: 'Increase $label',
          onPressed: value >= max
              ? null
              : () => onChanged((value + step).clamp(min, max)),
        ),
      ],
    ),
  );
}
