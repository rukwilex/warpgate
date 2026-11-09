import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/shell/presentation/widgets/status_bar_item.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

class TransferIndicator extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(transferQueueProvider);
    final running = jobs
        .where((job) => job.status == TransferStatus.running)
        .toList();
    final queued = jobs
        .where((job) => job.status == TransferStatus.queued)
        .length;
    final failed = jobs
        .where((job) => job.status == TransferStatus.failed)
        .length;
    final colors = context.colors;
    final meta = context.type.monoSmall.copyWith(color: colors.textMuted);
    if (running.isEmpty && queued == 0 && failed == 0) {
      return StatusBarItem(
        label: 'Transfers, none active',
        onPressed: () => GoRouter.of(context).go(Routes.transfers),
        child: Row(
          children: [
            Icon(
              WgIcons.transfer,
              size: context.sizes.icon,
              color: colors.textMuted,
            ),
            SizedBox(width: context.space.xs),
            Text('No transfers', style: meta),
          ],
        ),
      );
    }
    final total = running.fold<int>(0, (sum, job) => sum + job.totalBytes);
    final done = running.fold<int>(0, (sum, job) => sum + job.doneBytes);
    final speed = running.fold<double>(
      0,
      (sum, job) => sum + job.bytesPerSecond,
    );
    final fraction = total == 0 ? null : done / total;
    final text = [
      if (running.isNotEmpty) '${running.length} running',
      if (queued > 0) '$queued queued',
      if (speed > 0) Format.speed(speed),
    ].join(' · ');
    final failedText = failed > 0 ? '$failed failed' : '';
    return StatusBarItem(
      label:
          'Transfers: ${[text, failedText].where((part) => part.isNotEmpty).join(', ')}. Open queue',
      onPressed: () => GoRouter.of(context).go(Routes.transfers),
      child: Row(
        children: [
          Icon(
            WgIcons.transfer,
            size: context.sizes.icon,
            color: colors.textSecondary,
          ),
          SizedBox(width: context.space.xs),
          if (text.isNotEmpty)
            Text(text, style: meta.copyWith(color: colors.textSecondary)),
          if (text.isNotEmpty && failedText.isNotEmpty)
            Text(' · ', style: meta),
          if (failedText.isNotEmpty)
            Text(failedText, style: meta.copyWith(color: colors.negative)),
          if (running.isNotEmpty) ...[
            SizedBox(width: context.space.sm),
            SizedBox(
              width: context.space.huge,
              child: WgProgressBar(value: fraction, label: 'Transfer progress'),
            ),
          ],
        ],
      ),
    );
  }
}
