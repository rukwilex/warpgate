import 'dart:async';
import 'dart:convert';

import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_codec.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

enum DirectTool { rsync, scp }

class DirectProbe {
  const new({required this.reachable, this.tool, this.reason});

  final bool reachable;
  final DirectTool? tool;
  final String? reason;
}

class DirectTransfer {
  new(this._pool);

  final ConnectionPool _pool;

  static String _sshTarget(Host target) =>
      '${target.username}@${target.address}';

  static String sshOptions(Host target) =>
      '-o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new -p ${target.port}';

  Future<DirectProbe> probe(Host source, Host target) async {
    final tools = await _pool.exec(
      source.id,
      'command -v rsync >/dev/null 2>&1 && echo rsync; command -v scp >/dev/null 2>&1 && echo scp',
      timeout: const Duration(seconds: 10),
    );
    if (tools.error != null) {
      return DirectProbe(reachable: false, reason: tools.error);
    }
    final found = tools.stdout.split('\n').map((line) => line.trim()).toSet();
    final tool = found.contains('rsync')
        ? DirectTool.rsync
        : found.contains('scp')
        ? DirectTool.scp
        : null;
    if (tool == null) {
      return DirectProbe(
        reachable: false,
        reason: '${source.label} has neither rsync nor scp',
      );
    }
    final login = await _pool.exec(
      source.id,
      'ssh ${sshOptions(target)} ${_sshTarget(target)} true',
      timeout: const Duration(seconds: 15),
    );
    if (login.exitCode != 0) {
      return DirectProbe(
        reachable: false,
        tool: tool,
        reason:
            '${source.label} cannot sign in to ${target.label} without a password',
      );
    }
    return DirectProbe(reachable: true, tool: tool);
  }

  Future<void> run({
    required Host source,
    required Host target,
    required String sourcePath,
    required String targetPath,
    required DirectTool tool,
    required CancelToken cancel,
    required void Function(double fraction, double bytesPerSecond) onProgress,
  }) async {
    final ssh = await _pool.client(source.id);
    final remote = '${_sshTarget(target)}:${KeyCodec.shellQuote(targetPath)}';
    final command = switch (tool) {
      DirectTool.rsync =>
        'rsync -a --partial --info=progress2 -e ${KeyCodec.shellQuote('ssh ${sshOptions(target)}')} '
            '${KeyCodec.shellQuote(sourcePath)} $remote',
      DirectTool.scp =>
        'scp -r -p ${sshOptions(target).replaceAll('-p ', '-P ')} ${KeyCodec.shellQuote(sourcePath)} $remote',
    };
    final session = await ssh.execute(command);
    cancel.onCancel(session.close);
    final errors = StringBuffer();
    final progress = RegExp(r'(\d+)%\s+([\d.]+)([kMG]?B)/s');
    final out = session.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((chunk) {
          final matches = progress.allMatches(chunk);
          if (matches.isEmpty) return;
          final last = matches.last;
          final unit = switch (last.group(3)) {
            'kB' => 1024,
            'MB' => 1024 * 1024,
            'GB' => 1024 * 1024 * 1024,
            _ => 1,
          };
          onProgress(
            int.parse(last.group(1)!) / 100,
            double.parse(last.group(2)!) * unit,
          );
        });
    final err = session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(errors.write);
    final code = await session.waitForExit();
    await out.cancel();
    await err.cancel();
    cancel.throwIfCancelled();
    if (code != 0) {
      final message = errors.toString().trim().split('\n').lastOrNull;
      throw FileOperationException(
        message == null || message.isEmpty
            ? '${tool.name} exited with code $code'
            : message,
      );
    }
    onProgress(1, 0);
  }
}
