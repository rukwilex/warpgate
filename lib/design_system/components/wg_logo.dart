import 'package:flutter/material.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgLogoMark extends StatelessWidget {
  const new({super.key, this.size, this.color});

  static const asset = 'assets/brand/mark.png';

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final extent = size ?? context.sizes.logoMark;
    return ExcludeSemantics(
      child: Image.asset(
        asset,
        width: extent,
        height: extent,
        color: color ?? context.colors.textPrimary,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}
