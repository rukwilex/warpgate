import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';

abstract final class PathCompletion {
  static (String, String) split(String input, p.Context paths) {
    final separator = paths.separator;
    final index = input.lastIndexOf(separator);
    if (index < 0) return ('', input);
    final directory = index == 0 ? separator : input.substring(0, index);
    return (directory, input.substring(index + 1));
  }

  static List<String> matches(Iterable<String> names, String prefix) {
    final lower = prefix.toLowerCase();
    final exact = [
      for (final name in names)
        if (name.startsWith(prefix)) name,
    ];
    if (exact.isNotEmpty || prefix.isEmpty) return exact..sort();
    return [
      for (final name in names)
        if (name.toLowerCase().startsWith(lower)) name,
    ]..sort();
  }

  static String commonPrefix(List<String> names) {
    if (names.isEmpty) return '';
    var prefix = names.first;
    for (final name in names.skip(1)) {
      var i = 0;
      while (i < prefix.length && i < name.length && prefix[i] == name[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
    }
    return prefix;
  }

  static String? complete(String input, List<String> folders, p.Context paths) {
    final (directory, prefix) = split(input, paths);
    final found = matches(folders, prefix);
    if (found.isEmpty) return null;
    final base = directory == paths.separator
        ? paths.separator
        : directory.isEmpty
        ? ''
        : '$directory${paths.separator}';
    if (found.length == 1) return '$base${found.single}${paths.separator}';
    final common = commonPrefix(found);
    if (common.length <= prefix.length) return null;
    return '$base$common';
  }
}

class PathBarController extends ChangeNotifier {
  bool _editRequested = false;

  void edit() {
    _editRequested = true;
    notifyListeners();
  }

  bool takeEditRequest() {
    final value = _editRequested;
    _editRequested = false;
    return value;
  }
}

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
      _suggestions = found.take(50).toList();
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
          overlayChildBuilder: (context) => _Suggestions(
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

class _Suggestions extends StatelessWidget {
  const new({
    required this.link,
    required this.suggestions,
    required this.highlight,
    required this.onPick,
  });

  final LayerLink link;
  final List<String> suggestions;
  final int highlight;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final width = link.leaderSize?.width ?? sizes.completionList;
    return CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.bottomLeft,
      offset: Offset(0, space.xs),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: Material(
            color: colors.raised,
            borderRadius: context.radii.mdAll,
            child: Container(
              constraints: BoxConstraints(maxHeight: sizes.completionList),
              decoration: BoxDecoration(
                borderRadius: context.radii.mdAll,
                border: Border.all(color: colors.hairlineStrong),
              ),
              child: ListView.builder(
                padding: EdgeInsets.all(space.xs),
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) => WgPressable(
                  semanticLabel: suggestions[index],
                  selected: index == highlight,
                  borderRadius: context.radii.smAll,
                  onPressed: () => onPick(suggestions[index]),
                  builder: (context, state) => Container(
                    height: sizes.rowCompact,
                    padding: EdgeInsets.symmetric(horizontal: space.sm),
                    decoration: BoxDecoration(
                      color: index == highlight || state.highlighted
                          ? colors.pressed
                          : colors.transparent,
                      borderRadius: context.radii.smAll,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          WgIcons.folder,
                          size: sizes.icon,
                          color: colors.textSecondary,
                        ),
                        SizedBox(width: space.sm),
                        Expanded(
                          child: Text(
                            suggestions[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.monoSmall,
                          ),
                        ),
                      ],
                    ),
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
