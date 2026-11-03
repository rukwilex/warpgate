import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/sftp/data/endpoints.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class EndpointResolver {
  new({
    required this.pool,
    required this.labelOf,
    this.ready,
  });

  final ConnectionPool pool;
  final String? Function(String hostId) labelOf;
  final Future<void> Function()? ready;
  final Map<String, (SftpClient, SftpEndpoint)> _cache = {};
  final LocalEndpoint _local = LocalEndpoint();

  Future<FileEndpoint> resolve(String? hostId) async {
    if (hostId == null) return _local;
    await ready?.call();
    final sftp = await pool.sftp(hostId);
    final cached = _cache[hostId];
    if (cached != null && identical(cached.$1, sftp)) return cached.$2;
    final endpoint = SftpEndpoint(
      sftp,
      label: labelOf(hostId) ?? 'Remote host',
    );
    _cache[hostId] = (sftp, endpoint);
    return endpoint;
  }

  void invalidate(String hostId) {
    _cache.remove(hostId);
    pool.dropSftp(hostId);
  }
}
