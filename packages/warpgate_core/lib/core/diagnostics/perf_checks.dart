class PerfCheck {
  const new(this.name, {required this.ok, required this.detail, this.fix});

  final String name;
  final bool ok;
  final String detail;
  final String? fix;
}

abstract final class PerfChecks {
  static List<PerfCheck> from(Map<String, Object?> report) {
    final memory = (report['memory'] as Map?)?.cast<String, Object?>() ?? const {};
    final loop = (report['event_loop'] as Map?)?.cast<String, Object?>() ?? const {};
    final frames = (report['frames'] as Map?)?.cast<String, Object?>() ?? const {};
    final stalls = (report['stalls'] as List?) ?? const [];
    final sessions = (report['sessions'] as List?) ?? const [];
    final rss = (memory['rss_mb'] as num?)?.toInt() ?? 0;
    final limit = (memory['soft_limit_mb'] as num?)?.toInt() ?? 1536;
    final cpu = (report['cpu_percent'] as num?)?.toDouble() ?? 0;
    final p99 = (loop['p99_ms'] as num?)?.toDouble() ?? 0;
    final worst = (loop['max_ms'] as num?)?.toDouble() ?? 0;
    final janky = (frames['janky_over_16ms'] as num?)?.toInt() ?? 0;
    final total = (frames['frames'] as num?)?.toInt() ?? 0;
    final terminals = (memory['terminals_mb'] as num?)?.toDouble() ?? 0;
    return [
      PerfCheck(
        'Memory',
        ok: rss < limit,
        detail: '$rss MB in use, ${terminals.toStringAsFixed(1)} MB in ${sessions.length} terminals, limit $limit MB',
        fix: rss < limit ? null : 'Open Settings, Diagnostics and press Free memory, or lower Scrollback',
      ),
      PerfCheck(
        'CPU',
        ok: cpu < 25,
        detail: '${cpu.toStringAsFixed(1)} % over the last 10 seconds',
        fix: cpu < 25 ? null : 'Check for panes printing a lot of output or running transfers',
      ),
      PerfCheck(
        'Responsiveness',
        ok: p99 < 50,
        detail: 'Event loop delay p99 ${p99.toStringAsFixed(1)} ms, worst ${worst.toStringAsFixed(0)} ms in the last minute',
        fix: p99 < 50 ? null : 'Run warpgate diagnostics export and attach the file to a bug report',
      ),
      PerfCheck(
        'Stalls',
        ok: stalls.isEmpty,
        detail: stalls.isEmpty ? 'No stalls over 2 s since the app started' : '${stalls.length} stalls over 2 s since the app started',
        fix: stalls.isEmpty ? null : 'Run warpgate diagnostics export and attach the file to a bug report',
      ),
      PerfCheck(
        'Frames',
        ok: total == 0 || janky * 100 < total * 5,
        detail: '$janky of $total frames over 16 ms',
      ),
    ];
  }
}
