import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/application/path_bar_controller.dart';
import 'package:warpgate/features/sftp/presentation/file_browser_constants.dart';
import 'package:warpgate/features/sftp/presentation/widgets/path_bar_suggestions.dart';
import 'package:warpgate/features/sftp/utils/path_completion.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class PathBar extends StatefulWidget {
  const new({
    required this.endpoint,
    required this.path,
    required this.onNavigate,
    super.key,
    this.controller,
  });

  final FileEndpoint? endpoint;
  final String? path;
  final ValueChanged<String> onNavigate;
  final PathBarController? controller;

  @override
  State<PathBar> createState() => _PathBarState();
}

class _PathBarState extends State<PathBar> {
  final _text = TextEditingController();
  final _focus = FocusNode(debugLabel: 'path field');
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  bool _editing = false;
  List<String> _suggestions = const [];
  int _highlight = -1;
  String? _listedDirectory;
  List<String> _folders = const [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onRequest);
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _stopEditing();
    });
  }

  @override
  void didUpdateWidget(PathBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onRequest);
      widget.controller?.addListener(_onRequest);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onRequest);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onRequest() {
    if (widget.controller?.takeEditRequest() ?? false) _startEditing();
  }

  void _startEditing() {
    final path = widget.path;
    if (path == null || widget.endpoint == null) return;
    final separator = widget.endpoint!.paths.separator;
    final text = path.endsWith(separator) ? path : '$path$separator';
    setState(() {
      _editing = true;
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    unawaited(_refreshSuggestions());
  }

  void _stopEditing() {
    _portal.hide();
    if (!mounted) return;
    setState(() {
      _editing = false;
      _suggestions = const [];
      _highlight = -1;
    });
  }

  Future<List<String>> _foldersIn(String directory) async {
    if (directory == _listedDirectory) return _folders;
    final endpoint = widget.endpoint;
    if (endpoint == null) return const [];
    try {
      final resolved = await endpoint.resolve(directory);
      final entries = await endpoint.list(resolved);
      _listedDirectory = directory;
      _folders = [
        for (final entry in entries)
          if (entry.isDirectory) entry.name,
      ];
    } on Object {
      _listedDirectory = directory;
      _folders = const [];
    }
    return _folders;
  }

  Future<void> _refreshSuggestions() async {
    final endpoint = widget.endpoint;
    if (endpoint == null) return;
    final generation = ++_generation;
    final (directory, prefix) = PathCompletion.split(
      _text.text,
      endpoint.paths,
    );
    final folders = await _foldersIn(
      directory.isEmpty ? (widget.path ?? '~') : directory,
    );
    if (!mounted || generation != _generation || !_editing) return;
    final found = PathCompletion.matches(folders, prefix);
    setState(() {
      _suggestions = found.take(FileBrowserConstants.suggestionLimit).toList();
      _highlight = -1;
    });
    if (_suggestions.isEmpty) {
      _portal.hide();
    } else {
      _portal.show();
    }
  }

  Future<void> _tabComplete() async {
    final endpoint = widget.endpoint;
    if (endpoint == null) return;
    final (directory, _) = PathCompletion.split(_text.text, endpoint.paths);
    final folders = await _foldersIn(
      directory.isEmpty ? (widget.path ?? '~') : directory,
    );
    final next = PathCompletion.complete(_text.text, folders, endpoint.paths);
    if (next == null || !mounted) return;
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    unawaited(_refreshSuggestions());
  }

  void _accept(String name) {
    final endpoint = widget.endpoint;
    if (endpoint == null) return;
    final (directory, _) = PathCompletion.split(_text.text, endpoint.paths);
    final separator = endpoint.paths.separator;
    final base = directory == separator
        ? separator
        : directory.isEmpty
        ? ''
        : '$directory$separator';
    final next = '$base$name$separator';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    unawaited(_refreshSuggestions());
  }

  Future<void> _submit() async {
    final endpoint = widget.endpoint;
    if (endpoint == null) return;
    if (_highlight >= 0 && _highlight < _suggestions.length) {
      _accept(_suggestions[_highlight]);
      return;
    }
    var target = _text.text.trim();
    final separator = endpoint.paths.separator;
    if (target.length > 1 && target.endsWith(separator)) {
      target = target.substring(0, target.length - 1);
    }
    _stopEditing();
    if (target.isEmpty) return;
    if (!endpoint.paths.isAbsolute(target) && !target.startsWith('~')) {
      target = endpoint.paths.join(widget.path ?? '', target);
    }
    widget.onNavigate(endpoint.paths.normalize(target));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      unawaited(_tabComplete());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _stopEditing();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _suggestions.isNotEmpty) {
      setState(() => _highlight = (_highlight + 1) % _suggestions.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && _suggestions.isNotEmpty) {
      setState(
        () => _highlight = _highlight <= 0
            ? _suggestions.length - 1
            : _highlight - 1,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<(String, String)> _crumbs() {
    final endpoint = widget.endpoint;
    final path = widget.path;
    if (endpoint == null || path == null) return const [];
    final crumbs = <(String, String)>[];
    var cursor = '';
    for (final part in endpoint.paths.split(path)) {
      cursor = cursor.isEmpty ? part : endpoint.paths.join(cursor, part);
      crumbs.add((part, cursor));
    }
    return crumbs;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final height = sizes.rowCompact - space.xs;
    if (_editing) {
      return CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => PathBarSuggestions(
            link: _link,
            suggestions: _suggestions,
            highlight: _highlight,
            onPick: _accept,
          ),
          child: Focus(
            onKeyEvent: _onKey,
            skipTraversal: true,
            child: SizedBox(
              height: height,
              child: Semantics(
                textField: true,
                label: 'Folder path',
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  style: context.type.monoSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                  cursorColor: colors.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: colors.canvas,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: space.sm,
                      vertical: space.xs,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: context.radii.smAll,
                      borderSide: BorderSide(color: colors.accent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: context.radii.smAll,
                      borderSide: BorderSide(color: colors.accent),
                    ),
                  ),
                  onChanged: (_) => unawaited(_refreshSuggestions()),
                  onSubmitted: (_) => unawaited(_submit()),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final crumbs = _crumbs();
    return Semantics(
      button: true,
      label: 'Edit folder path ${widget.path ?? ''}',
      onTap: _startEditing,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _startEditing,
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    children: [
                      for (final (index, crumb) in crumbs.indexed) ...[
                        if (index > 0)
                          Icon(
                            WgIcons.chevronRight,
                            size: sizes.icon,
                            color: colors.textMuted,
                          ),
                        WgPressable(
                          semanticLabel: 'Go to ${crumb.$2}',
                          onPressed: index == crumbs.length - 1
                              ? _startEditing
                              : () => widget.onNavigate(crumb.$2),
                          borderRadius: context.radii.xsAll,
                          builder: (context, state) => Padding(
                            padding: EdgeInsets.symmetric(horizontal: space.xs),
                            child: Center(
                              child: Text(
                                crumb.$1,
                                style: context.type.monoSmall.copyWith(
                                  color:
                                      index == crumbs.length - 1 ||
                                          state.highlighted
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
