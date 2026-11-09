import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/application/file_column.dart';
import 'package:warpgate/features/sftp/application/file_sort_key.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_column_resize_handle.dart';

class FileColumnsHeader extends StatelessWidget {
  const new({
    required this.columns,
    required this.widthOf,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onResize,
    super.key,
  });

  final List<FileColumn> columns;
  final double Function(FileColumn column) widthOf;
  final SortKey sort;
  final bool ascending;
  final ValueChanged<SortKey> onSort;
  final void Function(FileColumn column, double width) onResize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    Widget cell(String label, SortKey key, {bool end = false}) {
      final active = sort == key;
      return WgPressable(
        semanticLabel:
            'Sort by $label${active ? (ascending ? ', ascending' : ', descending') : ''}',
        onPressed: () => onSort(key),
        builder: (context, state) => Row(
          mainAxisAlignment: end
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.caption.copyWith(
                  color: active || state.highlighted
                      ? colors.textPrimary
                      : colors.textMuted,
                ),
              ),
            ),
            if (active) ...[
              SizedBox(width: space.xs),
              Icon(
                ascending ? WgIcons.sortAsc : WgIcons.sortDesc,
                size: sizes.icon,
                color: colors.textSecondary,
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      height: sizes.rowCompact,
      padding: EdgeInsets.symmetric(horizontal: space.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: sizes.icon + space.sm),
          Expanded(child: cell('Name', SortKey.name)),
          for (final column in columns)
            SizedBox(
              width: widthOf(column),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FileColumnResizeHandle(
                    label: 'Resize ${column.label} column',
                    onDrag: (delta) => onResize(
                      column,
                      (widthOf(column) - delta).clamp(
                        sizes.columnMin,
                        sizes.columnName * 2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: cell(
                      column.label,
                      column.sort,
                      end: column == FileColumn.size,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
