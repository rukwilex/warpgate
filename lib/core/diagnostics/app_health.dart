import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/terminal/data/terminal_ingest.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/core/diagnostics/app_log.dart';
import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/core/diagnostics/process_stats.dart';
import 'package:warpgate_core/core/diagnostics/watchdog.dart';
import 'package:warpgate_core/core/util/worker.dart';
import 'package:warpgate_core/features/connection/engine/native_ssh.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';
import 'package:xterm/xterm.dart';

class FrameStats {
  int frames = 0;
  int janky = 0;
  int worstBuildMicros = 0;
  int worstRasterMicros = 0;
  DateTime since = DateTime.now();

  void add(FrameTiming timing) {
    frames++;
    final build = timing.buildDuration.inMicroseconds;
    final raster = timing.rasterDuration.inMicroseconds;
    if (build > 16000 || raster > 16000) janky++;
    if (build > worstBuildMicros) worstBuildMicros = build;
    if (raster > worstRasterMicros) worstRasterMicros = raster;
  }

  Map<String, Object?> toJson() => {
    'since': since.toIso8601String(),
    'frames': frames,
    'janky_over_16ms': janky,
    'worst_build_ms': worstBuildMicros / 1000,
    'worst_raster_ms': worstRasterMicros / 1000,
  };

  void reset() {
    frames = 0;
    janky = 0;
    worstBuildMicros = 0;
    worstRasterMicros = 0;
    since = DateTime.now();
  }
}

class MemoryTrim {
  const new({
    required this.at,
    required this.before,
    required this.after,
    required this.reason,
    required this.steps,
  });

  final DateTime at;
  final int before;
  final int after;
  final String reason;
  final List<String> steps;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'reason': reason,
    'rss_before_mb': before >> 20,
    'rss_after_mb': after >> 20,
    'steps': steps,
  };
}

class AppHealth extends ChangeNotifier {
  new(this._ref);

  final Ref _ref;
  late final Watchdog watchdog = Watchdog(onStall: _onStall);
  final frames = FrameStats();
  final cpu = CpuMeter();
  final trims = <MemoryTrim>[];
  final stallNotice = ValueNotifier<Stall?>(null);
  Timer? _guard;
  bool _started = false;
  Map<String, Object?>? _latest;

  Map<String, Object?> get latest => _latest ??= snapshot();
  bool _trimming = false;
  DateTime? _lastTrim;

  static const backgroundKeepLines = 1000;

  Future<void> start() async {
    if (_started || !_ref.read(appHealthEnabledProvider)) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    String? serviceUri;
    String? isolateId;
    if (!kReleaseMode) {
      final info = await developer.Service.getInfo();
      serviceUri = info.serverUri?.toString();
      isolateId = developer.Service.getIsolateId(Isolate.current);
    }
    try {
      await watchdog.start(serviceUri: serviceUri, isolateId: isolateId);
    } on Object catch (error, stack) {
      AppLog.instance.error('watchdog', error, stack);
    }
    cpu.sample();
    _guard = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  Future<void> stop() async {
    _guard?.cancel();
    if (_started) SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _started = false;
    await watchdog.stop();
  }

  void _onTimings(List<FrameTiming> timings) {
    timings.forEach(frames.add);
  }

  void _onStall(Stall stall) {
    AppLog.instance.warning(
      'watchdog',
      'The app did not respond for ${(stall.duration.inMilliseconds / 1000).toStringAsFixed(1)} s while: ${stall.activity.label}${stall.stack == null ? '' : '\n${stall.stack}'}',
    );
    stallNotice.value = stall;
    _latest = null;
    notifyListeners();
  }

  int get softLimitBytes => _ref.read(settingsProvider).memorySoftLimitMb << 20;

  void _check() {
    cpu.sample();
    final rss = ProcessStats.rss;
    if (rss > softLimitBytes && !_trimming) {
      final last = _lastTrim;
      if (last == null ||
          DateTime.now().difference(last) > const Duration(minutes: 1)) {
        unawaited(
          freeMemory(
            reason: 'Memory above ${softLimitBytes >> 20} MB',
            background: true,
          ),
        );
      }
    }
    _latest = null;
    notifyListeners();
  }

  Future<MemoryTrim> freeMemory({
    String reason = 'Requested',
    bool background = false,
  }) async {
    _trimming = true;
    final before = ProcessStats.rss;
    final steps = <String>[];
    try {
      Watchdog.during(Activity.memoryTrim, () {
        final glyphs = ParagraphCache.instance.length;
        ParagraphCache.instance.trim(256);
        steps.add(
          'Glyph cache ${glyphs - ParagraphCache.instance.length} entries freed',
        );
        LineStore.clearFree();
        final images = PaintingBinding.instance.imageCache.currentSizeBytes;
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        if (images > 0) steps.add('Image cache ${images >> 10} KB freed');
        var packed = 0;
        for (final session in _ref.read(terminalSessionsProvider).all) {
          packed += session.terminal.mainBuffer.compactScrollback();
        }
        steps.add('$packed scrollback lines compacted');
        if (background) {
          final visible = _visiblePaneIds();
          var trimmed = 0;
          for (final session in _ref.read(terminalSessionsProvider).all) {
            if (visible.contains(session.id)) continue;
            trimmed += session.terminal.mainBuffer.trimScrollback(
              backgroundKeepLines,
            );
          }
          if (trimmed > 0) {
            steps.add('$trimmed old lines dropped from background panes');
          }
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      _trimming = false;
    }
    final trim = MemoryTrim(
      at: DateTime.now(),
      before: before,
      after: ProcessStats.rss,
      reason: reason,
      steps: steps,
    );
    _lastTrim = trim.at;
    trims.insert(0, trim);
    if (trims.length > 20) trims.removeLast();
    AppLog.instance.info('memory', '$reason: ${trim.toJson()}');
    _latest = null;
    notifyListeners();
    return trim;
  }

  Set<String> _visiblePaneIds() {
    final tab = _ref.read(workbenchProvider).activeWorkspace?.activeTab;
    return {...?tab?.panes.keys};
  }

  Map<String, Object?> snapshot() {
    final sessions = _ref.read(terminalSessionsProvider).all.toList();
    final pool = _ref.read(connectionPoolProvider);
    final transfers = _ref.read(transferQueueProvider);
    var terminalBytes = 0;
    final perSession = <Map<String, Object?>>[];
    for (final session in sessions) {
      final bytes =
          session.terminal.mainBuffer.storageBytes +
          session.terminal.altBuffer.storageBytes;
      terminalBytes += bytes;
      perSession.add({
        'id': session.id,
        'host': session.hostId,
        'status': session.status.value.state.name,
        'scrollback_lines': session.terminal.mainBuffer.lines.length,
        'memory_kb': bytes >> 10,
        'pending_kb': session.pendingBytes >> 10,
        'throttled': session.throttled,
      });
    }
    return {
      'at': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'ssh_engine': NativeEngine.active ? NativeEngine.version : 'dartssh2',
      'memory': {
        'rss_mb': ProcessStats.rss >> 20,
        'peak_rss_mb': ProcessStats.maxRss >> 20,
        'soft_limit_mb': softLimitBytes >> 20,
        'terminals_mb': double.parse(
          (terminalBytes / 1048576).toStringAsFixed(1),
        ),
        'glyph_cache_entries': ParagraphCache.instance.length,
        'image_cache_kb':
            PaintingBinding.instance.imageCache.currentSizeBytes >> 10,
        'trims': [for (final trim in trims) trim.toJson()],
      },
      'cpu_percent': double.parse(cpu.percent.toStringAsFixed(2)),
      'sessions': perSession,
      'connections': pool.openConnections,
      'channels': sessions.where((s) => s.isRunning).length,
      'transfers': {
        'running': transfers
            .where((job) => job.status == TransferStatus.running)
            .length,
        'queued': transfers
            .where((job) => job.status == TransferStatus.queued)
            .length,
        'history': transfers.where((job) => job.status.isFinished).length,
      },
      'isolates': {
        'workers': [
          for (final worker in Worker.all)
            if (worker.running) worker.name,
        ],
        'watchdog': watchdog.running,
      },
      'event_loop': watchdog.loop.summary(),
      'frames': frames.toJson(),
      'stalls': [for (final stall in watchdog.stalls) stall.toJson()],
      'links': {
        'dead_links_closed': pool.deadLinksClosed,
        'wake_ups': pool.wakeUps,
        'liveness_timer': pool.livenessRunning,
      },
      'ingest': {
        'runs': TerminalIngest.instance.runs,
        'yields': TerminalIngest.instance.yields,
        'longest_run_ms': TerminalIngest.instance.longestRunMicros / 1000,
        'waiting': TerminalIngest.instance.waiting,
      },
      'live_objects': LiveObjects.snapshot(),
      'log': {
        'file': AppLog.instance.currentFile,
        'recent_errors': AppLog.instance.recent
            .where((e) => e.level == LogLevel.error)
            .length,
      },
    };
  }

  @override
  void dispose() {
    unawaited(stop());
    stallNotice.dispose();
    super.dispose();
  }
}

final appHealthEnabledProvider = Provider<bool>(
  (ref) => kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST'),
);

final appHealthProvider = Provider<AppHealth>((ref) {
  final health = AppHealth(ref);
  ref.onDispose(health.dispose);
  return health;
});
