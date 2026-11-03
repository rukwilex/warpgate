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

enum FilesDock { right, bottom }

@immutable
class AttachedFiles {
  const new({
    this.open = false,
    this.dock = FilesDock.right,
    this.ratio = 0.62,
    this.path,
    this.follow = true,
    this.tree = false,
  });

  factory fromJson(JsonMap? json) {
    if (json == null) return const AttachedFiles();
    return AttachedFiles(
      open: json['open'] as bool? ?? false,
      dock:
          FilesDock.values
              .where((value) => value.name == json['dock'])
              .firstOrNull ??
          FilesDock.right,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0.62,
      path: json['path'] as String?,
      follow: json['follow'] as bool? ?? true,
      tree: json['tree'] as bool? ?? false,
    );
  }

  final bool open;
  final FilesDock dock;
  final double ratio;
  final String? path;
  final bool follow;
  final bool tree;

  AttachedFiles copyWith({
    bool? open,
    FilesDock? dock,
    double? ratio,
    String? Function()? path,
    bool? follow,
    bool? tree,
  }) => AttachedFiles(
    open: open ?? this.open,
    dock: dock ?? this.dock,
    ratio: ratio ?? this.ratio,
    path: path == null ? this.path : path(),
    follow: follow ?? this.follow,
    tree: tree ?? this.tree,
  );

  JsonMap toJson() => {
    'open': open,
    'dock': dock.name,
    'ratio': ratio,
    'path': path,
    'follow': follow,
    'tree': tree,
  };

  @override
  bool operator ==(Object other) =>
      other is AttachedFiles &&
      other.open == open &&
      other.dock == dock &&
      other.ratio == ratio &&
      other.path == path &&
      other.follow == follow &&
      other.tree == tree;

  @override
  int get hashCode => Object.hash(open, dock, ratio, path, follow, tree);
}

sealed class PaneContent {
  const new();

  factory fromJson(JsonMap json) => switch (json['kind']) {
    'ssh' => SshTerminalContent(
      hostId: json['hostId']! as String,
      tmuxSession: json['tmuxSession'] as String?,
      directory: json['directory'] as String?,
      files: AttachedFiles.fromJson((json['files'] as Map?)?.cast()),
    ),
    'local' => LocalTerminalContent(
      directory: json['directory'] as String?,
      files: AttachedFiles.fromJson((json['files'] as Map?)?.cast()),
    ),
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

sealed class TerminalContent extends PaneContent {
  const new();

  String? get directory;

  AttachedFiles get files;

  TerminalContent withFiles(AttachedFiles files);
}

class SshTerminalContent extends TerminalContent {
  const new({
    required this.hostId,
    this.tmuxSession,
    this.directory,
    this.files = const AttachedFiles(),
  });

  @override
  final String hostId;
  final String? tmuxSession;
  @override
  final String? directory;
  @override
  final AttachedFiles files;

  @override
  SshTerminalContent withFiles(AttachedFiles files) => SshTerminalContent(
    hostId: hostId,
    tmuxSession: tmuxSession,
    directory: directory,
    files: files,
  );

  @override
  JsonMap toJson() => {
    'kind': 'ssh',
    'hostId': hostId,
    'tmuxSession': tmuxSession,
    'directory': directory,
    'files': files.toJson(),
  };
}

class LocalTerminalContent extends TerminalContent {
  const new({this.directory, this.files = const AttachedFiles()});

  @override
  final String? directory;
  @override
  final AttachedFiles files;

  @override
  String? get hostId => null;

  @override
  LocalTerminalContent withFiles(AttachedFiles files) =>
      LocalTerminalContent(directory: directory, files: files);

  @override
  JsonMap toJson() => {
    'kind': 'local',
    'directory': directory,
    'files': files.toJson(),
  };
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
    this.fontSize,
  });

  factory fromJson(JsonMap json) => Pane(
    id: json['id']! as String,
    content: PaneContent.fromJson((json['content']! as Map).cast()),
    origin: PaneOrigin.values.byName(json['origin'] as String? ?? 'user'),
    fontSize: (json['fontSize'] as num?)?.toDouble(),
  );

  final String id;
  final PaneContent content;
  final PaneOrigin origin;
  final double? fontSize;

  Pane withContent(PaneContent value) =>
      Pane(id: id, content: value, origin: origin, fontSize: fontSize);

  Pane withFontSize(double? value) =>
      Pane(id: id, content: content, origin: origin, fontSize: value);

  JsonMap toJson() => {
    'id': id,
    'content': content.toJson(),
    'origin': origin.name,
    'fontSize': fontSize,
  };
}
