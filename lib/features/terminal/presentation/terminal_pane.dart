import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/sftp/presentation/file_drop.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/terminal/presentation/mobile_key_row.dart';
import 'package:warpgate/features/terminal/presentation/terminal_file_targets.dart';
import 'package:warpgate/features/terminal/presentation/terminal_folder_poller.dart';
import 'package:warpgate/features/terminal/presentation/terminal_menu_entries.dart';
import 'package:warpgate/features/terminal/presentation/terminal_prompts.dart';
import 'package:warpgate/features/terminal/presentation/terminal_selection.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_drop_zone.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_files_browser.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_files_split.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_files_toggle.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_notice_banner.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_unavailable_pane.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_viewport.dart';
import 'package:warpgate/features/terminal/utils/folder_hook_message.dart';
import 'package:warpgate/features/terminal/utils/terminal_cursor_type.dart';
import 'package:warpgate/features/terminal/utils/terminal_shortcuts.dart';
import 'package:warpgate/features/workspace/presentation/pane_frame.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/keys/data/key_codec.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';
import 'package:xterm/xterm.dart';

class TerminalPane extends ConsumerStatefulWidget {
  const new({required this.pane, super.key, this.compactChrome = false});

  final Pane pane;
  final bool compactChrome;

  @override
  ConsumerState<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends ConsumerState<TerminalPane>
    with WidgetsBindingObserver {
  final _controller = TerminalController();
  late final _selection = TerminalSelection(
    _controller,
    session: () => _session,
  );
  final _focus = FocusNode(debugLabel: 'terminal');
  TerminalSession? _session;
  bool _bell = false;
  Timer? _bellTimer;
  final _filesArea = FocusNode(
    debugLabel: 'attached files',
    skipTraversal: true,
  );
  final _folderPoll = TerminalFolderPoller();
  bool _osDrop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = ref.read(terminalSessionsProvider).obtain(widget.pane);
    _attach();
    _controller.addListener(_onSelection);
  }

  void _attach() {
    _session?.terminal.onBell = _ringBell;
  }

  bool _focusQueued = false;

  @override
  void didUpdateWidget(TerminalPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pane.id != widget.pane.id) {
      _session = ref.read(terminalSessionsProvider).obtain(widget.pane);
      _attach();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final focused =
        ref.read(workbenchProvider).locate(widget.pane.id)?.tab.focusedPaneId ==
        widget.pane.id;
    if (focused && !_focus.hasFocus && !_filesArea.hasFocus) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bellTimer?.cancel();
    _controller
      ..removeListener(_onSelection)
      ..dispose();
    _focus.dispose();
    _filesArea.dispose();
    _folderPoll.dispose();
    super.dispose();
  }

  TerminalContent get _content => widget.pane.content as TerminalContent;

  void _updateFiles(AttachedFiles Function(AttachedFiles files) change) => ref
      .read(workbenchProvider.notifier)
      .updateAttachedFiles(widget.pane.id, change);

  void _syncFolderPolling(TerminalSession session) {
    final files = _content.files;
    _folderPoll.sync(
      session,
      wanted: files.open && files.follow && !session.reportsFolder,
      interval: context.motion.cwdPoll,
    );
  }

  TerminalFileTargets get _fileTargets => TerminalFileTargets(
    ref.read(endpointResolverProvider),
    hostId: _content.hostId,
  );

  String _terminalFolder(TerminalSession session) =>
      session.cwd.value ?? _content.files.path ?? _content.directory ?? '~';

  void _cdHere(String path) {
    _session?.send(' cd ${KeyCodec.shellQuote(path)}\r');
    _focus.requestFocus();
  }

  Future<void> _showInFiles() async {
    final session = _session;
    final text = _selection.text()?.trim();
    if (session == null || text == null || text.isEmpty) return;
    final path = await _fileTargets.selectionPath(
      text,
      folder: () => _terminalFolder(session),
    );
    _controller.clearSelection();
    _updateFiles(
      (files) => files.copyWith(open: true, follow: false, path: () => path),
    );
  }

  Future<void> _installHook() async {
    final session = _session;
    if (session == null) return;
    final ok = await confirmFolderTracking(context, host: _title());
    if (!ok) return;
    final result = await session.installFolderHook();
    if (!mounted) return;
    showWgToast(context, folderHookMessage(result, _title()));
  }

  Future<void> _upload(List<FileEntry> entries, String? fromHostId) async {
    final session = _session;
    if (session == null || entries.isEmpty) return;
    final folder = await _fileTargets.folder(() => _terminalFolder(session));
    if (!mounted) return;
    try {
      final count = await FileDelivery.deliver(
        context,
        ref,
        fromHostId: fromHostId,
        entries: entries,
        toHostId: _content.hostId,
        toDirectory: folder,
        move: false,
      );
      if (count > 0 && mounted) {
        showWgToast(
          context,
          'Copying ${entries.length == 1 ? entries.first.name : '${entries.length} items'} to $folder on ${_title()}',
        );
      }
    } on Object catch (error) {
      if (mounted) showWgToast(context, 'Could not copy: $error');
    }
  }

  Future<void> _uploadOsFiles(List<String> paths) async {
    await _upload(await _fileTargets.localEntries(paths), null);
  }

  Widget _terminalDrop(TerminalSession session, Widget child) =>
      TerminalDropZone(
        session: session,
        hostId: _content.hostId,
        hostLabel: _title(),
        folder: () => _terminalFolder(session),
        osDrop: _osDrop,
        onOsDragChanged: (value) => setState(() => _osDrop = value),
        onDrop: (entries, fromHostId) =>
            unawaited(_upload(entries, fromHostId)),
        onOsDrop: (paths) => unawaited(_uploadOsFiles(paths)),
        child: child,
      );

  void _toggleFiles() =>
      _updateFiles((files) => files.copyWith(open: !files.open));

  Widget _withFiles(Widget terminal, TerminalSession session) {
    final content = _content;
    final files = content.files;
    if (!files.open) return terminal;
    return TerminalFilesSplit(
      files: files,
      terminal: terminal,
      browser: TerminalFilesBrowser(
        paneId: widget.pane.id,
        focusNode: _filesArea,
        content: content,
        session: session,
        onFilesChanged: _updateFiles,
        cdHere: _cdHere,
        onInstallHook: content is SshTerminalContent
            ? () => unawaited(_installHook())
            : null,
      ),
      onFilesChanged: _updateFiles,
      onDragEnd: session.settleSize,
    );
  }

  void _ringBell() {
    if (ref.read(settingsProvider).bell == BellMode.off || !mounted) return;
    setState(() => _bell = true);
    _bellTimer?.cancel();
    _bellTimer = Timer(context.motion.medium, () {
      if (mounted) setState(() => _bell = false);
    });
  }

  void _onSelection() {
    if (!ref.read(settingsProvider).copyOnSelect) return;
    _selection.copyIfChanged();
  }

  Future<void> _copy() => _selection.copy();

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final lines = '\n'.allMatches(text.trimRight()).length + 1;
    if (lines > 1 && ref.read(settingsProvider).confirmMultilinePaste) {
      final ok = await confirmMultilinePaste(
        context,
        text: text,
        lines: lines,
      );
      if (!ok) return;
    }
    _session?.paste(text);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final keys = ref.read(shortcutMapProvider);
    final copy = terminalCopyActivator();
    final paste = terminalPasteActivator();
    if (copy.accepts(event, HardwareKeyboard.instance)) {
      unawaited(_copy());
      return KeyEventResult.handled;
    }
    if (paste.accepts(event, HardwareKeyboard.instance)) {
      unawaited(_paste());
      return KeyEventResult.handled;
    }
    if (keys.values.any(
      (activator) => activator.accepts(event, HardwareKeyboard.instance),
    )) {
      return KeyEventResult.skipRemainingHandlers;
    }
    return KeyEventResult.ignored;
  }

  void _menu(Offset position) {
    final keys = ref.read(shortcutMapProvider);
    final registry = ref.read(commandRegistryProvider);
    final bench = ref.read(workbenchProvider.notifier);
    unawaited(
      showWgMenu(
        context,
        position: position,
        entries: terminalContextMenuEntries(
          paneId: widget.pane.id,
          keys: keys,
          registry: registry,
          bench: bench,
          hasSelection: _controller.selection != null,
          filesOpen: _content.files.open,
          isSsh: widget.pane.content is SshTerminalContent,
          onCopy: () => unawaited(_copy()),
          onPaste: () => unawaited(_paste()),
          onClearScrollback: () => _session?.terminal.buffer.clear(),
          onShowInFiles: () => unawaited(_showInFiles()),
          onToggleFiles: _toggleFiles,
        ),
      ),
    );
  }

  String _title() {
    return switch (widget.pane.content) {
      SshTerminalContent(:final hostId) =>
        ref.watch(hostsProvider).value?.host(hostId)?.label ?? 'Removed host',
      LocalTerminalContent() => 'Local',
      _ => 'Terminal',
    };
  }

  @override
  Widget build(BuildContext context) {
    final session =
        _session ?? ref.read(terminalSessionsProvider).obtain(widget.pane);
    _session = session;
    final settings = ref.watch(settingsProvider);
    final bench = ref.watch(workbenchProvider);
    final focused =
        bench.locate(widget.pane.id)?.tab.focusedPaneId == widget.pane.id;
    if (focused &&
        !_focusQueued &&
        !_focus.hasFocus &&
        !_filesArea.hasFocus &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _focusQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusQueued = false;
        if (mounted && !_focus.hasFocus && !_filesArea.hasFocus) {
          _focus.requestFocus();
        }
      });
    }
    if (session == null) {
      return TerminalUnavailablePane(
        pane: widget.pane,
        loading: ref.watch(hostsProvider).isLoading,
        title: _title(),
      );
    }
    final colors = context.colors;
    final theme = settings.terminalScheme.resolve(
      Theme.of(context).brightness,
      colors.accent,
    );
    _syncFolderPolling(session);
    return ValueListenableBuilder<LinkStatus>(
      valueListenable: session.status,
      builder: (context, status, _) => PaneFrame(
        pane: widget.pane,
        title: _title(),
        subtitle: switch (widget.pane.content) {
          SshTerminalContent(:final tmuxSession?) => 'tmux $tmuxSession',
          _ => null,
        },
        dot: status.state.dot,
        compact: widget.compactChrome,
        actions: [
          TerminalFilesToggle(
            open: _content.files.open,
            shortcut: ref.read(shortcutMapProvider)['sftp.here'],
            onPressed: _toggleFiles,
          ),
        ],
        menu: terminalPaneMenuEntries(
          treeShown: _content.files.tree,
          filesOpen: _content.files.open,
          isSsh: _content is SshTerminalContent,
          onToggleTree: () =>
              _updateFiles((files) => files.copyWith(tree: !files.tree)),
          onInstallHook: () => unawaited(_installHook()),
        ),
        child: Column(
          children: [
            TerminalNoticeBanner(session: session),
            Expanded(
              child: _withFiles(
                _terminalDrop(
                  session,
                  TerminalViewport(
                    session: session,
                    status: status,
                    title: _title(),
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: focused,
                    theme: theme,
                    cursorType: terminalCursorType(settings.cursorShape),
                    fontSize: widget.pane.fontSize ?? settings.terminalFontSize,
                    onFontSize: (size) => ref
                        .read(workbenchProvider.notifier)
                        .setPaneFontSize(
                          widget.pane.id,
                          size == settings.terminalFontSize ? null : size,
                        ),
                    onKeyEvent: _onKey,
                    onFocusPane: () => ref
                        .read(workbenchProvider.notifier)
                        .focusPane(widget.pane.id),
                    onMenu: _menu,
                    bell: _bell,
                  ),
                ),
                session,
              ),
            ),
            if (PlatformInfo.isMobile && focused)
              MobileKeyRow(session: session, onPaste: _paste),
          ],
        ),
      ),
    );
  }
}
