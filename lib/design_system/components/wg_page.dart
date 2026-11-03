import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/wg_feedback.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';
import 'package:warpgate/design_system/tokens/wg_metrics.dart';

class WgPage extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.child,
    this.empty,
    this.actions = const [],
    this.subtitle,
    this.scrollable = true,
    this.maxWidth,
    this.leading,
  }) : assert(child != null || empty != null, 'Pass a child or an empty state');

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? child;
  final Widget? empty;
  final bool scrollable;
  final double? maxWidth;
  final Widget? leading;

  static double gutterOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < WgBreakpoints.medium
      ? context.space.lg
      : context.space.xxl;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final gutter = gutterOf(context);
    final narrow = MediaQuery.sizeOf(context).width < WgBreakpoints.medium;
    final heading = Row(
      children: [
        if (leading != null) ...[leading!, SizedBox(width: space.sm)],
        Expanded(
          child: Column(
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
        ),
      ],
    );
    final actionBar = Wrap(
      spacing: space.sm,
      runSpacing: space.sm,
      alignment: narrow ? WrapAlignment.start : WrapAlignment.end,
      children: actions,
    );
    final header = Padding(
      key: const ValueKey('page-header'),
      padding: EdgeInsets.fromLTRB(gutter, space.xl, gutter, space.lg),
      child: actions.isEmpty
          ? heading
          : narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                SizedBox(height: space.md),
                actionBar,
              ],
            )
          : Row(
              children: [
                Expanded(child: heading),
                SizedBox(width: space.md),
                actionBar,
              ],
            ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          maxWidth ?? context.sizes.contentMax,
        );
        final Widget page;
        if (empty != null && child == null) {
          page = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: Padding(
                  key: const ValueKey('page-empty'),
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, space.xxl),
                  child: empty,
                ),
              ),
            ],
          );
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: page,
          );
        }
        page = scrollable
            ? ListView(
                children: [
                  header,
                  Padding(
                    key: const ValueKey('page-body'),
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, space.xxl),
                    child: child,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const WgHairline(),
                  Expanded(child: child!),
                ],
              );
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: page,
          ),
        );
      },
    );
  }
}
