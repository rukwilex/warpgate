import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/diagnostics/app_health.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/utils/diagnostic_format.dart';
import 'package:warpgate/features/settings/utils/diagnostic_snapshot.dart';
import 'package:warpgate/features/settings/utils/stall_activity_labels.dart';

class StallList extends ConsumerWidget {
  const new({super.key, this.limit = 5});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(appHealthProvider);
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final stalls = DiagnosticSnapshot.list(health.latest['stalls']);
        if (stalls.isEmpty) {
          return Text(
            'None since Warpgate started',
            style: context.type.caption,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final stall in stalls.take(limit))
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.space.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        StallActivityLabels.label('${stall['activity']}'),
                        style: context.type.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${((stall['ms']! as int) / 1000).toStringAsFixed(1)} s · ${DiagnosticFormat.clockTime('${stall['at']}')}',
                      style: context.type.monoSmall.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
