import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class HostFieldLabel extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.space.xs),
    child: Text(
      text,
      style: context.type.label.copyWith(color: context.colors.textSecondary),
    ),
  );
}
