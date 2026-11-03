import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:warpgate_core/core/data/document_store.dart';

enum AuthMethod {
  password('Password'),
  key('Key'),
  keyboardInteractive('Keyboard interactive'),
  agent('SSH agent');

  new(this.label);

  final String label;
}

enum McpPermission {
  off('Off'),
  readOnly('Read only'),
  full('Full');

  new(this.label);

  final String label;
}

enum ForwardKind {
  local('Local'),
  remote('Remote'),
  dynamic('Dynamic SOCKS');

  new(this.label);

  final String label;
}

@immutable
class PortForwardSpec {
  const new({
    required this.id,
    required this.kind,
    required this.bindPort,
    this.bindHost = '127.0.0.1',
    this.targetHost = '',
    this.targetPort = 0,
    this.autoStart = false,
  });

  factory fromJson(JsonMap json) => PortForwardSpec(
    id: json['id']! as String,
    kind: ForwardKind.values.byName(json['kind']! as String),
    bindHost: json['bindHost'] as String? ?? '127.0.0.1',
    bindPort: json['bindPort']! as int,
    targetHost: json['targetHost'] as String? ?? '',
    targetPort: json['targetPort'] as int? ?? 0,
    autoStart: json['autoStart'] as bool? ?? false,
  );

  final String id;
  final ForwardKind kind;
  final String bindHost;
  final int bindPort;
  final String targetHost;
  final int targetPort;
  final bool autoStart;

  String get summary => switch (kind) {
    ForwardKind.local => '$bindHost:$bindPort → $targetHost:$targetPort',
    ForwardKind.remote => 'remote :$bindPort → $targetHost:$targetPort',
    ForwardKind.dynamic => 'SOCKS $bindHost:$bindPort',
  };

  JsonMap toJson() => {
    'id': id,
    'kind': kind.name,
    'bindHost': bindHost,
    'bindPort': bindPort,
    'targetHost': targetHost,
    'targetPort': targetPort,
    'autoStart': autoStart,
  };
}

@immutable
class Host {
  const new({
    required this.id,
    required this.label,
    required this.address,
    required this.username,
    this.port = 22,
    this.auth = AuthMethod.password,
    this.keyId,
    this.groupId,
    this.tags = const [],
    this.jumpHostId,
    this.tmuxPersistence = false,
    this.mcpPermission = McpPermission.off,
    this.forwards = const [],
    this.keepAliveSeconds = 15,
    this.startDirectory,
  });

  factory fromJson(JsonMap json) => Host(
    id: json['id']! as String,
    label: json['label']! as String,
    address: json['address']! as String,
    port: json['port'] as int? ?? 22,
    username: json['username']! as String,
    auth: AuthMethod.values.byName(json['auth'] as String? ?? 'password'),
    keyId: json['keyId'] as String?,
    groupId: json['groupId'] as String?,
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    jumpHostId: json['jumpHostId'] as String?,
    tmuxPersistence: json['tmuxPersistence'] as bool? ?? false,
    mcpPermission: McpPermission.values.byName(
      json['mcpPermission'] as String? ?? 'off',
    ),
    forwards: [
      for (final item in (json['forwards'] as List?) ?? const <Object?>[])
        PortForwardSpec.fromJson((item! as Map).cast<String, Object?>()),
    ],
    keepAliveSeconds: json['keepAliveSeconds'] as int? ?? 15,
    startDirectory: json['startDirectory'] as String?,
  );

  final String id;
  final String label;
  final String address;
  final int port;
  final String username;
  final AuthMethod auth;
  final String? keyId;
  final String? groupId;
  final List<String> tags;
  final String? jumpHostId;
  final bool tmuxPersistence;
  final McpPermission mcpPermission;
  final List<PortForwardSpec> forwards;
  final int keepAliveSeconds;
  final String? startDirectory;

  String get endpoint =>
      port == 22 ? '$username@$address' : '$username@$address:$port';

  String get knownHostsKey => '$address:$port';

  Host copyWith({
    String? label,
    String? address,
    int? port,
    String? username,
    AuthMethod? auth,
    String? Function()? keyId,
    String? Function()? groupId,
    List<String>? tags,
    String? Function()? jumpHostId,
    bool? tmuxPersistence,
    McpPermission? mcpPermission,
    List<PortForwardSpec>? forwards,
    int? keepAliveSeconds,
    String? Function()? startDirectory,
  }) => Host(
    id: id,
    label: label ?? this.label,
    address: address ?? this.address,
    port: port ?? this.port,
    username: username ?? this.username,
    auth: auth ?? this.auth,
    keyId: keyId == null ? this.keyId : keyId(),
    groupId: groupId == null ? this.groupId : groupId(),
    tags: tags ?? this.tags,
    jumpHostId: jumpHostId == null ? this.jumpHostId : jumpHostId(),
    tmuxPersistence: tmuxPersistence ?? this.tmuxPersistence,
    mcpPermission: mcpPermission ?? this.mcpPermission,
    forwards: forwards ?? this.forwards,
    keepAliveSeconds: keepAliveSeconds ?? this.keepAliveSeconds,
    startDirectory: startDirectory == null
        ? this.startDirectory
        : startDirectory(),
  );

  JsonMap toJson() => {
    'id': id,
    'label': label,
    'address': address,
    'port': port,
    'username': username,
    'auth': auth.name,
    'keyId': keyId,
    'groupId': groupId,
    'tags': tags,
    'jumpHostId': jumpHostId,
    'tmuxPersistence': tmuxPersistence,
    'mcpPermission': mcpPermission.name,
    'forwards': [for (final forward in forwards) forward.toJson()],
    'keepAliveSeconds': keepAliveSeconds,
    'startDirectory': startDirectory,
  };

  @override
  bool operator ==(Object other) =>
      other is Host &&
      const DeepCollectionEquality().equals(toJson(), other.toJson());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toJson());
}

@immutable
class HostGroup {
  const new({required this.id, required this.name});

  factory fromJson(JsonMap json) =>
      HostGroup(id: json['id']! as String, name: json['name']! as String);

  final String id;
  final String name;

  JsonMap toJson() => {'id': id, 'name': name};
}

@immutable
class KnownHost {
  const new({
    required this.endpoint,
    required this.keyType,
    required this.fingerprint,
    required this.addedAt,
  });

  factory fromJson(JsonMap json) => KnownHost(
    endpoint: json['endpoint']! as String,
    keyType: json['keyType']! as String,
    fingerprint: json['fingerprint']! as String,
    addedAt: DateTime.parse(json['addedAt']! as String),
  );

  final String endpoint;
  final String keyType;
  final String fingerprint;
  final DateTime addedAt;

  JsonMap toJson() => {
    'endpoint': endpoint,
    'keyType': keyType,
    'fingerprint': fingerprint,
    'addedAt': addedAt.toIso8601String(),
  };
}

abstract final class HostChain {
  static List<Host> resolve(Host target, Map<String, Host> byId) {
    final chain = <Host>[target];
    final seen = <String>{target.id};
    var cursor = target;
    while (cursor.jumpHostId != null) {
      final next = byId[cursor.jumpHostId];
      if (next == null || !seen.add(next.id)) break;
      chain.insert(0, next);
      cursor = next;
    }
    return chain;
  }

  static bool wouldCycle(
    String hostId,
    String? jumpHostId,
    Map<String, Host> byId,
  ) {
    var cursor = jumpHostId;
    final seen = <String>{};
    while (cursor != null) {
      if (cursor == hostId || !seen.add(cursor)) return true;
      cursor = byId[cursor]?.jumpHostId;
    }
    return false;
  }
}
