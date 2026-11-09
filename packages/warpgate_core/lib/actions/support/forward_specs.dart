import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

abstract final class ForwardSpecs {
  static PortForwardSpec parse(String kind, String spec, {bool autoStart = false}) {
    final parts = spec.split(':');
    Never bad(String shape) => throw ActionFailure(
      'Could not read "$spec". Use $shape',
      kind: ExitKind.usage,
    );
    int port(String value, String shape) {
      final parsed = int.tryParse(value);
      if (parsed == null || parsed < 0 || parsed > ActionLimits.maxPort) bad(shape);
      return parsed;
    }

    switch (kind) {
      case 'dynamic':
        const shape = '[bind:]port';
        if (parts.length > 2) bad(shape);
        return PortForwardSpec(
          id: Ids.short(),
          kind: ForwardKind.dynamic,
          bindHost: parts.length == 2 ? parts[0] : ActionDefaults.bindHost,
          bindPort: port(parts.last, shape),
          autoStart: autoStart,
        );
      default:
        const shape = '[bind:]port:host:hostport';
        if (parts.length < 3 || parts.length > 4) bad(shape);
        final bound = parts.length == 4;
        return PortForwardSpec(
          id: Ids.short(),
          kind: kind == 'remote' ? ForwardKind.remote : ForwardKind.local,
          bindHost: bound ? parts[0] : ActionDefaults.bindHost,
          bindPort: port(parts[bound ? 1 : 0], shape),
          targetHost: parts[bound ? 2 : 1],
          targetPort: port(parts[bound ? 3 : 2], shape),
          autoStart: autoStart,
        );
    }
  }
}
