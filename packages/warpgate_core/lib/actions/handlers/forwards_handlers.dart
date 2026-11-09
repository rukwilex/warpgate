import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/support/forward_specs.dart';
import 'package:warpgate_core/actions/support/json_views.dart';
import 'package:warpgate_core/actions/support/lookups.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';

abstract final class ForwardHandlers {
  static final Map<String, ActionHandler> all = {
    'forward.list': _forwardList,
    'forward.add': _forwardAdd,
    'forward.rm': _forwardRm,
  };

  static Future<JsonMap> _forwardList(ActionCall call) async {
    final rt = call.runtime;
    final reference = call.maybe('host');
    final hosts = reference == null ? rt.hosts.catalog.hosts : [Lookups.savedHost(call, reference)];
    final active = {
      for (final forward in rt.forwarder.forwards) forward.spec.id: forward.state.name,
    };
    return {
      'forwards': [
        for (final host in hosts)
          for (final spec in host.forwards)
            Json.forward(host, spec, state: active[spec.id]),
      ],
    };
  }

  static Future<JsonMap> _forwardAdd(ActionCall call) async {
    final host = Lookups.savedHost(call, call.string('host'));
    final chosen = [
      for (final kind in const ['local', 'remote', 'dynamic'])
        if (call.maybe(kind) != null) kind,
    ];
    if (chosen.length != 1) {
      throw const ActionFailure('Pick exactly one of -L, -R or -D', kind: ExitKind.usage);
    }
    final spec = ForwardSpecs.parse(
      chosen.single,
      call.string(chosen.single),
      autoStart: call.on('auto-start'),
    );
    await call.runtime.hosts.saveHost(host.copyWith(forwards: [...host.forwards, spec]));
    return {'id': spec.id, 'host': host.label};
  }

  static Future<JsonMap> _forwardRm(ActionCall call) async {
    final id = call.string('id');
    for (final host in call.runtime.hosts.catalog.hosts) {
      if (host.forwards.any((spec) => spec.id == id)) {
        await call.runtime.hosts.saveHost(
          host.copyWith(forwards: host.forwards.where((spec) => spec.id != id).toList()),
        );
        return {'id': id};
      }
    }
    throw ActionFailure('No forward "$id"', kind: ExitKind.notFound);
  }
}
