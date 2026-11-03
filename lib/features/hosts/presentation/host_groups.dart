import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';

@immutable
class HostDrag {
  const new(this.host);

  final Host host;
}

const ungroupedKey = '';

bool isGroupCollapsed(WidgetRef ref, String key) => ref.watch(
  settingsProvider.select((s) => s.collapsedHostGroups.contains(key)),
);

void toggleGroup(WidgetRef ref, String key) {
  final current = ref.read(settingsProvider).collapsedHostGroups;
  ref.read(settingsProvider.notifier).update({
    'collapsedHostGroups': current.contains(key)
        ? [...current.where((item) => item != key)]
        : [...current, key],
  });
}

Future<void> moveHostToGroup(WidgetRef ref, Host host, String? groupId) async {
  if (host.groupId == groupId) return;
  await ref
      .read(hostsProvider.notifier)
      .saveHost(host.copyWith(groupId: () => groupId));
}

Widget draggableHost(BuildContext context, Host host, Widget child) {
  final feedback = Material(
    color: context.colors.transparent,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.md,
        vertical: context.space.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.raised,
        borderRadius: context.radii.mdAll,
        border: Border.all(color: context.colors.accent),
      ),
      child: Text(host.label, style: context.type.label),
    ),
  );
  return Draggable<HostDrag>(
    data: HostDrag(host),
    feedback: feedback,
    dragAnchorStrategy: pointerDragAnchorStrategy,
    child: child,
  );
}

class HostGroupHeader extends ConsumerStatefulWidget {
  const new({
    required this.groupKey,
    required this.name,
    required this.count,
    super.key,
    this.groupId,
    this.trailing,
    this.renamable = true,
    this.dense = false,
  });

  final String groupKey;
  final String? groupId;
  final String name;
  final int count;
  final Widget? trailing;
  final bool renamable;
  final bool dense;

  @override
  ConsumerState<HostGroupHeader> createState() => _HostGroupHeaderState();
}

class _HostGroupHeaderState extends ConsumerState<HostGroupHeader> {
  bool _editing = false;
  late final _text = TextEditingController(text: widget.name);
  final _focus = FocusNode(debugLabel: 'group name');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) unawaited(_commit());
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (!widget.renamable || widget.groupId == null) return;
    setState(() {
      _editing = true;
      _text.value = TextEditingValue(
        text: widget.name,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: widget.name.length,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _commit() async {
    final name = _text.text.trim();
    setState(() => _editing = false);
    if (name.isEmpty || name == widget.name || widget.groupId == null) return;
    await ref.read(hostsProvider.notifier).renameGroup(widget.groupId!, name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final collapsed = isGroupCollapsed(ref, widget.groupKey);
    return DragTarget<HostDrag>(
      onWillAcceptWithDetails: (details) =>
          details.data.host.groupId != widget.groupId,
      onAcceptWithDetails: (details) =>
          unawaited(moveHostToGroup(ref, details.data.host, widget.groupId)),
      builder: (context, candidates, _) {
        final dropping = candidates.isNotEmpty;
        return Container(
          margin: EdgeInsets.only(top: widget.dense ? space.lg : space.xl),
          padding: EdgeInsets.only(left: space.xs, right: space.sm),
          height: sizes.touch ? sizes.touchTarget : sizes.rowCompact,
          decoration: BoxDecoration(
            color: dropping ? colors.accentWash : colors.transparent,
            borderRadius: context.radii.smAll,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: context.radii.smAll,
            border: Border.all(
              color: dropping ? colors.accent : colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _editing
                    ? Align(
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.escape,
                            ): () {
                              _text.text = widget.name;
                              _focus.unfocus();
                            },
                          },
                          child: TextField(
                            controller: _text,
                            focusNode: _focus,
                            style: context.type.caption.copyWith(
                              color: colors.textPrimary,
                            ),
                            cursorColor: colors.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: space.xs,
                                vertical: space.xs,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: context.radii.xsAll,
                                borderSide: BorderSide(color: colors.accent),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: context.radii.xsAll,
                                borderSide: BorderSide(color: colors.accent),
                              ),
                            ),
                            onSubmitted: (_) => _focus.unfocus(),
                          ),
                        ),
                      )
                    : Semantics(
                        header: true,
                        expanded: !collapsed,
                        hint: widget.renamable && widget.groupId != null
                            ? 'Double-click to rename'
                            : null,
                        child: WgPressable(
                          semanticLabel:
                              '${widget.name}, ${Format.plural(widget.count, 'host')}, ${collapsed ? 'collapsed' : 'expanded'}',
                          borderRadius: context.radii.xsAll,
                          onPressed: () => toggleGroup(ref, widget.groupKey),
                          onDoubleTap: _startEditing,
                          builder: (context, state) => Row(
                            children: [
                              Icon(
                                collapsed
                                    ? WgIcons.chevronRight
                                    : WgIcons.chevronDown,
                                size: sizes.icon,
                                color: colors.textMuted,
                              ),
                              SizedBox(width: space.xs),
                              Flexible(
                                child: Text(
                                  widget.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.type.caption.copyWith(
                                    color: state.highlighted
                                        ? colors.textPrimary
                                        : colors.textMuted,
                                  ),
                                ),
                              ),
                              if (collapsed) ...[
                                SizedBox(width: space.xs),
                                Text(
                                  '${widget.count}',
                                  style: context.type.caption.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
              if (widget.trailing != null) Align(child: widget.trailing),
            ],
          ),
        );
      },
    );
  }
}
