import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/presentation/file_drop.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class TerminalDropZone extends StatelessWidget {
  const new({
    required this.session,
    required this.hostId,
    required this.hostLabel,
    required this.folder,
    required this.osDrop,
    required this.onOsDragChanged,
    required this.onDrop,
    required this.onOsDrop,
    required this.child,
    super.key,
  });

  final TerminalSession session;
  final String? hostId;
  final String hostLabel;
  final String Function() folder;
  final bool osDrop;
  final ValueChanged<bool> onOsDragChanged;
  final void Function(List<FileEntry> entries, String? fromHostId) onDrop;
  final ValueChanged<List<String>> onOsDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget zone = ValueListenableBuilder<String?>(
      valueListenable: session.cwd,
      builder: (context, cwd, _) => FileDropTarget(
        hostId: hostId,
        hostLabel: hostLabel,
        folder: folder(),
        verb: 'Copy',
        onDrop: (payload, {required move}) =>
            onDrop(payload.entries, payload.hostId),
        builder: (context, {required active}) => Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (active || osDrop)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accentWash,
                    border: Border.all(
                      color: colors.accent,
                      width: context.sizes.markerBar,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (PlatformInfo.isDesktop) {
      zone = DropTarget(
        onDragEntered: (_) => onOsDragChanged(true),
        onDragExited: (_) => onOsDragChanged(false),
        onDragDone: (details) {
          onOsDragChanged(false);
          onOsDrop([for (final file in details.files) file.path]);
        },
        child: zone,
      );
    }
    return zone;
  }
}
