import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/engine/native_ssh.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';

final _env = Platform.environment;
final _label = _env['WARPGATE_PERF_LABEL'] ?? 'run';
final _out = File(_env['WARPGATE_PERF_OUT'] ?? '../../build/perf/results.jsonl');

void record(String scenario, Map<String, Object?> values) {
  final line = jsonEncode({
    'scenario': scenario,
    'label': _label,
    'at': DateTime.now().toIso8601String(),
    ...values,
  });
  stdout.writeln('PERF $line');
  _out.parent.createSync(recursive: true);
  _out.writeAsStringSync('$line\n', mode: FileMode.append);
}

double mb(int bytes) => double.parse((bytes / (1 << 20)).toStringAsFixed(1));

class LoopProbe {
  final _samples = <int>[];
  Timer? _timer;
  late Stopwatch _watch;
  int _last = 0;

  void start() {
    _samples.clear();
    _watch = Stopwatch()..start();
    _last = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      final now = _watch.elapsedMicroseconds;
      _samples.add(now - _last);
      _last = now;
    });
  }

  Map<String, Object?> stop() {
    _timer?.cancel();
    final sorted = [..._samples]..sort();
    if (sorted.isEmpty) return {'loop_p99_ms': 0, 'loop_max_ms': 0};
    double at(double q) => sorted[(q * (sorted.length - 1)).round()] / 1000;
    return {
      'loop_p50_ms': at(0.5),
      'loop_p99_ms': at(0.99),
      'loop_max_ms': sorted.last / 1000,
      'stalls_over_100ms': sorted.where((v) => v > 100000).length,
    };
  }
}

Future<double> cpuSeconds([int? process]) async {
  final result = await Process.run('ps', ['-o', 'time=', '-p', '${process ?? pid}']);
  final text = (result.stdout as String).trim();
  final parts = text.split(':');
  var seconds = 0.0;
  for (final part in parts) {
    seconds = seconds * 60 + double.parse(part);
  }
  return seconds;
}

Future<int> openSockets() async {
  final result = await Process.run('lsof', ['-a', '-p', '$pid', '-i', 'TCP']);
  return (result.stdout as String).split('\n').where((l) => l.contains('TCP')).length;
}

Future<int> openFiles() async {
  final result = await Process.run('lsof', ['-p', '$pid']);
  return (result.stdout as String).split('\n').length - 2;
}

class Fleet {
  Fleet._(this.pool, this.hosts, this.store);

  final ConnectionPool pool;
  final List<Host> hosts;
  final SqliteDocumentStore store;

  static Future<Fleet> open({int hostsCount = 4, int keepAlive = 15, Duration idle = const Duration(seconds: 90)}) async {
    final base = int.parse(_env['WARPGATE_PERF_PORT'] ?? '2300');
    final ports = int.parse(_env['WARPGATE_PERF_COUNT'] ?? '4');
    final user = _env['WARPGATE_PERF_USER'] ?? Platform.environment['USER']!;
    final keyPath = _env['WARPGATE_PERF_KEY']!;
    final dir = Directory.systemTemp.createTempSync('wg_perf');
    final store = SqliteDocumentStore.open('${dir.path}/perf.db');
    final secrets = MemorySecretStore();
    final hostRepo = HostRepository(store, secrets);
    final pem = File(keyPath).readAsStringSync();
    final hosts = [
      for (var i = 0; i < hostsCount; i++)
        Host(
          id: 'h$i',
          label: 'perf-$i',
          address: '127.0.0.1',
          port: base + i % ports,
          username: user,
          auth: AuthMethod.agent,
          keepAliveSeconds: keepAlive,
        ),
    ];
    final broker = InteractionBroker()..attach();
    broker.requests.listen((request) {
      if (request is HostKeyRequest) request.respond(HostKeyVerdict.trustOnce);
    });
    final byId = {for (final host in hosts) host.id: host};
    final pool = ConnectionPool(
      lookup: (id) => byId[id],
      hosts: hostRepo,
      keys: KeyRepository(store, secrets),
      broker: broker,
      idleTimeout: idle,
      agentIdentities: () async => const [],
      fallbackIdentities: (_) async => SSHKeyPair.fromPem(pem),
      fallbackKeys: (_) async => [pem],
    );
    return Fleet._(pool, hosts, store);
  }
}

Future<void> sftpThroughput(String remoteFile, int bytes) async {
  final fleet = await Fleet.open(hostsCount: 1);
  final probe = LoopProbe();
  final sftp = await fleet.pool.sftp('h0');
  final cpu0 = await cpuSeconds();
  final watch = Stopwatch()..start();
  probe.start();
  final file = await sftp.open(remoteFile);
  var got = 0;
  await for (final chunk in file.read()) {
    got += chunk.length;
  }
  await file.close();
  final seconds = watch.elapsedMicroseconds / 1e6;
  final loop = probe.stop();
  final cpu = await cpuSeconds() - cpu0;
  record('ssh.sftp_download', {
    'mb': mb(got),
    'mb_per_s': double.parse((got / (1 << 20) / seconds).toStringAsFixed(1)),
    'cpu_s': cpu,
    'cpu_ms_per_mb': double.parse((cpu * 1000 / (got / (1 << 20))).toStringAsFixed(2)),
    ...loop,
  });

  final local = File('${Directory.systemTemp.path}/wg_perf_upload.bin');
  final upCpu0 = await cpuSeconds();
  final up = Stopwatch()..start();
  probe.start();
  final target = await sftp.open('/tmp/wg_perf_upload.bin', mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate);
  await target.write(local.openRead().map(Uint8List.fromList)).done;
  await target.close();
  final upSeconds = up.elapsedMicroseconds / 1e6;
  final upLoop = probe.stop();
  final upCpu = await cpuSeconds() - upCpu0;
  final upBytes = local.lengthSync();
  record('ssh.sftp_upload', {
    'mb': mb(upBytes),
    'mb_per_s': double.parse((upBytes / (1 << 20) / upSeconds).toStringAsFixed(1)),
    'cpu_s': upCpu,
    'cpu_ms_per_mb': double.parse((upCpu * 1000 / (upBytes / (1 << 20))).toStringAsFixed(2)),
    ...upLoop,
  });
  await fleet.pool.dispose();
}

Future<void> shellFlood(String command, String name) async {
  final fleet = await Fleet.open(hostsCount: 1);
  final client = await fleet.pool.client('h0');
  final probe = LoopProbe();
  final session = await client.execute(command, pty: const SSHPtyConfig(width: 120, height: 40));
  final cpu0 = await cpuSeconds();
  final watch = Stopwatch()..start();
  probe.start();
  var got = 0;
  final decoder = const Utf8Decoder(allowMalformed: true);
  await for (final chunk in session.stdout) {
    got += decoder.convert(chunk).length;
  }
  final seconds = watch.elapsedMicroseconds / 1e6;
  final loop = probe.stop();
  final cpu = await cpuSeconds() - cpu0;
  record('ssh.shell_flood', {
    'load': name,
    'mb': mb(got),
    'mb_per_s': double.parse((got / (1 << 20) / seconds).toStringAsFixed(1)),
    'cpu_ms_per_mb': double.parse((cpu * 1000 / (got / (1 << 20))).toStringAsFixed(2)),
    ...loop,
  });
  await fleet.pool.dispose();
}

Future<void> idleSessions(int count, Duration span) async {
  final fleet = await Fleet.open(hostsCount: count);
  final sessions = <SSHSession>[];
  for (final host in fleet.hosts) {
    final client = await fleet.pool.client(host.id);
    fleet.pool.retain(host.id);
    sessions.add(await client.shell(pty: const SSHPtyConfig()));
  }
  await Future<void>.delayed(const Duration(seconds: 5));
  final cpu0 = await cpuSeconds();
  final rss0 = ProcessInfo.currentRss;
  await Future<void>.delayed(span);
  final cpu = await cpuSeconds() - cpu0;
  record('ssh.idle', {
    'sessions': count,
    'seconds': span.inSeconds,
    'cpu_percent': double.parse((cpu * 100 / span.inSeconds).toStringAsFixed(3)),
    'rss_mb': mb(ProcessInfo.currentRss),
    'rss_growth_mb': mb(ProcessInfo.currentRss - rss0),
    'sockets': await openSockets(),
  });
  for (final session in sessions) {
    session.close();
  }
  await fleet.pool.dispose();
}

Future<void> deadLink(Duration limit) async {
  final fleet = await Fleet.open(hostsCount: 4, keepAlive: 5);
  final detected = <String, Duration>{};
  final watch = Stopwatch();
  for (final host in fleet.hosts) {
    final client = await fleet.pool.client(host.id);
    fleet.pool.retain(host.id);
    await client.shell(pty: const SSHPtyConfig());
    unawaited(client.done.then((_) {}, onError: (_) {}).whenComplete(() => detected[host.id] = watch.elapsed));
  }
  await Process.run('../../tool/perf/sshd_fleet.sh', ['pause']);
  watch.start();
  final deadline = DateTime.now().add(limit);
  while (detected.length < fleet.hosts.length && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  await Process.run('../../tool/perf/sshd_fleet.sh', ['resume']);
  record('ssh.dead_link', {
    'keep_alive_s': 5,
    'hosts': fleet.hosts.length,
    'detected': detected.length,
    'limit_s': limit.inSeconds,
    'slowest_detect_s': detected.isEmpty ? null : detected.values.reduce((a, b) => a > b ? a : b).inMilliseconds / 1000,
    'statuses': {for (final host in fleet.hosts) host.id: fleet.pool.status(host.id).state.name},
  });
  unawaited(fleet.pool.dispose());
}

Future<void> reconnectStorm(int rounds, Duration every) async {
  final fleet = await Fleet.open(hostsCount: 8);
  final rss0 = ProcessInfo.currentRss;
  final sockets0 = await openSockets();
  final probe = LoopProbe()..start();
  for (var round = 0; round < rounds; round++) {
    for (final host in fleet.hosts) {
      try {
        final client = await fleet.pool.client(host.id);
        await fleet.pool.exec(host.id, 'true', timeout: const Duration(seconds: 5));
        unawaited(client.done.then((_) {}, onError: (_) {}));
      } on Object {
        continue;
      }
    }
    await Process.run('../../tool/perf/sshd_fleet.sh', ['drop']);
    await Future<void>.delayed(every);
  }
  final loop = probe.stop();
  await Future<void>.delayed(const Duration(seconds: 2));
  record('ssh.reconnect_storm', {
    'rounds': rounds,
    'hosts': fleet.hosts.length,
    'rss_growth_mb': mb(ProcessInfo.currentRss - rss0),
    'sockets_before': sockets0,
    'sockets_after': await openSockets(),
    'open_files': await openFiles(),
    ...loop,
  });
  await fleet.pool.dispose();
}

Future<void> execLoop(int calls) async {
  final fleet = await Fleet.open(hostsCount: 4);
  final rss0 = ProcessInfo.currentRss;
  final watch = Stopwatch()..start();
  final probe = LoopProbe()..start();
  var failed = 0;
  final rssAt = <int>[];
  for (var i = 0; i < calls; i++) {
    final result = await fleet.pool.exec(fleet.hosts[i % 4].id, 'echo $i');
    if (!result.succeeded) failed++;
    if (i % (calls ~/ 10) == 0) rssAt.add(ProcessInfo.currentRss);
  }
  final loop = probe.stop();
  record('ssh.exec_loop', {
    'calls': calls,
    'failed': failed,
    'calls_per_s': double.parse((calls / (watch.elapsedMilliseconds / 1000)).toStringAsFixed(1)),
    'rss_growth_mb': mb(ProcessInfo.currentRss - rss0),
    'rss_curve_mb': [for (final r in rssAt) mb(r)],
    'sockets': await openSockets(),
    ...loop,
  });
  await fleet.pool.dispose();
}

Future<void> main(List<String> args) async {
  final native = await NativeEngine.ensureLoaded();
  stdout.writeln('engine: ${native && NativeEngine.active ? NativeEngine.version : 'dartssh2'}');
  final which = args.isEmpty ? 'all' : args.first;
  final big = _env['WARPGATE_PERF_FILE'] ?? '${Directory.systemTemp.path}/wg_perf_1g.bin';
  final bytes = File(big).existsSync() ? File(big).lengthSync() : 0;
  if (which == 'sftp' || which == 'all') await sftpThroughput(big, bytes);
  if (which == 'flood' || which == 'all') {
    await shellFlood('yes | head -c 200000000', 'yes');
    await shellFlood('cat $big | head -c 300000000 | base64', 'cat_base64');
  }
  if (which == 'idle' || which == 'all') {
    await idleSessions(20, Duration(seconds: int.parse(_env['WARPGATE_PERF_IDLE_S'] ?? '120')));
  }
  if (which == 'dead' || which == 'all') await deadLink(const Duration(seconds: 90));
  if (which == 'storm' || which == 'all') await reconnectStorm(int.parse(_env['WARPGATE_PERF_ROUNDS'] ?? '20'), const Duration(seconds: 3));
  if (which == 'exec' || which == 'all') await execLoop(int.parse(_env['WARPGATE_PERF_CALLS'] ?? '3000'));
  exit(0);
}
