import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/src/engine/api/error.dart';
import 'package:warpgate_core/src/engine/api/util.dart' as rs;
import 'package:warpgate_core/src/engine/frb_generated.dart';

enum SshEngineKind { native, dart }

abstract final class NativeEngine {
  static SshEngineKind preferred = SshEngineKind.native;
  static Future<bool>? _loading;
  static bool _available = false;
  static String? loadError;

  static bool get available => _available;

  static bool get active => _available && preferred == SshEngineKind.native;

  static List<String> candidates() {
    final override = Platform.environment['WARPGATE_ENGINE_LIBRARY'];
    final executable = p.dirname(Platform.resolvedExecutable);
    final name = Platform.isWindows
        ? 'warpgate_engine.dll'
        : Platform.isMacOS
        ? 'libwarpgate_engine.dylib'
        : 'libwarpgate_engine.so';
    return [
      ?override,
      p.join(executable, name),
      p.join(executable, 'lib', name),
      p.join(executable, '..', 'Frameworks', 'warpgate_engine.framework', 'warpgate_engine'),
      p.join(executable, '..', 'Frameworks', name),
      if (Platform.isMacOS || Platform.isIOS) 'warpgate_engine.framework/warpgate_engine',
      name,
    ];
  }

  static Future<bool> ensureLoaded() => _loading ??= _load();

  static Future<bool> _load() async {
    if (Platform.environment['WARPGATE_ENGINE'] == 'dart') {
      preferred = SshEngineKind.dart;
      return false;
    }
    final errors = <String>[];
    if (Platform.isMacOS || Platform.isIOS) {
      try {
        await WarpgateEngine.init(externalLibrary: ExternalLibrary.process(iKnowHowToUseIt: true));
        _available = true;
        return true;
      } on Object catch (error) {
        errors.add('process: $error');
      }
    }
    for (final candidate in candidates()) {
      if (p.isAbsolute(candidate) && !File(candidate).existsSync()) continue;
      try {
        await WarpgateEngine.init(externalLibrary: ExternalLibrary.open(candidate));
        _available = true;
        return true;
      } on Object catch (error) {
        errors.add('$candidate: $error');
      }
    }
    loadError = errors.isEmpty ? 'The engine library was not found' : errors.join('; ');
    return false;
  }

  static String? get version => _available ? rs.engineVersion() : null;

  static Future<String?> sha256File(String path) async {
    if (!await ensureLoaded()) return null;
    return await rs.sha256File(path: path);
  }
}

Object nativeError(Object error) {
  if (error is! EngineError) return error is AnyhowException ? SSHStateError(error.message) : error;
  final message = error.message;
  return switch (error.kind) {
    EngineErrorKind.hostKey => SSHHostkeyError(message),
    EngineErrorKind.auth => SSHAuthFailError(message),
    EngineErrorKind.authAbort => SSHAuthAbortError(message),
    EngineErrorKind.keyDecrypt => SSHKeyDecryptError(message),
    EngineErrorKind.keyDecode => SSHKeyDecodeError(message),
    EngineErrorKind.timeout => TimeoutException(message),
    EngineErrorKind.socket => SSHSocketError(SocketException(message)),
    EngineErrorKind.handshake => SSHHandshakeError(message),
    EngineErrorKind.channel => SSHChannelOpenError(2, message),
    EngineErrorKind.channelRequest => SSHChannelRequestError(message),
    EngineErrorKind.cancelled => const ConnectCancelledException(),
    EngineErrorKind.disconnect => SSHDisconnectError(error.code ?? 11, message),
    EngineErrorKind.sftpStatus => SftpStatusError(error.code ?? 4, message),
    EngineErrorKind.sftp || EngineErrorKind.internal => SSHStateError(message),
  };
}

Future<T> guardNative<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on EngineError catch (error) {
    throw nativeError(error);
  } on AnyhowException catch (error) {
    throw nativeError(error);
  }
}
