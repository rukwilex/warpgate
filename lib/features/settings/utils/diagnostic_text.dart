import 'package:warpgate/features/settings/utils/diagnostic_format.dart';
import 'package:warpgate/features/settings/utils/diagnostic_snapshot.dart';

abstract final class DiagnosticText {
  static String memory(Snapshot s) {
    final memory = DiagnosticSnapshot.map(s['memory']);
    return '${DiagnosticFormat.megabytes(memory['rss_mb'])} MB · terminals ${DiagnosticFormat.megabytes(memory['terminals_mb'])} MB';
  }

  static String cpu(Snapshot s) =>
      '${(s['cpu_percent'] as num? ?? 0).toStringAsFixed(1)} %';

  static String latency(Snapshot s) {
    final loop = DiagnosticSnapshot.map(s['event_loop']);
    return 'p99 ${DiagnosticFormat.milliseconds(loop['p99_ms'])} ms · worst ${DiagnosticFormat.milliseconds(loop['max_ms'])} ms';
  }

  static String frames(Snapshot s) {
    final frames = DiagnosticSnapshot.map(s['frames']);
    return '${frames['janky_over_16ms']} of ${frames['frames']} over 16 ms';
  }

  static String links(Snapshot s) {
    final transfers = DiagnosticSnapshot.map(s['transfers']);
    final sessions = DiagnosticSnapshot.list(s['sessions']);
    return '${s['connections']} hosts · ${sessions.length} terminals · ${transfers['running']} transfers';
  }

  static String workers(Snapshot s) {
    final isolates = DiagnosticSnapshot.map(s['isolates']);
    final names = [
      if (isolates['watchdog'] == true) 'watchdog',
      ...((isolates['workers'] as List?) ?? const []).map((name) => '$name'),
    ];
    return names.isEmpty ? 'None' : names.join(', ');
  }
}
