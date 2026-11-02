import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/sftp/data/endpoints.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';

class EndpointResolver {
  new(this._ref);

  final Ref _ref;
  final Map<String, (SftpClient, SftpEndpoint)> _cache = {};
  final LocalEndpoint _local = LocalEndpoint();

  Future<FileEndpoint> resolve(String? hostId) async {
    if (hostId == null) return _local;
    await _ref.read(hostsProvider.future);
    final pool = _ref.read(connectionPoolProvider);
    final sftp = await pool.sftp(hostId);
    final cached = _cache[hostId];
    if (cached != null && identical(cached.$1, sftp)) return cached.$2;
    final label =
        _ref.read(hostsProvider).value?.host(hostId)?.label ?? 'Remote host';
    final endpoint = SftpEndpoint(sftp, label: label);
    _cache[hostId] = (sftp, endpoint);
    return endpoint;
  }

  void invalidate(String hostId) {
    _cache.remove(hostId);
    _ref.read(connectionPoolProvider).dropSftp(hostId);
  }
}

final endpointResolverProvider = Provider<EndpointResolver>(
  EndpointResolver.new,
);
