import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/domain/ssh_key.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/snippets/domain/snippet.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

abstract final class Json {
  static JsonMap host(Host host, {required Map<String, String> groups, String status = 'idle'}) => {
    'id': host.id,
    'label': host.label,
    'address': host.address,
    'port': host.port,
    'username': host.username,
    'auth': host.auth.name,
    'key_id': host.keyId,
    'group': groups[host.groupId],
    'tags': host.tags,
    'jump_host_id': host.jumpHostId,
    'tmux': host.tmuxPersistence,
    'mcp_permission': host.mcpPermission.name,
    'status': status,
  };

  static JsonMap key(SshKey key) => {
    'id': key.id,
    'name': key.name,
    'algorithm': key.algorithm.name,
    'fingerprint': key.fingerprint,
    'public_key': key.publicKey,
    'created_at': key.createdAt.toIso8601String(),
    'has_passphrase': key.hasPassphrase,
  };

  static JsonMap knownHost(KnownHost host) => {
    'endpoint': host.endpoint,
    'key_type': host.keyType,
    'fingerprint': host.fingerprint,
    'added_at': host.addedAt.toIso8601String(),
  };

  static JsonMap entry(FileEntry entry) => {
    'name': entry.name,
    'path': entry.path,
    'type': entry.isLink
        ? 'link'
        : entry.isDirectory
        ? 'directory'
        : 'file',
    'size': entry.size,
    'modified': entry.modified?.toIso8601String(),
    'mode': entry.mode == null ? null : (entry.mode! & 0xFFF).toRadixString(8),
    'permissions': entry.permissions,
    'owner': entry.owner,
    'group': entry.group,
  };

  static String _ref(WarpgateRuntime runtime, TransferRef ref) {
    if (ref.hostId == null) return ref.path;
    final label = runtime.lookup(ref.hostId!)?.label ?? ref.hostId;
    return '$label:${ref.path}';
  }

  static JsonMap transfer(WarpgateRuntime runtime, TransferJob job) => {
    'id': job.id,
    'name': job.name,
    'status': job.status.name,
    'source': _ref(runtime, job.source),
    'target': _ref(runtime, job.target),
    'total_bytes': job.totalBytes,
    'done_bytes': job.doneBytes,
    'bytes_per_second': job.bytesPerSecond.round(),
    'origin': job.origin,
    'error': job.error,
  };

  static JsonMap snippet(Snippet snippet) => {
    'id': snippet.id,
    'name': snippet.name,
    'body': snippet.body,
    'variables': [for (final item in snippet.variables) item.name],
  };

  static JsonMap forward(Host host, PortForwardSpec spec, {String? state}) => {
    'id': spec.id,
    'host': host.label,
    'kind': spec.kind.name,
    'bind_host': spec.bindHost,
    'bind_port': spec.bindPort,
    'target_host': spec.targetHost,
    'target_port': spec.targetPort,
    'auto_start': spec.autoStart,
    'state': state,
  };
}
