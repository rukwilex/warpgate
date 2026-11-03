import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

@immutable
class FileEntry {
  const new({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isLink = false,
    this.size = 0,
    this.modified,
    this.mode,
    this.owner,
    this.group,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isLink;
  final int size;
  final DateTime? modified;
  final int? mode;
  final String? owner;
  final String? group;

  bool get isHidden => name.startsWith('.');

  String get permissions =>
      FileModes.describe(mode, isDirectory: isDirectory, isLink: isLink);

  static (String?, String?) ownerFromLongName(String longName) {
    final parts = longName.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) return (null, null);
    return (parts[2], parts[3]);
  }

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get looksLikeImage =>
      const {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'}.contains(extension);

  bool get looksLikeText =>
      !looksLikeImage &&
      (const {
            'txt',
            'md',
            'log',
            'conf',
            'cfg',
            'ini',
            'yaml',
            'yml',
            'json',
            'toml',
            'sh',
            'bash',
            'zsh',
            'py',
            'js',
            'ts',
            'dart',
            'go',
            'rs',
            'c',
            'h',
            'cpp',
            'java',
            'kt',
            'rb',
            'php',
            'html',
            'css',
            'xml',
            'sql',
            'env',
            'service',
            'csv',
            'tf',
          }.contains(extension) ||
          !name.contains('.') ||
          name.startsWith('.'));
}

abstract final class FileModes {
  static String describe(
    int? mode, {
    bool isDirectory = false,
    bool isLink = false,
  }) {
    if (mode == null) return '';
    const letters = 'rwxrwxrwx';
    final buffer = StringBuffer(
      isLink
          ? 'l'
          : isDirectory
          ? 'd'
          : '-',
    );
    for (var i = 0; i < 9; i++) {
      final bit = 1 << (8 - i);
      buffer.write(mode & bit != 0 ? letters[i] : '-');
    }
    return buffer.toString();
  }
}

class CancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const TransferCancelled();
  }
}

class TransferCancelled implements Exception {
  const new();
}

class FileOperationException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class FileEndpoint {
  String get label;

  bool get isLocal;

  p.Context get paths;

  Future<String> home();

  Future<String> resolve(String path) async {
    final home = await this.home();
    if (path == '~' || path.isEmpty) return home;
    if (path.startsWith('~/')) return paths.join(home, path.substring(2));
    return path;
  }

  Future<List<FileEntry>> list(String directory);

  Future<FileEntry?> stat(String path);

  Future<void> createDirectory(String path);

  Future<void> rename(String from, String to);

  Future<void> deleteFile(String path);

  Future<void> deleteDirectory(String path) async {
    for (final entry in await list(path)) {
      if (entry.isDirectory && !entry.isLink) {
        await deleteDirectory(entry.path);
      } else {
        await deleteFile(entry.path);
      }
    }
    await removeEmptyDirectory(path);
  }

  Future<void> removeEmptyDirectory(String path);

  Future<void> setMode(String path, int mode);

  Stream<Uint8List> read(String path, {int offset = 0});

  Future<void> write(
    String path,
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int written)? onProgress,
    CancelToken? cancel,
  });

  Future<Uint8List> readAll(
    String path, {
    int maxBytes = 2 * 1024 * 1024,
  }) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in read(path)) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw FileOperationException(
          'The file is larger than ${maxBytes ~/ 1024} KB',
        );
      }
    }
    return builder.takeBytes();
  }

  Future<void> writeAll(String path, Uint8List bytes) =>
      write(path, Stream.value(bytes));

  Future<bool> exists(String path) async => await stat(path) != null;

  Future<String> uniqueName(String path) async {
    if (!await exists(path)) return path;
    final dir = paths.dirname(path);
    final base = paths.basenameWithoutExtension(path);
    final ext = paths.extension(path);
    for (var i = 1; i < 1000; i++) {
      final candidate = paths.join(dir, '$base ($i)$ext');
      if (!await exists(candidate)) return candidate;
    }
    return paths.join(
      dir,
      '$base (${DateTime.now().millisecondsSinceEpoch})$ext',
    );
  }

  Future<void> close() async {}
}
