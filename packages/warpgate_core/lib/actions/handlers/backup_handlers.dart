import 'dart:io';

import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/security/data/backup_codec.dart';

abstract final class BackupHandlers {
  static final Map<String, ActionHandler> all = {
    'backup.export': _backupExport,
    'backup.import': _backupImport,
  };

  static Future<JsonMap> _backupExport(ActionCall call) async {
    final path = call.string('file');
    final withSecrets = call.on('with-secrets');
    final content = await call.runtime.backup.export(
      passphrase: call.string('_passphrase'),
      includeSecrets: withSecrets,
    );
    final file = File(path);
    await file.writeAsString('', flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', path]);
    }
    await file.writeAsString(content, flush: true);
    return {'file': path, 'with_secrets': withSecrets};
  }

  static Future<JsonMap> _backupImport(ActionCall call) async {
    final path = call.string('file');
    final file = File(path);
    if (!file.existsSync()) {
      throw ActionFailure('$path does not exist', kind: ExitKind.notFound);
    }
    final raw = await file.readAsString();
    try {
      final summary = await call.runtime.backup.restore(raw, call.string('_passphrase'));
      return {'hosts': summary.hosts, 'keys': summary.keys, 'snippets': summary.snippets};
    } on BackupException catch (error) {
      throw ActionFailure(error.toString());
    }
  }
}
