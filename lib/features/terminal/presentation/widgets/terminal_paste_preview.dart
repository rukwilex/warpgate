import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class TerminalPastePreview extends StatelessWidget {
  const new({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxHeight: context.sizes.previewMax),
    padding: EdgeInsets.all(context.space.sm),
    decoration: BoxDecoration(
      color: context.colors.canvasDeep,
      borderRadius: context.radii.smAll,
    ),
    child: SingleChildScrollView(
      child: Text(text, style: context.type.monoSmall),
    ),
  );
}
