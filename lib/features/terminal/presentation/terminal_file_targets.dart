import 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class TerminalFileTargets {
  const new(this._resolver, {required this.hostId});

  final EndpointResolver _resolver;
  final String? hostId;

  Future<String> selectionPath(
    String text, {
    required String Function() folder,
  }) async {
    final endpoint = await _resolver.resolve(hostId);
    final paths = endpoint.paths;
    var path = text.split('\n').first.trim();
    if (path.startsWith('~')) {
      path = await endpoint.resolve(path);
    } else if (!paths.isAbsolute(path)) {
      path = paths.join(await endpoint.resolve(folder()), path);
    }
    return paths.normalize(path);
  }

  Future<String> folder(String Function() folder) async {
    final endpoint = await _resolver.resolve(hostId);
    return await endpoint.resolve(folder());
  }

  Future<List<FileEntry>> localEntries(List<String> paths) async {
    final local = await _resolver.resolve(null);
    return [for (final path in paths) ?await local.stat(path)];
  }
}
