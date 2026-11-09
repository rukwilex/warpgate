import 'package:flutter/foundation.dart';

class TerminalLink {
  const new({
    required this.cwd,
    required this.follow,
    required this.onFollow,
    required this.cdHere,
    this.onInstallHook,
  });

  final ValueListenable<String?> cwd;
  final bool follow;
  final ValueChanged<bool> onFollow;
  final ValueChanged<String> cdHere;
  final VoidCallback? onInstallHook;
}
