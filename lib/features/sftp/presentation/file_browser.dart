import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
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
import 'package:warpgate/features/sftp/application/file_selection.dart';
import 'package:warpgate/features/sftp/application/file_sort_key.dart';
import 'package:warpgate/features/sftp/application/path_bar_controller.dart';
import 'package:warpgate/features/sftp/application/repeat_tap_detector.dart';
import 'package:warpgate/features/sftp/application/terminal_link.dart';
import 'package:warpgate/features/sftp/application/type_ahead_buffer.dart';
import 'package:warpgate/features/sftp/application/view_mode.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/sftp/presentation/file_browser_constants.dart';
import 'package:warpgate/features/sftp/presentation/file_browser_shortcuts.dart';
import 'package:warpgate/features/sftp/presentation/file_columns.dart';
import 'package:warpgate/features/sftp/presentation/file_dialogs.dart';
import 'package:warpgate/features/sftp/presentation/file_drop.dart';
import 'package:warpgate/features/sftp/presentation/folder_tree.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_browser_filter_bar.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_browser_footer.dart';
import 'package:warpgate/features/sftp/presentation/widgets/file_browser_toolbar.dart';
import 'package:warpgate/features/sftp/utils/file_filter.dart';
import 'package:warpgate/features/sftp/utils/file_icon.dart';
import 'package:warpgate/features/sftp/utils/file_sorting.dart';
import 'package:warpgate/features/sftp/utils/transfer_changes.dart';
import 'package:warpgate/features/sftp/utils/type_ahead.dart';
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

export 'package:warpgate/features/sftp/application/file_sort_key.dart'
    show SortKey;

part 'file_browser_actions.dart';
part 'file_browser_content.dart';
part 'file_browser_input.dart';
part 'file_browser_loading.dart';
part 'file_browser_menu.dart';

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
  final _selected = FileSelection();
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
  final _typeAheadBuffer = TypeAheadBuffer();
  final _taps = RepeatTapDetector();
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

  String? get _hostId => widget.side.hostId;

  void _update(VoidCallback change) => setState(change);

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
    _generation++;
    _entries = null;
    _visibleCache = null;
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

  List<FileEntry>? _visibleCache;
  Object? _visibleKey;

  List<FileEntry> get _visible {
    final key = (_entries, _filter, _showHidden, _sort, _ascending);
    final cached = _visibleCache;
    if (cached != null && key == _visibleKey) return cached;
    final result = FileSorting.sorted(
      filterFileEntries(
        _entries ?? const <FileEntry>[],
        _filter,
        showHidden: _showHidden,
      ),
      _sort,
      ascending: _ascending,
    );
    _visibleKey = key;
    return _visibleCache = result;
  }

  List<FileEntry> get _selection => _selected.entriesIn(_visible);

  String get _hostLabel => _hostId == null
      ? 'This device'
      : ref.read(hostsProvider).value?.host(_hostId)?.label ?? 'Removed host';

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
      final touched = completedTransfersTouch(
        previous,
        next,
        hostId: hostId,
        path: path,
        paths: _endpoint?.paths,
      );
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
          FileBrowserToolbar(
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
            FileBrowserFilterBar(
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
          FileBrowserFooter(
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
}
