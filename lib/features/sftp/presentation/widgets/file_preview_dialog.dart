import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/presentation/file_browser_constants.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class FilePreviewDialog extends StatefulWidget {
  const new({required this.endpoint, required this.entry, super.key});

  final FileEndpoint endpoint;
  final FileEntry entry;

  @override
  State<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<FilePreviewDialog> {
  late final Future<Uint8List> _bytes = widget.endpoint.readAll(
    widget.entry.path,
    maxBytes: widget.entry.looksLikeImage
        ? FileBrowserConstants.imagePreviewMaxBytes
        : FileBrowserConstants.textPreviewMaxBytes,
  );

  @override
  Widget build(BuildContext context) => WgDialog(
    title: widget.entry.name,
    wide: true,
    scrollable: false,
    actions: [
      WgButton.ghost(
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height *
            FileBrowserConstants.dialogHeightFactor,
      ),
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return WgInlineMessage(
              tone: WgTone.negative,
              title: 'Preview is not available',
              message: snapshot.error.toString(),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const WgSkeletonList(
              rows: FileBrowserConstants.previewSkeletonRows,
              label: 'Loading preview',
            );
          }
          if (widget.entry.looksLikeImage) {
            return Semantics(
              image: true,
              label: widget.entry.name,
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            );
          }
          final text = utf8.decode(bytes, allowMalformed: true);
          if (text.contains('\u0000')) {
            return const WgInlineMessage(
              message: 'This looks like a binary file, so there is nothing to show as text.',
            );
          }
          return Container(
            decoration: BoxDecoration(
              color: context.colors.canvasDeep,
              borderRadius: context.radii.mdAll,
              border: Border.all(color: context.colors.hairline),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.space.md),
              child: SelectableText(text, style: context.type.mono),
            ),
          );
        },
      ),
    ),
  );
}
