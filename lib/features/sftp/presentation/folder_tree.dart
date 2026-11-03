import 'dart:async';

import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';

class FolderTree extends StatefulWidget {
  const new({
    required this.endpoint,
    required this.current,
    required this.onOpen,
    required this.showHidden,
    super.key,
  });

  final FileEndpoint endpoint;
  final String current;
  final ValueChanged<String> onOpen;
  final bool showHidden;

  @override
  State<FolderTree> createState() => _FolderTreeState();
}

class _FolderTreeState extends State<FolderTree> {
  final Map<String, List<String>> _children = {};
  final Set<String> _expanded = {};
  final Set<String> _loading = {};
  final Set<String> _failed = {};
  String? _root;

  @override
  void initState() {
    super.initState();
    _reveal(widget.current);
  }

  @override
  void didUpdateWidget(FolderTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endpoint != widget.endpoint) {
      _children.clear();
      _expanded.clear();
      _failed.clear();
    }
    if (oldWidget.current != widget.current ||
        oldWidget.endpoint != widget.endpoint ||
        oldWidget.showHidden != widget.showHidden) {
      if (oldWidget.showHidden != widget.showHidden) _children.clear();
      _reveal(widget.current);
    }
  }

  void _reveal(String path) {
    final paths = widget.endpoint.paths;
    final parts = paths.split(path);
    if (parts.isEmpty) return;
    _root = parts.first;
    var cursor = '';
    for (final part in parts) {
      cursor = cursor.isEmpty ? part : paths.join(cursor, part);
      if (cursor != path) {
        _expanded.add(cursor);
        unawaited(_load(cursor));
      }
    }
    unawaited(_load(_root!));
    setState(() {});
  }

  Future<void> _load(String path) async {
    if (_children.containsKey(path) || _loading.contains(path)) return;
    _loading.add(path);
    try {
      final entries = await widget.endpoint.list(path);
      final folders = [
        for (final entry in entries)
          if (entry.isDirectory && (widget.showHidden || !entry.isHidden))
            entry.name,
      ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _children[path] = folders;
      _failed.remove(path);
    } on Object {
      _children[path] = const [];
      _failed.add(path);
    } finally {
      _loading.remove(path);
      if (mounted) setState(() {});
    }
  }

  void _toggle(String path) {
    setState(() {
      if (!_expanded.remove(path)) {
        _expanded.add(path);
        unawaited(_load(path));
      }
    });
  }

  List<(String, int)> _rows() {
    final root = _root;
    if (root == null) return const [];
    final paths = widget.endpoint.paths;
    final rows = <(String, int)>[];
    void walk(String path, int depth) {
      rows.add((path, depth));
      if (!_expanded.contains(path)) return;
      for (final name in _children[path] ?? const <String>[]) {
        walk(paths.join(path, name), depth + 1);
      }
    }

    walk(root, 0);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final rows = _rows();
    final paths = widget.endpoint.paths;
    return Semantics(
      container: true,
      label: 'Folder tree',
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: space.xs),
        itemCount: rows.length,
        itemExtent: sizes.rowCompact,
        itemBuilder: (context, index) {
          final (path, depth) = rows[index];
          final name = depth == 0 ? path : paths.basename(path);
          final open = _expanded.contains(path);
          final selected = path == widget.current;
          final known = _children[path];
          final leaf = known != null && known.isEmpty;
          return WgPressable(
            semanticLabel:
                '$name${selected ? ', current folder' : ''}${leaf
                    ? ''
                    : open
                    ? ', expanded'
                    : ', collapsed'}',
            selected: selected,
            onPressed: () {
              if (!_expanded.contains(path)) _toggle(path);
              widget.onOpen(path);
            },
            builder: (context, state) => Container(
              padding: EdgeInsets.only(
                left: space.xs + depth * sizes.treeIndent,
                right: space.sm,
              ),
              color: selected
                  ? colors.pressed
                  : state.highlighted
                  ? colors.raised
                  : colors.transparent,
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: sizes.icon + space.xs,
                    child: leaf
                        ? null
                        : WgPressable(
                            semanticLabel: open
                                ? 'Collapse $name'
                                : 'Expand $name',
                            onPressed: () => _toggle(path),
                            borderRadius: context.radii.xsAll,
                            builder: (context, _) => Icon(
                              open ? WgIcons.chevronDown : WgIcons.chevronRight,
                              size: sizes.icon,
                              color: colors.textMuted,
                            ),
                          ),
                  ),
                  Icon(
                    open ? WgIcons.folderOpen : WgIcons.folder,
                    size: sizes.icon,
                    color: _failed.contains(path)
                        ? colors.textMuted
                        : colors.textSecondary,
                  ),
                  SizedBox(width: space.sm),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.label.copyWith(
                        color: selected
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
