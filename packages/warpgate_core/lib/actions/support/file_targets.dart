import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

abstract final class FileTargets {
  static Future<(FileEndpoint, String, PathRef)> endpoint(ActionCall call, String name) async {
    final ref = PathRef.parse(call.string(name));
    return await open(call.runtime, ref);
  }

  static Future<(FileEndpoint, String, PathRef)> open(WarpgateRuntime rt, PathRef ref) async {
    final hostId = ref.host == null ? null : rt.host(ref.host!).id;
    final endpoint = await rt.endpoints.resolve(hostId);
    return (endpoint, await endpoint.resolve(ref.path), ref);
  }
}
