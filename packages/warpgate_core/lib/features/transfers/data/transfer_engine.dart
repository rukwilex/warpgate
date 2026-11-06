import 'dart:async';

import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

typedef EndpointFor = Future<FileEndpoint> Function(String? hostId);
typedef JobUpdate = void Function(TransferJob Function(TransferJob job) change);
typedef Checksum = Future<String?> Function(String? hostId, String path);

class VerificationFailed implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

class _PlanItem {
  const new(this.relative, this.size, this.mode, {required this.isDirectory});

  final String relative;
  final bool isDirectory;
  final int size;
  final int? mode;
}

class TransferEngine {
  new({
    required this.endpointFor,
    required this.askConflict,
    this.checksum,
    this.progressEvery = const Duration(milliseconds: 250),
  });

  final Duration progressEvery;

  final EndpointFor endpointFor;
  final Checksum? checksum;
  final Future<ConflictAnswer> Function(ConflictRequest request) askConflict;

  Future<void> run(
    TransferJob job, {
    required JobUpdate update,
    required CancelToken cancel,
    required ConflictPolicy policy,
    ConflictResolution? forced,
  }) async {
    final source = await endpointFor(job.source.hostId);
    final target = await endpointFor(job.target.hostId);
    final sourceRoot = await source.resolve(job.source.path);
    final targetRoot = await target.resolve(job.target.path);
    final rootEntry = await source.stat(sourceRoot);
    if (rootEntry == null) {
      throw const FileOperationException('The source no longer exists');
    }

    final plan = <_PlanItem>[];
    if (rootEntry.isDirectory) {
      await _walk(source, sourceRoot, '', plan, cancel);
    } else {
      plan.add(
        _PlanItem('', rootEntry.size, rootEntry.mode, isDirectory: false),
      );
    }
    final total = plan.fold<int>(0, (sum, item) => sum + item.size);
    final files = plan.where((item) => !item.isDirectory).length;
    var done = job.completedFiles.isEmpty
        ? 0
        : plan
              .where((item) => job.completedFiles.contains(item.relative))
              .fold<int>(0, (sum, item) => sum + item.size);
    update(
      (job) =>
          job.copyWith(totalBytes: total, filesTotal: files, doneBytes: done),
    );

    var sticky =
        forced ??
        switch (policy) {
          ConflictPolicy.overwrite => ConflictResolution.overwrite,
          ConflictPolicy.skip => ConflictResolution.skip,
          ConflictPolicy.rename => ConflictResolution.rename,
          ConflictPolicy.ask => null,
        };

    if (rootEntry.isDirectory && !await target.exists(targetRoot)) {
      await target.createDirectory(targetRoot);
      if (rootEntry.mode != null) {
        await _tryMode(target, targetRoot, rootEntry.mode!);
      }
    }

    final meter = SpeedMeter();
    final skippedItems = <String>{};
    final completed = {...job.completedFiles};
    final clock = Stopwatch()..start();
    var lastPublish = -progressEvery.inMicroseconds;
    var filesDone = job.filesDone;
    bool due() {
      final now = clock.elapsedMicroseconds;
      if (now - lastPublish < progressEvery.inMicroseconds) return false;
      lastPublish = now;
      return true;
    }
    for (final item in plan) {
      cancel.throwIfCancelled();
      final sourcePath = item.relative.isEmpty
          ? sourceRoot
          : source.paths.join(sourceRoot, item.relative);
      var targetPath = item.relative.isEmpty
          ? targetRoot
          : target.paths.joinAll([
              targetRoot,
              ...source.paths.split(item.relative),
            ]);
      if (item.isDirectory) {
        if (!await target.exists(targetPath)) {
          await target.createDirectory(targetPath);
          if (item.mode != null) await _tryMode(target, targetPath, item.mode!);
        }
        continue;
      }
      if (job.completedFiles.contains(item.relative)) continue;

      var offset = 0;
      final existing = await target.stat(targetPath);
      final resumable =
          job.partialFile == item.relative &&
          existing != null &&
          existing.size < item.size;
      if (resumable) {
        offset = existing.size;
      } else if (existing != null) {
        var resolution = sticky;
        if (resolution == null) {
          final answer = await askConflict(
            ConflictRequest(
              path: targetPath,
              targetLabel: target.label,
              existingSize: existing.size,
              incomingSize: item.size,
            ),
          );
          resolution = answer.resolution;
          if (answer.applyToAll) sticky = resolution;
        }
        switch (resolution) {
          case ConflictResolution.skip:
            skippedItems.add(item.relative);
            done += item.size;
            completed.add(item.relative);
            filesDone++;
            if (due()) {
              final bytes = done;
              final count = filesDone;
              update(
                (job) => job.copyWith(
                  doneBytes: bytes,
                  filesDone: count,
                  completedFiles: completed,
                ),
              );
            }
            continue;
          case ConflictResolution.rename:
            targetPath = await target.uniqueName(targetPath);
          case ConflictResolution.resume:
            if (existing.size < item.size) offset = existing.size;
          case ConflictResolution.overwrite:
            break;
        }
      }

      final relative = item.relative;
      final fileName = source.paths.basename(sourcePath);
      if (item.size >= 1 << 20 || due()) {
        update(
          (job) => job.copyWith(
            currentFile: () => fileName,
            partialFile: () => relative,
          ),
        );
      }
      final base = done + offset;
      await target.write(
        targetPath,
        source.read(sourcePath, offset: offset),
        offset: offset,
        cancel: cancel,
        onProgress: (written) {
          final now = base + written;
          final speed = meter.add(now);
          if (due()) {
            update(
              (job) => job.copyWith(doneBytes: now, bytesPerSecond: speed),
            );
          }
        },
      );
      cancel.throwIfCancelled();
      if (item.mode != null) await _tryMode(target, targetPath, item.mode!);
      if (job.move || job.verify) {
        await _verify(
          job,
          source: source,
          sourcePath: sourcePath,
          target: target,
          targetPath: targetPath,
          size: item.size,
        );
        final verified = relative;
        update(
          (job) =>
              job.copyWith(verifiedFiles: {...job.verifiedFiles, verified}),
        );
      }
      done += item.size;
      completed.add(relative);
      filesDone++;
      if (item.size >= 1 << 20 || due()) {
        final bytes = done;
        final count = filesDone;
        update(
          (job) => job.copyWith(
            doneBytes: bytes,
            filesDone: count,
            completedFiles: completed,
            partialFile: () => null,
          ),
        );
      }
    }
    final bytes = done;
    final count = filesDone;
    update(
      (job) => job.copyWith(
        doneBytes: bytes,
        filesDone: count,
        completedFiles: completed,
        partialFile: () => null,
      ),
    );
    if (job.move) {
      await _removeSource(
        source,
        sourceRoot,
        plan,
        skippedItems,
        isDirectory: rootEntry.isDirectory,
        cancel: cancel,
      );
    }
  }

  Future<void> _verify(
    TransferJob job, {
    required FileEndpoint source,
    required String sourcePath,
    required FileEndpoint target,
    required String targetPath,
    required int size,
  }) async {
    final written = await target.stat(targetPath);
    if (written == null || written.size != size) {
      throw VerificationFailed(
        'The copy of ${source.paths.basename(sourcePath)} on ${target.label} has ${written?.size ?? 0} bytes, expected $size. The original was kept',
      );
    }
    final hash = checksum;
    if (hash == null) return;
    final (left, right) = await (
      hash(job.source.hostId, sourcePath),
      hash(job.target.hostId, targetPath),
    ).wait;
    if (job.verify && (left == null || right == null)) {
      throw VerificationFailed(
        'No sha256 tool on ${left == null ? source.label : target.label}, so ${source.paths.basename(sourcePath)} could not be verified',
      );
    }
    if (left != null && right != null && left != right) {
      throw VerificationFailed(
        'The checksum of ${source.paths.basename(sourcePath)} on ${target.label} does not match. The original was kept',
      );
    }
  }

  Future<void> _removeSource(
    FileEndpoint source,
    String root,
    List<_PlanItem> plan,
    Set<String> skipped, {
    required bool isDirectory,
    required CancelToken cancel,
  }) async {
    if (!isDirectory) {
      if (!skipped.contains('')) await source.deleteFile(root);
      return;
    }
    for (final item in plan.where((item) => !item.isDirectory)) {
      cancel.throwIfCancelled();
      if (skipped.contains(item.relative)) continue;
      await source.deleteFile(source.paths.join(root, item.relative));
    }
    final folders = [
      for (final item in plan)
        if (item.isDirectory) item.relative,
    ]..sort((a, b) => b.length.compareTo(a.length));
    for (final folder in [...folders, '']) {
      try {
        await source.removeEmptyDirectory(
          folder.isEmpty ? root : source.paths.join(root, folder),
        );
      } on FileOperationException {
        continue;
      }
    }
  }

  Future<void> _walk(
    FileEndpoint endpoint,
    String root,
    String relative,
    List<_PlanItem> plan,
    CancelToken cancel,
  ) async {
    cancel.throwIfCancelled();
    final directory = relative.isEmpty
        ? root
        : endpoint.paths.join(root, relative);
    final entries = await endpoint.list(directory);
    entries.sort((a, b) => a.name.compareTo(b.name));
    for (final entry in entries) {
      final child = relative.isEmpty
          ? entry.name
          : endpoint.paths.join(relative, entry.name);
      if (entry.isDirectory && !entry.isLink) {
        plan.add(_PlanItem(child, 0, entry.mode, isDirectory: true));
        await _walk(endpoint, root, child, plan, cancel);
      } else if (!entry.isDirectory) {
        plan.add(_PlanItem(child, entry.size, entry.mode, isDirectory: false));
      }
    }
  }

  Future<void> _tryMode(FileEndpoint endpoint, String path, int mode) async {
    try {
      await endpoint.setMode(path, mode & 0xFFF);
    } on Object {
      return;
    }
  }
}
