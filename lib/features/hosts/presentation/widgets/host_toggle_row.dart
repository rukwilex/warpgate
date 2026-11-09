import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class HostToggleRow extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.type.bodyStrong),
              SizedBox(height: context.space.hair),
              Text(body, style: context.type.caption),
            ],
          ),
        ),
        SizedBox(width: context.space.md),
        WgSwitch(value: value, onChanged: onChanged, label: title),
      ],
    ),
  );
}
