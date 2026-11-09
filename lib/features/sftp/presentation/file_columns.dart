import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/application/file_column.dart';
import 'package:warpgate/features/sftp/application/file_sort_key.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_columns_header.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_columns_row.dart';
import 'package:warpgate/features/sftp/utils/file_sorting.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

typedef RowWrapper = Widget Function(FileEntry entry, Widget row);

class FileColumnsView extends StatelessWidget {
  const new({
    required this.entries,
    required this.selected,
    required this.focusedPath,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.widths,
    required this.onResize,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    required this.wrap,
    required this.scroll,
    super.key,
    this.dropFolder,
    this.cutPaths = const {},
  });

  final List<FileEntry> entries;
  final Set<String> selected;
  final String? focusedPath;
  final SortKey sort;
  final bool ascending;
  final ValueChanged<SortKey> onSort;
  final Map<String, double> widths;
  final void Function(FileColumn column, double width) onResize;
  final ValueChanged<FileEntry> onTap;
  final ValueChanged<FileEntry> onOpen;
  final void Function(Offset position, FileEntry entry) onMenu;
  final RowWrapper wrap;
  final ScrollController scroll;
  final String? dropFolder;
  final Set<String> cutPaths;

  @override
  Widget build(BuildContext context) {
    final sizes = context.sizes;
    final space = context.space;
    double widthOf(FileColumn column) =>
        widths[column.name] ?? column.defaultWidth(sizes);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = FileSorting.visible(
          available: constraints.maxWidth - space.sm * 2,
          nameMin: sizes.columnName,
          widthOf: widthOf,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FileColumnsHeader(
              columns: columns,
              widthOf: widthOf,
              sort: sort,
              ascending: ascending,
              onSort: onSort,
              onResize: onResize,
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemExtent: sizes.rowCompact,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return wrap(
                    entry,
                    FileColumnsRow(
                      entry: entry,
                      columns: columns,
                      widthOf: widthOf,
                      selected: selected.contains(entry.path),
                      focused: entry.path == focusedPath,
                      dropping: entry.path == dropFolder,
                      cut: cutPaths.contains(entry.path),
                      onTap: () => onTap(entry),
                      onOpen: () => onOpen(entry),
                      onMenu: (position) => onMenu(position, entry),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
