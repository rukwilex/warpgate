import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class HostFieldRow extends StatelessWidget {
  const new({required this.children, super.key});

  final List<(int, Widget)> children;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < WgBreakpoints.medium;
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (_, child)) in children.indexed) ...[
            if (index > 0) SizedBox(height: context.space.lg),
            child,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, (flex, child)) in children.indexed) ...[
          if (index > 0) SizedBox(width: context.space.md),
          Expanded(flex: flex, child: child),
        ],
      ],
    );
  }
}
