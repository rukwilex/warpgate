import 'dart:async';

import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/features/settings/domain/app_settings.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate/features/transfers/domain/transfer_job.dart';

typedef EndpointFor = Future<FileEndpoint> Function(String? hostId);
typedef JobUpdate = void Function(TransferJob Function(TransferJob job) change);

class _PlanItem {
  const new(this.relative, this.size, this.mode, {required this.isDirectory});

  final String relative;
  final bool isDirectory;
  final int size;
  final int? mode;
}

class TransferEngine {
  new({required this.endpointFor, required this.askConflict});

  final EndpointFor endpointFor;
  final Future<ConflictAnswer> Function(ConflictRequest request) askConflict;

  Future<void> run(
    TransferJob job, {
    required JobUpdate update,
    required CancelToken cancel,
    required ConflictPolicy policy,
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

    var sticky = switch (policy) {
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
            done += item.size;
            final skipped = item.relative;
            update(
              (job) => job.copyWith(
                doneBytes: done,
                filesDone: job.filesDone + 1,
                completedFiles: {...job.completedFiles, skipped},
              ),
            );
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
      update(
        (job) => job.copyWith(
          currentFile: () => fileName,
          partialFile: () => relative,
        ),
      );
      final base = done + offset;
      await target.write(
        targetPath,
        source.read(sourcePath, offset: offset),
        offset: offset,
        cancel: cancel,
        onProgress: (written) {
          final now = base + written;
          final speed = meter.add(now);
          update((job) => job.copyWith(doneBytes: now, bytesPerSecond: speed));
        },
      );
      cancel.throwIfCancelled();
      if (item.mode != null) await _tryMode(target, targetPath, item.mode!);
      done += item.size;
      update(
        (job) => job.copyWith(
          doneBytes: done,
          filesDone: job.filesDone + 1,
          completedFiles: {...job.completedFiles, relative},
          partialFile: () => null,
        ),
      );
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
