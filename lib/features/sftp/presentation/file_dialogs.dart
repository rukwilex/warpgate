import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/presentation/file_browser_constants.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_editor_dialog.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_permissions_dialog.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_preview_dialog.dart';
import 'package:warpgate/features/sftp/utils/folder_title.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

Future<void> showFilePreview(
  BuildContext context,
  FileEndpoint endpoint,
  FileEntry entry,
) => showDialog<void>(
  context: context,
  builder: (_) => FilePreviewDialog(endpoint: endpoint, entry: entry),
);

Future<bool> showFileEditor(
  BuildContext context,
  FileEndpoint endpoint,
  FileEntry entry,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FileEditorDialog(endpoint: endpoint, entry: entry),
    ) ??
    false;

Future<int?> showPermissionsDialog(BuildContext context, FileEntry entry) =>
    showDialog<int>(
      context: context,
      builder: (_) => FilePermissionsDialog(entry: entry),
    );

Future<void> showProperties(
  BuildContext context,
  FileEndpoint endpoint,
  FileEntry entry,
) => showDialog<void>(
  context: context,
  builder: (context) => WgDialog(
    title: entry.name,
    actions: [
      WgButton.ghost(
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in [
          ('Location', endpoint.label),
          ('Path', entry.path),
          (
            'Kind',
            entry.isDirectory
                ? 'Folder'
                : entry.isLink
                ? 'Link'
                : 'File',
          ),
          if (!entry.isDirectory)
            ('Size', '${Format.bytes(entry.size)} (${entry.size} bytes)'),
          if (entry.modified != null)
            ('Modified', Format.time(entry.modified!)),
          if (entry.mode != null)
            (
              'Permissions',
              '${Format.mode(entry.mode!)}  ${Format.octal(entry.mode!)}',
            ),
        ])
          Padding(
            padding: EdgeInsets.only(bottom: context.space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.type.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                SelectableText(value, style: context.type.mono),
              ],
            ),
          ),
      ],
    ),
  ),
);

Future<String?> showQuickJump(
  BuildContext context, {
  required List<String> favorites,
  required List<String> recents,
  required List<String> subfolders,
  required String hostLabel,
}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close',
  barrierColor: context.colors.scrim,
  transitionDuration: context.motion.fast,
  pageBuilder: (dialogContext, _, _) => WgFloatingPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.space.lg,
            context.space.md,
            context.space.lg,
            0,
          ),
          child: Semantics(
            header: true,
            child: Text(
              'Jump to a folder on $hostLabel',
              style: context.type.label,
            ),
          ),
        ),
        WgSearchList<String>(
          placeholder: 'Folder name or path',
          emptyTitle: 'No folder matches',
          emptyBody: 'Star a folder to keep it here. Folders you open show up as recent.',
          onCancel: () => Navigator.of(dialogContext).pop(),
          onSelected: (value) => Navigator.of(dialogContext).pop(value),
          items: (query) {
            final lower = query.toLowerCase();
            bool matches(String path) =>
                lower.isEmpty || path.toLowerCase().contains(lower);
            final seen = <String>{};
            WgSearchItem<String>? item(String path, String section) {
              if (!matches(path) || !seen.add(path)) return null;
              return WgSearchItem<String>(
                value: path,
                title: folderTitle(path),
                subtitle: path,
                section: section,
                leading: Icon(
                  section == FileBrowserConstants.favoritesSection
                      ? WgIcons.star
                      : WgIcons.folder,
                ),
              );
            }

            return [
              for (final path in favorites)
                ?item(path, FileBrowserConstants.favoritesSection),
              for (final path in recents)
                ?item(path, FileBrowserConstants.recentSection),
              for (final path in subfolders)
                ?item(path, FileBrowserConstants.subfolderSection),
            ];
          },
        ),
      ],
    ),
  ),
);
