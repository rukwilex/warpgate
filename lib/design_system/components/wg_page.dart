import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/wg_feedback.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';
import 'package:warpgate/design_system/tokens/wg_metrics.dart';

class WgPage extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    super.key,
    this.actions = const [],
    this.subtitle,
    this.scrollable = true,
    this.maxWidth,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool scrollable;
  final double? maxWidth;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final narrow = MediaQuery.sizeOf(context).width < WgBreakpoints.medium;
    final gutter = narrow ? space.lg : space.xxl;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(gutter, space.xl, gutter, space.lg),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: space.md,
        spacing: space.md,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, SizedBox(width: space.sm)],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: context.type.heading),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: context.type.caption.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: space.sm, runSpacing: space.sm, children: actions),
        ],
      ),
    );
    final body = Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, space.xxl),
      child: child,
    );
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? context.sizes.contentMax,
        ),
        child: scrollable
            ? ListView(children: [header, body])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const WgHairline(),
                  Expanded(child: child),
                ],
              ),
      ),
    );
  }
}
