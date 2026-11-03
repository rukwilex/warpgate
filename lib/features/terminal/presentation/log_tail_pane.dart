import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/terminal/data/log_tail_session.dart';
import 'package:warpgate/features/workspace/presentation/pane_frame.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';
import 'package:xterm/xterm.dart';

class LogTailPane extends ConsumerStatefulWidget {
  const new({required this.pane, super.key, this.compactChrome = false});

  final Pane pane;
  final bool compactChrome;

  @override
  ConsumerState<LogTailPane> createState() => _LogTailPaneState();
}

class _LogTailPaneState extends ConsumerState<LogTailPane> {
  late LogTailSession _session = _create();

  LogTailSession _create() {
    final content = widget.pane.content as LogTailContent;
    final session = LogTailSession(
      hostId: content.hostId,
      path: content.path,
      pool: ref.read(connectionPoolProvider),
    );
    unawaited(session.start());
    return session;
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _restart() {
    _session.dispose();
    setState(() => _session = _create());
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.pane.content as LogTailContent;
    final host = ref.watch(hostsProvider).value?.host(content.hostId);
    final settings = ref.watch(settingsProvider);
    final theme = settings.terminalScheme.resolve(
      Theme.of(context).brightness,
      context.colors.accent,
    );
    return ValueListenableBuilder<LinkStatus>(
      valueListenable: _session.status,
      builder: (context, status, _) => PaneFrame(
        pane: widget.pane,
        title: host?.label ?? 'Removed host',
        subtitle: 'tail ${content.path}',
        dot: status.state.dot,
        compact: widget.compactChrome,
        menu: [
          WgMenuEntry(
            label: 'Restart',
            icon: WgIcons.retry,
            onSelected: _restart,
          ),
        ],
        child: Stack(
          fit: StackFit.expand,
          children: [
            TerminalView(
              _session.terminal,
              readOnly: true,
              theme: theme,
              textStyle: TerminalStyle(
                fontSize: settings.terminalFontSize,
                fontFamily: WgFonts.mono,
                fontFamilyFallback: WgFonts.monoFallback,
              ),
              padding: EdgeInsets.all(context.space.sm),
            ),
            if (status.state == LinkState.dropped)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(context.space.lg),
                  child: WgInlineMessage(
                    tone: WgTone.caution,
                    message: status.message ?? 'The log stream stopped',
                    action: WgButton(
                      label: 'Restart',
                      icon: WgIcons.retry,
                      onPressed: _restart,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
