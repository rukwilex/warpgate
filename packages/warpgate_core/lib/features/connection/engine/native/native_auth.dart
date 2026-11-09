import 'package:dartssh2/dartssh2.dart';

sealed class NativeCredential {
  const new();
}

class AgentCredential extends NativeCredential {
  const new(this.socket);

  final String? socket;
}

class KeyCredential extends NativeCredential {
  const new(this.pem, this.passphrase);

  final String pem;
  final String? passphrase;
}

class NativeAuth {
  const new({
    required this.username,
    this.credentials = const [],
    this.password,
    this.keyboardInteractive,
  });

  final String username;
  final List<NativeCredential> credentials;
  final Future<String?> Function()? password;
  final Future<List<String>?> Function(SSHUserInfoRequest request)? keyboardInteractive;
}
