import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/diagnostics/app_health.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_session_memory_row.dart';
import 'package:warpgate/features/settings/utils/diagnostic_snapshot.dart';

class SessionMemoryList extends ConsumerWidget {
  const new({super.key, this.limit = 8});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(appHealthProvider);
    final catalog = ref.watch(hostsProvider).value;
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final sessions = DiagnosticSnapshot.list(health.latest['sessions'])
          ..sort(
            (a, b) =>
                (b['memory_kb']! as int).compareTo(a['memory_kb']! as int),
          );
        if (sessions.isEmpty) {
          return Text('No terminals are open', style: context.type.caption);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final session in sessions.take(limit))
              SettingsSessionMemoryRow(
                label: switch (session['host']) {
                  final String id => catalog?.host(id)?.label ?? 'Removed host',
                  _ => 'This device',
                },
                status: '${session['status']}',
                memoryKb: session['memory_kb']! as int,
                lines: session['scrollback_lines']! as int,
                throttled: session['throttled'] == true,
              ),
            if (sessions.length > limit)
              Padding(
                padding: EdgeInsets.only(top: context.space.xs),
                child: Text(
                  '${sessions.length - limit} more',
                  style: context.type.caption,
                ),
              ),
          ],
        );
      },
    );
  }
}
