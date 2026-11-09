import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/utils/diagnostic_format.dart';
import 'package:warpgate/features/settings/utils/session_status_dot.dart';

class SettingsSessionMemoryRow extends StatelessWidget {
  const new({
    required this.label,
    required this.status,
    required this.memoryKb,
    required this.lines,
    required this.throttled,
    super.key,
  });

  final String label;
  final String status;
  final int memoryKb;
  final int lines;
  final bool throttled;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final figure = memoryKb >= 1024
        ? '${DiagnosticFormat.megabytes(memoryKb / 1024)} MB'
        : '$memoryKb KB';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: space.xs),
      child: Row(
        children: [
          WgStatusDot(state: SessionStatusDot.fromStatus(status), subject: label),
          SizedBox(width: space.sm),
          Expanded(
            child: Text(
              label,
              style: context.type.body,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (throttled) ...[
            const WgTag('Catching up'),
            SizedBox(width: space.sm),
          ],
          Text(
            '$lines lines · $figure',
            style: context.type.monoSmall.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
