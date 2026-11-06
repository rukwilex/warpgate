@Tags(['perf'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

class _VirtualEndpoint extends FileEndpoint {
  new(this.label, {this.files = 0, this.fileSize = 0});

  @override
  final String label;
  final int files;
  final int fileSize;
  final Map<String, int> written = {};
  static final _chunk = Uint8List(32 * 1024);

  @override
  bool get isLocal => false;

  @override
  p.Context get paths => p.posix;

  @override
  Future<String> home() async => '/';

  @override
  Future<List<FileEntry>> list(String directory) async => [
    for (var i = 0; i < files; i++)
      FileEntry(name: 'f$i', path: '$directory/f$i', isDirectory: false, size: fileSize),
  ];

  @override
  Future<FileEntry?> stat(String path) async {
    if (path == '/src') return const FileEntry(name: 'src', path: '/src', isDirectory: true);
    if (path.startsWith('/src/')) {
      return FileEntry(name: p.basename(path), path: path, isDirectory: false, size: fileSize);
    }
    final size = written[path];
    return size == null ? null : FileEntry(name: p.basename(path), path: path, isDirectory: false, size: size);
  }

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> rename(String from, String to) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> removeEmptyDirectory(String path) async {}

  @override
  Future<void> setMode(String path, int mode) async {}

  @override
  Stream<Uint8List> read(String path, {int offset = 0}) async* {
    for (var sent = offset; sent < fileSize; sent += _chunk.length) {
      yield _chunk;
    }
  }

  @override
  Future<void> write(
    String path,
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int written)? onProgress,
    CancelToken? cancel,
  }) async {
    var total = 0;
    await for (final chunk in data) {
      total += chunk.length;
      onProgress?.call(total);
      if (total % (1 << 20) == 0) await Future<void>.delayed(Duration.zero);
    }
    written[path] = offset + total;
  }
}

class _Resolver extends EndpointResolver {
  new(this.source, this.target, ConnectionPool pool) : super(pool: pool, labelOf: (_) => null);

  final FileEndpoint source;
  final FileEndpoint target;

  @override
  Future<FileEndpoint> resolve(String? hostId) async => hostId == 'src' ? source : target;
}

Future<Map<String, Object?>> _run({required int files, required int fileSize, required int history}) async {
  final dir = Directory.systemTemp.createTempSync('wg_transfer_perf');
  final store = SqliteDocumentStore.open('${dir.path}/t.db');
  final secrets = MemorySecretStore();
  final pool = ConnectionPool(
    lookup: (_) => null,
    hosts: HostRepository(store, secrets),
    keys: KeyRepository(store, secrets),
    broker: InteractionBroker(),
  );
  final source = _VirtualEndpoint('src', files: files, fileSize: fileSize);
  final target = _VirtualEndpoint('dst');
  var publishes = 0;
  var listCopies = 0;
  final old = [
    for (var i = 0; i < history; i++)
      TransferJob(
        id: 'old$i',
        source: const TransferRef(path: '/a', hostId: 'src'),
        target: const TransferRef(path: '/b'),
        name: 'old',
        createdAt: DateTime(2026),
        status: TransferStatus.completed,
      ),
  ];
  final scheduler = TransferScheduler(
    store: store,
    pool: pool,
    resolver: _Resolver(source, target, pool),
    broker: InteractionBroker(),
    hostOf: (_) => null,
    settings: () => const AppSettings(),
    initial: old,
    autoRun: false,
    onChange: (jobs) {
      publishes++;
      listCopies += jobs.length;
    },
  );
  final id = scheduler.enqueue(
    source: TransferRef(path: files > 1 ? '/src' : '/src/one', hostId: 'src'),
    target: const TransferRef(path: '/dst'),
    name: 'perf',
    isDirectory: files > 1,
    start: false,
  );
  final watch = Stopwatch()..start();
  final result = await scheduler.run(id);
  final seconds = watch.elapsedMicroseconds / 1e6;
  final bytes = files * fileSize;
  final json = jsonEncode(result.toJson()).length;
  store.close();
  dir.deleteSync(recursive: true);
  return {
    'status': result.status.name,
    'files': files,
    'mb': bytes >> 20,
    'seconds': double.parse(seconds.toStringAsFixed(2)),
    'publishes': publishes,
    'publishes_per_s': (publishes / seconds).round(),
    'job_list_copies': listCopies,
    'final_job_json_bytes': json,
    'mb_per_s_overhead_bound': double.parse(((bytes >> 20) / seconds).toStringAsFixed(1)),
  };
}

void record(String scenario, Map<String, Object?> values) {
  final line = jsonEncode({
    'scenario': scenario,
    'label': Platform.environment['WARPGATE_PERF_LABEL'] ?? 'run',
    'at': DateTime.now().toIso8601String(),
    ...values,
  });
  stdout.writeln('PERF $line');
  final out = File(Platform.environment['WARPGATE_PERF_OUT'] ?? '../../build/perf/results.jsonl');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$line\n', mode: FileMode.append);
}

void main() {
  test('one 2 GB file with 200 old jobs in the list', () async {
    final result = await _run(files: 1, fileSize: 2 << 30, history: 200);
    record('transfer.big_file', result);
    expect(result['publishes']! as int, lessThan(((result['seconds']! as double) * 8).ceil() + 10));
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('20,000 small files', () async {
    final result = await _run(files: 20000, fileSize: 4096, history: 0);
    record('transfer.many_files', result);
    expect(result['publishes']! as int, lessThan(((result['seconds']! as double) * 8).ceil() + 10));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
