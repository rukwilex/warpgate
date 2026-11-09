import 'package:flutter/material.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgSectionLabel extends StatelessWidget {
  const new(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(space.sm, space.xxl, space.xs, space.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: context.type.caption.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
