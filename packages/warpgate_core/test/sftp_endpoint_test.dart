import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart' show SftpAbortError, SftpStatusError;
import 'package:test/test.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/sftp/data/endpoints.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

import 'helpers/fake_ssh.dart';

class StallingWriter implements SshSftpWriter {
  final _done = Completer<void>();
  bool aborted = false;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> abort() async {
    aborted = true;
    if (!_done.isCompleted) _done.completeError(SftpAbortError('The transfer was cancelled'));
  }

  void fail(Object error) => _done.completeError(error);
}

class WritableFile implements SshSftpFile {
  new(this.writer);

  final StallingWriter writer;
  bool closed = false;

  @override
  Stream<Uint8List> read({int? length, int offset = 0, void Function(int bytes)? onProgress}) =>
      const Stream.empty();

  @override
  SshSftpWriter write(Stream<Uint8List> data, {int offset = 0, void Function(int total)? onProgress}) => writer;

  @override
  Future<void> close() async => closed = true;
}

class WritableSftp extends FakeSftp {
  new(this.file);

  final WritableFile file;

  @override
  Future<SshSftpFile> open(String path, {SftpFileOpenMode mode = SftpFileOpenMode.read}) async => file;
}

class LinkSftp extends FakeSftp {
  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async =>
      SftpFileAttrs(mode: SftpFileMode.value(followLink ? 0x4000 | 493 : 0xA000 | 511));
}

void main() {
  late StallingWriter writer;
  late WritableFile file;
  late SftpEndpoint endpoint;

  setUp(() {
    writer = StallingWriter();
    file = WritableFile(writer);
    endpoint = SftpEndpoint(WritableSftp(file), label: 'remote');
  });

  test('cancelling an upload reports a cancellation, not a failure', () async {
    final cancel = CancelToken();
    final writing = endpoint.write('/tmp/x', const Stream.empty(), cancel: cancel);
    await Future<void>.delayed(Duration.zero);
    cancel.cancel();
    await expectLater(writing, throwsA(isA<TransferCancelled>()));
    expect(writer.aborted, isTrue);
    expect(file.closed, isTrue);
  });

  test('a server error during an upload is reported as a file error', () async {
    final writing = endpoint.write('/tmp/x', const Stream.empty(), cancel: CancelToken());
    await Future<void>.delayed(Duration.zero);
    writer.fail(SftpStatusError(3, 'denied'));
    await expectLater(
      writing,
      throwsA(isA<FileOperationException>().having((e) => e.message, 'message', 'Permission denied')),
    );
    expect(file.closed, isTrue);
  });

  test('stat reports a symlink to a folder as a link so it is not deleted through', () async {
    final entry = await SftpEndpoint(LinkSftp(), label: 'remote').stat('/srv/current');
    expect(entry!.isLink, isTrue);
    expect(entry.isDirectory, isTrue);
  });
}
