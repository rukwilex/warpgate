import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';
import 'package:warpgate_core/ipc/ipc.dart';

final env = Platform.environment;
final label = env['WARPGATE_PERF_LABEL'] ?? 'run';
final out = File(env['WARPGATE_PERF_OUT'] ?? 'build/perf/results.jsonl');
final appPid = int.parse(env['WARPGATE_PERF_APP_PID']!);
final fleet = env['WARPGATE_PERF_FLEET'] ?? 'tool/perf/sshd_fleet.sh';

void record(String scenario, Map<String, Object?> values) {
  final line = jsonEncode({'scenario': scenario, 'label': label, 'at': DateTime.now().toIso8601String(), ...values});
  stdout.writeln('PERF $line');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$line\n', mode: FileMode.append);
}

double round(num value, [int digits = 1]) => double.parse(value.toStringAsFixed(digits));

Future<double> cpuSeconds() async {
  final result = await Process.run('ps', ['-o', 'time=', '-p', '$appPid']);
  var seconds = 0.0;
  for (final part in (result.stdout as String).trim().split(':')) {
    seconds = seconds * 60 + double.parse(part);
  }
  return seconds;
}

Future<int> rssBytes() async {
  final result = await Process.run('ps', ['-o', 'rss=', '-p', '$appPid']);
  return int.parse((result.stdout as String).trim()) * 1024;
}

Future<int> sockets() async {
  final result = await Process.run('lsof', ['-a', '-p', '$appPid', '-i', 'TCP']);
  return (result.stdout as String).split('\n').where((l) => l.contains('TCP')).length;
}

Future<Map<String, int>> fdTypes() async {
  final result = await Process.run('lsof', ['-p', '$appPid']);
  final counts = <String, int>{};
  for (final line in (result.stdout as String).split('\n').skip(1)) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 9) continue;
    final type = parts[4];
    final name = parts.sublist(8).join(' ');
    final key = name.startsWith('/dev/ptmx') || name.startsWith('/dev/ttys')
        ? 'pty'
        : type == 'REG'
        ? 'file'
        : type;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

Future<int> openFiles() async {
  final result = await Process.run('lsof', ['-p', '$appPid']);
  return (result.stdout as String).split('\n').length - 2;
}

class Frames {
  final List<(int, int, int)> _frames = [];
  final List<DateTime> _times = [];

  void add(Map<String, Object?> data) {
    _frames.add(((data['elapsed']! as num).toInt(), (data['build']! as num).toInt(), (data['raster']! as num).toInt()));
    _times.add(DateTime.now());
  }

  void reset() {
    _frames.clear();
    _times.clear();
  }

  int since(DateTime at) => _times.where((t) => t.isAfter(at)).length;

  List<int> buckets(DateTime start, Duration size, int count) => [
    for (var i = 0; i < count; i++)
      _times.where((t) => !t.isBefore(start.add(size * i)) && t.isBefore(start.add(size * (i + 1)))).length,
  ];

  Map<String, Object?> summary(Duration span) {
    if (_frames.isEmpty) return {'frames': 0, 'frames_per_s': 0};
    final builds = [for (final f in _frames) f.$2]..sort();
    final rasters = [for (final f in _frames) f.$3]..sort();
    int p(List<int> v, double q) => v[(q * (v.length - 1)).round()];
    return {
      'frames': _frames.length,
      'frames_per_s': round(_frames.length / (span.inMilliseconds / 1000)),
      'jank_frames_over_16ms': _frames.where((f) => f.$2 > 16000 || f.$3 > 16000).length,
      'build_p50_ms': round(p(builds, 0.5) / 1000, 2),
      'build_p99_ms': round(p(builds, 0.99) / 1000, 2),
      'build_max_ms': round(builds.last / 1000, 2),
      'raster_p99_ms': round(p(rasters, 0.99) / 1000, 2),
      'raster_max_ms': round(rasters.last / 1000, 2),
    };
  }
}

class Latency {
  Latency(this.ipc);

  final IpcClient ipc;
  final List<int> _samples = [];
  Timer? _timer;
  bool _busy = false;

  void start() {
    _samples.clear();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (_busy) return;
      _busy = true;
      final watch = Stopwatch()..start();
      try {
        await ipc.call('ping').timeout(const Duration(seconds: 30));
        _samples.add(watch.elapsedMicroseconds);
      } on Object {
        _samples.add(30000000);
      } finally {
        _busy = false;
      }
    });
  }

  Map<String, Object?> stop() {
    _timer?.cancel();
    if (_samples.isEmpty) return {};
    final sorted = [..._samples]..sort();
    int p(double q) => sorted[(q * (sorted.length - 1)).round()];
    return {
      'loop_p50_ms': round(p(0.5) / 1000, 2),
      'loop_p99_ms': round(p(0.99) / 1000, 2),
      'loop_max_ms': round(sorted.last / 1000, 2),
      'stalls_over_500ms': sorted.where((v) => v > 500000).length,
    };
  }
}

class Sampler {
  Sampler(this.vm, this.isolateId);

  final VmService vm;
  final String isolateId;
  final List<double> rss = [];
  Timer? _timer;

  Future<int> heap() async {
    final usage = await vm.getMemoryUsage(isolateId);
    return (usage.heapUsage ?? 0) + (usage.externalUsage ?? 0);
  }

  void start(Duration every) {
    rss.clear();
    _timer = Timer.periodic(every, (_) async => rss.add(round((await rssBytes()) / 1048576)));
  }

  List<double> stop() {
    _timer?.cancel();
    return List.of(rss);
  }
}

late IpcClient ipc;
late VmService vm;
late String isolateId;
final frames = Frames();

Future<Map<String, Object?>> act(String name, [Map<String, Object?> args = const {}]) async {
  final watch = Stopwatch()..start();
  try {
    return await ipc.call('action', {'name': name, 'args': args});
  } finally {
    if (watch.elapsedMilliseconds > 2000) {
      stdout.writeln('slow action $name took ${watch.elapsedMilliseconds} ms');
    }
  }
}

void step(String text) => stdout.writeln('${DateTime.now().toIso8601String().substring(11, 19)} $text');

Future<List<String>> sessionIds() async {
  final result = await act('sessions.list');
  return [for (final s in (result['sessions']! as List).cast<Map<String, Object?>>()) s['session_id']! as String];
}

Future<String> open(String host, {String? split}) async {
  final result = await act('sessions.open', {'host': host, 'split': ?split});
  return result['session_id']! as String;
}

Future<void> send(String id, String text) => act('sessions.send', {'session': id, 'text': text});

Future<void> closeAll() async {
  for (final id in await sessionIds()) {
    await act('sessions.close', {'session': id});
  }
}

Future<void> waitFor(String id, String needle, Duration limit) async {
  final end = DateTime.now().add(limit);
  while (DateTime.now().isBefore(end)) {
    try {
      final text = (await act('sessions.read', {'session': id, 'lines': 30}))['text']! as String;
      if (text.contains(needle)) return;
    } on Object {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

Future<Map<String, Object?>> measure(Duration span, Future<void> Function() body) async {
  final sampler = Sampler(vm, isolateId)..start(const Duration(seconds: 1));
  final latency = Latency(ipc)..start();
  frames.reset();
  final cpu0 = await cpuSeconds();
  final watch = Stopwatch()..start();
  await body();
  step('measure body done');
  final cpu = await cpuSeconds() - cpu0;
  final elapsed = watch.elapsed;
  final curve = sampler.stop();
  return {
    'seconds': elapsed.inSeconds,
    'cpu_percent': round(cpu * 100 / (elapsed.inMilliseconds / 1000), 2),
    ...frames.summary(elapsed),
    ...latency.stop(),
    'rss_start_mb': curve.isEmpty ? null : curve.first,
    'rss_max_mb': curve.isEmpty ? null : curve.reduce((a, b) => a > b ? a : b),
    'rss_end_mb': round((await rssBytes()) / 1048576),
    'heap_mb': round((await Sampler(vm, isolateId).heap()) / 1048576),
    'sockets': await sockets(),
  };
}

String flood(int copies) => 'for i in \$(seq 1 $copies); do cat /usr/share/dict/words; done; echo FLOOD_\$((1+1))\r';

Future<void> scenarioIdle(int count, Duration span) async {
  await closeAll();
  for (var i = 0; i < count; i++) {
    await open('perf-$i');
  }
  step('opened $count sessions');
  await Future<void>.delayed(const Duration(seconds: 20));
  final statuses = <String, int>{};
  for (final s in ((await act('sessions.list'))['sessions']! as List).cast<Map<String, Object?>>()) {
    final status = '${s['status']}';
    statuses[status] = (statuses[status] ?? 0) + 1;
  }
  step('measuring idle');
  final started = DateTime.now();
  Map<String, int>? busy;
  Map<String, int>? hot;
  final result = await measure(span, () async {
    final end = started.add(span);
    while (DateTime.now().isBefore(end)) {
      final mark = DateTime.now();
      await Future<void>.delayed(const Duration(seconds: 5));
      if (busy == null && frames.since(mark) > 100) {
        step('frames while idle, sampling');
        hot = await cpuHotspots(const Duration(seconds: 4));
        busy = await traceBuilds(const Duration(seconds: 3));
      }
    }
  });
  final links = <String, int>{};
  for (final value in (await ipc.call('link.statuses')).values) {
    links['$value'] = (links['$value'] ?? 0) + 1;
  }
  record('app.idle', {
    'sessions': count,
    'statuses': statuses,
    'host_links': links,
    ...result,
    'frames_per_10s': frames.buckets(started, const Duration(seconds: 10), span.inSeconds ~/ 10),
    'busy_widgets': busy ?? await traceBuilds(const Duration(seconds: 3)),
    'cpu_hotspots': ?hot,
  });
}

Future<void> scenarioFlood(int panes, int copies) async {
  await closeAll();
  final ids = <String>[await open('perf-0')];
  for (var i = 1; i < panes; i++) {
    ids.add(await open('perf-${i % 20}', split: i.isOdd ? 'right' : 'down'));
  }
  await Future<void>.delayed(const Duration(seconds: 5));
  final size = File('/usr/share/dict/words').lengthSync() * copies;
  final watch = Stopwatch()..start();
  final result = await measure(Duration.zero, () async {
    for (final id in ids) {
      await send(id, flood(copies));
    }
    for (final id in ids) {
      await waitFor(id, 'FLOOD_2', const Duration(minutes: 10));
    }
  });
  record('app.flood', {
    'panes': panes,
    'mb_per_pane': round(size / 1048576),
    'mb_per_s_total': round(size * panes / 1048576 / (watch.elapsedMilliseconds / 1000)),
    ...result,
  });
  await Future<void>.delayed(const Duration(seconds: 10));
  record('app.after_flood', {'panes': panes, 'rss_mb': round((await rssBytes()) / 1048576), 'heap_mb': round((await Sampler(vm, isolateId).heap()) / 1048576)});
}

Future<void> scenarioFullScreen(int seconds) async {
  await closeAll();
  final top = await open('perf-0');
  final vim = await open('perf-1', split: 'right');
  await send(top, 'top -s 1 -o cpu\r');
  await send(vim, 'vim -R /usr/share/dict/words\r');
  await Future<void>.delayed(const Duration(seconds: 3));
  record('app.full_screen', {
    ...await measure(Duration(seconds: seconds), () async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      var flip = false;
      while (DateTime.now().isBefore(end)) {
        await send(vim, '\x06\x06\x06');
        if (flip) {
          final extra = await open('perf-2', split: 'down');
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await act('sessions.close', {'session': extra});
        }
        flip = !flip;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }),
  });
  await send(vim, '\x1b:q!\r');
  await send(top, 'q');
}

Future<void> scenarioStorm(int rounds, Duration every) async {
  await closeAll();
  for (var i = 0; i < 8; i++) {
    await open('perf-$i');
  }
  await Future<void>.delayed(const Duration(seconds: 10));
  final sockets0 = await sockets();
  final files0 = await openFiles();
  final types0 = await fdTypes();
  record('app.reconnect_storm', {
    'fd_types_before': types0,
    'rounds': rounds,
    ...await measure(every * rounds, () async {
      for (var r = 0; r < rounds; r++) {
        await Process.run(fleet, ['drop']);
        await Future<void>.delayed(every);
      }
    }),
    'sockets_before': sockets0,
    'open_files_before': files0,
    'open_files_after': await openFiles(),
    'fd_types_after': await fdTypes(),
    'sessions': (await sessionIds()).length,
  });
}

Future<void> scenarioChurn(int rounds) async {
  await closeAll();
  await Future<void>.delayed(const Duration(seconds: 5));
  final heap0 = await Sampler(vm, isolateId).heap();
  final rss0 = await rssBytes();
  final files0 = await openFiles();
  final types0 = await fdTypes();
  record('app.churn', {
    'fd_types_before': types0,
    'rounds': rounds,
    ...await measure(Duration.zero, () async {
      for (var i = 0; i < rounds; i++) {
        final a = await open('perf-${i % 20}');
        final b = (await act('open', {'local': true, 'split': 'right'}))['session_id'] as String?;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (b != null) await act('sessions.close', {'session': b});
        await act('sessions.close', {'session': a});
      }
      await Future<void>.delayed(const Duration(seconds: 15));
    }),
    'heap_growth_mb': round(((await Sampler(vm, isolateId).heap()) - heap0) / 1048576),
    'rss_growth_mb': round(((await rssBytes()) - rss0) / 1048576),
    'open_files_before': files0,
    'open_files_after': await openFiles(),
    'fd_types_after': await fdTypes(),
  });
}

Future<void> scenarioRequests(int calls) async {
  await closeAll();
  final id = await open('perf-0');
  await Future<void>.delayed(const Duration(seconds: 3));
  final token = (await ipc.call('secret.read', {'key': 'mcp.token'}))['value'] as String?;
  final port = int.parse(env['WARPGATE_PERF_MCP_PORT'] ?? '0');
  final http = HttpClient();
  var mcpCalls = 0;
  var failures = 0;
  String? firstFailure;
  Future<void> mcp(String tool, Map<String, Object?> args) async {
    if (token == null || port == 0) return;
    final request = await http.postUrl(Uri.parse('http://127.0.0.1:$port/mcp'));
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..contentType = ContentType.json
      ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
    request.write(jsonEncode({'jsonrpc': '2.0', 'id': mcpCalls, 'method': 'tools/call', 'params': {'name': tool, 'arguments': args}}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    mcpCalls++;
    if (response.statusCode != 200 || body.contains('"isError":true')) {
      failures++;
      firstFailure ??= '${response.statusCode} ${body.length > 300 ? body.substring(0, 300) : body}';
    }
  }

  final rss0 = await rssBytes();
  final curve = <double>[];
  record('app.requests', {
    'calls': calls,
    ...await measure(Duration.zero, () async {
      for (var i = 0; i < calls; i++) {
        await act('sessions.read', {'session': id, 'lines': 200});
        if (i % 4 == 0) await send(id, 'echo $i\r');
        if (i % 5 == 0) {
          await mcp('read_terminal', {'session_id': id, 'lines': 100});
          await mcp('run_command', {'host': 'perf-1', 'command': 'echo $i'});
          await mcp('sftp_list', {'host': 'perf-2', 'path': '/usr/share'});
        }
        if (i % (calls ~/ 10) == 0) curve.add(round((await rssBytes()) / 1048576));
      }
    }),
    'mcp_calls': mcpCalls,
    'mcp_failures': failures,
    'mcp_first_failure': firstFailure,
    'rss_growth_mb': round(((await rssBytes()) - rss0) / 1048576),
    'rss_curve_mb': curve,
  });
  http.close(force: true);
}

Future<Map<String, int>> cpuHotspots(Duration span) async {
  final start = (await vm.getVMTimelineMicros()).timestamp!;
  await Future<void>.delayed(span);
  final samples = await vm.getCpuSamples(isolateId, start, span.inMicroseconds);
  final functions = samples.functions ?? const <ProfileFunction>[];
  final counts = <String, int>{};
  for (final sample in samples.samples ?? const <CpuSample>[]) {
    final seen = <String>{};
    for (final index in sample.stack ?? const <int>[]) {
      if (index < 0 || index >= functions.length) continue;
      final function = functions[index];
      final uri = '${function.resolvedUrl}';
      final dynamic raw = function.function;
      final name = raw is FuncRef ? '${raw.owner is ClassRef ? '${(raw.owner as ClassRef).name}.' : ''}${raw.name}' : '$raw';
      final interesting = uri.contains('warpgate') ||
          uri.contains('xterm') ||
          name.contains('Ticker') ||
          name.contains('AnimationController') ||
          name.contains('scheduleFrame') ||
          name.contains('markNeedsPaint') ||
          name.contains('markNeedsLayout');
      if (!interesting) continue;
      final key = '$name (${uri.split('/').skip(uri.split('/').length > 2 ? uri.split('/').length - 2 : 0).join('/')})';
      if (seen.add(key)) counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return {'samples': samples.samples?.length ?? 0, for (final e in top.take(40)) e.key: e.value};
}

Future<Map<String, int>> traceBuilds(Duration span) async {
  await vm.callServiceExtension('ext.flutter.profileWidgetBuilds', isolateId: isolateId, args: {'enabled': 'true'});
  await vm.callServiceExtension('ext.flutter.profileRenderObjectPaints', isolateId: isolateId, args: {'enabled': 'true'});
  await vm.setVMTimelineFlags(['Dart', 'Embedder']);
  await vm.clearVMTimeline();
  await Future<void>.delayed(span);
  final timeline = await vm.getVMTimeline();
  await vm.callServiceExtension('ext.flutter.profileWidgetBuilds', isolateId: isolateId, args: {'enabled': 'false'});
  await vm.callServiceExtension('ext.flutter.profileRenderObjectPaints', isolateId: isolateId, args: {'enabled': 'false'});
  final counts = <String, int>{};
  for (final event in timeline.traceEvents ?? const <TimelineEvent>[]) {
    final json = event.json ?? const {};
    if (json['ph'] != 'X' && json['ph'] != 'B') continue;
    final name = '${json['name']}';
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in top.take(25)) e.key: e.value};
}

Future<void> scenarioTrace(int count, Duration span) async {
  await closeAll();
  for (var i = 0; i < count; i++) {
    await open('perf-$i');
  }
  await Future<void>.delayed(const Duration(seconds: 15));
  await vm.callServiceExtension('ext.flutter.profileWidgetBuilds', isolateId: isolateId, args: {'enabled': 'true'});
  await vm.setVMTimelineFlags(['Dart', 'Embedder']);
  await vm.clearVMTimeline();
  await Future<void>.delayed(span);
  final timeline = await vm.getVMTimeline();
  final counts = <String, int>{};
  for (final event in timeline.traceEvents ?? const <TimelineEvent>[]) {
    final json = event.json ?? const {};
    final phase = json['ph'];
    if (phase != 'X' && phase != 'B') continue;
    final name = '${json['name']}';
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  record('app.trace', {
    'sessions': count,
    'seconds': span.inSeconds,
    'top_events': {for (final e in top.take(40)) e.key: e.value},
  });
  await vm.callServiceExtension('ext.flutter.profileWidgetBuilds', isolateId: isolateId, args: {'enabled': 'false'});
}

Future<void> scenarioFill(int count, int lines) async {
  await closeAll();
  final ids = <String>[];
  for (var i = 0; i < count; i++) {
    ids.add(await open('perf-$i'));
  }
  await Future<void>.delayed(const Duration(seconds: 15));
  final rss0 = await rssBytes();
  for (final id in ids) {
    await send(id, "awk 'BEGIN{for(i=1;i<=$lines;i++) printf \"%06d  build step %d  compiling module_%d.rs  ok  took %dms\\n\", i, i%97, i%541, i%1000}'; echo FILL_DONE\r");
  }
  for (final id in ids) {
    await waitFor(id, 'FILL_DONE', const Duration(minutes: 3));
  }
  await Future<void>.delayed(const Duration(seconds: 10));
  final diagnostics = await ipc.call('diagnostics.snapshot');
  final memory = (diagnostics['memory'] as Map?) ?? const {};
  record('app.fill', {
    'sessions': count,
    'lines_each': lines,
    'rss_before_mb': round(rss0 / 1048576),
    'rss_after_mb': round((await rssBytes()) / 1048576),
    'heap_mb': round((await Sampler(vm, isolateId).heap()) / 1048576),
    'terminals_mb': memory['terminals_mb'],
    'scrollback_lines_total': ((diagnostics['sessions'] as List?) ?? const [])
        .fold<int>(0, (sum, s) => sum + (((s as Map)['scrollback_lines'] as int?) ?? 0)),
  });
}

final dataDir = Directory(env['WARPGATE_PERF_DATA'] ?? '${Directory.current.path}/../../../build/perf/data').absolute.path;

Future<void> prepareData() async {
  final big = env['WARPGATE_PERF_FILE'];
  await Directory('$dataDir/big').create(recursive: true);
  if (big != null && File(big).existsSync()) {
    for (var i = 0; i < 3; i++) {
      final link = File('$dataDir/big/part$i.bin');
      if (!link.existsSync()) await Process.run('ln', [big, link.path]);
    }
  }
  if (!Directory('$dataDir/small').existsSync()) {
    await Process.run('sh', ['-c', 'mkdir -p "$dataDir/small" && cd "$dataDir/small" && i=0; while [ \$i -lt 20000 ]; do head -c 4096 /dev/urandom > f\$i.dat; i=\$((i+1)); done']);
  }
  if (!Directory('$dataDir/huge_dir').existsSync()) {
    await Process.run('sh', ['-c', 'mkdir -p "$dataDir/huge_dir" && cd "$dataDir/huge_dir" && seq -f "entry_%06g.log" 1 100000 | xargs touch']);
  }
}

Future<List<Map<String, Object?>>> transferJobs() async {
  final result = await act('transfers.list');
  return ((result['transfers'] ?? result['jobs'] ?? const []) as List).cast<Map<String, Object?>>();
}

Future<void> scenarioTransfers() async {
  await closeAll();
  await prepareData();
  final out = '$dataDir/out';
  await Process.run('rm', ['-rf', out]);
  for (final dir in ['down', 'up', 'remote', 'small']) {
    await Directory('$out/$dir').create(recursive: true);
  }
  final watch = Stopwatch()..start();
  late Map<String, Object?> statusAtEnd;
  final result = await measure(Duration.zero, () async {
    final down = await act('files.cp', {'sources': ['perf-0:$dataDir/big/part0.bin', 'perf-0:$dataDir/big/part1.bin', 'perf-0:$dataDir/big/part2.bin'], 'target': '$out/down/'});
    await act('files.cp', {'sources': ['$dataDir/big/part0.bin', '$dataDir/big/part1.bin', '$dataDir/big/part2.bin'], 'target': 'perf-1:$out/up/'});
    await act('files.cp', {'sources': ['perf-2:$dataDir/big/part0.bin', 'perf-2:$dataDir/big/part1.bin', 'perf-2:$dataDir/big/part2.bin'], 'target': 'perf-3:$out/remote/'});
    await act('files.cp', {'sources': ['perf-0:$dataDir/small'], 'target': '$out/small/'});
    final downIds = [for (final job in ((down['transfers'] ?? down['jobs'] ?? const []) as List).cast<Map<String, Object?>>()) '${job['id']}'];
    await Future<void>.delayed(const Duration(seconds: 3));
    if (downIds.length > 1) {
      await act('transfers.pause', {'id': downIds[0]});
      await act('transfers.cancel', {'id': downIds[1]});
      await Future<void>.delayed(const Duration(seconds: 5));
      await act('transfers.resume', {'id': downIds[0]});
    }
    final deadline = DateTime.now().add(const Duration(minutes: 30));
    while (DateTime.now().isBefore(deadline)) {
      final jobs = await transferJobs();
      final active = jobs.where((j) => const {'running', 'queued', 'paused'}.contains(j['status'])).length;
      if (active == 0) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    final jobs = await transferJobs();
    final byStatus = <String, int>{};
    var bytes = 0;
    for (final job in jobs) {
      byStatus['${job['status']}'] = (byStatus['${job['status']}'] ?? 0) + 1;
      if (job['status'] == 'completed') bytes += (job['total_bytes'] ?? job['totalBytes'] ?? 0) as int;
    }
    statusAtEnd = {'jobs': byStatus, 'bytes_completed': bytes};
  });
  final seconds = watch.elapsedMilliseconds / 1000;
  final bytes = statusAtEnd['bytes_completed']! as int;
  record('app.transfers', {
    ...statusAtEnd,
    'gb_completed': round(bytes / (1 << 30), 2),
    'mb_per_s': round(bytes / 1048576 / seconds),
    ...result,
  });
  await act('transfers.clear');
  await Process.run('rm', ['-rf', out]);
}

Future<void> scenarioBigDir(int rounds) async {
  await closeAll();
  await prepareData();
  await act('settings.set', {'key': 'defaultRemotePath', 'value': '$dataDir/huge_dir'});
  final result = await measure(Duration.zero, () async {
    for (var i = 0; i < rounds; i++) {
      final opened = await act('open', {'host': 'perf-${i % 4}', 'files': true});
      await Future<void>.delayed(const Duration(seconds: 4));
      final id = opened['session_id'] as String?;
      if (id != null) await act('sessions.close', {'session': id});
    }
  });
  await act('settings.set', {'key': 'defaultRemotePath', 'value': '~'});
  record('app.big_dir', {'entries': 100000, 'rounds': rounds, ...result});
}

Future<void> scenarioSoak(Duration span) async {
  final out = File(env['WARPGATE_PERF_SOAK_OUT'] ?? 'build/perf/soak.jsonl');
  out.parent.createSync(recursive: true);
  final watch = Stopwatch()..start();
  final samples = <Map<String, Object?>>[];
  var cycle = 0;
  var worstPing = 0;
  Timer? sampler;
  Future<void> sample() async {
    Map<String, Object?> diagnostics = const {};
    try {
      diagnostics = await ipc.call('diagnostics.snapshot').timeout(const Duration(seconds: 30));
    } on Object {
      diagnostics = const {};
    }
    final ping = Stopwatch()..start();
    try {
      await ipc.call('ping').timeout(const Duration(seconds: 30));
    } on Object {
      worstPing = 30000;
    }
    final pingMs = ping.elapsedMilliseconds;
    if (pingMs > worstPing) worstPing = pingMs;
    final row = {
      'minute': round(watch.elapsed.inSeconds / 60, 2),
      'cycle': cycle,
      'rss_mb': round((await rssBytes()) / 1048576),
      'heap_mb': round((await Sampler(vm, isolateId).heap()) / 1048576),
      'open_files': await openFiles(),
      'sockets': await sockets(),
      'ping_ms': pingMs,
      'stalls': ((diagnostics['stalls'] as List?) ?? const []).length,
      'terminals_mb': (diagnostics['memory'] as Map?)?['terminals_mb'],
      'loop_p99_ms': (diagnostics['event_loop'] as Map?)?['p99_ms'],
      'loop_max_ms': (diagnostics['event_loop'] as Map?)?['max_ms'],
    };
    samples.add(row);
    out.writeAsStringSync('${jsonEncode({'label': label, ...row})}\n', mode: FileMode.append);
  }

  await sample();
  sampler = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(sample()));
  final steps = <Future<void> Function()>[
    () => scenarioFlood(2, 4),
    () => scenarioIdle(10, const Duration(seconds: 60)),
    () => scenarioFullScreen(20),
    () => scenarioChurn(20),
    () => scenarioRequests(200),
    () async {
      await Process.run(fleet, ['drop']);
      await Future<void>.delayed(const Duration(seconds: 20));
    },
  ];
  while (watch.elapsed < span) {
    try {
      await steps[cycle % steps.length]();
    } on Object catch (error) {
      stdout.writeln('soak step failed: $error');
    }
    cycle++;
  }
  sampler.cancel();
  await sample();
  final afterHour = samples.where((r) => (r['minute']! as double) >= 60).toList();
  final base = afterHour.isEmpty ? samples.first : afterHour.first;
  final last = samples.last;
  double growth(String key) {
    final from = (base[key]! as num).toDouble();
    final to = (last[key]! as num).toDouble();
    return from == 0 ? 0 : round((to - from) * 100 / from, 1);
  }

  record('app.soak', {
    'minutes': round(watch.elapsed.inSeconds / 60, 1),
    'cycles': cycle,
    'samples': samples.length,
    'rss_mb_first_hour_end': base['rss_mb'],
    'rss_mb_end': last['rss_mb'],
    'rss_growth_after_first_hour_percent': growth('rss_mb'),
    'heap_growth_after_first_hour_percent': growth('heap_mb'),
    'open_files_growth_after_first_hour_percent': growth('open_files'),
    'rss_max_mb': samples.map((r) => r['rss_mb']! as double).reduce((a, b) => a > b ? a : b),
    'stalls_reported_by_app': last['stalls'],
    'worst_ipc_ping_ms': worstPing,
    'worst_loop_ms_in_app': samples
        .map((r) => (r['loop_max_ms'] as num?)?.toDouble() ?? 0)
        .reduce((a, b) => a > b ? a : b),
    'minutes_with_loop_over_500ms': samples.where((r) => ((r['loop_max_ms'] as num?) ?? 0) > 500).length,
  });
}

Future<void> main(List<String> args) async {
  final paths = AppPaths.resolve();
  IpcClient? client;
  for (var i = 0; i < 60 && client == null; i++) {
    client = await IpcClient.connect(paths, timeout: const Duration(seconds: 2));
    if (client == null) await Future<void>.delayed(const Duration(seconds: 1));
  }
  if (client == null) throw StateError('Could not reach the app over IPC at ${paths.root}');
  ipc = client;
  vm = await vmServiceConnectUri(env['WARPGATE_PERF_VM']!);
  final isolates = (await vm.getVM()).isolates!;
  isolateId = isolates.firstWhere((i) => i.name == 'main', orElse: () => isolates.first).id!;
  await vm.streamListen(EventStreams.kExtension);
  vm.onExtensionEvent.listen((event) {
    if (event.extensionKind == 'Flutter.Frame') frames.add(event.extensionData!.data.cast<String, Object?>());
  });
  final which = args.isEmpty ? ['idle', 'flood1', 'flood8', 'full', 'storm', 'churn', 'requests'] : args;
  final idleSpan = Duration(seconds: int.parse(env['WARPGATE_PERF_IDLE_S'] ?? '120'));
  final floodCopies = int.parse(env['WARPGATE_PERF_FLOOD_COPIES'] ?? '20');
  for (final scenario in which) {
    stdout.writeln('scenario $scenario');
    switch (scenario) {
      case 'idle':
        await scenarioIdle(int.parse(env['WARPGATE_PERF_IDLE_SESSIONS'] ?? '20'), idleSpan);
      case 'flood1':
        await scenarioFlood(1, floodCopies);
      case 'flood8':
        await scenarioFlood(8, floodCopies ~/ 4);
      case 'full':
        await scenarioFullScreen(int.parse(env['WARPGATE_PERF_FULL_S'] ?? '60'));
      case 'storm':
        await scenarioStorm(int.parse(env['WARPGATE_PERF_ROUNDS'] ?? '10'), const Duration(seconds: 30));
      case 'churn':
        await scenarioChurn(int.parse(env['WARPGATE_PERF_CHURN'] ?? '200'));
      case 'trace':
        await scenarioTrace(int.parse(env['WARPGATE_PERF_TRACE_SESSIONS'] ?? '20'), const Duration(seconds: 3));
      case 'transfers':
        await scenarioTransfers();
      case 'bigdir':
        await scenarioBigDir(10);
      case 'fill':
        await scenarioFill(20, 12000);
      case 'soak':
        await scenarioSoak(Duration(minutes: int.parse(env['WARPGATE_PERF_SOAK_MIN'] ?? '720')));
      case 'requests':
        await scenarioRequests(int.parse(env['WARPGATE_PERF_CALLS'] ?? '2000'));
    }
  }
  await closeAll();
  await ipc.close();
  await vm.dispose();
  exit(0);
}
