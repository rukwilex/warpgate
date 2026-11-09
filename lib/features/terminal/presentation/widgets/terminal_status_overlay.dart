import 'dart:async';

import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/terminal/presentation/terminal_constants.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';

class TerminalStatusOverlay extends StatefulWidget {
  const new({
    required this.status,
    required this.session,
    required this.title,
    super.key,
  });

  final LinkStatus status;
  final TerminalSession session;
  final String title;

  @override
  State<TerminalStatusOverlay> createState() => _TerminalStatusOverlayState();
}

class _TerminalStatusOverlayState extends State<TerminalStatusOverlay> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(TerminalConstants.statusTick, (_) {
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
            'Next try in ${retry.difference(DateTime.now()).inSeconds.clamp(0, TerminalConstants.retryCountdownMaxSeconds)} s',
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
