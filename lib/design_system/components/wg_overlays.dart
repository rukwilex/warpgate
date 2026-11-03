import 'dart:async';

import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/wg_button.dart';
import 'package:warpgate/design_system/components/wg_icons.dart';
import 'package:warpgate/design_system/components/wg_keycap.dart';
import 'package:warpgate/design_system/components/wg_pressable.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgDialog extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    super.key,
    this.actions = const [],
    this.wide = false,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool wide;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final sizes = context.sizes;
    final body = Padding(
      padding: EdgeInsets.symmetric(horizontal: space.xxl),
      child: child,
    );
    return Dialog(
      insetPadding: EdgeInsets.all(space.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? sizes.dialogWide : sizes.dialog,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                space.xxl,
                space.xxl,
                space.xxl,
                space.lg,
              ),
              child: Semantics(
                header: true,
                child: Text(title, style: context.type.title),
              ),
            ),
            Flexible(
              child: scrollable ? SingleChildScrollView(child: body) : body,
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(space.xxl),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: space.sm,
                  runSpacing: space.sm,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showWgConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  Widget? detail,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => WgDialog(
      title: title,
      actions: [
        WgButton.ghost(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        if (destructive)
          WgButton.danger(
            label: confirmLabel,
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(true),
          )
        else
          WgButton.primary(
            label: confirmLabel,
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: context.type.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          if (detail != null) ...[SizedBox(height: context.space.md), detail],
        ],
      ),
    ),
  );
  return result ?? false;
}

@immutable
class WgMenuEntry {
  const new({
    required this.label,
    required this.onSelected,
    this.icon,
    this.shortcut,
    this.destructive = false,
    this.enabled = true,
    this.trailing,
  }) : divider = false;

  const new divider()
    : label = '',
      onSelected = null,
      icon = null,
      shortcut = null,
      trailing = null,
      destructive = false,
      enabled = false,
      divider = true;

  final String label;
  final VoidCallback? onSelected;
  final IconData? icon;
  final SingleActivator? shortcut;
  final bool destructive;
  final bool enabled;
  final bool divider;
  final String? trailing;
}

Future<void> showWgMenu(
  BuildContext context, {
  required Offset position,
  required List<WgMenuEntry> entries,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final selected = await showMenu<WgMenuEntry>(
    context: context,
    position: RelativeRect.fromRect(
      position & Size.zero,
      Offset.zero & overlay.size,
    ),
    menuPadding: EdgeInsets.all(context.space.xs),
    items: [
      for (final entry in entries)
        if (entry.divider)
          const PopupMenuDivider()
        else
          PopupMenuItem<WgMenuEntry>(
            value: entry,
            enabled: entry.enabled,
            height: context.sizes.rowCompact,
            padding: EdgeInsets.zero,
            child: _MenuRow(entry: entry),
          ),
    ],
  );
  selected?.onSelected?.call();
}

class _MenuRow extends StatelessWidget {
  const new({required this.entry});

  final WgMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final ink = !entry.enabled
        ? colors.textMuted
        : entry.destructive
        ? colors.negative
        : colors.textPrimary;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.sm),
      child: Row(
        children: [
          SizedBox(
            width: context.sizes.icon,
            child: entry.icon == null
                ? null
                : Icon(
                    entry.icon,
                    size: context.sizes.icon,
                    color: entry.destructive
                        ? colors.negative
                        : colors.textSecondary,
                  ),
          ),
          SizedBox(width: space.sm),
          Expanded(
            child: Text(
              entry.label,
              style: context.type.body.copyWith(color: ink),
            ),
          ),
          if (entry.trailing != null) ...[
            SizedBox(width: space.lg),
            Text(
              entry.trailing!,
              style: context.type.caption.copyWith(color: colors.textMuted),
            ),
          ],
          if (entry.shortcut != null) ...[
            SizedBox(width: space.xl),
            WgKeycap(entry.shortcut!),
          ],
        ],
      ),
    );
  }
}

class WgMenuButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.entries,
    super.key,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final List<WgMenuEntry> Function() entries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => WgIconButton(
        icon: icon,
        label: label,
        compact: compact,
        onPressed: () {
          final box = buttonContext.findRenderObject()! as RenderBox;
          final origin = box.localToGlobal(Offset(0, box.size.height));
          unawaited(
            showWgMenu(buttonContext, position: origin, entries: entries()),
          );
        },
      ),
    );
  }
}

void showWgToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        width: context.sizes.dialog,
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: context.colors.accentInk,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}

class WgSheetHandle extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: EdgeInsets.symmetric(vertical: context.space.sm),
      width: context.space.xxxl,
      height: context.space.xs,
      decoration: BoxDecoration(
        color: context.colors.hairlineStrong,
        borderRadius: context.radii.xsAll,
      ),
    ),
  );
}

class WgTabChip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
    this.leading,
    this.trailing,
    this.onClose,
    this.onSecondaryTapDown,
    this.marker,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onClose;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Color? marker;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    return WgPressable(
      semanticLabel: label,
      selected: selected,
      onPressed: onPressed,
      onSecondaryTapDown: onSecondaryTapDown,
      borderRadius: context.radii.smAll,
      builder: (context, state) => AnimatedContainer(
        duration: context.motion.fast,
        curve: context.motion.curve,
        height: sizes.tabBar - space.sm,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: selected
              ? colors.raised
              : state.highlighted
              ? colors.surface
              : colors.transparent,
          borderRadius: context.radii.smAll,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(left: space.sm, right: space.xs),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      SizedBox(width: space.sm),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.label.copyWith(
                          color: selected
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      SizedBox(width: space.xs),
                      trailing!,
                    ],
                    if (onClose != null)
                      Opacity(
                        opacity: selected || state.hovered || state.focused
                            ? 1
                            : 0,
                        child: WgIconButton(
                          icon: WgIcons.close,
                          label: 'Close $label',
                          compact: true,
                          onPressed: onClose,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (marker != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: sizes.markerBar,
                child: ColoredBox(color: marker!),
              ),
          ],
        ),
      ),
    );
  }
}
