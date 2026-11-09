import 'package:flutter/material.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgTag extends StatelessWidget {
  const new(this.text, {super.key, this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = tone ?? colors.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.xs + context.space.hair,
        vertical: context.sizes.hairline,
      ),
      decoration: BoxDecoration(
        borderRadius: context.radii.xsAll,
        border: Border.all(
          color: tone == null ? colors.hairlineStrong : colors.line(tone!),
        ),
      ),
      child: Text(text, style: context.type.monoSmall.copyWith(color: ink)),
    );
  }
}
