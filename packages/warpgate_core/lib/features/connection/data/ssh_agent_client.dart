import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

class AgentKey {
  const new(this.blob, this.comment);

  final Uint8List blob;
  final String comment;

  String get algorithm {
    final length = ByteData.sublistView(blob).getUint32(0);
    return String.fromCharCodes(blob.sublist(4, 4 + length));
  }
}

class _RawPublicKey implements SSHHostKey {
  const new(this._blob);

  final Uint8List _blob;

  @override
  Uint8List encode() => _blob;
}

abstract interface class AgentTransport {
  Future<Uint8List> exchange(Uint8List message);

  Future<void> close();
}

class _SocketTransport implements AgentTransport {
  new(this._socket) {
    _socket.listen(_received, onDone: _closed, onError: (Object _) => _closed());
  }

  final Socket _socket;
  final _buffer = BytesBuilder();
  Completer<Uint8List>? _waiting;

  void _closed() {
    _waiting?.completeError(const SocketException('The ssh-agent closed'));
    _waiting = null;
  }

  void _received(Uint8List chunk) {
    _buffer.add(chunk);
    final bytes = _buffer.toBytes();
    if (bytes.length < 4) return;
    final size = ByteData.sublistView(bytes).getUint32(0);
    if (bytes.length < size + 4) return;
    _buffer
      ..clear()
      ..add(bytes.sublist(size + 4));
    final waiting = _waiting;
    _waiting = null;
    waiting?.complete(bytes.sublist(0, size + 4));
  }

  @override
  Future<Uint8List> exchange(Uint8List message) {
    final completer = Completer<Uint8List>();
    _waiting = completer;
    _socket.add(message);
    return completer.future.timeout(const Duration(minutes: 2));
  }

  @override
  Future<void> close() async => _socket.destroy();
}

class _PipeTransport implements AgentTransport {
  const new(this._file);

  final RandomAccessFile _file;

  @override
  Future<Uint8List> exchange(Uint8List message) async {
    await _file.writeFrom(message);
    await _file.flush();
    final header = await _file.read(4);
    final size = ByteData.sublistView(header).getUint32(0);
    final body = BytesBuilder();
    while (body.length < size) {
      final chunk = await _file.read(size - body.length);
      if (chunk.isEmpty) break;
      body.add(chunk);
    }
    return Uint8List.fromList([...header, ...body.toBytes()]);
  }

  @override
  Future<void> close() => _file.close();
}

class SshAgentClient {
  new(this._transport);

  static const _requestIdentities = 11;
  static const _identitiesAnswer = 12;
  static const _signRequest = 13;
  static const _signResponse = 14;
  static const windowsPipe = r'\\.\pipe\openssh-ssh-agent';
  static const _rsaSha256Flag = 2;

  final AgentTransport _transport;

  static String? get location {
    final socket = Platform.environment['SSH_AUTH_SOCK'];
    if (socket != null && socket.isNotEmpty) return socket;
    return Platform.isWindows ? windowsPipe : null;
  }

  static Future<SshAgentClient?> connect([String? path]) async {
    final target = path ?? location;
    if (target == null) return null;
    try {
      if (target.startsWith(r'\\.\pipe\')) {
        final file = await File(target).open(mode: FileMode.append);
        return SshAgentClient(_PipeTransport(file));
      }
      final socket = await Socket.connect(
        InternetAddress(target, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 2),
      );
      return SshAgentClient(_SocketTransport(socket));
    } on Object {
      return null;
    }
  }

  static Future<List<SSHIdentity>> identitiesFromEnvironment() async {
    final client = await connect();
    if (client == null) return const [];
    try {
      return await client.identities();
    } on Object {
      return const [];
    }
  }

  static Uint8List frame(List<int> payload) {
    final out = BytesBuilder();
    final size = ByteData(4)..setUint32(0, payload.length);
    out
      ..add(size.buffer.asUint8List())
      ..add(payload);
    return out.toBytes();
  }

  static List<int> _string(List<int> value) {
    final size = ByteData(4)..setUint32(0, value.length);
    return [...size.buffer.asUint8List(), ...value];
  }

  static List<AgentKey> parseIdentities(Uint8List framed) {
    final data = ByteData.sublistView(framed);
    if (framed.length < 9 || framed[4] != _identitiesAnswer) {
      throw const FormatException('The ssh-agent sent an unexpected answer');
    }
    final count = data.getUint32(5);
    var offset = 9;
    Uint8List read() {
      final length = data.getUint32(offset);
      final value = framed.sublist(offset + 4, offset + 4 + length);
      offset += 4 + length;
      return value;
    }

    return [
      for (var i = 0; i < count; i++)
        AgentKey(read(), String.fromCharCodes(read())),
    ];
  }

  Future<List<AgentKey>> keys() async => parseIdentities(
    await _transport.exchange(frame([_requestIdentities])),
  );

  Future<Uint8List> sign(AgentKey key, Uint8List data) async {
    final flags = key.algorithm == 'ssh-rsa' ? _rsaSha256Flag : 0;
    final flagBytes = ByteData(4)..setUint32(0, flags);
    final reply = await _transport.exchange(
      frame([
        _signRequest,
        ..._string(key.blob),
        ..._string(data),
        ...flagBytes.buffer.asUint8List(),
      ]),
    );
    if (reply.length < 9 || reply[4] != _signResponse) {
      throw SSHAuthAbortError('The ssh-agent refused to sign');
    }
    final length = ByteData.sublistView(reply).getUint32(5);
    return reply.sublist(9, 9 + length);
  }

  Future<List<SSHIdentity>> identities() async => [
    for (final key in await keys())
      SSHIdentity.custom(
        type: key.algorithm == 'ssh-rsa' ? 'rsa-sha2-256' : key.algorithm,
        publicKey: _RawPublicKey(key.blob),
        comment: key.comment,
        shouldProbe: true,
        signer: (data) async => SSHRawSignature(await sign(key, data)),
      ),
  ];

  Future<void> close() => _transport.close();
}
