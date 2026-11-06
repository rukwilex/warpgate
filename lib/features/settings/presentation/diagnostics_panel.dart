import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/diagnostics/app_health.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate_core/core/diagnostics/app_log.dart';

typedef Snapshot = Map<String, Object?>;

Map<String, Object?> _map(Object? value) =>
    (value as Map?)?.cast<String, Object?>() ?? const {};

List<Map<String, Object?>> _list(Object? value) =>
    ((value as List?) ?? const []).map(_map).toList();

String _mb(Object? value) {
  final number = (value as num?)?.toDouble() ?? 0;
  return number < 10 ? number.toStringAsFixed(1) : number.toStringAsFixed(0);
}

String _ms(Object? value) {
  final number = (value as num?)?.toDouble() ?? 0;
  return number < 10 ? number.toStringAsFixed(1) : number.toStringAsFixed(0);
}

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

abstract final class DiagnosticText {
  static String memory(Snapshot s) {
    final memory = _map(s['memory']);
    return '${_mb(memory['rss_mb'])} MB · terminals ${_mb(memory['terminals_mb'])} MB';
  }

  static String cpu(Snapshot s) =>
      '${(s['cpu_percent'] as num? ?? 0).toStringAsFixed(1)} %';

  static String latency(Snapshot s) {
    final loop = _map(s['event_loop']);
    return 'p99 ${_ms(loop['p99_ms'])} ms · worst ${_ms(loop['max_ms'])} ms';
  }

  static String frames(Snapshot s) {
    final frames = _map(s['frames']);
    return '${frames['janky_over_16ms']} of ${frames['frames']} over 16 ms';
  }

  static String links(Snapshot s) {
    final transfers = _map(s['transfers']);
    final sessions = _list(s['sessions']);
    return '${s['connections']} hosts · ${sessions.length} terminals · ${transfers['running']} transfers';
  }

  static String workers(Snapshot s) {
    final isolates = _map(s['isolates']);
    final names = [
      if (isolates['watchdog'] == true) 'watchdog',
      ...((isolates['workers'] as List?) ?? const []).map((name) => '$name'),
    ];
    return names.isEmpty ? 'None' : names.join(', ');
  }
}

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
        final sessions = _list(health.latest['sessions'])
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
              _SessionRow(
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

class _SessionRow extends StatelessWidget {
  const new({
    required this.label,
    required this.status,
    required this.memoryKb,
    required this.lines,
    required this.throttled,
  });

  final String label;
  final String status;
  final int memoryKb;
  final int lines;
  final bool throttled;

  WgDotState get _dot => switch (status) {
    'connected' => WgDotState.connected,
    'connecting' => WgDotState.connecting,
    'reconnecting' => WgDotState.reconnecting,
    'busy' => WgDotState.busy,
    'dropped' => WgDotState.dropped,
    _ => WgDotState.idle,
  };

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final figure = memoryKb >= 1024
        ? '${_mb(memoryKb / 1024)} MB'
        : '$memoryKb KB';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: space.xs),
      child: Row(
        children: [
          WgStatusDot(state: _dot, subject: label),
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

class StallList extends ConsumerWidget {
  const new({super.key, this.limit = 5});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(appHealthProvider);
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final stalls = _list(health.latest['stalls']);
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
                        _activity('${stall['activity']}'),
                        style: context.type.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${((stall['ms']! as int) / 1000).toStringAsFixed(1)} s · ${_time('${stall['at']}')}',
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

  static String _activity(String name) => switch (name) {
    'idle' => 'Not doing anything in particular',
    'terminalIngest' => 'Reading terminal output',
    'terminalResize' => 'Resizing a terminal',
    'transfer' => 'Updating transfers',
    'fileList' => 'Listing files',
    'ssh' => 'SSH traffic',
    'storage' => 'Reading or writing the database',
    'ipc' => 'A command line request',
    'mcp' => 'An MCP request',
    'memoryTrim' => 'Freeing memory',
    _ => 'Drawing the window',
  };

  static String _time(String iso) {
    final at = DateTime.tryParse(iso)?.toLocal();
    if (at == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}

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
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final location = await getSaveLocation(
      suggestedName: 'warpgate-diagnostics-$stamp.json',
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
