import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/workspace/presentation/widgets/session_tabs.dart';

class WorkbenchTabStrip extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: context.sizes.tabBar,
    padding: EdgeInsets.symmetric(horizontal: context.space.sm),
    decoration: BoxDecoration(
      color: context.colors.canvasDeep,
      border: Border(bottom: BorderSide(color: context.colors.hairline)),
    ),
    child: const SessionTabs(),
  );
}
