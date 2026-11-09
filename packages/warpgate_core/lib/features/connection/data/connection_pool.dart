import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart' show SSHIdentity;
import 'package:warpgate_core/core/diagnostics/app_log.dart';
import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/host_credentials.dart';
import 'package:warpgate_core/features/connection/data/host_prompts.dart';
import 'package:warpgate_core/features/connection/data/ssh_connector.dart';
import 'package:warpgate_core/features/connection/data/ssh_defaults.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart' show CancelToken;

export 'package:warpgate_core/features/connection/data/ssh_defaults.dart';

typedef HostLookup = Host? Function(String id);

class _Entry {
  final cancel = CancelToken();
  late final Future<SshClient> client;
  SshClient? live;
  Future<SshSftp>? sftp;
  int holders = 0;
  int operations = 0;
  Timer? idleTimer;
  bool closing = false;
  bool probing = false;
  DateTime lastProbe = DateTime.now();
  int keepAliveSeconds = 0;

  bool get usable => !closing && live != null;
}

class ConnectionPool {
  ConnectionPool({
    required HostLookup lookup,
    required HostRepository hosts,
    required KeyRepository keys,
    required InteractionBroker broker,
    Duration idleTimeout = SshDefaults.idleTimeout,
    this.probeTimeout = SshDefaults.probeTimeout,
    this.livenessTick = SshDefaults.livenessTick,
    Future<List<SSHIdentity>> Function()? agentIdentities,
    Future<List<SSHIdentity>> Function(Host host)? fallbackIdentities,
    Future<List<String>> Function(Host host)? fallbackKeys,
    SocketDialer? dial,
    SshConnector? connector,
  }) : _lookup = lookup,
       _idleTimeout = idleTimeout,
       _connector =
           connector ??
           _defaultConnector(
             hosts: hosts,
             keys: keys,
             broker: broker,
             agentIdentities: agentIdentities,
             fallbackIdentities: fallbackIdentities,
             fallbackKeys: fallbackKeys,
             dial: dial,
           );

  static SshConnector _defaultConnector({
    required HostRepository hosts,
    required KeyRepository keys,
    required InteractionBroker broker,
    required Future<List<SSHIdentity>> Function()? agentIdentities,
    required Future<List<SSHIdentity>> Function(Host host)? fallbackIdentities,
    required Future<List<String>> Function(Host host)? fallbackKeys,
    required SocketDialer? dial,
  }) {
    final prompts = HostPrompts(hosts, broker);
    final credentials = HostCredentials(
      keys: keys,
      prompts: prompts,
      agentIdentities: agentIdentities,
      fallbackIdentities: fallbackIdentities,
      fallbackKeys: fallbackKeys,
    );
    return EngineSshConnector(credentials: credentials, prompts: prompts, dial: dial);
  }

  final HostLookup _lookup;
  final Duration _idleTimeout;
  final SshConnector _connector;
  final Duration probeTimeout;
  final Duration livenessTick;

  final Map<String, _Entry> _entries = {};
  Timer? _liveness;
  DateTime _lastTick = DateTime.now();
  final Stopwatch _clock = Stopwatch()..start();
  Duration _lastTickClock = Duration.zero;
  int deadLinksClosed = 0;
  int wakeUps = 0;
  final Map<String, LinkStatus> _status = {};
  final _changes = StreamController<String>.broadcast();

  Stream<String> get changes => _changes.stream;

  LinkStatus status(String hostId) => _status[hostId] ?? LinkStatus.idle;

  Map<String, LinkStatus> get statuses => Map.unmodifiable(_status);

  bool isOpen(String hostId) => _entries.containsKey(hostId);

  void _emit(String hostId, LinkStatus status) {
    if (_status[hostId] == status) return;
    _status[hostId] = status;
    if (!_changes.isClosed) _changes.add(hostId);
  }

  void _refreshBusy(String hostId) {
    final entry = _entries[hostId];
    if (entry == null || !status(hostId).isUsable) return;
    _emit(hostId, LinkStatus(entry.operations > 0 ? LinkState.busy : LinkState.connected));
  }

  Host _require(String hostId) {
    final host = _lookup(hostId);
    if (host == null) {
      throw StateError('This host is no longer saved. Add it again in Hosts');
    }
    return host;
  }

  bool _current(String hostId, _Entry entry) => identical(_entries[hostId], entry) && !entry.closing;

  Future<SshClient> client(String hostId) => _entryFor(hostId).client;

  _Entry _entryFor(String hostId) {
    final existing = _entries[hostId];
    if (existing != null && !existing.closing) return existing;
    final host = _require(hostId);
    final entry = _Entry();
    entry.client = _open(host, entry.cancel);
    _entries[hostId] = entry;
    _emit(hostId, const LinkStatus(LinkState.connecting));
    unawaited(
      entry.client.then(
        (client) => _onOpened(hostId, entry, client),
        onError: (Object error) => _onFailed(hostId, entry, error),
      ),
    );
    return entry;
  }

  void _onOpened(String hostId, _Entry entry, SshClient client) {
    if (!_current(hostId, entry)) {
      unawaited(client.close());
      return;
    }
    entry
      ..live = client
      ..keepAliveSeconds = _lookup(hostId)?.keepAliveSeconds ?? 0
      ..lastProbe = DateTime.now();
    LiveObjects.opened('ssh connection');
    _ensureLiveness();
    _emit(hostId, const LinkStatus(LinkState.connected));
    _refreshBusy(hostId);
    unawaited(
      client.done.then<void>(
        (_) => _onClosed(hostId, entry, null),
        onError: (Object error) => _onClosed(hostId, entry, error),
      ),
    );
    _scheduleIdle(hostId, entry);
  }

  void _onFailed(String hostId, _Entry entry, Object error) {
    if (!identical(_entries[hostId], entry)) return;
    _entries.remove(hostId);
    _emit(
      hostId,
      error is ConnectCancelledException
          ? LinkStatus.idle
          : LinkStatus(LinkState.dropped, message: SshErrorText.describe(error)),
    );
  }

  void _onClosed(String hostId, _Entry entry, Object? error) {
    if (entry.live != null) {
      entry.live = null;
      LiveObjects.closed('ssh connection');
    }
    if (!identical(_entries[hostId], entry)) {
      _stopLivenessIfIdle();
      return;
    }
    _entries.remove(hostId);
    entry.idleTimer?.cancel();
    _stopLivenessIfIdle();
    _emit(
      hostId,
      entry.closing
          ? LinkStatus.idle
          : LinkStatus(
              LinkState.dropped,
              message: error == null ? 'The connection closed' : SshErrorText.describe(error),
            ),
    );
  }

  void cancelConnect(String hostId) {
    final entry = _entries[hostId];
    if (entry == null || entry.live != null) return;
    entry.cancel.cancel();
  }

  void retain(String hostId) {
    final entry = _entries[hostId];
    if (entry == null) return;
    entry
      ..holders += 1
      ..idleTimer?.cancel();
  }

  void release(String hostId) {
    final entry = _entries[hostId];
    if (entry == null) return;
    entry.holders = entry.holders > 0 ? entry.holders - 1 : 0;
    _scheduleIdle(hostId, entry);
  }

  void _scheduleIdle(String hostId, _Entry entry) {
    entry.idleTimer?.cancel();
    if (entry.holders > 0 || entry.operations > 0 || !entry.usable) return;
    entry.idleTimer = Timer(_idleTimeout, () {
      if (entry.holders == 0 && entry.operations == 0 && _current(hostId, entry)) {
        unawaited(disconnect(hostId));
      }
    });
  }

  Future<T> withOperation<T>(String hostId, Future<T> Function(SshClient client) body) async {
    final entry = _entryFor(hostId);
    final ssh = await entry.client;
    entry
      ..operations += 1
      ..idleTimer?.cancel();
    _refreshBusy(hostId);
    try {
      return await body(ssh);
    } finally {
      entry.operations -= 1;
      if (_current(hostId, entry)) {
        _refreshBusy(hostId);
        _scheduleIdle(hostId, entry);
      }
    }
  }

  Future<SshSftp> sftp(String hostId) async {
    final entry = _entryFor(hostId);
    final ssh = await entry.client;
    if (!_current(hostId, entry) || !identical(entry.live, ssh)) {
      throw StateError('The connection to this host closed. Try again');
    }
    final pending = entry.sftp ??= ssh.sftp();
    try {
      return await pending;
    } on Object {
      if (identical(entry.sftp, pending)) entry.sftp = null;
      rethrow;
    }
  }

  void dropSftp(String hostId) => _entries[hostId]?.sftp = null;

  Future<ExecResult> exec(String hostId, String command, {Duration timeout = SshDefaults.execTimeout}) async {
    final watch = Stopwatch()..start();
    try {
      return await withOperation(hostId, (ssh) async {
        final session = await ssh.execute(command);
        final stdout = BytesBuilder(copy: false);
        final stderr = BytesBuilder(copy: false);
        final outDone = session.stdout.forEach(stdout.add);
        final errDone = session.stderr.forEach(stderr.add);
        var timedOut = false;
        int? exitCode;
        try {
          exitCode = await session.waitForExit(timeout: timeout);
        } on TimeoutException {
          timedOut = true;
          session.close();
        }
        await Future.wait([outDone, errDone]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
        if (!timedOut) exitCode ??= session.exitCode;
        return ExecResult(
          stdout: utf8.decode(stdout.takeBytes(), allowMalformed: true),
          stderr: utf8.decode(stderr.takeBytes(), allowMalformed: true),
          exitCode: exitCode,
          duration: watch.elapsed,
          timedOut: timedOut,
        );
      });
    } on Object catch (error) {
      return ExecResult.failure(SshErrorText.describe(error), watch.elapsed);
    }
  }

  Future<void> disconnect(String hostId) async {
    final entry = _entries[hostId];
    if (entry == null) return;
    entry
      ..closing = true
      ..idleTimer?.cancel();
    _entries.remove(hostId);
    _emit(hostId, LinkStatus.idle);
    if (entry.live == null) entry.cancel.cancel();
    try {
      final ssh = await entry.client;
      await ssh.close();
    } on Object {
      return;
    }
  }

  Future<void> dispose() async {
    _liveness?.cancel();
    _liveness = null;
    for (final hostId in List.of(_entries.keys)) {
      await disconnect(hostId);
    }
    await _changes.close();
  }

  int get openConnections => _entries.values.where((e) => e.live != null).length;

  bool get livenessRunning => _liveness != null;

  void _ensureLiveness() {
    if (_liveness != null) return;
    _lastTick = DateTime.now();
    _lastTickClock = _clock.elapsed;
    _liveness = Timer.periodic(livenessTick, (_) => _checkLiveness());
  }

  void _stopLivenessIfIdle() {
    if (_entries.values.any((e) => e.live != null)) return;
    _liveness?.cancel();
    _liveness = null;
  }

  void _checkLiveness() {
    final now = DateTime.now();
    final clock = _clock.elapsed;
    final wallGap = now.difference(_lastTick);
    final clockGap = clock - _lastTickClock;
    _lastTick = now;
    _lastTickClock = clock;
    final woke = wallGap > livenessTick * 5 || wallGap - clockGap > const Duration(seconds: 3);
    if (woke) wakeUps++;
    for (final MapEntry(key: hostId, value: entry) in _entries.entries.toList()) {
      final client = entry.live;
      if (client == null || entry.closing || entry.probing) continue;
      final every = entry.keepAliveSeconds;
      if (every <= 0 && !woke) continue;
      if (!woke && now.difference(entry.lastProbe) < Duration(seconds: every)) continue;
      unawaited(_probe(hostId, entry, client, woke ? probeTimeout ~/ 2 : probeTimeout));
    }
  }

  Future<void> probe(String hostId) async {
    final entry = _entries[hostId];
    final client = entry?.live;
    if (entry == null || client == null || entry.probing) return;
    await _probe(hostId, entry, client, probeTimeout);
  }

  Future<void> probeAll() async {
    await Future.wait([for (final hostId in List.of(_entries.keys)) probe(hostId)]);
  }

  Future<void> _probe(String hostId, _Entry entry, SshClient client, Duration timeout) async {
    entry
      ..probing = true
      ..lastProbe = DateTime.now();
    try {
      await client.ping().timeout(timeout);
    } on Object {
      if (identical(entry.live, client) && !entry.closing) {
        deadLinksClosed++;
        AppLog.instance.warning(
          'ssh',
          'Closed the connection to $hostId: no keep-alive reply within ${timeout.inSeconds} s',
        );
        unawaited(client.close());
        _onClosed(hostId, entry, const DeadLinkError());
      }
    } finally {
      entry.probing = false;
    }
  }

  Future<SshClient> _open(Host host, CancelToken cancel) async {
    final jumpId = host.jumpHostId;
    if (jumpId == null) return _connector.open(host, cancel: cancel);
    final jump = await client(jumpId);
    retain(jumpId);
    try {
      final opened = await _connector.open(host, jump: jump, cancel: cancel);
      unawaited(opened.done.then((_) => release(jumpId), onError: (_) => release(jumpId)));
      return opened;
    } on Object {
      release(jumpId);
      rethrow;
    }
  }
}
