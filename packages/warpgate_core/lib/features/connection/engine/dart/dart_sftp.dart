import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';

class DartSftp implements SshSftp {
  new(this._sftp);

  final SftpClient _sftp;

  @override
  Future<List<SftpName>> listdir(String path) => _sftp.listdir(path);

  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) =>
      _sftp.stat(path, followLink: followLink);

  @override
  Future<void> setStat(String path, SftpFileAttrs attrs) => _sftp.setStat(path, attrs);

  @override
  Future<void> mkdir(String path) => _sftp.mkdir(path);

  @override
  Future<void> rmdir(String path) => _sftp.rmdir(path);

  @override
  Future<void> remove(String path) => _sftp.remove(path);

  @override
  Future<void> rename(String from, String to) => _sftp.rename(from, to);

  @override
  Future<String> absolute(String path) => _sftp.absolute(path);

  @override
  Future<SshSftpFile> open(String path, {SftpFileOpenMode mode = SftpFileOpenMode.read}) async =>
      DartSftpFile(await _sftp.open(path, mode: mode));

  @override
  Future<void> close() => _sftp.close();
}

class DartSftpFile implements SshSftpFile {
  new(this._file);

  final SftpFile _file;

  @override
  Stream<Uint8List> read({int? length, int offset = 0, void Function(int bytes)? onProgress}) =>
      _file.read(length: length, offset: offset, onProgress: onProgress);

  @override
  SshSftpWriter write(Stream<Uint8List> data, {int offset = 0, void Function(int total)? onProgress}) =>
      DartSftpWriter(_file.write(data, offset: offset, onProgress: onProgress));

  @override
  Future<void> close() => _file.close();
}

class DartSftpWriter implements SshSftpWriter {
  new(this._writer);

  final SftpFileWriter _writer;

  @override
  Future<void> get done => _writer.done;

  @override
  Future<void> abort() => _writer.abort();
}
