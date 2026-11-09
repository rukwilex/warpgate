import 'package:flutter/material.dart';
import 'package:warpgate/features/sftp/application/terminal_link.dart';
import 'package:warpgate/features/sftp/presentation/file_browser.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

class TerminalFilesBrowser extends StatelessWidget {
  const new({
    required this.paneId,
    required this.focusNode,
    required this.content,
    required this.session,
    required this.onFilesChanged,
    required this.cdHere,
    this.onInstallHook,
    super.key,
  });

  final String paneId;
  final FocusNode focusNode;
  final TerminalContent content;
  final TerminalSession session;
  final ValueChanged<AttachedFiles Function(AttachedFiles files)> onFilesChanged;
  final ValueChanged<String> cdHere;
  final VoidCallback? onInstallHook;

  @override
  Widget build(BuildContext context) {
    final files = content.files;
    return Focus(
      focusNode: focusNode,
      skipTraversal: true,
      child: FileBrowser(
        key: ValueKey('$paneId-files'),
        side: SftpSide(
          hostId: content.hostId,
          path: files.path ?? session.cwd.value ?? content.directory,
        ),
        paneKey: '$paneId-files',
        showTree: files.tree,
        onTreeChanged: (tree) =>
            onFilesChanged((files) => files.copyWith(tree: tree)),
        onSideChanged: (side) =>
            onFilesChanged((files) => files.copyWith(path: () => side.path)),
        link: TerminalLink(
          cwd: session.cwd,
          follow: files.follow,
          onFollow: (follow) =>
              onFilesChanged((files) => files.copyWith(follow: follow)),
          cdHere: cdHere,
          onInstallHook: onInstallHook,
        ),
      ),
    );
  }
}
