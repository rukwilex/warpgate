import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/wg_icons.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

enum WgTone { info, positive, caution, negative, offline }

class WgInlineMessage extends StatelessWidget {
  const new({
    required this.message,
    super.key,
    this.tone = WgTone.info,
    this.title,
    this.action,
  });

  final String message;
  final String? title;
  final WgTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final (icon, ink) = switch (tone) {
      WgTone.info => (WgIcons.info, colors.textSecondary),
      WgTone.positive => (WgIcons.check, colors.positive),
      WgTone.caution => (WgIcons.warning, colors.caution),
      WgTone.negative => (WgIcons.error, colors.negative),
      WgTone.offline => (WgIcons.offline, colors.textSecondary),
    };
    return Semantics(
      liveRegion: tone == WgTone.negative || tone == WgTone.caution,
      container: true,
      child: Container(
        padding: EdgeInsets.all(space.md),
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: context.radii.mdAll,
          border: Border.all(color: colors.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: space.hair),
              child: Icon(icon, size: context.sizes.icon, color: ink),
            ),
            SizedBox(width: space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title!, style: context.type.bodyStrong),
                  Text(
                    message,
                    style: context.type.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[SizedBox(width: space.sm), action!],
          ],
        ),
      ),
    );
  }
}

class WgEmptyState extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.icon,
    this.body,
    this.action,
    this.secondary,
  });

  final IconData? icon;
  final String title;
  final String? body;
  final Widget? action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(space.xxl),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sizes.dialog),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: context.sizes.iconLarge,
                  color: colors.textMuted,
                ),
                SizedBox(height: space.lg),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.type.title,
              ),
              if (body != null) ...[
                SizedBox(height: space.sm),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: context.type.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              if (action != null || secondary != null) ...[
                SizedBox(height: space.xl),
                Wrap(
                  spacing: space.sm,
                  runSpacing: space.sm,
                  alignment: WrapAlignment.center,
                  children: [?action, ?secondary],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WgSkeleton extends StatelessWidget {
  const new({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height ?? context.space.md,
        decoration: BoxDecoration(
          color: context.colors.raised,
          borderRadius: context.radii.xsAll,
        ),
      ),
    );
  }
}

class WgSkeletonList extends StatelessWidget {
  const new({super.key, this.rows = 6, this.label = 'Loading'});

  final int rows;
  final String label;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final widths = [0.62, 0.44, 0.7, 0.38, 0.56, 0.5, 0.66, 0.4];
    return Semantics(
      label: label,
      liveRegion: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows; i++)
              SizedBox(
                height: context.sizes.row,
                child: Row(
                  children: [
                    SizedBox(width: space.sm),
                    WgSkeleton(
                      width: context.sizes.icon,
                      height: context.sizes.icon,
                    ),
                    SizedBox(width: space.sm),
                    WgSkeleton(
                      width:
                          (constraints.maxWidth - space.huge).clamp(
                            0,
                            double.infinity,
                          ) *
                          widths[i % widths.length],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WgProgressBar extends StatelessWidget {
  const new({required this.label, super.key, this.value, this.tone});

  final double? value;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = value == null ? null : (value! * 100).round();
    return Semantics(
      label: label,
      value: percent == null ? null : '$percent percent',
      child: ClipRRect(
        borderRadius: context.radii.xsAll,
        child: LinearProgressIndicator(
          value: value,
          minHeight: context.sizes.progressBar,
          backgroundColor: colors.raised,
          color: tone ?? colors.accent,
        ),
      ),
    );
  }
}

class WgHairline extends StatelessWidget {
  const new({super.key, this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.hairline;
    final size = context.sizes.hairline;
    return vertical
        ? Container(width: size, color: color)
        : Container(height: size, color: color);
  }
}

class WgPanel extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.padding,
    this.raised = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding ?? EdgeInsets.all(context.space.lg),
      decoration: BoxDecoration(
        color: raised ? colors.raised : colors.surface,
        borderRadius: context.radii.lgAll,
        border: Border.all(color: colors.hairline),
      ),
      child: child,
    );
  }
}
