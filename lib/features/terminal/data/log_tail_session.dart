import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/keys/data/key_codec.dart';
import 'package:xterm/xterm.dart';

class LogTailSession {
  new({required this.hostId, required this.path, required this._pool});

  final String hostId;
  final String path;
  final ConnectionPool _pool;
  final terminal = Terminal(maxLines: 20000);
  final status = ValueNotifier<LinkStatus>(LinkStatus.idle);
  SshSession? _session;
  final List<StreamSubscription<String>> _subscriptions = [];
  bool _disposed = false;

  Future<void> start() async {
    if (_session != null || _disposed) return;
    status.value = const LinkStatus(LinkState.connecting);
    try {
      final client = await _pool.client(hostId);
      _pool.retain(hostId);
      final session = await client.execute(
        'tail -n 500 -F ${KeyCodec.shellQuote(path)}',
      );
      _session = session;
      status.value = const LinkStatus(LinkState.connected);
      void pipe(Stream<List<int>> stream) => _subscriptions.add(
        stream
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen((text) => terminal.write(text.replaceAll('\n', '\r\n'))),
      );
      pipe(session.stdout);
      pipe(session.stderr);
      unawaited(
        session.done.whenComplete(() {
          _pool.release(hostId);
          _session = null;
          if (!_disposed) {
            status.value = const LinkStatus(
              LinkState.dropped,
              message: 'The log stream stopped',
            );
          }
        }),
      );
    } on Object catch (error) {
      if (!_disposed) {
        status.value = LinkStatus(
          LinkState.dropped,
          message: SshErrorText.describe(error),
        );
      }
    }
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _session?.close();
    status.dispose();
  }
}
