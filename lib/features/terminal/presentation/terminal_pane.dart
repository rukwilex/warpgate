import 'dart:async';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/application/terminal_link.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/sftp/presentation/file_browser.dart';
import 'package:warpgate/features/sftp/presentation/file_drop.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/terminal/presentation/mobile_key_row.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/terminal/presentation/terminal_surface.dart';
import 'package:warpgate/features/workspace/presentation/layout_view.dart';
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
  final _focus = FocusNode(debugLabel: 'terminal');
  TerminalSession? _session;
  bool _bell = false;
  Timer? _bellTimer;
  String? _lastSelection;
  final _filesArea = FocusNode(
    debugLabel: 'attached files',
    skipTraversal: true,
  );
  Timer? _folderPoll;
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
    _folderPoll?.cancel();
    super.dispose();
  }

  TerminalContent get _content => widget.pane.content as TerminalContent;

  void _updateFiles(AttachedFiles Function(AttachedFiles files) change) => ref
      .read(workbenchProvider.notifier)
      .updateAttachedFiles(widget.pane.id, change);

  void _syncFolderPolling(TerminalSession session) {
    final files = _content.files;
    final wanted = files.open && files.follow && !session.reportsFolder;
    if (wanted && _folderPoll == null) {
      unawaited(session.pollFolder());
      _folderPoll = Timer.periodic(
        context.motion.cwdPoll,
        (_) => unawaited(session.pollFolder()),
      );
    } else if (!wanted && _folderPoll != null) {
      _folderPoll?.cancel();
      _folderPoll = null;
    }
  }

  String _terminalFolder(TerminalSession session) =>
      session.cwd.value ?? _content.files.path ?? _content.directory ?? '~';

  void _cdHere(String path) {
    _session?.send(' cd ${KeyCodec.shellQuote(path)}\r');
    _focus.requestFocus();
  }

  Future<void> _showInFiles() async {
    final session = _session;
    final text = _selectedText()?.trim();
    if (session == null || text == null || text.isEmpty) return;
    final endpoint = await ref
        .read(endpointResolverProvider)
        .resolve(_content.hostId);
    final paths = endpoint.paths;
    var path = text.split('\n').first.trim();
    if (path.startsWith('~')) {
      path = await endpoint.resolve(path);
    } else if (!paths.isAbsolute(path)) {
      path = paths.join(await endpoint.resolve(_terminalFolder(session)), path);
    }
    path = paths.normalize(path);
    _controller.clearSelection();
    _updateFiles(
      (files) => files.copyWith(open: true, follow: false, path: () => path),
    );
  }

  Future<void> _installHook() async {
    final session = _session;
    if (session == null) return;
    final ok = await showWgConfirm(
      context,
      title: 'Track the folder of this shell?',
      message:
          'Warpgate adds one line to your shell startup file on ${_title()} (.bashrc, .zshrc or fish conf.d). The line tells the app which folder the shell is in after every command, so the files panel can follow it. It also runs in this terminal now.',
      confirmLabel: 'Turn on folder tracking',
    );
    if (!ok) return;
    final result = await session.installFolderHook();
    if (!mounted) return;
    showWgToast(context, switch (result) {
      FolderHookResult.installed =>
        'Folder tracking is on. New shells on ${_title()} report their folder',
      FolderHookResult.unsupported =>
        'The shell on ${_title()} is not bash, zsh or fish. The panel checks the folder every few seconds instead',
      FolderHookResult.failed =>
        'Could not write the startup file on ${_title()}',
    });
  }

  Future<void> _upload(List<FileEntry> entries, String? fromHostId) async {
    final session = _session;
    if (session == null || entries.isEmpty) return;
    final endpoint = await ref
        .read(endpointResolverProvider)
        .resolve(_content.hostId);
    final folder = await endpoint.resolve(_terminalFolder(session));
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
    final local = await ref.read(endpointResolverProvider).resolve(null);
    final entries = <FileEntry>[
      for (final path in paths) ?await local.stat(path),
    ];
    await _upload(entries, null);
  }

  Widget _terminalDrop(TerminalSession session, Widget child) {
    final colors = context.colors;
    Widget zone = ValueListenableBuilder<String?>(
      valueListenable: session.cwd,
      builder: (context, cwd, _) => FileDropTarget(
        hostId: _content.hostId,
        hostLabel: _title(),
        folder: _terminalFolder(session),
        verb: 'Copy',
        onDrop: (payload, {required move}) =>
            unawaited(_upload(payload.entries, payload.hostId)),
        builder: (context, {required active}) => Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (active || _osDrop)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accentWash,
                    border: Border.all(
                      color: colors.accent,
                      width: context.sizes.markerBar,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (PlatformInfo.isDesktop) {
      zone = DropTarget(
        onDragEntered: (_) => setState(() => _osDrop = true),
        onDragExited: (_) => setState(() => _osDrop = false),
        onDragDone: (details) {
          setState(() => _osDrop = false);
          unawaited(
            _uploadOsFiles([for (final file in details.files) file.path]),
          );
        },
        child: zone,
      );
    }
    return zone;
  }

  Widget _filesHeaderButtons() {
    final files = _content.files;
    final keys = ref.read(shortcutMapProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WgIconButton(
          icon: WgIcons.filesPanel,
          label: files.open ? 'Hide files' : 'Show files',
          compact: true,
          selected: files.open,
          shortcut: keys['sftp.here'],
          onPressed: () =>
              _updateFiles((files) => files.copyWith(open: !files.open)),
        ),
      ],
    );
  }

  Widget _withFiles(Widget terminal, TerminalSession session) {
    final content = _content;
    final files = content.files;
    if (!files.open) return terminal;
    final browser = Focus(
      focusNode: _filesArea,
      skipTraversal: true,
      child: FileBrowser(
        key: ValueKey('${widget.pane.id}-files'),
        side: SftpSide(
          hostId: content.hostId,
          path: files.path ?? session.cwd.value ?? content.directory,
        ),
        paneKey: '${widget.pane.id}-files',
        showTree: files.tree,
        onTreeChanged: (tree) =>
            _updateFiles((files) => files.copyWith(tree: tree)),
        onSideChanged: (side) =>
            _updateFiles((files) => files.copyWith(path: () => side.path)),
        link: TerminalLink(
          cwd: session.cwd,
          follow: files.follow,
          onFollow: (follow) =>
              _updateFiles((files) => files.copyWith(follow: follow)),
          cdHere: _cdHere,
          onInstallHook: content is SshTerminalContent
              ? () => unawaited(_installHook())
              : null,
        ),
      ),
    );
    final horizontal = files.dock == FilesDock.right;
    final sizes = context.sizes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final available = math.max(extent - sizes.splitterHit, 0);
        double clampRatio(double ratio) {
          if (available <= 0) return ratio;
          final low = math.min(sizes.terminalMin / available, 0.5);
          final high = math.max(1 - sizes.filesPanelMin / available, 0.5);
          return ratio.clamp(low, high);
        }

        final ratio = clampRatio(files.ratio);
        final pixel = MediaQuery.devicePixelRatioOf(context);
        final first = (available * ratio * pixel).roundToDouble() / pixel;
        return Flex(
          direction: horizontal ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: horizontal ? first : null,
              height: horizontal ? null : first,
              child: terminal,
            ),
            PaneDivider(
              horizontal: horizontal,
              ratio: ratio,
              label: horizontal
                  ? 'Resize terminal and files left and right'
                  : 'Resize terminal and files up and down',
              onDrag: (delta) {
                if (available <= 0) return;
                _updateFiles(
                  (files) => files.copyWith(
                    ratio: clampRatio(files.ratio + delta / available),
                  ),
                );
              },
              onStep: (delta) => _updateFiles(
                (files) =>
                    files.copyWith(ratio: clampRatio(files.ratio + delta)),
              ),
              onReset: () => _updateFiles(
                (files) => files.copyWith(ratio: const AttachedFiles().ratio),
              ),
              onDragEnd: session.settleSize,
            ),
            Expanded(child: browser),
          ],
        );
      },
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

  String? _selectedText() {
    final selection = _controller.selection;
    final session = _session;
    if (selection == null || session == null) return null;
    return session.terminal.buffer.getText(selection);
  }

  void _onSelection() {
    if (!ref.read(settingsProvider).copyOnSelect) return;
    final text = _selectedText();
    if (text != null && text.isNotEmpty && text != _lastSelection) {
      _lastSelection = text;
      unawaited(Clipboard.setData(ClipboardData(text: text)));
    }
  }

  Future<void> _copy() async {
    final text = _selectedText();
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _controller.clearSelection();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final lines = '\n'.allMatches(text.trimRight()).length + 1;
    if (lines > 1 && ref.read(settingsProvider).confirmMultilinePaste) {
      final ok = await showWgConfirm(
        context,
        title: 'Paste $lines lines?',
        message:
            'Each line may run as a separate command as soon as it arrives.',
        confirmLabel: 'Paste $lines lines',
        detail: Container(
          constraints: BoxConstraints(maxHeight: context.sizes.previewMax),
          padding: EdgeInsets.all(context.space.sm),
          decoration: BoxDecoration(
            color: context.colors.canvasDeep,
            borderRadius: context.radii.smAll,
          ),
          child: SingleChildScrollView(
            child: Text(text, style: context.type.monoSmall),
          ),
        ),
      );
      if (!ok) return;
    }
    _session?.paste(text);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final keys = ref.read(shortcutMapProvider);
    final copy = PlatformInfo.isApple
        ? const SingleActivator(LogicalKeyboardKey.keyC, meta: true)
        : const SingleActivator(
            LogicalKeyboardKey.keyC,
            control: true,
            shift: true,
          );
    final paste = PlatformInfo.isApple
        ? const SingleActivator(LogicalKeyboardKey.keyV, meta: true)
        : const SingleActivator(
            LogicalKeyboardKey.keyV,
            control: true,
            shift: true,
          );
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
    final isSsh = widget.pane.content is SshTerminalContent;
    unawaited(
      showWgMenu(
        context,
        position: position,
        entries: [
          WgMenuEntry(
            label: 'Copy',
            icon: WgIcons.copy,
            enabled: _controller.selection != null,
            onSelected: () => unawaited(_copy()),
          ),
          WgMenuEntry(
            label: 'Paste',
            icon: WgIcons.paste,
            onSelected: () => unawaited(_paste()),
          ),
          WgMenuEntry(
            label: 'Clear scrollback',
            icon: WgIcons.trash,
            onSelected: () => _session?.terminal.buffer.clear(),
          ),
          if (_controller.selection != null)
            WgMenuEntry(
              label: 'Show in files',
              icon: WgIcons.folderOpen,
              onSelected: () => unawaited(_showInFiles()),
            ),
          const WgMenuEntry.divider(),
          WgMenuEntry(
            label: _content.files.open ? 'Hide files' : 'Show files',
            icon: WgIcons.filesPanel,
            shortcut: keys['sftp.here'],
            onSelected: () =>
                _updateFiles((files) => files.copyWith(open: !files.open)),
          ),
          if (isSsh)
            WgMenuEntry(
              label: 'Open files in a new pane',
              icon: WgIcons.folder,
              onSelected: () {
                bench.focusPane(widget.pane.id);
                registry.openSftpHere();
              },
            ),
          WgMenuEntry(
            label: 'Split right',
            icon: WgIcons.splitHorizontal,
            shortcut: keys['pane.splitRight'],
            onSelected: () => registry.run('pane.splitRight'),
          ),
          WgMenuEntry(
            label: 'Split down',
            icon: WgIcons.splitVertical,
            shortcut: keys['pane.splitDown'],
            onSelected: () => registry.run('pane.splitDown'),
          ),
          WgMenuEntry(
            label: 'Toggle broadcast',
            icon: WgIcons.broadcast,
            onSelected: () => bench.toggleBroadcast(widget.pane.id),
          ),
          const WgMenuEntry.divider(),
          WgMenuEntry(
            label: 'Close pane',
            icon: WgIcons.close,
            destructive: true,
            shortcut: keys['pane.close'],
            onSelected: () => bench.closePane(widget.pane.id),
          ),
        ],
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
    if (session == null && ref.watch(hostsProvider).isLoading) {
      return PaneFrame(
        pane: widget.pane,
        title: 'Loading',
        dot: WgDotState.connecting,
        child: const WgSkeletonList(label: 'Loading hosts'),
      );
    }
    if (session == null) {
      return PaneFrame(
        pane: widget.pane,
        title: _title(),
        dot: WgDotState.dropped,
        child: const WgEmptyState(
          icon: WgIcons.server,
          title: 'This host was removed',
          body: 'The pane points at a host that is no longer saved. Close it, or add the host again.',
        ),
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
        actions: [_filesHeaderButtons()],
        menu: [
          WgMenuEntry(
            label: _content.files.tree
                ? 'Hide folder tree'
                : 'Show folder tree',
            icon: WgIcons.folderTree,
            enabled: _content.files.open,
            onSelected: () =>
                _updateFiles((files) => files.copyWith(tree: !files.tree)),
          ),
          if (_content is SshTerminalContent)
            WgMenuEntry(
              label: 'Set up folder tracking…',
              icon: WgIcons.follow,
              onSelected: () => unawaited(_installHook()),
            ),
        ],
        child: Column(
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: session.notice,
              builder: (context, notice, _) => notice == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.all(context.space.sm),
                      child: WgInlineMessage(
                        tone: WgTone.caution,
                        message: notice,
                        action: WgIconButton(
                          icon: WgIcons.close,
                          label: 'Dismiss',
                          compact: true,
                          onPressed: () => session.notice.value = null,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: _withFiles(
                _terminalDrop(
                  session,
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        label:
                            'Terminal, ${_title()}, ${status.state.dot.label.toLowerCase()}',
                        textField: true,
                        child: TerminalSurface(
                          session: session,
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: focused,
                          theme: theme,
                          cursorType: switch (settings.cursorShape) {
                            CursorShape.block => TerminalCursorType.block,
                            CursorShape.underline =>
                              TerminalCursorType.underline,
                            CursorShape.bar => TerminalCursorType.verticalBar,
                          },
                          fontSize:
                              widget.pane.fontSize ?? settings.terminalFontSize,
                          onFontSize: (size) => ref
                              .read(workbenchProvider.notifier)
                              .setPaneFontSize(
                                widget.pane.id,
                                size == settings.terminalFontSize ? null : size,
                              ),
                          onKeyEvent: _onKey,
                          onTapUp: (_, _) => ref
                              .read(workbenchProvider.notifier)
                              .focusPane(widget.pane.id),
                          onSecondaryTapDown: (details, _) =>
                              _menu(details.globalPosition),
                        ),
                      ),
                      if (_bell)
                        IgnorePointer(
                          child: ColoredBox(color: colors.accentWash),
                        ),
                      if (status.state != LinkState.connected &&
                          status.state != LinkState.busy)
                        _StatusOverlay(
                          status: status,
                          session: session,
                          title: _title(),
                        ),
                    ],
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

class _StatusOverlay extends StatefulWidget {
  const new({required this.status, required this.session, required this.title});

  final LinkStatus status;
  final TerminalSession session;
  final String title;

  @override
  State<_StatusOverlay> createState() => _StatusOverlayState();
}

class _StatusOverlayState extends State<_StatusOverlay> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.status.nextRetry != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final space = context.space;
    final (title, body, action) = switch (status.state) {
      LinkState.connecting => (
        'Connecting to ${widget.title}',
        null,
        WgButton(
          label: 'Cancel',
          icon: WgIcons.close,
          onPressed: widget.session.cancelConnect,
        ),
      ),
      LinkState.reconnecting => (
        'Reconnecting, attempt ${status.attempt} of ${Backoff.maxAttempts}',
        [
          ?status.message,
          if (status.nextRetry case final retry?)
            'Next try in ${retry.difference(DateTime.now()).inSeconds.clamp(0, 999)} s',
        ].join('. '),
        Wrap(
          spacing: space.sm,
          runSpacing: space.sm,
          children: [
            WgButton(
              label: 'Retry now',
              icon: WgIcons.retry,
              onPressed: () => unawaited(widget.session.retryNow()),
            ),
            WgButton.ghost(
              label: 'Stop',
              icon: WgIcons.close,
              onPressed: widget.session.cancelConnect,
            ),
          ],
        ),
      ),
      LinkState.dropped => (
        'Disconnected',
        status.message ??
            'The session ended and will not come back on its own.',
        WgButton.primary(
          label: 'Reconnect',
          icon: WgIcons.retry,
          onPressed: () => unawaited(widget.session.retryNow()),
        ),
      ),
      LinkState.idle when status.message != null => (
        status.message!,
        'Press Enter in the terminal or reconnect.',
        WgButton(
          label: 'Start again',
          icon: WgIcons.play,
          onPressed: () => unawaited(widget.session.retryNow()),
        ),
      ),
      _ => ('', null, null),
    };
    if (title.isEmpty) return const SizedBox.shrink();
    final blocking =
        status.state == LinkState.dropped ||
        status.state == LinkState.connecting;
    final card = Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: EdgeInsets.all(space.lg),
        padding: EdgeInsets.all(space.lg),
        constraints: BoxConstraints(maxWidth: context.sizes.dialog),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: context.radii.lgAll,
          border: Border.all(color: context.colors.hairlineStrong),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: space.xs),
              child: WgStatusDot(state: status.state.dot),
            ),
            SizedBox(width: space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.type.bodyStrong),
                  if (body != null && body.isNotEmpty) ...[
                    SizedBox(height: space.xs),
                    Text(
                      body,
                      style: context.type.body.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                  if (action != null) ...[SizedBox(height: space.md), action],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      color: blocking ? context.colors.veil : context.colors.transparent,
      alignment: blocking ? Alignment.center : Alignment.bottomCenter,
      child: card,
    );
  }
}
