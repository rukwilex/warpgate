
import 'package:warpgate_core/features/hosts/domain/host.dart';

sealed class SessionTarget {
  const new();
}

class SshTarget extends SessionTarget {
  const new({required this.host, this.tmuxSession, this.directory});

  final Host host;
  final String? tmuxSession;
  final String? directory;
}

class LocalTarget extends SessionTarget {
  const new({this.directory});

  final String? directory;
}
