import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_editor_dialog.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_permissions_dialog.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_preview_dialog.dart';
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
