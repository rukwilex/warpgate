import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/data/ssh_errors.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/host_picker.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/sftp/presentation/file_dialogs.dart';
import 'package:warpgate/features/shell/presentation/prompts.dart';
import 'package:warpgate/features/transfers/presentation/transfer_actions.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

enum SortKey { name, size, modified }

enum ViewMode { list, grid }

class FileBrowser extends ConsumerStatefulWidget {
  const new({
    required this.side,
    required this.paneKey,
    required this.onSideChanged,
    super.key,
    this.copyTarget,
    this.copyLabel,
  });

  final SftpSide side;
  final String paneKey;
  final ValueChanged<SftpSide> onSideChanged;
  final SftpSide? copyTarget;
  final String? copyLabel;

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
  late bool _showHidden = ref.read(settingsProvider).showHiddenFiles;
  bool _dropHover = false;
  final _focus = FocusNode(debugLabel: 'file browser');
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_open(widget.side));
  }

  @override
  void didUpdateWidget(FileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.side.hostId != widget.side.hostId) {
      unawaited(_open(widget.side));
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
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
      final fallback = side.isLocal
          ? (ref.read(settingsProvider).defaultLocalPath ?? '~')
          : ref.read(settingsProvider).defaultRemotePath;
      final path = await endpoint.resolve(side.path ?? fallback);
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
      final entries = await endpoint.list(path);
      if (generation != _generation || !mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
        _loading = false;
        _selected.retainWhere((p) => entries.any((entry) => entry.path == p));
      });
      if (remember) {
        widget.onSideChanged(SftpSide(hostId: widget.side.hostId, path: path));
      }
    } on Object catch (error) {
      if (generation != _generation || !mounted) return;
      if (!widget.side.isLocal) {
        ref.read(endpointResolverProvider).invalidate(widget.side.hostId!);
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
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
    final entries = [
      for (final entry in _entries ?? const <FileEntry>[])
        if ((_showHidden || !entry.isHidden) &&
            (query.isEmpty || entry.name.toLowerCase().contains(query)))
          entry,
    ];
    int compare(FileEntry a, FileEntry b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      final result = switch (_sort) {
        SortKey.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        SortKey.size => a.size.compareTo(b.size),
        SortKey.modified => (a.modified ?? DateTime(0)).compareTo(
          b.modified ?? DateTime(0),
        ),
      };
      return _ascending ? result : -result;
    }

    return entries..sort(compare);
  }

  List<FileEntry> get _selection => [
    for (final entry in _visible)
      if (_selected.contains(entry.path)) entry,
  ];

  void _tap(FileEntry entry, List<FileEntry> visible) {
    _focus.requestFocus();
    final keyboard = HardwareKeyboard.instance;
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

  Future<void> _copyTo(List<FileEntry> entries, SftpSide target) async {
    final destination = await ref
        .read(endpointResolverProvider)
        .resolve(target.hostId);
    final dir = await destination.resolve(target.path ?? '~');
    if (!mounted) return;
    final count = await TransferActions.copy(
      context,
      ref,
      fromHostId: widget.side.hostId,
      entries: entries,
      toHostId: target.hostId,
      toDirectory: dir,
      join: destination.paths.join,
    );
    if (count > 0 && mounted) {
      showWgToast(context, 'Queued ${Format.plural(count, 'item')}');
    }
  }

  Future<void> _receive(FileDragPayload payload) async {
    final path = _path;
    final endpoint = _endpoint;
    if (path == null || endpoint == null) return;
    if (payload.hostId == widget.side.hostId &&
        payload.sourcePaneKey == widget.paneKey) {
      return;
    }
    final count = await TransferActions.copy(
      context,
      ref,
      fromHostId: payload.hostId,
      entries: payload.entries,
      toHostId: widget.side.hostId,
      toDirectory: path,
      join: endpoint.paths.join,
    );
    if (count > 0 && mounted) {
      showWgToast(
        context,
        'Queued ${Format.plural(count, 'item')} to ${endpoint.label}',
      );
    }
  }

  Future<void> _receiveOsFiles(List<String> paths) async {
    final local = await ref.read(endpointResolverProvider).resolve(null);
    final entries = <FileEntry>[];
    for (final path in paths) {
      final entry = await local.stat(path);
      if (entry != null) entries.add(entry);
    }
    if (entries.isEmpty || !mounted) return;
    await _receive(
      FileDragPayload(hostId: null, entries: entries, sourcePaneKey: 'os'),
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

  void _openTerminalHere(String path) {
    final hostId = widget.side.hostId;
    final bench = ref.read(workbenchProvider.notifier);
    if (hostId == null) {
      if (PlatformInfo.supportsLocalTerminal) {
        bench.openPane(
          LocalTerminalContent(directory: path),
          placement: PanePlacement.splitDown,
        );
      }
      return;
    }
    bench.openPane(
      SshTerminalContent(hostId: hostId, directory: path),
      placement: PanePlacement.splitDown,
    );
  }

  Future<void> _pickEndpoint() async {
    final pick = await showEndpointPicker(context, title: 'Show files from');
    if (pick == null) return;
    widget.onSideChanged(SftpSide(hostId: pick.host?.id));
    if (pick.host?.id == widget.side.hostId) {
      unawaited(_open(SftpSide(hostId: pick.host?.id)));
    }
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
              onSelected: () => _activate(single),
            ),
            if (single.looksLikeText)
              WgMenuEntry(
                label: 'Edit',
                icon: WgIcons.edit,
                onSelected: () => unawaited(_edit(single)),
              ),
          ],
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
          if (single != null)
            WgMenuEntry(
              label: 'Rename',
              icon: WgIcons.edit,
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
          if (single != null)
            WgMenuEntry(
              label: 'Copy path',
              icon: WgIcons.copy,
              onSelected: () => unawaited(
                Clipboard.setData(ClipboardData(text: single.path)),
              ),
            ),
          WgMenuEntry(
            label: 'Open terminal here',
            icon: WgIcons.terminal,
            enabled: !widget.side.isLocal || PlatformInfo.supportsLocalTerminal,
            onSelected: () => _openTerminalHere(
              single?.isDirectory ?? false ? single!.path : _path!,
            ),
          ),
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
              onSelected: () => unawaited(_delete(selection)),
            ),
        ],
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final visible = _visible;
    final key = event.logicalKey;
    final index = visible.indexWhere((entry) => entry.path == _anchor);
    void select(int next) {
      if (visible.isEmpty) return;
      final entry = visible[next.clamp(0, visible.length - 1)];
      setState(() {
        _selected
          ..clear()
          ..add(entry.path);
        _anchor = entry.path;
      });
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      select(index + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      select(index <= 0 ? 0 : index - 1);
    } else if (key == LogicalKeyboardKey.enter && index >= 0) {
      _activate(visible[index]);
    } else if (key == LogicalKeyboardKey.backspace &&
        !HardwareKeyboard.instance.isMetaPressed) {
      _up();
    } else if (key == LogicalKeyboardKey.delete ||
        (key == LogicalKeyboardKey.backspace &&
            HardwareKeyboard.instance.isMetaPressed)) {
      unawaited(_delete(_selection));
    } else if (key == LogicalKeyboardKey.f2 && index >= 0) {
      unawaited(_rename(visible[index]));
    } else if (key == LogicalKeyboardKey.f5 && widget.copyTarget != null) {
      unawaited(_copyTo(_selection, widget.copyTarget!));
    } else if (key == LogicalKeyboardKey.keyA &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed)) {
      setState(() => _selected.addAll(visible.map((entry) => entry.path)));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hostId = widget.side.hostId;
    final host = ref.watch(hostsProvider).value?.host(hostId);
    final link = hostId == null ? null : ref.watch(hostLinksProvider)[hostId];
    final label = hostId == null
        ? 'This device'
        : host?.label ?? 'Removed host';
    final visible = _visible;
    Widget body = DragTarget<FileDragPayload>(
      onWillAcceptWithDetails: (details) =>
          details.data.sourcePaneKey != widget.paneKey ||
          details.data.hostId != widget.side.hostId,
      onAcceptWithDetails: (details) => unawaited(_receive(details.data)),
      builder: (context, candidates, _) => Container(
        decoration: BoxDecoration(
          color: candidates.isNotEmpty || _dropHover
              ? colors.accentWash
              : colors.canvas,
          border: candidates.isNotEmpty || _dropHover
              ? Border.all(color: colors.accent, width: context.sizes.markerBar)
              : null,
        ),
        child: _content(context, visible, label),
      ),
    );
    if (PlatformInfo.isDesktop) {
      body = DropTarget(
        onDragEntered: (_) => setState(() => _dropHover = true),
        onDragExited: (_) => setState(() => _dropHover = false),
        onDragDone: (details) {
          setState(() => _dropHover = false);
          unawaited(
            _receiveOsFiles([for (final file in details.files) file.path]),
          );
        },
        child: body,
      );
    }
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
            path: _path,
            endpoint: _endpoint,
            onPickEndpoint: () => unawaited(_pickEndpoint()),
            onNavigate: (path) => unawaited(_list(path)),
            onUp: _up,
            onRefresh: () => unawaited(_refresh()),
            onNewFolder: () => unawaited(_newFolder()),
            onUpload: PlatformInfo.isWeb ? null : () => unawaited(_upload()),
            showHidden: _showHidden,
            onToggleHidden: () => setState(() => _showHidden = !_showHidden),
            view: _view,
            onView: (value) => setState(() => _view = value),
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
            onFilter: (value) => setState(() => _filter = value.trim()),
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
      final offline = !denied && widget.side.hostId != null;
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
                  ? 'Drop files here, or drag them in from another pane.'
                  : 'Upload files or copy them in from another pane.',
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
        ],
      );
    }
    final list = _view == ViewMode.list ? _listView(visible) : _grid(visible);
    return Stack(
      children: [
        GestureDetector(
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

  Widget _draggable(FileEntry entry, Widget child) {
    final payload = FileDragPayload(
      hostId: widget.side.hostId,
      entries: _selected.contains(entry.path) ? _selection : [entry],
      sourcePaneKey: widget.paneKey,
    );
    final feedback = Material(
      color: context.colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.space.md,
          vertical: context.space.sm,
        ),
        decoration: BoxDecoration(
          color: context.colors.raised,
          borderRadius: context.radii.mdAll,
          border: Border.all(color: context.colors.accent),
        ),
        child: Text(
          payload.entries.length == 1
              ? entry.name
              : Format.plural(payload.entries.length, 'item'),
          style: context.type.label,
        ),
      ),
    );
    return PlatformInfo.isMobile
        ? LongPressDraggable<FileDragPayload>(
            data: payload,
            feedback: feedback,
            child: child,
          )
        : Draggable<FileDragPayload>(
            data: payload,
            feedback: feedback,
            child: child,
          );
  }

  Widget _listView(List<FileEntry> visible) {
    final colors = context.colors;
    return ListView.builder(
      padding: EdgeInsets.all(context.space.xs),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final entry = visible[index];
        final meta = [
          if (!entry.isDirectory) Format.bytes(entry.size),
          if (entry.modified != null) Format.time(entry.modified!),
        ].join('  ');
        return _draggable(
          entry,
          WgListRow(
            title: entry.name,
            dense: true,
            selected: _selected.contains(entry.path),
            leading: Icon(
              _iconFor(entry),
              color: entry.isDirectory
                  ? colors.textSecondary
                  : colors.textMuted,
            ),
            meta: meta,
            semanticLabel:
                '${entry.isDirectory ? 'Folder' : 'File'} ${entry.name}${meta.isEmpty ? '' : ', $meta'}',
            onPressed: () => PlatformInfo.isMobile
                ? _activateOrSelect(entry, visible)
                : _tap(entry, visible),
            onDoubleTap: PlatformInfo.isMobile ? null : () => _activate(entry),
            onLongPress: PlatformInfo.isMobile
                ? () => _tap(entry, visible)
                : null,
            onSecondaryTapDown: (details) =>
                _menu(details.globalPosition, entry),
          ),
        );
      },
    );
  }

  void _activateOrSelect(FileEntry entry, List<FileEntry> visible) {
    if (_selected.isNotEmpty) {
      setState(() {
        if (!_selected.remove(entry.path)) _selected.add(entry.path);
      });
      return;
    }
    _activate(entry);
  }

  Widget _grid(List<FileEntry> visible) {
    final colors = context.colors;
    return GridView.builder(
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
        return _draggable(
          entry,
          WgPressable(
            semanticLabel:
                '${entry.isDirectory ? 'Folder' : 'File'} ${entry.name}',
            selected: selected,
            onPressed: () => _tap(entry, visible),
            onDoubleTap: () => _activate(entry),
            onSecondaryTapDown: (details) =>
                _menu(details.globalPosition, entry),
            builder: (context, state) => Container(
              padding: EdgeInsets.all(context.space.sm),
              decoration: BoxDecoration(
                color: selected
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
                    _iconFor(entry),
                    size: context.sizes.iconLarge,
                    color: colors.textSecondary,
                  ),
                  SizedBox(height: context.space.sm),
                  Text(
                    entry.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      color: colors.textPrimary,
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

  static IconData _iconFor(FileEntry entry) {
    if (entry.isDirectory) return WgIcons.folder;
    if (entry.isLink) return WgIcons.link;
    if (entry.looksLikeImage) return WgIcons.image;
    if (entry.looksLikeText) return WgIcons.fileText;
    return WgIcons.file;
  }
}

class _Toolbar extends StatefulWidget {
  const new({
    required this.label,
    required this.dot,
    required this.path,
    required this.endpoint,
    required this.onPickEndpoint,
    required this.onNavigate,
    required this.onUp,
    required this.onRefresh,
    required this.onNewFolder,
    required this.onUpload,
    required this.showHidden,
    required this.onToggleHidden,
    required this.view,
    required this.onView,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.onFilter,
  });

  final String label;
  final WgDotState dot;
  final String? path;
  final FileEndpoint? endpoint;
  final VoidCallback onPickEndpoint;
  final ValueChanged<String> onNavigate;
  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final VoidCallback onNewFolder;
  final VoidCallback? onUpload;
  final bool showHidden;
  final VoidCallback onToggleHidden;
  final ViewMode view;
  final ValueChanged<ViewMode> onView;
  final SortKey sort;
  final bool ascending;
  final ValueChanged<SortKey> onSort;
  final ValueChanged<String> onFilter;

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  bool _filtering = false;

  List<(String, String)> _crumbs() {
    final endpoint = widget.endpoint;
    final path = widget.path;
    if (endpoint == null || path == null) return const [];
    final parts = endpoint.paths.split(path);
    final crumbs = <(String, String)>[];
    var cursor = '';
    for (final part in parts) {
      cursor = cursor.isEmpty ? part : endpoint.paths.join(cursor, part);
      crumbs.add((part == '/' ? '/' : part, cursor));
    }
    return crumbs;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final crumbs = _crumbs();
    return Container(
      decoration: BoxDecoration(
        color: colors.canvasDeep,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      padding: EdgeInsets.symmetric(horizontal: space.xs, vertical: space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WgPressable(
                semanticLabel: 'Location: ${widget.label}. Change',
                onPressed: widget.onPickEndpoint,
                borderRadius: context.radii.smAll,
                builder: (context, state) => Container(
                  height: context.sizes.rowCompact - space.xs,
                  padding: EdgeInsets.symmetric(horizontal: space.sm),
                  decoration: BoxDecoration(
                    color: state.highlighted
                        ? colors.raised
                        : colors.transparent,
                    borderRadius: context.radii.smAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WgStatusDot(state: widget.dot, subject: widget.label),
                      SizedBox(width: space.sm),
                      Text(widget.label, style: context.type.label),
                      SizedBox(width: space.xs),
                      Icon(
                        WgIcons.chevronDown,
                        size: context.sizes.icon,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              WgIconButton(
                icon: WgIcons.arrowUp,
                label: 'Up one folder',
                compact: true,
                onPressed: widget.onUp,
              ),
              WgIconButton(
                icon: WgIcons.refresh,
                label: 'Refresh',
                compact: true,
                onPressed: widget.onRefresh,
              ),
              WgIconButton(
                icon: WgIcons.search,
                label: 'Filter',
                compact: true,
                selected: _filtering,
                onPressed: () {
                  setState(() => _filtering = !_filtering);
                  if (!_filtering) widget.onFilter('');
                },
              ),
              WgIconButton(
                icon: widget.showHidden ? WgIcons.eye : WgIcons.hidden,
                label: widget.showHidden
                    ? 'Hide hidden files'
                    : 'Show hidden files',
                compact: true,
                selected: widget.showHidden,
                onPressed: widget.onToggleHidden,
              ),
              WgMenuButton(
                icon: widget.ascending ? WgIcons.sortAsc : WgIcons.sortDesc,
                label: 'Sort',
                entries: () => [
                  for (final (key, label) in [
                    (SortKey.name, 'Name'),
                    (SortKey.size, 'Size'),
                    (SortKey.modified, 'Modified'),
                  ])
                    WgMenuEntry(
                      label: widget.sort == key
                          ? '$label ${widget.ascending ? '↑' : '↓'}'
                          : label,
                      icon: widget.sort == key ? WgIcons.check : null,
                      onSelected: () => widget.onSort(key),
                    ),
                  const WgMenuEntry.divider(),
                  WgMenuEntry(
                    label: widget.view == ViewMode.list
                        ? 'Show as grid'
                        : 'Show as list',
                    icon: widget.view == ViewMode.list
                        ? WgIcons.grid
                        : WgIcons.list,
                    onSelected: () => widget.onView(
                      widget.view == ViewMode.list
                          ? ViewMode.grid
                          : ViewMode.list,
                    ),
                  ),
                ],
              ),
              WgIconButton(
                icon: WgIcons.folderPlus,
                label: 'New folder',
                compact: true,
                onPressed: widget.onNewFolder,
              ),
              if (widget.onUpload != null)
                WgIconButton(
                  icon: WgIcons.upload,
                  label: 'Upload files',
                  compact: true,
                  onPressed: widget.onUpload,
                ),
            ],
          ),
          if (crumbs.isNotEmpty)
            SizedBox(
              height: context.sizes.rowCompact - space.sm,
              child: ListView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                children: [
                  for (final (index, crumb) in crumbs.reversed.indexed) ...[
                    if (index > 0)
                      Icon(
                        WgIcons.chevronRight,
                        size: context.sizes.icon,
                        color: colors.textMuted,
                      ),
                    WgPressable(
                      semanticLabel: 'Go to ${crumb.$2}',
                      onPressed: index == 0
                          ? null
                          : () => widget.onNavigate(crumb.$2),
                      borderRadius: context.radii.xsAll,
                      builder: (context, state) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: space.xs),
                        child: Center(
                          child: Text(
                            crumb.$1,
                            style: context.type.monoSmall.copyWith(
                              color: index == 0
                                  ? colors.textPrimary
                                  : state.highlighted
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
          if (_filtering)
            Padding(
              padding: EdgeInsets.only(top: space.xs),
              child: WgTextField(
                autofocus: true,
                placeholder: 'Filter',
                leadingIcon: WgIcons.search,
                onChanged: widget.onFilter,
              ),
            ),
        ],
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
