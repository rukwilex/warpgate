import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';

class SettingsRow extends StatelessWidget {
  const new({required this.item, super.key});

  final SettingsItem item;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: context.type.body),
        if (item.description != null) ...[
          SizedBox(height: space.hair),
          Text(item.description!, style: context.type.caption),
        ],
      ],
    );
    if (item.leading != null) {
      text = Row(
        children: [
          item.leading!,
          SizedBox(width: space.md),
          Expanded(child: text),
        ],
      );
    }
    final narrow = MediaQuery.sizeOf(context).width < WgBreakpoints.medium;
    return Container(
      padding: EdgeInsets.symmetric(vertical: space.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.hairline)),
      ),
      child: item.stacked || narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                SizedBox(height: space.sm),
                Align(alignment: Alignment.centerLeft, child: item.control),
              ],
            )
          : Row(
              children: [
                Expanded(child: text),
                SizedBox(width: space.lg),
                item.control,
              ],
            ),
    );
  }
}
