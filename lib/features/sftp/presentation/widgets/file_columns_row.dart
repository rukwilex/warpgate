import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/application/file_column.dart';
import 'package:warpgate/features/sftp/utils/file_column_text.dart';
import 'package:warpgate/features/sftp/utils/file_icon.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class FileColumnsRow extends StatelessWidget {
  const new({
    required this.entry,
    required this.columns,
    required this.widthOf,
    required this.selected,
    required this.focused,
    required this.dropping,
    required this.cut,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    super.key,
  });

  final FileEntry entry;
  final List<FileColumn> columns;
  final double Function(FileColumn column) widthOf;
  final bool selected;
  final bool focused;
  final bool dropping;
  final bool cut;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final tabular = context.type.caption.copyWith(
      color: colors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String value(FileColumn column) => fileColumnText(entry, column);
    final meta = [
      for (final column in columns)
        if (value(column).isNotEmpty) '${column.label} ${value(column)}',
    ].join(', ');
    return GestureDetector(
      excludeFromSemantics: true,
      onSecondaryTapDown: (details) => onMenu(details.globalPosition),
      child: WgPressable(
        semanticLabel:
            '${entry.isDirectory ? 'Folder' : 'File'} ${entry.name}${meta.isEmpty ? '' : ', $meta'}',
        selected: selected,
        onPressed: onTap,
        builder: (context, state) => Container(
          padding: EdgeInsets.symmetric(horizontal: space.sm),
          decoration: BoxDecoration(
            color: dropping
                ? colors.accentWash
                : selected
                ? colors.pressed
                : state.highlighted
                ? colors.raised
                : colors.transparent,
            border: Border.all(
              color: dropping
                  ? colors.accent
                  : focused && selected
                  ? colors.hairlineStrong
                  : colors.transparent,
              width: sizes.hairline,
            ),
          ),
          child: IconTheme.merge(
            data: const IconThemeData(),
            child: Row(
              children: [
                Icon(
                  fileIcon(entry),
                  size: sizes.icon,
                  color: entry.isDirectory && !cut
                      ? colors.textSecondary
                      : colors.textMuted,
                ),
                SizedBox(width: space.sm),
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.label.copyWith(
                      color: cut ? colors.textMuted : colors.textPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                for (final column in columns)
                  SizedBox(
                    width: widthOf(column),
                    child: Padding(
                      padding: EdgeInsets.only(left: sizes.splitterHit),
                      child: Text(
                        value(column),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: column == FileColumn.size
                            ? TextAlign.end
                            : TextAlign.start,
                        style: column == FileColumn.permissions
                            ? context.type.monoSmall.copyWith(
                                color: colors.textSecondary,
                              )
                            : tabular,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
