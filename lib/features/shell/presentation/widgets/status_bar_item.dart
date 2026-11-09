import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class StatusBarItem extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => WgPressable(
    semanticLabel: label,
    onPressed: onPressed,
    borderRadius: context.radii.xsAll,
    builder: (context, state) => Container(
      padding: EdgeInsets.symmetric(horizontal: context.space.xs),
      decoration: BoxDecoration(
        color: state.highlighted
            ? context.colors.raised
            : context.colors.transparent,
        borderRadius: context.radii.xsAll,
      ),
      child: child,
    ),
  );
}
