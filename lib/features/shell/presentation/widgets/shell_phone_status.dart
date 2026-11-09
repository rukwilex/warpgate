import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/shell/presentation/widgets/transfer_indicator.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';

class ShellPhoneStatus extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(transferQueueProvider);
    final active = jobs.any((job) => job.status.isActive);
    final connected = ref
        .watch(hostLinksProvider)
        .values
        .any((link) => link.isUsable);
    if (!active && !connected) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.md,
        vertical: context.space.xs,
      ),
      color: context.colors.canvasDeep,
      child: Row(
        children: [
          Icon(
            WgIcons.info,
            size: context.sizes.icon,
            color: context.colors.textMuted,
          ),
          SizedBox(width: context.space.sm),
          Expanded(
            child: Text(
              PlatformInfo.isMobile
                  ? 'Sessions stay open while Warpgate is on screen. The system may pause them in the background.'
                  : 'Sessions are active',
              style: context.type.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
          if (active) const TransferIndicator(),
        ],
      ),
    );
  }
}
