import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/diagnostics/app_health.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/utils/export_file_names.dart';
import 'package:warpgate_core/core/diagnostics/app_log.dart';

class DiagnosticActions extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DiagnosticActions> createState() => _DiagnosticActionsState();
}

class _DiagnosticActionsState extends ConsumerState<DiagnosticActions> {
  bool _freeing = false;

  Future<void> _free() async {
    setState(() => _freeing = true);
    final trim = await ref.read(appHealthProvider).freeMemory();
    if (!mounted) return;
    setState(() => _freeing = false);
    final saved = (trim.before - trim.after) >> 20;
    showWgToast(
      context,
      saved > 0
          ? 'Freed $saved MB. Warpgate now uses ${trim.after >> 20} MB'
          : 'Caches cleared. Warpgate uses ${trim.after >> 20} MB',
    );
  }

  Future<void> _export() async {
    final location = await getSaveLocation(
      suggestedName: ExportFileNames.diagnostics(DateTime.now()),
    );
    if (location == null || !mounted) return;
    final report = ref.read(appHealthProvider).snapshot()
      ..['log_recent'] = [
        for (final entry in AppLog.instance.recent) entry.toJson(),
      ];
    await XFile.fromData(
      Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(report)),
      ),
      mimeType: 'application/json',
    ).saveTo(location.path);
    if (mounted) showWgToast(context, 'Report saved to ${location.path}');
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: context.space.sm,
    runSpacing: context.space.sm,
    children: [
      WgButton(label: 'Free memory', onPressed: _free, loading: _freeing),
      WgButton(
        label: 'Export report',
        icon: WgIcons.export,
        onPressed: _export,
      ),
    ],
  );
}
