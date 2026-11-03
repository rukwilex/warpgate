import 'dart:async';

import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/host_picker.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/application/file_places.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/sftp/presentation/file_columns.dart';
import 'package:warpgate/features/sftp/presentation/file_dialogs.dart';
import 'package:warpgate/features/sftp/presentation/file_drop.dart';
import 'package:warpgate/features/sftp/presentation/folder_tree.dart';
import 'package:warpgate/features/sftp/presentation/path_bar.dart';
import 'package:warpgate/features/shell/presentation/prompts.dart';
import 'package:warpgate/features/transfers/presentation/transfer_actions.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

export 'package:warpgate/features/sftp/presentation/file_columns.dart'
    show SortKey;

enum ViewMode { list, grid }

class TerminalLink {
  const new({
    required this.cwd,
    required this.follow,
    required this.onFollow,
    required this.cdHere,
    this.onInstallHook,
  });

  final ValueListenable<String?> cwd;
  final bool follow;
  final ValueChanged<bool> onFollow;
  final ValueChanged<String> cdHere;
  final VoidCallback? onInstallHook;
}

class FileBrowser extends ConsumerStatefulWidget {
  const new({
    required this.side,
    required this.paneKey,
    required this.onSideChanged,
    super.key,
    this.copyTarget,
    this.copyLabel,
    this.link,
    this.showTree = false,
    this.onTreeChanged,
  });

  final SftpSide side;
  final String paneKey;
  final ValueChanged<SftpSide> onSideChanged;
  final SftpSide? copyTarget;
  final String? copyLabel;
  final TerminalLink? link;
  final bool showTree;
  final ValueChanged<bool>? onTreeChanged;

  @override
  ConsumerState<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends ConsumerState<FileBrowser> {
  FileEndpoint? _endpoint;
  String? _path;
  List<FileEntry>? _entries;
  Object? _error;
  bool _loading = false;
  final Set<String> _selected = {};
  String? _anchor;
  SortKey _sort = SortKey.name;
  bool _ascending = true;
  ViewMode _view = ViewMode.list;
  String _filter = '';
  bool _filtering = false;
  late bool _showHidden = ref.read(settingsProvider).showHiddenFiles;
  bool _osDropHover = false;
  String? _dropFolder;
  final _focus = FocusNode(debugLabel: 'file browser');
  final _scroll = ScrollController();
  final _pathBar = PathBarController();
  final _filterText = TextEditingController();
  int _generation = 0;
  String _typed = '';
  bool _localTree = false;

  bool get _showTree =>
      widget.onTreeChanged == null ? _localTree : widget.showTree;

  void _toggleTree() {
    final change = widget.onTreeChanged;
    if (change == null) {
      setState(() => _localTree = !_localTree);
    } else {
      change(!widget.showTree);
    }
  }

  DateTime _typedAt = DateTime(0);

  String? get _hostId => widget.side.hostId;

  @override
  void initState() {
    super.initState();
    widget.link?.cwd.addListener(_onTerminalFolder);
    unawaited(_open(widget.side));
  }

  @override
  void didUpdateWidget(FileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link?.cwd != widget.link?.cwd) {
      oldWidget.link?.cwd.removeListener(_onTerminalFolder);
      widget.link?.cwd.addListener(_onTerminalFolder);
    }
    final requested = widget.side.path;
    if (oldWidget.side.hostId != widget.side.hostId) {
      unawaited(_open(widget.side));
    } else if (requested != null &&
        requested != oldWidget.side.path &&
        requested != _path &&
        _endpoint != null) {
      unawaited(_goTo(requested));
    } else if (widget.link?.follow == true && oldWidget.link?.follow != true) {
      _onTerminalFolder();
    }
  }

  @override
  void dispose() {
    widget.link?.cwd.removeListener(_onTerminalFolder);
    _focus.dispose();
    _scroll.dispose();
    _pathBar.dispose();
    _filterText.dispose();
    super.dispose();
  }

  void _onTerminalFolder() {
    final link = widget.link;
    final cwd = link?.cwd.value;
    if (link == null || !link.follow || cwd == null || cwd == _path) return;
    if (_endpoint == null) return;
    unawaited(_list(cwd));
  }

  Future<void> _open(SftpSide side) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _entries = null;
      _selected.clear();
    });
    try {
      final endpoint = await ref
          .read(endpointResolverProvider)
          .resolve(side.hostId);
      final settings = ref.read(settingsProvider);
      final fallback = side.isLocal
          ? (settings.defaultLocalPath ?? '~')
          : settings.defaultRemotePath;
      final link = widget.link;
      final followed = link != null && link.follow ? link.cwd.value : null;
      final path = await endpoint.resolve(followed ?? side.path ?? fallback);
      if (generation != _generation) return;
      _endpoint = endpoint;
      await _list(path);
    } on Object catch (error) {
      if (generation != _generation || !mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _list(String path, {bool remember = true}) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resolved = await endpoint.resolve(path);
      final entries = await endpoint.list(resolved);
      if (generation != _generation || !mounted) return;
      final changed = resolved != _path;
      setState(() {
        _path = resolved;
        _entries = entries;
        _loading = false;
        if (changed) {
          _selected.clear();
          _anchor = null;
        } else {
          _selected.retainWhere((p) => entries.any((e) => e.path == p));
        }
      });
      if (changed && _scroll.hasClients) _scroll.jumpTo(0);
      if (remember) {
        ref.read(filePlacesProvider.notifier).visit(_hostId, resolved);
        widget.onSideChanged(SftpSide(hostId: _hostId, path: resolved));
      }
    } on Object catch (error) {
      if (generation != _generation || !mounted) return;
      if (!widget.side.isLocal) {
        ref.read(endpointResolverProvider).invalidate(_hostId!);
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _goTo(String path) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final resolved = await endpoint.resolve(path);
    final entry = await endpoint.stat(resolved);
    if (!mounted) return;
    if (entry != null && !entry.isDirectory) {
      await _list(endpoint.paths.dirname(resolved));
      if (!mounted) return;
      setState(() {
        _selected
          ..clear()
          ..add(resolved);
        _anchor = resolved;
      });
      final index = _visible.indexWhere((item) => item.path == resolved);
      if (index >= 0) _reveal(index);
      return;
    }
    await _list(resolved);
  }

  Future<void> _refresh() async {
    if (_endpoint == null) {
      await _open(widget.side);
    } else if (_path != null) {
      await _list(_path!, remember: false);
    }
  }

  List<FileEntry> get _visible {
    final query = _filter.toLowerCase();
    return [
      for (final entry in _entries ?? const <FileEntry>[])
        if ((_showHidden || !entry.isHidden) &&
            (query.isEmpty || entry.name.toLowerCase().contains(query)))
          entry,
    ]..sort((a, b) => FileSorting.compare(a, b, _sort, ascending: _ascending));
  }

  List<FileEntry> get _selection => [
    for (final entry in _visible)
      if (_selected.contains(entry.path)) entry,
  ];

  String get _hostLabel => _hostId == null
      ? 'This device'
      : ref.read(hostsProvider).value?.host(_hostId)?.label ?? 'Removed host';

  String? _lastTapPath;
  DateTime _lastTapAt = DateTime(0);

  void _tap(FileEntry entry, List<FileEntry> visible) {
    _focus.requestFocus();
    final now = DateTime.now();
    final keyboard = HardwareKeyboard.instance;
    final repeat =
        _lastTapPath == entry.path &&
        now.difference(_lastTapAt) <= kDoubleTapTimeout &&
        !keyboard.isShiftPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isControlPressed;
    _lastTapPath = repeat ? null : entry.path;
    _lastTapAt = now;
    if (repeat) {
      _activate(entry);
      return;
    }
    setState(() {
      if (keyboard.isShiftPressed && _anchor != null) {
        final a = visible.indexWhere((e) => e.path == _anchor);
        final b = visible.indexOf(entry);
        if (a >= 0 && b >= 0) {
          _selected
            ..clear()
            ..addAll(
              visible
                  .sublist(a < b ? a : b, (a < b ? b : a) + 1)
                  .map((e) => e.path),
            );
          return;
        }
      }
      if (keyboard.isMetaPressed || keyboard.isControlPressed) {
        if (!_selected.remove(entry.path)) _selected.add(entry.path);
      } else {
        _selected
          ..clear()
          ..add(entry.path);
      }
      _anchor = entry.path;
    });
  }

  void _activate(FileEntry entry) {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    if (entry.isDirectory) {
      unawaited(_list(entry.path));
    } else if (entry.looksLikeImage || entry.looksLikeText) {
      unawaited(showFilePreview(context, endpoint, entry));
    }
  }

  void _up() {
    final endpoint = _endpoint;
    final path = _path;
    if (endpoint == null || path == null) return;
    final parent = endpoint.paths.dirname(path);
    if (parent != path) unawaited(_list(parent));
  }

  Future<void> _guard(Future<void> Function() action, String failure) async {
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        showWgToast(
          context,
          '$failure: ${error is FileOperationException ? error.message : error}',
        );
      }
    }
    await _refresh();
  }

  Future<void> _newFolder() async {
    final endpoint = _endpoint;
    final path = _path;
    if (endpoint == null || path == null) return;
    final name = await showTextPrompt(
      context,
      title: 'New folder',
      label: 'Name',
      confirm: 'Create folder',
    );
    if (name == null) return;
    await _guard(
      () => endpoint.createDirectory(endpoint.paths.join(path, name)),
      'Could not create the folder',
    );
  }

  Future<void> _rename(FileEntry entry) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final name = await showTextPrompt(
      context,
      title: 'Rename ${entry.name}',
      label: 'New name',
      initial: entry.name,
      confirm: 'Rename',
    );
    if (name == null || name == entry.name) return;
    await _guard(
      () => endpoint.rename(
        entry.path,
        endpoint.paths.join(endpoint.paths.dirname(entry.path), name),
      ),
      'Could not rename',
    );
  }

  Future<void> _move(List<FileEntry> entries) async {
    final endpoint = _endpoint;
    final path = _path;
    if (endpoint == null || path == null || entries.isEmpty) return;
    final target = await showTextPrompt(
      context,
      title: entries.length == 1
          ? 'Move ${entries.first.name}'
          : 'Move ${entries.length} items',
      label: 'Destination folder',
      initial: path,
      confirm: 'Move',
      mono: true,
    );
    if (target == null || target == path) return;
    await _guard(() async {
      final resolved = await endpoint.resolve(target);
      for (final entry in entries) {
        await endpoint.rename(
          entry.path,
          endpoint.paths.join(resolved, entry.name),
        );
      }
    }, 'Could not move');
  }

  Future<void> _delete(List<FileEntry> entries) async {
    final endpoint = _endpoint;
    if (endpoint == null || entries.isEmpty) return;
    final folders = entries.where((entry) => entry.isDirectory).length;
    final title = entries.length == 1
        ? 'Delete ${entries.first.name}?'
        : 'Delete ${entries.length} items?';
    final ok = await showWgConfirm(
      context,
      title: title,
      message: [
        'This removes them from ${endpoint.label} for good.',
        if (folders > 0) 'Folders are deleted with everything inside.',
      ].join(' '),
      confirmLabel: entries.length == 1
          ? 'Delete'
          : 'Delete ${entries.length} items',
      destructive: true,
    );
    if (!ok) return;
    await _guard(() async {
      for (final entry in entries) {
        if (entry.isDirectory && !entry.isLink) {
          await endpoint.deleteDirectory(entry.path);
        } else {
          await endpoint.deleteFile(entry.path);
        }
      }
    }, 'Could not delete');
  }

  Future<void> _chmod(FileEntry entry) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final mode = await showPermissionsDialog(context, entry);
    if (mode == null) return;
    await _guard(
      () => endpoint.setMode(entry.path, mode),
      'Could not change permissions',
    );
  }

  Future<void> _edit(FileEntry entry) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final saved = await showFileEditor(context, endpoint, entry);
    if (saved && mounted) {
      showWgToast(context, 'Saved ${entry.name}');
      await _refresh();
    }
  }

  Future<void> _deliver(
    FileDragPayload payload,
    String folder, {
    required bool move,
  }) async {
    try {
      final count = await FileDelivery.deliver(
        context,
        ref,
        fromHostId: payload.hostId,
        entries: payload.entries,
        toHostId: _hostId,
        toDirectory: folder,
        move: move,
      );
      if (!mounted || count == 0) return;
      final sameHost = payload.hostId == _hostId;
      showWgToast(
        context,
        move && sameHost
            ? 'Moved ${Format.plural(count, 'item')}'
            : '${move ? 'Moving' : 'Copying'} ${Format.plural(count, 'item')} to $_hostLabel. Progress is in Transfers',
      );
    } on Object catch (error) {
      if (mounted) {
        showWgToast(
          context,
          'Could not ${move ? 'move' : 'copy'}: ${error is FileOperationException ? error.message : error}',
        );
      }
    }
    await _refresh();
  }

  Future<void> _copyTo(List<FileEntry> entries, SftpSide target) async {
    final destination = await ref
        .read(endpointResolverProvider)
        .resolve(target.hostId);
    final dir = await destination.resolve(target.path ?? '~');
    if (!mounted) return;
    final count = await TransferActions.copy(
      context,
      ref,
      fromHostId: _hostId,
      entries: entries,
      toHostId: target.hostId,
      toDirectory: dir,
      join: destination.paths.join,
    );
    if (count > 0 && mounted) {
      showWgToast(context, 'Queued ${Format.plural(count, 'item')}');
    }
  }

  Future<void> _receiveOsFiles(List<String> paths, {String? folder}) async {
    final target = folder ?? _path;
    if (target == null) return;
    final local = await ref.read(endpointResolverProvider).resolve(null);
    final entries = <FileEntry>[];
    for (final path in paths) {
      final entry = await local.stat(path);
      if (entry != null) entries.add(entry);
    }
    if (entries.isEmpty || !mounted) return;
    await _deliver(
      FileDragPayload(hostId: null, entries: entries, sourcePaneKey: 'os'),
      target,
      move: false,
    );
  }

  Future<void> _upload() async {
    final files = await openFiles();
    if (files.isEmpty) return;
    await _receiveOsFiles([for (final file in files) file.path]);
  }

  Future<void> _download(List<FileEntry> entries) async {
    final directory = await getDirectoryPath(
      confirmButtonText: 'Download here',
    );
    if (directory == null || !mounted) return;
    await _copyTo(entries, SftpSide(path: directory));
  }

  void _clip({required bool cut}) {
    final selection = _selection;
    if (selection.isEmpty) return;
    ref.read(fileClipboardProvider.notifier).put(_hostId, selection, cut: cut);
    showWgToast(
      context,
      '${Format.plural(selection.length, 'item')} ready to ${cut ? 'move' : 'copy'}. Paste in any files panel',
    );
  }

  Future<void> _paste() async {
    final clip = ref.read(fileClipboardProvider);
    final path = _path;
    if (clip == null || path == null) return;
    await _deliver(
      FileDragPayload(
        hostId: clip.hostId,
        entries: clip.entries,
        sourcePaneKey: 'clipboard',
      ),
      path,
      move: clip.cut,
    );
    if (clip.cut) ref.read(fileClipboardProvider.notifier).clear();
  }

  void _openTerminalHere(String path, {bool split = false}) {
    final link = widget.link;
    if (link != null && !split) {
      link.cdHere(path);
      return;
    }
    final bench = ref.read(workbenchProvider.notifier);
    if (_hostId == null) {
      if (PlatformInfo.supportsLocalTerminal) {
        bench.openPane(
          LocalTerminalContent(directory: path),
          placement: PanePlacement.splitDown,
        );
      }
      return;
    }
    bench.openPane(
      SshTerminalContent(hostId: _hostId!, directory: path),
      placement: PanePlacement.splitDown,
    );
  }

  Future<void> _pickEndpoint() async {
    final pick = await showEndpointPicker(context, title: 'Show files from');
    if (pick == null) return;
    widget.onSideChanged(SftpSide(hostId: pick.host?.id));
    if (pick.host?.id == _hostId) {
      unawaited(_open(SftpSide(hostId: pick.host?.id)));
    }
  }

  Future<void> _quickJump() async {
    final endpoint = _endpoint;
    final path = _path;
    if (endpoint == null || path == null) return;
    final places = ref.read(filePlacesProvider.notifier).of(_hostId);
    final subfolders = [
      for (final entry in _visible)
        if (entry.isDirectory) entry.path,
    ];
    final picked = await showQuickJump(
      context,
      favorites: places.favorites,
      recents: places.recents.where((item) => item != path).toList(),
      subfolders: subfolders,
      hostLabel: _hostLabel,
    );
    if (picked != null) unawaited(_list(picked));
  }

  void _toggleFavorite() {
    final path = _path;
    if (path == null) return;
    ref.read(filePlacesProvider.notifier).toggleFavorite(_hostId, path);
  }

  void _menu(Offset position, FileEntry? entry) {
    if (entry != null && !_selected.contains(entry.path)) {
      setState(() {
        _selected
          ..clear()
          ..add(entry.path);
        _anchor = entry.path;
      });
    }
    final selection = _selection;
    final single = selection.length == 1 ? selection.first : null;
    final target = widget.copyTarget;
    final clip = ref.read(fileClipboardProvider);
    final keys = _Keys.of();
    final folder = single?.isDirectory ?? false ? single!.path : _path;
    unawaited(
      showWgMenu(
        context,
        position: position,
        entries: [
          if (single != null && single.isDirectory)
            WgMenuEntry(
              label: 'Open',
              icon: WgIcons.folderOpen,
              onSelected: () => _activate(single),
            ),
          if (single != null && !single.isDirectory) ...[
            WgMenuEntry(
              label: 'Quick look',
              icon: WgIcons.eye,
              shortcut: const SingleActivator(LogicalKeyboardKey.space),
              onSelected: () => _activate(single),
            ),
            if (single.looksLikeText)
              WgMenuEntry(
                label: 'Edit',
                icon: WgIcons.edit,
                onSelected: () => unawaited(_edit(single)),
              ),
          ],
          if (selection.isNotEmpty) ...[
            WgMenuEntry(
              label: 'Cut',
              icon: WgIcons.cut,
              shortcut: keys.cut,
              onSelected: () => _clip(cut: true),
            ),
            WgMenuEntry(
              label: 'Copy',
              icon: WgIcons.copy,
              shortcut: keys.copy,
              onSelected: () => _clip(cut: false),
            ),
          ],
          if (clip != null)
            WgMenuEntry(
              label: clip.cut
                  ? 'Move ${Format.plural(clip.entries.length, 'item')} here'
                  : 'Paste ${Format.plural(clip.entries.length, 'item')}',
              icon: WgIcons.paste,
              shortcut: keys.paste,
              onSelected: () => unawaited(_paste()),
            ),
          if (selection.isNotEmpty && target != null)
            WgMenuEntry(
              label: 'Copy to ${widget.copyLabel ?? 'other side'}',
              icon: WgIcons.arrowRight,
              onSelected: () => unawaited(_copyTo(selection, target)),
            ),
          if (selection.isNotEmpty && !widget.side.isLocal)
            WgMenuEntry(
              label: 'Download to…',
              icon: WgIcons.download,
              onSelected: () => unawaited(_download(selection)),
            ),
          const WgMenuEntry.divider(),
          if (single != null)
            WgMenuEntry(
              label: 'Rename',
              icon: WgIcons.edit,
              shortcut: const SingleActivator(LogicalKeyboardKey.f2),
              onSelected: () => unawaited(_rename(single)),
            ),
          if (selection.isNotEmpty)
            WgMenuEntry(
              label: 'Move to…',
              icon: WgIcons.move,
              onSelected: () => unawaited(_move(selection)),
            ),
          if (single != null)
            WgMenuEntry(
              label: 'Permissions',
              icon: WgIcons.permissions,
              onSelected: () => unawaited(_chmod(single)),
            ),
          if (single != null)
            WgMenuEntry(
              label: 'Properties',
              icon: WgIcons.info,
              onSelected: () =>
                  unawaited(showProperties(context, _endpoint!, single)),
            ),
          WgMenuEntry(
            label: 'Copy path',
            icon: WgIcons.copy,
            onSelected: () => unawaited(
              Clipboard.setData(ClipboardData(text: single?.path ?? _path!)),
            ),
          ),
          if (folder != null) ...[
            WgMenuEntry(
              label: widget.link == null
                  ? 'Open terminal here'
                  : 'Change the terminal to this folder',
              icon: WgIcons.terminal,
              enabled:
                  !widget.side.isLocal || PlatformInfo.supportsLocalTerminal,
              onSelected: () => _openTerminalHere(folder),
            ),
            if (widget.link != null)
              WgMenuEntry(
                label: 'Open a new terminal here',
                icon: WgIcons.splitVertical,
                onSelected: () => _openTerminalHere(folder, split: true),
              ),
          ],
          const WgMenuEntry.divider(),
          WgMenuEntry(
            label: 'New folder',
            icon: WgIcons.folderPlus,
            onSelected: () => unawaited(_newFolder()),
          ),
          if (selection.isNotEmpty)
            WgMenuEntry(
              label: selection.length == 1
                  ? 'Delete'
                  : 'Delete ${selection.length} items',
              icon: WgIcons.trash,
              destructive: true,
              shortcut: const SingleActivator(LogicalKeyboardKey.delete),
              onSelected: () => unawaited(_delete(selection)),
            ),
        ],
      ),
    );
  }

  void _select(List<FileEntry> visible, int index, {bool extend = false}) {
    if (visible.isEmpty) return;
    final next = index.clamp(0, visible.length - 1);
    final entry = visible[next];
    setState(() {
      if (extend && _anchor != null) {
        _selected.add(entry.path);
      } else {
        _selected
          ..clear()
          ..add(entry.path);
      }
      _anchor = entry.path;
    });
    _reveal(next);
  }

  void _reveal(int index) {
    if (!_scroll.hasClients || _view != ViewMode.list) return;
    final extent = context.sizes.rowCompact;
    final top = index * extent;
    final position = _scroll.position;
    var target = position.pixels;
    if (top < target) target = top;
    if (top + extent > target + position.viewportDimension) {
      target = top + extent - position.viewportDimension;
    }
    _scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
  }

  void _typeAhead(String character, List<FileEntry> visible) {
    final now = DateTime.now();
    final fresh = now.difference(_typedAt) > context.motion.typeAhead;
    _typed = (fresh ? '' : _typed) + character.toLowerCase();
    _typedAt = now;
    final index = visible.indexWhere(
      (entry) => entry.name.toLowerCase().startsWith(_typed),
    );
    if (index >= 0) _select(visible, index);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final visible = _visible;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final primary = PlatformInfo.isApple
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
    final shift = keyboard.isShiftPressed;
    final index = visible.indexWhere((entry) => entry.path == _anchor);
    final focused = index >= 0 ? visible[index] : null;
    final page = _scroll.hasClients
        ? (_scroll.position.viewportDimension / context.sizes.rowCompact)
              .floor()
        : 10;
    if (primary && key == LogicalKeyboardKey.arrowUp) {
      _up();
    } else if (primary && key == LogicalKeyboardKey.arrowDown) {
      if (focused != null) _activate(focused);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _select(visible, index + 1, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _select(visible, index <= 0 ? 0 : index - 1, extend: shift);
    } else if (key == LogicalKeyboardKey.home) {
      _select(visible, 0);
    } else if (key == LogicalKeyboardKey.end) {
      _select(visible, visible.length - 1);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _select(visible, index + page);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _select(visible, index - page);
    } else if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        focused != null) {
      _activate(focused);
    } else if (key == LogicalKeyboardKey.space && focused != null) {
      if (!focused.isDirectory && _endpoint != null) {
        unawaited(showFilePreview(context, _endpoint!, focused));
      }
    } else if (key == LogicalKeyboardKey.backspace && !primary) {
      _up();
    } else if (key == LogicalKeyboardKey.delete ||
        (key == LogicalKeyboardKey.backspace && primary)) {
      unawaited(_delete(_selection));
    } else if (key == LogicalKeyboardKey.f2 && focused != null) {
      unawaited(_rename(focused));
    } else if (key == LogicalKeyboardKey.f5 && widget.copyTarget != null) {
      unawaited(_copyTo(_selection, widget.copyTarget!));
    } else if (primary && key == LogicalKeyboardKey.keyA) {
      setState(() => _selected.addAll(visible.map((entry) => entry.path)));
    } else if (primary && key == LogicalKeyboardKey.keyC) {
      _clip(cut: false);
    } else if (primary && key == LogicalKeyboardKey.keyX) {
      _clip(cut: true);
    } else if (primary && key == LogicalKeyboardKey.keyV) {
      unawaited(_paste());
    } else if (primary && key == LogicalKeyboardKey.keyP) {
      unawaited(_quickJump());
    } else if (primary && key == LogicalKeyboardKey.keyL) {
      _pathBar.edit();
    } else if (primary && key == LogicalKeyboardKey.keyF) {
      setState(() => _filtering = true);
    } else if (key == LogicalKeyboardKey.escape && _selected.isNotEmpty) {
      setState(_selected.clear);
    } else if (isTypeAheadKey(event)) {
      _typeAhead(event.character!, visible);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hostId = _hostId;
    final host = ref.watch(hostsProvider).value?.host(hostId);
    final link = hostId == null ? null : ref.watch(hostLinksProvider)[hostId];
    final label = hostId == null
        ? 'This device'
        : host?.label ?? 'Removed host';
    final favorite = ref.watch(
      filePlacesProvider.select(
        (places) =>
            _path != null &&
            (places[placesKey(hostId)]?.favorites.contains(_path) ?? false),
      ),
    );
    ref.listen<List<TransferJob>>(transferQueueProvider, (previous, next) {
      final path = _path;
      if (path == null || previous == null) return;
      final touched = next.any((job) {
        if (job.status != TransferStatus.completed) return false;
        final before = previous.firstWhereOrNull((item) => item.id == job.id);
        if (before?.status == TransferStatus.completed) return false;
        final target = job.target;
        final source = job.source;
        return (target.hostId == hostId &&
                _endpoint?.paths.dirname(target.path) == path) ||
            (job.move &&
                source.hostId == hostId &&
                _endpoint?.paths.dirname(source.path) == path);
      });
      if (touched) unawaited(_refresh());
    });
    final visible = _visible;
    Widget body = FileDropTarget(
      hostId: hostId,
      hostLabel: label,
      folder: _path == null ? null : _endpoint?.paths.basename(_path!) ?? _path,
      rejectFrom: widget.paneKey,
      onDrop: (payload, {required move}) =>
          unawaited(_deliver(payload, _path!, move: move)),
      builder: (context, {required active}) {
        final highlight = active || _osDropHover;
        return Container(
          decoration: BoxDecoration(
            color: highlight ? colors.accentWash : colors.canvas,
            border: Border.all(
              color: highlight ? colors.accent : colors.transparent,
              width: context.sizes.markerBar,
            ),
          ),
          child: _content(context, visible, label),
        );
      },
    );
    if (PlatformInfo.isDesktop) {
      body = DropTarget(
        onDragEntered: (_) => setState(() => _osDropHover = true),
        onDragExited: (_) => setState(() => _osDropHover = false),
        onDragDone: (details) {
          setState(() => _osDropHover = false);
          unawaited(
            _receiveOsFiles([for (final file in details.files) file.path]),
          );
        },
        child: body,
      );
    }
    final endpoint = _endpoint;
    final path = _path;
    if (_showTree && endpoint != null && path != null) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: context.sizes.treeWidth,
            child: ColoredBox(
              color: colors.canvasDeep,
              child: FolderTree(
                endpoint: endpoint,
                current: path,
                showHidden: _showHidden,
                onOpen: (folder) => unawaited(_list(folder)),
              ),
            ),
          ),
          const WgHairline(vertical: true),
          Expanded(child: body),
        ],
      );
    }
    final terminal = widget.link;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            label: label,
            dot: hostId == null
                ? WgDotState.connected
                : (link?.state ?? LinkState.idle).dot,
            attached: terminal != null,
            following: terminal?.follow ?? false,
            onFollow: terminal == null
                ? null
                : () => terminal.onFollow(!terminal.follow),
            onGoToTerminal:
                terminal == null ||
                    terminal.follow ||
                    terminal.cwd.value == null ||
                    terminal.cwd.value == _path
                ? null
                : () => unawaited(_list(terminal.cwd.value!)),
            onInstallHook: terminal?.onInstallHook,
            path: path,
            endpoint: endpoint,
            pathBar: _pathBar,
            favorite: favorite,
            onFavorite: path == null ? null : _toggleFavorite,
            onQuickJump: () => unawaited(_quickJump()),
            onPickEndpoint: () => unawaited(_pickEndpoint()),
            onNavigate: (path) => unawaited(_list(path)),
            onUp: _up,
            onRefresh: () => unawaited(_refresh()),
            onNewFolder: () => unawaited(_newFolder()),
            onUpload: PlatformInfo.isWeb ? null : () => unawaited(_upload()),
            showHidden: _showHidden,
            onToggleHidden: () => setState(() => _showHidden = !_showHidden),
            showTree: _showTree,
            onToggleTree: _toggleTree,
            view: _view,
            onView: (value) => setState(() => _view = value),
            filtering: _filtering,
            onToggleFilter: () => setState(() {
              _filtering = !_filtering;
              if (!_filtering) {
                _filter = '';
                _filterText.clear();
              }
            }),
            onOpenTerminal: path == null ? null : () => _openTerminalHere(path),
            onCopyPath: path == null
                ? null
                : () => unawaited(Clipboard.setData(ClipboardData(text: path))),
          ),
          if (_filtering)
            _FilterBar(
              controller: _filterText,
              onChanged: (value) => setState(() => _filter = value.trim()),
              onClose: () => setState(() {
                _filtering = false;
                _filter = '';
                _filterText.clear();
                _focus.requestFocus();
              }),
            ),
          Expanded(child: body),
          _Footer(
            total: visible.length,
            selected: _selection,
            copyLabel: widget.copyTarget == null ? null : widget.copyLabel,
            onCopy: widget.copyTarget == null || _selected.isEmpty
                ? null
                : () => unawaited(_copyTo(_selection, widget.copyTarget!)),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, List<FileEntry> visible, String label) {
    final error = _error;
    if (error != null) {
      final message = error is FileOperationException
          ? error.message
          : SshErrorText.describe(error);
      final denied = message.toLowerCase().contains('permission');
      final offline = !denied && _hostId != null;
      return WgEmptyState(
        icon: denied
            ? WgIcons.lock
            : offline
            ? WgIcons.offline
            : WgIcons.error,
        title: denied ? 'Permission denied' : 'Could not open this folder',
        body: denied
            ? 'Your account on $label cannot read ${_path ?? 'this folder'}. Pick another folder or change its permissions.'
            : message,
        action: WgButton(
          label: 'Try again',
          icon: WgIcons.retry,
          onPressed: () => unawaited(_refresh()),
        ),
        secondary: _path == null
            ? null
            : WgButton.ghost(label: 'Go up', onPressed: _up),
      );
    }
    if (_entries == null) {
      return const WgSkeletonList(rows: 10, label: 'Loading folder');
    }
    if (visible.isEmpty) {
      return Stack(
        children: [
          GestureDetector(
            excludeFromSemantics: true,
            onSecondaryTapDown: (details) =>
                _menu(details.globalPosition, null),
            child: WgEmptyState(
              icon: WgIcons.folderOpen,
              title: _filter.isNotEmpty
                  ? 'Nothing matches "$_filter"'
                  : 'This folder is empty',
              body: _filter.isNotEmpty
                  ? 'Clear the filter to see everything here.'
                  : PlatformInfo.isDesktop
                  ? 'Drop files here, or paste with ${PlatformInfo.isApple ? 'Cmd' : 'Ctrl'}+V.'
                  : 'Upload files or copy them in from another pane.',
            ),
          ),
          if (_loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: WgProgressBar(label: 'Refreshing'),
            ),
        ],
      );
    }
    final widths = ref.watch(
      settingsProvider.select((settings) => settings.fileColumnWidths),
    );
    final clip = ref.watch(fileClipboardProvider);
    final cutPaths = clip != null && clip.cut && clip.hostId == _hostId
        ? {for (final entry in clip.entries) entry.path}
        : const <String>{};
    final list = _view == ViewMode.list
        ? FileColumnsView(
            entries: visible,
            selected: _selected,
            focusedPath: _anchor,
            sort: _sort,
            ascending: _ascending,
            onSort: (key) => setState(() {
              if (_sort == key) {
                _ascending = !_ascending;
              } else {
                _sort = key;
                _ascending = true;
              }
            }),
            widths: widths,
            onResize: (column, width) =>
                ref.read(settingsProvider.notifier).update({
                  'fileColumnWidths': {...widths, column.name: width},
                }),
            onTap: (entry) => PlatformInfo.isMobile
                ? _activateOrSelect(entry)
                : _tap(entry, visible),
            onOpen: _activate,
            onMenu: _menu,
            wrap: _wrap,
            scroll: _scroll,
            dropFolder: _dropFolder,
            cutPaths: cutPaths,
          )
        : _grid(visible, cutPaths);
    return Stack(
      children: [
        GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: (details) => _menu(details.globalPosition, null),
          child: list,
        ),
        if (_loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: WgProgressBar(label: 'Refreshing'),
          ),
      ],
    );
  }

  Widget _wrap(FileEntry entry, Widget row) {
    final payload = FileDragPayload(
      hostId: _hostId,
      entries: _selected.contains(entry.path) ? _selection : [entry],
      sourcePaneKey: widget.paneKey,
    );
    final hints = ref.read(dropHintProvider.notifier);
    final feedback = FileDragFeedback(payload: payload);
    var child = row;
    if (entry.isDirectory) {
      child = FileDropTarget(
        hostId: _hostId,
        hostLabel: _hostLabel,
        folder: entry.name,
        onDrop: (payload, {required move}) {
          setState(() => _dropFolder = null);
          unawaited(_deliver(payload, entry.path, move: move));
        },
        builder: (context, {required active}) {
          if (active && _dropFolder != entry.path) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _dropFolder = entry.path);
            });
          } else if (!active && _dropFolder == entry.path) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _dropFolder = null);
            });
          }
          return row;
        },
      );
    }
    void ended() => hints.clear();
    return PlatformInfo.isMobile
        ? LongPressDraggable<FileDragPayload>(
            data: payload,
            feedback: feedback,
            onDragEnd: (_) => ended(),
            child: child,
          )
        : Draggable<FileDragPayload>(
            data: payload,
            feedback: feedback,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedbackOffset: Offset(context.space.lg, context.space.lg),
            onDragEnd: (_) => ended(),
            child: child,
          );
  }

  void _activateOrSelect(FileEntry entry) {
    if (_selected.isNotEmpty) {
      setState(() {
        if (!_selected.remove(entry.path)) _selected.add(entry.path);
      });
      return;
    }
    _activate(entry);
  }

  Widget _grid(List<FileEntry> visible, Set<String> cutPaths) {
    final colors = context.colors;
    return GridView.builder(
      controller: _scroll,
      padding: EdgeInsets.all(context.space.sm),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: context.sizes.gridTile,
        mainAxisSpacing: context.space.xs,
        crossAxisSpacing: context.space.xs,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final entry = visible[index];
        final selected = _selected.contains(entry.path);
        final cut = cutPaths.contains(entry.path);
        return _wrap(
          entry,
          WgPressable(
            semanticLabel:
                '${entry.isDirectory ? 'Folder' : 'File'} ${entry.name}',
            selected: selected,
            onPressed: () => _tap(entry, visible),
            onSecondaryTapDown: (details) =>
                _menu(details.globalPosition, entry),
            builder: (context, state) => Container(
              padding: EdgeInsets.all(context.space.sm),
              decoration: BoxDecoration(
                color: _dropFolder == entry.path
                    ? colors.accentWash
                    : selected
                    ? colors.pressed
                    : state.highlighted
                    ? colors.raised
                    : colors.transparent,
                borderRadius: context.radii.mdAll,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    fileIcon(entry),
                    size: context.sizes.iconLarge,
                    color: cut ? colors.textMuted : colors.textSecondary,
                  ),
                  SizedBox(height: context.space.sm),
                  Text(
                    entry.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      color: cut ? colors.textMuted : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Keys {
  const new({required this.cut, required this.copy, required this.paste});

  factory of() {
    final apple = PlatformInfo.isApple;
    SingleActivator key(LogicalKeyboardKey key) =>
        SingleActivator(key, meta: apple, control: !apple);
    return _Keys(
      cut: key(LogicalKeyboardKey.keyX),
      copy: key(LogicalKeyboardKey.keyC),
      paste: key(LogicalKeyboardKey.keyV),
    );
  }

  final SingleActivator cut;
  final SingleActivator copy;
  final SingleActivator paste;
}

class _Toolbar extends StatelessWidget {
  const new({
    required this.label,
    required this.dot,
    required this.attached,
    required this.following,
    required this.onFollow,
    required this.onGoToTerminal,
    required this.onInstallHook,
    required this.path,
    required this.endpoint,
    required this.pathBar,
    required this.favorite,
    required this.onFavorite,
    required this.onQuickJump,
    required this.onPickEndpoint,
    required this.onNavigate,
    required this.onUp,
    required this.onRefresh,
    required this.onNewFolder,
    required this.onUpload,
    required this.showHidden,
    required this.onToggleHidden,
    required this.showTree,
    required this.onToggleTree,
    required this.view,
    required this.onView,
    required this.filtering,
    required this.onToggleFilter,
    required this.onOpenTerminal,
    required this.onCopyPath,
  });

  final String label;
  final WgDotState dot;
  final bool attached;
  final bool following;
  final VoidCallback? onFollow;
  final VoidCallback? onGoToTerminal;
  final VoidCallback? onInstallHook;
  final String? path;
  final FileEndpoint? endpoint;
  final PathBarController pathBar;
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback onQuickJump;
  final VoidCallback onPickEndpoint;
  final ValueChanged<String> onNavigate;
  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final VoidCallback onNewFolder;
  final VoidCallback? onUpload;
  final bool showHidden;
  final VoidCallback onToggleHidden;
  final bool showTree;
  final VoidCallback onToggleTree;
  final ViewMode view;
  final ValueChanged<ViewMode> onView;
  final bool filtering;
  final VoidCallback onToggleFilter;
  final VoidCallback? onOpenTerminal;
  final VoidCallback? onCopyPath;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints.maxWidth),
  );

  Widget _build(BuildContext context, double width) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final keyName = PlatformInfo.isApple ? 'Cmd' : 'Ctrl';
    final button = sizes.rowCompact - space.sm + space.hair;
    final roomy = width - space.xs * 2 >= sizes.columnName + button * 7;
    final leading = attached
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WgIconButton(
                icon: following ? WgIcons.follow : WgIcons.followOff,
                label: following
                    ? 'Stop following the terminal'
                    : 'Follow the terminal',
                compact: true,
                selected: following,
                onPressed: onFollow,
              ),
              if (onGoToTerminal != null) ...[
                SizedBox(width: space.hair),
                if (roomy)
                  Flexible(
                    child: WgButton.ghost(
                      label: 'Go to terminal folder',
                      icon: WgIcons.goTo,
                      onPressed: onGoToTerminal,
                    ),
                  )
                else
                  WgIconButton(
                    icon: WgIcons.goTo,
                    label: 'Go to terminal folder',
                    compact: true,
                    onPressed: onGoToTerminal,
                  ),
              ],
            ],
          )
        : WgPressable(
            semanticLabel: 'Location: $label. Change',
            onPressed: onPickEndpoint,
            borderRadius: context.radii.smAll,
            builder: (context, state) => Container(
              height: sizes.rowCompact - space.xs,
              padding: EdgeInsets.symmetric(horizontal: space.sm),
              decoration: BoxDecoration(
                color: state.highlighted ? colors.raised : colors.transparent,
                borderRadius: context.radii.smAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WgStatusDot(state: dot, subject: label),
                  if (roomy) ...[
                    SizedBox(width: space.sm),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.label,
                      ),
                    ),
                  ],
                  SizedBox(width: space.xs),
                  Icon(
                    WgIcons.chevronDown,
                    size: sizes.icon,
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
          );
    final primary = SingleActivator(
      LogicalKeyboardKey.arrowUp,
      meta: PlatformInfo.isApple,
      control: !PlatformInfo.isApple,
    );
    final actions = <Widget>[
      WgIconButton(
        icon: WgIcons.arrowUp,
        label: 'Up one folder',
        compact: true,
        shortcut: primary,
        onPressed: onUp,
      ),
      WgIconButton(
        icon: WgIcons.refresh,
        label: 'Refresh',
        compact: true,
        onPressed: onRefresh,
      ),
      if (roomy) ...[
        WgIconButton(
          icon: WgIcons.search,
          label: 'Filter',
          compact: true,
          selected: filtering,
          onPressed: onToggleFilter,
        ),
        WgIconButton(
          icon: showHidden ? WgIcons.eye : WgIcons.hidden,
          label: showHidden ? 'Hide hidden files' : 'Show hidden files',
          compact: true,
          selected: showHidden,
          onPressed: onToggleHidden,
        ),
        WgIconButton(
          icon: favorite ? WgIcons.star : WgIcons.starOff,
          label: favorite ? 'Remove from favorites' : 'Add to favorites',
          compact: true,
          selected: favorite,
          onPressed: onFavorite,
        ),
        WgIconButton(
          icon: WgIcons.folderTree,
          label: showTree ? 'Hide folder tree' : 'Show folder tree',
          compact: true,
          selected: showTree,
          onPressed: onToggleTree,
        ),
      ],
      WgMenuButton(
        icon: WgIcons.more,
        label: 'More file actions',
        compact: true,
        entries: () => [
          if (!roomy) ...[
            WgMenuEntry(
              label: filtering ? 'Close filter' : 'Filter',
              icon: WgIcons.search,
              onSelected: onToggleFilter,
            ),
            WgMenuEntry(
              label: showHidden ? 'Hide hidden files' : 'Show hidden files',
              icon: showHidden ? WgIcons.eye : WgIcons.hidden,
              onSelected: onToggleHidden,
            ),
            WgMenuEntry(
              label: favorite ? 'Remove from favorites' : 'Add to favorites',
              icon: WgIcons.star,
              enabled: onFavorite != null,
              onSelected: () => onFavorite?.call(),
            ),
            WgMenuEntry(
              label: showTree ? 'Hide folder tree' : 'Show folder tree',
              icon: WgIcons.folderTree,
              onSelected: onToggleTree,
            ),
            const WgMenuEntry.divider(),
          ],
          WgMenuEntry(
            label: 'Jump to folder…',
            icon: WgIcons.goTo,
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyP,
              meta: PlatformInfo.isApple,
              control: !PlatformInfo.isApple,
            ),
            onSelected: onQuickJump,
          ),
          WgMenuEntry(
            label: 'Type a path…',
            icon: WgIcons.textCursor,
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyL,
              meta: PlatformInfo.isApple,
              control: !PlatformInfo.isApple,
            ),
            onSelected: pathBar.edit,
          ),
          WgMenuEntry(
            label: view == ViewMode.list ? 'Show as grid' : 'Show as list',
            icon: view == ViewMode.list ? WgIcons.grid : WgIcons.list,
            onSelected: () =>
                onView(view == ViewMode.list ? ViewMode.grid : ViewMode.list),
          ),
          const WgMenuEntry.divider(),
          WgMenuEntry(
            label: 'New folder',
            icon: WgIcons.folderPlus,
            onSelected: onNewFolder,
          ),
          if (onUpload != null)
            WgMenuEntry(
              label: 'Upload files…',
              icon: WgIcons.upload,
              onSelected: onUpload,
            ),
          WgMenuEntry(
            label: 'Copy path',
            icon: WgIcons.copy,
            enabled: onCopyPath != null,
            onSelected: () => onCopyPath?.call(),
          ),
          if (onOpenTerminal != null)
            WgMenuEntry(
              label: attached
                  ? 'Change the terminal to this folder'
                  : 'Open terminal here',
              icon: WgIcons.terminal,
              onSelected: onOpenTerminal,
            ),
          if (onInstallHook != null) ...[
            const WgMenuEntry.divider(),
            WgMenuEntry(
              label: 'Set up folder tracking on this host…',
              icon: WgIcons.follow,
              onSelected: onInstallHook,
            ),
          ],
        ],
      ),
    ];
    final pathBarWidget = Semantics(
      hint: 'Click to type a path. $keyName+L also works',
      child: PathBar(
        endpoint: endpoint,
        path: path,
        onNavigate: onNavigate,
        controller: pathBar,
      ),
    );
    final actionRow = [
      for (final (index, action) in actions.indexed) ...[
        if (index > 0) SizedBox(width: space.hair),
        action,
      ],
    ];
    final inline = width >= sizes.dialogWide;
    return Container(
      decoration: BoxDecoration(
        color: colors.canvasDeep,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      padding: EdgeInsets.all(space.xs),
      child: inline
          ? Row(
              children: [
                leading,
                SizedBox(width: space.sm),
                Expanded(child: pathBarWidget),
                SizedBox(width: space.sm),
                ...actionRow,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: leading,
                      ),
                    ),
                    SizedBox(width: space.xs),
                    ...actionRow,
                  ],
                ),
                SizedBox(height: space.xs),
                pathBarWidget,
              ],
            ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.space.xs),
      decoration: BoxDecoration(
        color: context.colors.canvasDeep,
        border: Border(bottom: BorderSide(color: context.colors.hairline)),
      ),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
        child: WgTextField(
          controller: controller,
          autofocus: true,
          placeholder: 'Filter this folder',
          leadingIcon: WgIcons.search,
          onChanged: onChanged,
          trailing: WgIconButton(
            icon: WgIcons.close,
            label: 'Clear filter',
            compact: true,
            onPressed: onClose,
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const new({
    required this.total,
    required this.selected,
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

Future<String?> showQuickJump(
  BuildContext context, {
  required List<String> favorites,
  required List<String> recents,
  required List<String> subfolders,
  required String hostLabel,
}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close',
  barrierColor: context.colors.scrim,
  transitionDuration: context.motion.fast,
  pageBuilder: (dialogContext, _, _) => WgFloatingPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.space.lg,
            context.space.md,
            context.space.lg,
            0,
          ),
          child: Semantics(
            header: true,
            child: Text(
              'Jump to a folder on $hostLabel',
              style: context.type.label,
            ),
          ),
        ),
        WgSearchList<String>(
          placeholder: 'Folder name or path',
          emptyTitle: 'No folder matches',
          emptyBody: 'Star a folder to keep it here. Folders you open show up as recent.',
          onCancel: () => Navigator.of(dialogContext).pop(),
          onSelected: (value) => Navigator.of(dialogContext).pop(value),
          items: (query) {
            final lower = query.toLowerCase();
            bool matches(String path) =>
                lower.isEmpty || path.toLowerCase().contains(lower);
            final seen = <String>{};
            WgSearchItem<String>? item(String path, String section) {
              if (!matches(path) || !seen.add(path)) return null;
              final name = path.split('/').where((part) => part.isNotEmpty);
              return WgSearchItem<String>(
                value: path,
                title: name.isEmpty ? path : name.last,
                subtitle: path,
                section: section,
                leading: Icon(
                  section == 'Favorites' ? WgIcons.star : WgIcons.folder,
                ),
              );
            }

            return [
              for (final path in favorites) ?item(path, 'Favorites'),
              for (final path in recents) ?item(path, 'Recent'),
              for (final path in subfolders) ?item(path, 'In this folder'),
            ];
          },
        ),
      ],
    ),
  ),
);
