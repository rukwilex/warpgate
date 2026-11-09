import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';
import 'package:warpgate_core/features/workspace/domain/workspace.dart';

final sessionAutoStartProvider = Provider<bool>((ref) => true);

class TerminalSessions extends ChangeNotifier {
  new(this._ref);

  static const scrollbackCollection = 'scrollback';

  final Ref _ref;
  final Map<String, TerminalSession> _sessions = {};
  final Map<String, String> _restoredScrollback = {};
  Set<String> _broadcast = const {};

  Iterable<TerminalSession> get all => _sessions.values;

  void settleSizes() {
    for (final session in _sessions.values) {
      session.settleSize();
    }
  }

  TerminalSession? operator [](String paneId) => _sessions[paneId];

  Future<void> preloadScrollback() async {
    final store = _ref.read(documentStoreProvider);
    for (final json in await store.all(scrollbackCollection)) {
      _restoredScrollback[json['paneId']! as String] = json['text']! as String;
    }
  }

  SessionTarget? _targetFor(Pane pane) {
    switch (pane.content) {
      case SshTerminalContent(
        :final hostId,
        :final tmuxSession,
        :final directory,
      ):
        final host = _ref.read(hostsProvider).value?.host(hostId);
        if (host == null) return null;
        return SshTarget(
          host: host,
          tmuxSession: tmuxSession,
          directory: directory,
        );
      case LocalTerminalContent(:final directory):
        return LocalTarget(directory: directory);
      case SftpContent():
      case LogTailContent():
        return null;
    }
  }

  TerminalSession? obtain(Pane pane, {bool start = true}) {
    final existing = _sessions[pane.id];
    if (existing != null) return existing;
    final target = _targetFor(pane);
    if (target == null) return null;
    final settings = _ref.read(settingsProvider);
    final session = TerminalSession(
      id: pane.id,
      target: target,
      pool: _ref.read(connectionPoolProvider),
      maxLines: settings.scrollbackLines,
      autoReconnect: settings.autoReconnect,
      restoredScrollback: _restoredScrollback.remove(pane.id),
    );
    _sessions[pane.id] = session;
    _applyBroadcast(session);
    if (start && _ref.read(sessionAutoStartProvider)) {
      unawaited(session.start());
    }
    notifyListeners();
    return session;
  }

  void sync(WorkbenchState state) {
    final alive = {for (final location in state.allPanes) location.pane.id};
    for (final id
        in _sessions.keys.where((id) => !alive.contains(id)).toList()) {
      _sessions.remove(id)?.dispose();
      unawaited(
        _ref.read(documentStoreProvider).delete(scrollbackCollection, id),
      );
    }
    if (!setEquals(_broadcast, state.broadcastPaneIds)) {
      _broadcast = state.broadcastPaneIds;
      _sessions.values.forEach(_applyBroadcast);
    }
    notifyListeners();
  }

  void _applyBroadcast(TerminalSession session) {
    session.inputSink = _broadcast.contains(session.id) && _broadcast.length > 1
        ? _fanOut
        : null;
  }

  void _fanOut(TerminalSession origin, String data) {
    for (final id in _broadcast) {
      _sessions[id]?.send(data);
    }
  }

  void broadcastText(String text, {Set<String>? paneIds}) {
    for (final id in paneIds ?? _broadcast) {
      _sessions[id]?.send(text);
    }
  }

  Future<void> restoreAll(WorkbenchState state) async {
    final panes = [
      for (final location in state.allPanes)
        if (location.pane.content is SshTerminalContent) location.pane,
    ];
    for (final pane in panes) {
      obtain(pane);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> persistScrollback() async {
    final settings = _ref.read(settingsProvider);
    final store = _ref.read(documentStoreProvider);
    if (!settings.persistScrollback) {
      await store.clear(scrollbackCollection);
      return;
    }
    for (final session in _sessions.values) {
      final text = session.tail(settings.persistedScrollbackLines);
      if (text.isEmpty) continue;
      await store.put(scrollbackCollection, session.id, {
        'paneId': session.id,
        'text': text,
      });
    }
  }

  @override
  void dispose() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}

final terminalSessionsProvider = Provider<TerminalSessions>((ref) {
  final sessions = TerminalSessions(ref);
  ref
    ..listen(
      workbenchProvider,
      (_, next) => sessions.sync(next),
      fireImmediately: true,
    )
    ..onDispose(sessions.dispose);
  return sessions;
});
