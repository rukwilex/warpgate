import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

enum SortKey { name, size, modified, permissions, owner }

enum FileColumn {
  size('Size', SortKey.size),
  modified('Modified', SortKey.modified),
  permissions('Permissions', SortKey.permissions),
  owner('Owner', SortKey.owner);

  new(this.label, this.sort);

  final String label;
  final SortKey sort;

  double defaultWidth(WgSizes sizes) => switch (this) {
    FileColumn.size => sizes.columnSize,
    FileColumn.modified => sizes.columnModified,
    FileColumn.permissions => sizes.columnPermissions,
    FileColumn.owner => sizes.columnOwner,
  };
}

abstract final class FileSorting {
  static int compare(
    FileEntry a,
    FileEntry b,
    SortKey key, {
    required bool ascending,
  }) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    final result = switch (key) {
      SortKey.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      SortKey.size => a.size.compareTo(b.size),
      SortKey.modified => (a.modified ?? DateTime(0)).compareTo(
        b.modified ?? DateTime(0),
      ),
      SortKey.permissions => (a.mode ?? 0).compareTo(b.mode ?? 0),
      SortKey.owner => (a.owner ?? '').compareTo(b.owner ?? ''),
    };
    final tieBroken = result == 0
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : result;
    return ascending ? tieBroken : -tieBroken;
  }

  static List<FileEntry> sorted(
    Iterable<FileEntry> entries,
    SortKey key, {
    required bool ascending,
  }) {
    final keyed =
        [for (final entry in entries) (entry, entry.name.toLowerCase())]
          ..sort((x, y) {
            final a = x.$1;
            final b = y.$1;
            if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
            final result = switch (key) {
              SortKey.name => x.$2.compareTo(y.$2),
              SortKey.size => a.size.compareTo(b.size),
              SortKey.modified => (a.modified ?? DateTime(0)).compareTo(
                b.modified ?? DateTime(0),
              ),
              SortKey.permissions => (a.mode ?? 0).compareTo(b.mode ?? 0),
              SortKey.owner => (a.owner ?? '').compareTo(b.owner ?? ''),
            };
            final tieBroken = result == 0 ? x.$2.compareTo(y.$2) : result;
            return ascending ? tieBroken : -tieBroken;
          });
    return [for (final item in keyed) item.$1];
  }

  static List<FileColumn> visible({
    required double available,
    required double nameMin,
    required double Function(FileColumn column) widthOf,
  }) {
    final columns = [...FileColumn.values];
    double used() => columns.fold(nameMin, (sum, c) => sum + widthOf(c));
    while (columns.isNotEmpty && used() > available) {
      columns.removeLast();
    }
    return columns;
  }
}

IconData fileIcon(FileEntry entry) {
  if (entry.isDirectory) return WgIcons.folder;
  if (entry.isLink) return WgIcons.link;
  if (entry.looksLikeImage) return WgIcons.image;
  if (entry.looksLikeText) return WgIcons.fileText;
  return WgIcons.file;
}

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
            _Header(
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
                    _Row(
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

class _Header extends StatelessWidget {
  const new({
    required this.columns,
    required this.widthOf,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onResize,
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
                  _ResizeHandle(
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

class _ResizeHandle extends StatefulWidget {
  const new({required this.label, required this.onDrag});

  final String label;
  final ValueChanged<double> onDrag;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sizes = context.sizes;
    final colors = context.colors;
    return Semantics(
      label: widget.label,
      slider: true,
      onIncrease: () => widget.onDrag(-sizes.treeIndent),
      onDecrease: () => widget.onDrag(sizes.treeIndent),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
          child: SizedBox(
            width: sizes.splitterHit,
            child: Center(
              child: Container(
                width: sizes.hairline,
                height: sizes.icon,
                color: _hovered ? colors.accent : colors.hairline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
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
    String value(FileColumn column) => switch (column) {
      FileColumn.size => entry.isDirectory ? '' : Format.bytes(entry.size),
      FileColumn.modified =>
        entry.modified == null ? '' : Format.time(entry.modified!),
      FileColumn.permissions => entry.permissions,
      FileColumn.owner => entry.owner ?? '',
    };
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

bool isTypeAheadKey(KeyEvent event) {
  final character = event.character;
  if (character == null || character.isEmpty) return false;
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isMetaPressed ||
      keyboard.isControlPressed ||
      keyboard.isAltPressed) {
    return false;
  }
  final code = character.codeUnitAt(0);
  return code > 32 && code != 127;
}
