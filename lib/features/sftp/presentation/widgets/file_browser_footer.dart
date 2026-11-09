import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class FileBrowserFooter extends StatelessWidget {
  const new({
    required this.total,
    required this.selected,
    super.key,
    this.copyLabel,
    this.onCopy,
  });

  final int total;
  final List<FileEntry> selected;
  final String? copyLabel;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bytes = selected
        .where((entry) => !entry.isDirectory)
        .fold<int>(0, (sum, entry) => sum + entry.size);
    final text = selected.isEmpty
        ? Format.plural(total, 'item')
        : '${selected.length} of $total selected${bytes > 0 ? ' · ${Format.bytes(bytes)}' : ''}';
    return Container(
      height: context.sizes.rowCompact,
      padding: EdgeInsets.symmetric(horizontal: context.space.sm),
      decoration: BoxDecoration(
        color: colors.canvasDeep,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.monoSmall.copyWith(color: colors.textMuted),
            ),
          ),
          if (copyLabel != null)
            WgButton.ghost(
              label: 'Copy to $copyLabel',
              icon: WgIcons.arrowRight,
              shortcut: const SingleActivator(LogicalKeyboardKey.f5),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}
