import 'package:flutter/foundation.dart';
import 'package:warpgate/core/data/app_database.dart';

enum PaneOrigin { user, claudeCode }

@immutable
class SftpSide {
  const new({this.hostId, this.path});

  factory fromJson(JsonMap json) => SftpSide(
    hostId: json['hostId'] as String?,
    path: json['path'] as String?,
  );

  final String? hostId;
  final String? path;

  bool get isLocal => hostId == null;

  SftpSide withPath(String value) => SftpSide(hostId: hostId, path: value);

  JsonMap toJson() => {'hostId': hostId, 'path': path};

  @override
  bool operator ==(Object other) =>
      other is SftpSide && other.hostId == hostId && other.path == path;

  @override
  int get hashCode => Object.hash(hostId, path);
}

sealed class PaneContent {
  const new();

  factory fromJson(JsonMap json) => switch (json['kind']) {
    'ssh' => SshTerminalContent(
      hostId: json['hostId']! as String,
      tmuxSession: json['tmuxSession'] as String?,
      directory: json['directory'] as String?,
    ),
    'local' => LocalTerminalContent(directory: json['directory'] as String?),
    'sftp' => SftpContent(
      left: SftpSide.fromJson((json['left']! as Map).cast()),
      right: json['right'] == null
          ? null
          : SftpSide.fromJson((json['right']! as Map).cast()),
    ),
    'log' => LogTailContent(
      hostId: json['hostId']! as String,
      path: json['path']! as String,
    ),
    _ => const LocalTerminalContent(),
  };

  String? get hostId;

  JsonMap toJson();
}

class SshTerminalContent extends PaneContent {
  const new({required this.hostId, this.tmuxSession, this.directory});

  @override
  final String hostId;
  final String? tmuxSession;
  final String? directory;

  @override
  JsonMap toJson() => {
    'kind': 'ssh',
    'hostId': hostId,
    'tmuxSession': tmuxSession,
    'directory': directory,
  };
}

class LocalTerminalContent extends PaneContent {
  const new({this.directory});

  final String? directory;

  @override
  String? get hostId => null;

  @override
  JsonMap toJson() => {'kind': 'local', 'directory': directory};
}

class SftpContent extends PaneContent {
  const new({required this.left, this.right});

  final SftpSide left;
  final SftpSide? right;

  bool get isDual => right != null;

  @override
  String? get hostId => left.hostId ?? right?.hostId;

  SftpContent copyWith({SftpSide? left, SftpSide? Function()? right}) =>
      SftpContent(
        left: left ?? this.left,
        right: right == null ? this.right : right(),
      );

  @override
  JsonMap toJson() => {
    'kind': 'sftp',
    'left': left.toJson(),
    'right': right?.toJson(),
  };
}

class LogTailContent extends PaneContent {
  const new({required this.hostId, required this.path});

  @override
  final String hostId;
  final String path;

  @override
  JsonMap toJson() => {'kind': 'log', 'hostId': hostId, 'path': path};
}

@immutable
class Pane {
  const new({
    required this.id,
    required this.content,
    this.origin = PaneOrigin.user,
  });

  factory fromJson(JsonMap json) => Pane(
    id: json['id']! as String,
    content: PaneContent.fromJson((json['content']! as Map).cast()),
    origin: PaneOrigin.values.byName(json['origin'] as String? ?? 'user'),
  );

  final String id;
  final PaneContent content;
  final PaneOrigin origin;

  Pane withContent(PaneContent value) =>
      Pane(id: id, content: value, origin: origin);

  JsonMap toJson() => {
    'id': id,
    'content': content.toJson(),
    'origin': origin.name,
  };
}
