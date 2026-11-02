import 'package:flutter/foundation.dart';
import 'package:warpgate/core/data/app_database.dart';

enum TransferStatus {
  queued('Queued'),
  running('Running'),
  paused('Paused'),
  completed('Done'),
  failed('Failed'),
  canceled('Cancelled');

  new(this.label);

  final String label;

  bool get isActive =>
      this == TransferStatus.queued || this == TransferStatus.running;

  bool get isFinished =>
      this == TransferStatus.completed ||
      this == TransferStatus.failed ||
      this == TransferStatus.canceled;
}

enum TransferMode {
  stream('Through the app'),
  direct('Direct between hosts');

  new(this.label);

  final String label;
}

@immutable
class TransferRef {
  const new({required this.path, this.hostId});

  factory fromJson(JsonMap json) => TransferRef(
    hostId: json['hostId'] as String?,
    path: json['path']! as String,
  );

  final String? hostId;
  final String path;

  bool get isLocal => hostId == null;

  JsonMap toJson() => {'hostId': hostId, 'path': path};
}

@immutable
class TransferJob {
  const new({
    required this.id,
    required this.source,
    required this.target,
    required this.name,
    required this.createdAt,
    this.isDirectory = false,
    this.status = TransferStatus.queued,
    this.mode = TransferMode.stream,
    this.totalBytes = 0,
    this.doneBytes = 0,
    this.filesTotal = 0,
    this.filesDone = 0,
    this.bytesPerSecond = 0,
    this.currentFile,
    this.error,
    this.startedAt,
    this.finishedAt,
    this.completedFiles = const {},
    this.partialFile,
    this.origin = 'user',
  });

  factory fromJson(JsonMap json) => TransferJob(
    id: json['id']! as String,
    source: TransferRef.fromJson((json['source']! as Map).cast()),
    target: TransferRef.fromJson((json['target']! as Map).cast()),
    name: json['name']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    isDirectory: json['isDirectory'] as bool? ?? false,
    status: TransferStatus.values.byName(json['status'] as String? ?? 'queued'),
    mode: TransferMode.values.byName(json['mode'] as String? ?? 'stream'),
    totalBytes: json['totalBytes'] as int? ?? 0,
    doneBytes: json['doneBytes'] as int? ?? 0,
    filesTotal: json['filesTotal'] as int? ?? 0,
    filesDone: json['filesDone'] as int? ?? 0,
    error: json['error'] as String?,
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt']! as String),
    finishedAt: json['finishedAt'] == null
        ? null
        : DateTime.parse(json['finishedAt']! as String),
    completedFiles: ((json['completedFiles'] as List?) ?? const <Object?>[])
        .cast<String>()
        .toSet(),
    partialFile: json['partialFile'] as String?,
    origin: json['origin'] as String? ?? 'user',
  );

  final String id;
  final TransferRef source;
  final TransferRef target;
  final String name;
  final DateTime createdAt;
  final bool isDirectory;
  final TransferStatus status;
  final TransferMode mode;
  final int totalBytes;
  final int doneBytes;
  final int filesTotal;
  final int filesDone;
  final double bytesPerSecond;
  final String? currentFile;
  final String? error;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final Set<String> completedFiles;
  final String? partialFile;
  final String origin;

  double? get fraction =>
      totalBytes <= 0 ? null : (doneBytes / totalBytes).clamp(0, 1);

  int get remainingBytes => (totalBytes - doneBytes).clamp(0, totalBytes);

  bool get isHostToHost =>
      source.hostId != null &&
      target.hostId != null &&
      source.hostId != target.hostId;

  TransferJob copyWith({
    TransferStatus? status,
    TransferMode? mode,
    int? totalBytes,
    int? doneBytes,
    int? filesTotal,
    int? filesDone,
    double? bytesPerSecond,
    String? Function()? currentFile,
    String? Function()? error,
    DateTime? Function()? startedAt,
    DateTime? Function()? finishedAt,
    Set<String>? completedFiles,
    String? Function()? partialFile,
  }) => TransferJob(
    id: id,
    source: source,
    target: target,
    name: name,
    createdAt: createdAt,
    isDirectory: isDirectory,
    origin: origin,
    status: status ?? this.status,
    mode: mode ?? this.mode,
    totalBytes: totalBytes ?? this.totalBytes,
    doneBytes: doneBytes ?? this.doneBytes,
    filesTotal: filesTotal ?? this.filesTotal,
    filesDone: filesDone ?? this.filesDone,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    currentFile: currentFile == null ? this.currentFile : currentFile(),
    error: error == null ? this.error : error(),
    startedAt: startedAt == null ? this.startedAt : startedAt(),
    finishedAt: finishedAt == null ? this.finishedAt : finishedAt(),
    completedFiles: completedFiles ?? this.completedFiles,
    partialFile: partialFile == null ? this.partialFile : partialFile(),
  );

  JsonMap toJson() => {
    'id': id,
    'source': source.toJson(),
    'target': target.toJson(),
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'isDirectory': isDirectory,
    'status': status.name,
    'mode': mode.name,
    'totalBytes': totalBytes,
    'doneBytes': doneBytes,
    'filesTotal': filesTotal,
    'filesDone': filesDone,
    'error': error,
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'completedFiles': completedFiles.toList(),
    'partialFile': partialFile,
    'origin': origin,
  };
}

class SpeedMeter {
  new({this.window = const Duration(seconds: 3)});

  final Duration window;
  final List<(DateTime, int)> _samples = [];

  double add(int totalBytes, [DateTime? at]) {
    final now = at ?? DateTime.now();
    _samples
      ..add((now, totalBytes))
      ..removeWhere((sample) => now.difference(sample.$1) > window);
    if (_samples.length < 2) return 0;
    final first = _samples.first;
    final elapsed = now.difference(first.$1).inMicroseconds / 1e6;
    if (elapsed <= 0) return 0;
    return (totalBytes - first.$2) / elapsed;
  }

  void reset() => _samples.clear();
}
