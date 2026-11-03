import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/transfers/presentation/transfer_actions.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

@immutable
class DropHint {
  const new({
    required this.folder,
    required this.hostLabel,
    required this.defaultMove,
    this.verb,
  });

  final String folder;
  final String hostLabel;
  final bool defaultMove;
  final String? verb;
}

final dropHintProvider = NotifierProvider<DropHintController, DropHint?>(
  DropHintController.new,
);

class DropHintController extends Notifier<DropHint?> {
  @override
  DropHint? build() => null;

  void show(DropHint hint) {
    if (state?.folder == hint.folder &&
        state?.hostLabel == hint.hostLabel &&
        state?.defaultMove == hint.defaultMove) {
      return;
    }
    state = hint;
  }

  void clear() => state = null;
}

class AltKey extends ValueNotifier<bool> {
  new _() : super(false) {
    HardwareKeyboard.instance.addHandler(_handle);
  }

  static final instance = AltKey._();

  bool _handle(KeyEvent event) {
    final pressed = HardwareKeyboard.instance.isAltPressed;
    if (pressed != value) value = pressed;
    return false;
  }

  static bool get pressed => HardwareKeyboard.instance.isAltPressed;
}

bool resolveMove({required bool defaultMove}) => defaultMove != AltKey.pressed;

class FileDragFeedback extends ConsumerWidget {
  const new({required this.payload, super.key});

  final FileDragPayload payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final hint = ref.watch(dropHintProvider);
    final count = payload.entries.length;
    final what = count == 1
        ? payload.entries.first.name
        : Format.plural(count, 'item');
    return Material(
      color: colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sizes.dragLabel),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: space.md,
            vertical: space.sm,
          ),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: context.radii.mdAll,
            border: Border.all(
              color: hint == null ? colors.hairlineStrong : colors.accent,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: space.lg,
                offset: Offset(0, space.xs),
              ),
            ],
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: AltKey.instance,
            builder: (context, _, _) {
              final move =
                  hint != null && resolveMove(defaultMove: hint.defaultMove);
              final verb = hint?.verb ?? (move ? 'Move' : 'Copy');
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    move ? WgIcons.move : WgIcons.copy,
                    size: context.sizes.icon,
                    color: hint == null ? colors.textMuted : colors.accentInk,
                  ),
                  SizedBox(width: space.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          what,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.label,
                        ),
                        Text(
                          hint == null
                              ? 'Drop on a folder, a files panel or a terminal'
                              : '$verb to ${hint.folder} on ${hint.hostLabel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class FileDropTarget extends ConsumerStatefulWidget {
  const new({
    required this.hostId,
    required this.hostLabel,
    required this.folder,
    required this.onDrop,
    required this.builder,
    super.key,
    this.verb,
    this.rejectFrom,
  });

  final String? hostId;
  final String hostLabel;
  final String? folder;
  final String? verb;
  final String? rejectFrom;
  final void Function(FileDragPayload payload, {required bool move}) onDrop;
  final Widget Function(BuildContext context, {required bool active}) builder;

  @override
  ConsumerState<FileDropTarget> createState() => _FileDropTargetState();
}

class _FileDropTargetState extends ConsumerState<FileDropTarget> {
  bool _active = false;

  bool _defaultMove(FileDragPayload payload) =>
      widget.verb == null && payload.hostId == widget.hostId;

  bool _accepts(FileDragPayload payload) {
    final folder = widget.folder;
    if (folder == null) return false;
    if (widget.rejectFrom != null &&
        payload.sourcePaneKey == widget.rejectFrom &&
        payload.hostId == widget.hostId) {
      return false;
    }
    if (payload.hostId != widget.hostId) return true;
    return payload.entries.every(
      (entry) => entry.path != folder && !_isParentOf(entry, folder),
    );
  }

  bool _isParentOf(FileEntry entry, String folder) =>
      entry.isDirectory && folder.startsWith('${entry.path}/');

  void _setActive(bool value) {
    if (_active == value || !mounted) return;
    setState(() => _active = value);
  }

  @override
  Widget build(BuildContext context) {
    final hints = ref.read(dropHintProvider.notifier);
    return DragTarget<FileDragPayload>(
      onWillAcceptWithDetails: (details) => _accepts(details.data),
      onMove: (details) {
        if (!_accepts(details.data)) return;
        _setActive(true);
        hints.show(
          DropHint(
            folder: widget.folder!,
            hostLabel: widget.hostLabel,
            defaultMove: _defaultMove(details.data),
            verb: widget.verb,
          ),
        );
      },
      onLeave: (_) {
        _setActive(false);
        hints.clear();
      },
      onAcceptWithDetails: (details) {
        _setActive(false);
        hints.clear();
        widget.onDrop(
          details.data,
          move:
              widget.verb == null &&
              resolveMove(defaultMove: _defaultMove(details.data)),
        );
      },
      builder: (context, _, _) => widget.builder(context, active: _active),
    );
  }
}

abstract final class FileDelivery {
  static Future<int> deliver(
    BuildContext context,
    WidgetRef ref, {
    required String? fromHostId,
    required List<FileEntry> entries,
    required String? toHostId,
    required String toDirectory,
    required bool move,
  }) async {
    final resolver = ref.read(endpointResolverProvider);
    final target = await resolver.resolve(toHostId);
    if (move && fromHostId == toHostId) {
      var moved = 0;
      for (final entry in entries) {
        final destination = target.paths.join(toDirectory, entry.name);
        if (destination == entry.path) continue;
        if (await target.exists(destination)) {
          throw FileOperationException(
            '${entry.name} already exists in $toDirectory',
          );
        }
        await target.rename(entry.path, destination);
        moved++;
      }
      return moved;
    }
    if (!context.mounted) return 0;
    return await TransferActions.copy(
      context,
      ref,
      fromHostId: fromHostId,
      entries: entries,
      toHostId: toHostId,
      toDirectory: toDirectory,
      join: target.paths.join,
      move: move,
    );
  }
}

class DragHoverSwitch extends StatefulWidget {
  const new({required this.onSwitch, required this.child, super.key});

  final VoidCallback onSwitch;
  final Widget child;

  @override
  State<DragHoverSwitch> createState() => _DragHoverSwitchState();
}

class _DragHoverSwitchState extends State<DragHoverSwitch> {
  Timer? _timer;

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delay = context.motion.hoverSwitch;
    return DragTarget<FileDragPayload>(
      onWillAcceptWithDetails: (_) {
        _timer ??= Timer(delay, () {
          _timer = null;
          widget.onSwitch();
        });
        return false;
      },
      onLeave: (_) => _cancel(),
      builder: (context, _, _) => widget.child,
    );
  }
}
