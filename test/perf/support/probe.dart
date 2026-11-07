import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate' as iso;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class HeapSample {
  const new(this.dartHeap, this.external, this.rss);

  final int dartHeap;
  final int external;
  final int rss;

  int get total => dartHeap + external;
}

class Probe {
  new _(this._service, this._isolateId);

  static Probe? _instance;

  final VmService _service;
  final String _isolateId;

  static const skipReason = 'Run with: flutter test --tags perf --enable-vmservice';

  static Future<bool> get available async {
    final info = await Service.getInfo();
    return info.serverWebSocketUri != null;
  }

  static Future<Probe> connect() async {
    final existing = _instance;
    if (existing != null) return existing;
    final info = await Service.getInfo();
    final uri = info.serverWebSocketUri;
    if (uri == null) {
      throw StateError(skipReason);
    }
    final service = await vmServiceConnectUri(uri.toString());
    final id = Service.getIsolateId(iso.Isolate.current)!;
    return _instance = Probe._(service, id);
  }

  Future<HeapSample> heap() async {
    final profile = await _service.getAllocationProfile(_isolateId, gc: true);
    final usage = profile.memoryUsage!;
    return HeapSample(
      usage.heapUsage ?? 0,
      usage.externalUsage ?? 0,
      ProcessInfo.currentRss,
    );
  }

  Future<Map<String, int>> instances(Set<String> classNames) async {
    final profile = await _service.getAllocationProfile(_isolateId, gc: true);
    return {
      for (final member in profile.members ?? const <ClassHeapStats>[])
        if (classNames.contains(member.classRef?.name))
          member.classRef!.name!: member.instancesCurrent ?? 0,
    };
  }

  Future<List<String>> retainingPaths(String className, {int limit = 3}) async {
    final profile = await _service.getAllocationProfile(_isolateId, gc: true);
    final member = (profile.members ?? const <ClassHeapStats>[])
        .where((m) => m.classRef?.name == className)
        .firstOrNull;
    if (member == null) return const [];
    final instances = await _service.getInstances(_isolateId, member.classRef!.id!, limit);
    final paths = <String>[];
    for (final instance in instances.instances ?? const <ObjRef>[]) {
      final path = await _service.getRetainingPath(_isolateId, instance.id!, 40);
      paths.add([
        for (final element in path.elements ?? const <RetainingObject>[])
          [
            '${element.value is InstanceRef ? (element.value! as InstanceRef).classRef?.name : element.value?.runtimeType}',
            if (element.parentField != null) '.${element.parentField}',
            if (element.parentMapKey != null) '[key]',
            if (element.parentListIndex != null) '[${element.parentListIndex}]',
          ].join(),
      ].join(' <- '));
    }
    return paths;
  }

  Future<int> isolateCount() async {
    final vm = await _service.getVM();
    return vm.isolates?.length ?? 0;
  }
}

abstract final class PerfLog {
  static final _file = File(
    Platform.environment['WARPGATE_PERF_OUT'] ?? 'build/perf/results.jsonl',
  );

  static void record(String scenario, Map<String, Object?> values) {
    final line = jsonEncode({
      'scenario': scenario,
      'label': Platform.environment['WARPGATE_PERF_LABEL'] ?? 'run',
      'at': DateTime.now().toIso8601String(),
      ...values,
    });
    stdout.writeln('PERF $line');
    _file.parent.createSync(recursive: true);
    _file.writeAsStringSync('$line\n', mode: FileMode.append);
  }
}

String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
