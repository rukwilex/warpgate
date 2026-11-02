import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/features/connection/data/ssh_errors.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/hosts/data/host_repository.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/keys/data/key_repository.dart';

typedef HostLookup = Host? Function(String id);

class _Entry {
  new(this.client);

  final Future<SSHClient> client;
  Future<SftpClient>? sftp;
  int holders = 0;
  int operations = 0;
  Timer? idleTimer;
  bool closing = false;
}

class ConnectionPool {
  new({
    required this._lookup,
    required this._hosts,
    required this._keys,
    required this._broker,
    this._idleTimeout = const Duration(seconds: 90),
    Future<SSHSocket> Function(String host, int port)? dial,
  }) : _dial = dial ?? _defaultDial;

  static Future<SSHSocket> _defaultDial(String host, int port) =>
      SSHSocket.connect(host, port, timeout: const Duration(seconds: 12));

  final HostLookup _lookup;
  final HostRepository _hosts;
  final KeyRepository _keys;
  final InteractionBroker _broker;
  final Duration _idleTimeout;
  final Future<SSHSocket> Function(String host, int port) _dial;

  final Map<String, _Entry> _entries = {};
  final Map<String, LinkStatus> _status = {};
  final _changes = StreamController<String>.broadcast();
  final Map<String, Future<void>> _promptLocks = {};

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
    final current = status(hostId);
    if (entry == null || !current.isUsable) return;
    _emit(
      hostId,
      LinkStatus(entry.operations > 0 ? LinkState.busy : LinkState.connected),
    );
  }

  Host _require(String hostId) {
    final host = _lookup(hostId);
    if (host == null) {
      throw StateError('This host is no longer saved. Add it again in Hosts');
    }
    return host;
  }

  Future<SSHClient> client(String hostId) {
    final existing = _entries[hostId];
    if (existing != null && !existing.closing) return existing.client;
    final entry = _Entry(_open(_require(hostId)));
    _entries[hostId] = entry;
    _emit(hostId, const LinkStatus(LinkState.connecting));
    unawaited(
      entry.client.then(
        (client) {
          _emit(hostId, const LinkStatus(LinkState.connected));
          _refreshBusy(hostId);
          unawaited(
            client.done.then<void>(
              (_) => _onClosed(hostId, entry, null),
              onError: (Object error) => _onClosed(hostId, entry, error),
            ),
          );
          _scheduleIdle(hostId, entry);
        },
        onError: (Object error) {
          if (identical(_entries[hostId], entry)) _entries.remove(hostId);
          _emit(
            hostId,
            LinkStatus(
              LinkState.dropped,
              message: SshErrorText.describe(error),
            ),
          );
        },
      ),
    );
    return entry.client;
  }

  void _onClosed(String hostId, _Entry entry, Object? error) {
    if (!identical(_entries[hostId], entry)) return;
    _entries.remove(hostId);
    entry.idleTimer?.cancel();
    _emit(
      hostId,
      entry.closing
          ? LinkStatus.idle
          : LinkStatus(
              LinkState.dropped,
              message: error == null
                  ? 'The connection closed'
                  : SshErrorText.describe(error),
            ),
    );
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
    entry.holders = (entry.holders - 1).clamp(0, 1 << 20);
    _scheduleIdle(hostId, entry);
  }

  void _scheduleIdle(String hostId, _Entry entry) {
    entry.idleTimer?.cancel();
    if (entry.holders > 0 || entry.operations > 0) return;
    entry.idleTimer = Timer(_idleTimeout, () {
      if (entry.holders == 0 && entry.operations == 0) {
        unawaited(disconnect(hostId));
      }
    });
  }

  Future<T> withOperation<T>(
    String hostId,
    Future<T> Function(SSHClient client) body,
  ) async {
    final ssh = await client(hostId);
    final entry = _entries[hostId];
    entry?.operations += 1;
    entry?.idleTimer?.cancel();
    _refreshBusy(hostId);
    try {
      return await body(ssh);
    } finally {
      if (entry != null) {
        entry.operations -= 1;
        _refreshBusy(hostId);
        _scheduleIdle(hostId, entry);
      }
    }
  }

  Future<SftpClient> sftp(String hostId) async {
    await client(hostId);
    final entry = _entries[hostId]!;
    final pending = entry.sftp ??= entry.client.then((ssh) => ssh.sftp());
    try {
      return await pending;
    } on Object {
      entry.sftp = null;
      rethrow;
    }
  }

  void dropSftp(String hostId) => _entries[hostId]?.sftp = null;

  Future<ExecResult> exec(
    String hostId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
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
        await Future.wait([outDone, errDone])
            .timeout(const Duration(seconds: 2), onTimeout: () => const []);
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
    try {
      final ssh = await entry.client;
      await ssh.close();
    } on Object {
      return;
    }
  }

  Future<void> dispose() async {
    for (final hostId in List.of(_entries.keys)) {
      await disconnect(hostId);
    }
    await _changes.close();
  }

  Future<SSHClient> _open(Host host) async {
    final socket = host.jumpHostId == null
        ? await _dial(host.address, host.port)
        : await _throughJump(host);
    final identities = await _identities(host);
    final ssh = SSHClient(
      socket,
      username: host.username,
      identities: identities,
      keepAliveInterval: host.keepAliveSeconds > 0
          ? Duration(seconds: host.keepAliveSeconds)
          : null,
      handshakeTimeout: const Duration(seconds: 15),
      onVerifyHostKey: (type, fingerprint) =>
          _verifyHostKey(host, type, utf8.decode(fingerprint)),
      onPasswordRequest: host.auth == AuthMethod.password
          ? () => _password(host)
          : null,
      onUserInfoRequest: (request) => _keyboardInteractive(host, request),
      ident: 'Warpgate_1.0',
    );
    try {
      await ssh.authenticated;
    } on Object {
      unawaited(ssh.close());
      rethrow;
    }
    return ssh;
  }

  Future<SSHSocket> _throughJump(Host host) async {
    final jumpId = host.jumpHostId!;
    final jump = await client(jumpId);
    retain(jumpId);
    final channel = await jump.forwardLocal(host.address, host.port);
    unawaited(channel.done.whenComplete(() => release(jumpId)));
    return channel;
  }

  Future<List<SSHKeyPair>?> _identities(Host host) async {
    if (host.auth != AuthMethod.key || host.keyId == null) return null;
    final material = await _keys.privateMaterial(host.keyId!);
    if (material == null) {
      throw const MissingCredentialsException(
        'The key for this host is missing. Pick a key in the host settings',
      );
    }
    var passphrase = material.passphrase;
    if (SSHKeyPair.isEncryptedPem(material.pem) && passphrase == null) {
      passphrase = await _serialPrompt(
        host.id,
        () => _broker.ask(
          SecretRequest(
            title: 'Unlock key',
            message:
                'The key for ${host.label} is protected with a passphrase.',
            fieldLabel: 'Passphrase',
          ),
        ),
      );
      if (passphrase == null) {
        throw const MissingCredentialsException(
          'A passphrase is needed to use this key',
        );
      }
    }
    return SSHKeyPair.fromPem(material.pem, passphrase);
  }

  Future<T> _serialPrompt<T>(String hostId, Future<T> Function() prompt) async {
    while (_promptLocks[hostId] != null) {
      await _promptLocks[hostId];
    }
    final completer = Completer<void>();
    _promptLocks[hostId] = completer.future;
    try {
      return await prompt();
    } finally {
      _promptLocks.remove(hostId)?.ignore();
      completer.complete();
    }
  }

  Future<String?> _password(Host host) async {
    final stored = await _hosts.password(host.id);
    if (stored != null) return stored;
    final request = SecretRequest(
      title: 'Password for ${host.label}',
      message: host.endpoint,
      fieldLabel: 'Password',
      allowRemember: true,
    );
    final value = await _serialPrompt(host.id, () => _broker.ask(request));
    if (value != null && request.remember) {
      await _hosts.setPassword(host.id, value);
    }
    return value;
  }

  Future<List<String>?> _keyboardInteractive(
    Host host,
    SSHUserInfoRequest request,
  ) async {
    final answers = <String>[];
    for (final prompt in request.prompts) {
      final isPassword = prompt.promptText.toLowerCase().contains('password');
      if (isPassword) {
        final stored = await _hosts.password(host.id);
        if (stored != null) {
          answers.add(stored);
          continue;
        }
      }
      final value = await _serialPrompt(
        host.id,
        () => _broker.ask(
          SecretRequest(
            title: request.name.isEmpty
                ? 'Sign in to ${host.label}'
                : request.name,
            message: request.instruction.isEmpty
                ? host.endpoint
                : request.instruction,
            fieldLabel: prompt.promptText.trim().replaceAll(RegExp(r':$'), ''),
          ),
        ),
      );
      if (value == null) return null;
      answers.add(value);
    }
    return answers;
  }

  Future<bool> _verifyHostKey(
    Host host,
    String type,
    String fingerprint,
  ) async {
    final known = await _hosts.knownHost(host.knownHostsKey);
    if (known != null && known.fingerprint == fingerprint) return true;
    final verdict = await _serialPrompt(
      host.id,
      () => _broker.ask(
        HostKeyRequest(
          hostLabel: host.label,
          endpoint: host.knownHostsKey,
          keyType: type,
          fingerprint: fingerprint,
          previousFingerprint: known?.fingerprint,
        ),
      ),
    );
    switch (verdict) {
      case HostKeyVerdict.reject:
        return false;
      case HostKeyVerdict.trustOnce:
        return true;
      case HostKeyVerdict.trustAndSave:
        await _hosts.trust(
          KnownHost(
            endpoint: host.knownHostsKey,
            keyType: type,
            fingerprint: fingerprint,
            addedAt: DateTime.now(),
          ),
        );
        return true;
    }
  }
}
