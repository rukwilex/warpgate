import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/diagnostics/app_health.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/utils/diagnostic_snapshot.dart';

class DiagnosticReadout extends ConsumerWidget {
  const new(this.text, {super.key, this.label});

  final String Function(Snapshot snapshot) text;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(appHealthProvider);
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final value = text(health.latest);
        return Semantics(
          label: label,
          value: value,
          child: ExcludeSemantics(
            child: Text(
              value,
              style: context.type.mono.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}
