import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/transfers/domain/transfer_job.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';

enum _Filter { all, active, failed, done }

class TransfersScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(transferQueueProvider).reversed.toList();
    final queue = ref.read(transferQueueProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final failed = jobs
        .where((job) => job.status == TransferStatus.failed)
        .length;
    final finished = jobs.where((job) => job.status.isFinished).length;
    final active = jobs
        .where(
          (job) => job.status.isActive || job.status == TransferStatus.paused,
        )
        .length;
    final visible = [
      for (final job in jobs)
        if (switch (_filter) {
          _Filter.all => true,
          _Filter.active =>
            job.status.isActive || job.status == TransferStatus.paused,
          _Filter.failed => job.status == TransferStatus.failed,
          _Filter.done => job.status == TransferStatus.completed,
        })
          job,
    ];
    return WgPage(
      title: 'Transfers',
      subtitle:
          'Up to ${settings.transferConcurrency} at once. Transfers keep running while you work in other panes',
      actions: [
        if (failed > 0)
          WgButton(
            label: 'Retry $failed failed',
            icon: WgIcons.retry,
            onPressed: queue.retryFailed,
          ),
        if (active > 0)
          WgButton(
            label: 'Pause all',
            icon: WgIcons.pause,
            onPressed: queue.pauseAll,
          ),
        if (finished > 0)
          WgButton.ghost(
            label: 'Clear finished',
            onPressed: queue.clearFinished,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (jobs.isNotEmpty) ...[
            WgSegmented<_Filter>(
              label: 'Show',
              value: _filter,
              onChanged: (value) => setState(() => _filter = value),
              segments: [
                WgSegment(_Filter.all, 'All ${jobs.length}'),
                WgSegment(_Filter.active, 'Active $active'),
                WgSegment(_Filter.failed, 'Failed $failed'),
                const WgSegment(_Filter.done, 'Done'),
              ],
            ),
            SizedBox(height: context.space.lg),
          ],
          if (jobs.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: context.space.huge),
              child: const WgEmptyState(
                icon: WgIcons.transfer,
                title: 'No transfers',
                body: 'Drag files between two file panes, or between a pane and your desktop. Copies between hosts stream through here without touching this disk.',
              ),
            )
          else if (visible.isEmpty)
            const WgEmptyState(title: 'Nothing in this view')
          else
            for (final job in visible) _JobRow(job: job),
        ],
      ),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const new({required this.job});

  final TransferJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(hostsProvider).value;
    final queue = ref.read(transferQueueProvider.notifier);
    final colors = context.colors;
    final space = context.space;
    String where(TransferRef ref) => ref.isLocal
        ? 'This device'
        : catalog?.host(ref.hostId)?.label ?? 'Removed host';
    final route = '${where(job.source)} → ${where(job.target)}';
    final tone = switch (job.status) {
      TransferStatus.failed => colors.negative,
      TransferStatus.completed => colors.positive,
      _ => colors.textMuted,
    };
    final progress = job.mode == TransferMode.direct
        ? (job.fraction == null
              ? ''
              : '${((job.fraction ?? 0) * 100).round()}%')
        : job.totalBytes > 0
        ? '${Format.bytes(job.doneBytes)} of ${Format.bytes(job.totalBytes)}'
        : '';
    final speed = job.status == TransferStatus.running && job.bytesPerSecond > 0
        ? '${Format.speed(job.bytesPerSecond)} · ${Format.eta(job.remainingBytes, job.bytesPerSecond)} left'
        : '';
    final files = job.isDirectory && job.filesTotal > 0
        ? '${job.filesDone}/${job.filesTotal} files'
        : '';
    final detail = [
      job.status.label,
      progress,
      files,
      speed,
    ].where((part) => part.isNotEmpty).join(' · ');
    return Semantics(
      container: true,
      label: '${job.name}, $route, $detail',
      child: Container(
        margin: EdgeInsets.only(bottom: space.sm),
        padding: EdgeInsets.all(space.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: context.radii.mdAll,
          border: Border.all(color: colors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  job.isDirectory ? WgIcons.folder : WgIcons.file,
                  size: context.sizes.icon,
                  color: colors.textSecondary,
                ),
                SizedBox(width: space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        style: context.type.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$route${job.mode == TransferMode.direct ? ' · direct' : ''}${job.origin == 'claude_code' ? ' · by Claude Code' : ''}',
                        style: context.type.monoSmall.copyWith(
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ..._actions(queue),
              ],
            ),
            SizedBox(height: space.sm),
            WgProgressBar(
              label: 'Progress of ${job.name}',
              value: job.status == TransferStatus.queued ? 0 : job.fraction,
              tone: switch (job.status) {
                TransferStatus.failed => colors.negative,
                TransferStatus.running || TransferStatus.queued => null,
                _ => colors.textMuted,
              },
            ),
            SizedBox(height: space.xs),
            Text(detail, style: context.type.monoSmall.copyWith(color: tone)),
            if (job.error != null) ...[
              SizedBox(height: space.xs),
              Text(
                job.error!,
                style: context.type.caption.copyWith(color: colors.negative),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(TransferQueue queue) => switch (job.status) {
    TransferStatus.running || TransferStatus.queued => [
      WgIconButton(
        icon: WgIcons.pause,
        label: 'Pause ${job.name}',
        compact: true,
        onPressed: () => queue.pause(job.id),
      ),
      WgIconButton(
        icon: WgIcons.close,
        label: 'Cancel ${job.name}',
        compact: true,
        onPressed: () => queue.cancel(job.id),
      ),
    ],
    TransferStatus.paused => [
      WgIconButton(
        icon: WgIcons.play,
        label: 'Resume ${job.name}',
        compact: true,
        onPressed: () => queue.resume(job.id),
      ),
      WgIconButton(
        icon: WgIcons.close,
        label: 'Cancel ${job.name}',
        compact: true,
        onPressed: () => queue.cancel(job.id),
      ),
    ],
    TransferStatus.failed || TransferStatus.canceled => [
      WgIconButton(
        icon: WgIcons.retry,
        label: 'Retry ${job.name}',
        compact: true,
        onPressed: () => queue.retry(job.id),
      ),
    ],
    TransferStatus.completed => const [],
  };
}
