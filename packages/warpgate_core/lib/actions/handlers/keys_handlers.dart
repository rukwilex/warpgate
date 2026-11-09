import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/support/json_views.dart';
import 'package:warpgate_core/actions/support/lookups.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/keys/data/key_codec.dart';
import 'package:warpgate_core/features/keys/domain/ssh_key.dart';

abstract final class KeyHandlers {
  static final Map<String, ActionHandler> all = {
    'keys.list': _keysList,
    'keys.generate': _keysGenerate,
    'keys.import': _keysImport,
    'keys.export-public': _keysPublic,
    'keys.install': _keysInstall,
    'keys.rm': _keysRm,
  };

  static Future<JsonMap> _keysList(ActionCall call) async {
    final keys = await call.runtime.keys.all();
    keys.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return {'keys': keys.map(Json.key).toList()};
  }

  static Future<JsonMap> _keysGenerate(ActionCall call) async {
    final name = call.string('name');
    final material = await KeyCodec.generate(
      algorithm: KeyAlgorithm.values.byName(call.maybe('type') ?? 'ed25519'),
      comment: name,
      rsaBits: ActionLimits.rsaBits,
    );
    return Json.key(await call.runtime.keys.save(name: name, material: material));
  }

  static Future<JsonMap> _keysImport(ActionCall call) async {
    final path = call.string('file');
    final file = File(path);
    if (!file.existsSync()) {
      throw ActionFailure('$path does not exist', kind: ExitKind.notFound);
    }
    final pem = await file.readAsString();
    final passphrase = call.maybe('_passphrase');
    final KeyMaterial material;
    try {
      material = KeyCodec.parse(pem, passphrase: passphrase);
    } on KeyFormatException catch (error) {
      throw ActionFailure(
        error.toString(),
        hint: KeyCodec.needsPassphrase(pem) ? 'This key needs a passphrase. Use --passphrase-stdin' : null,
      );
    }
    final name = call.maybe('name') ?? p.basenameWithoutExtension(path);
    return Json.key(
      await call.runtime.keys.save(name: name, material: material, passphrase: passphrase),
    );
  }

  static Future<JsonMap> _keysPublic(ActionCall call) async {
    final key = await Lookups.findKey(call.runtime, call.string('key'));
    return {'public_key': key.publicKey};
  }

  static Future<JsonMap> _keysInstall(ActionCall call) async {
    final rt = call.runtime;
    final key = await Lookups.findKey(rt, call.string('key'));
    final host = rt.host(call.string('host'));
    await rt.pool.client(host.id);
    final result = await rt.pool.exec(host.id, KeyCodec.installCommand(key.publicKey));
    if (!result.succeeded) {
      throw ActionFailure(
        'Could not install the key: ${result.error ?? result.stderr.trim()}',
      );
    }
    return {'key': key.name, 'host': host.label};
  }

  static Future<JsonMap> _keysRm(ActionCall call) async {
    final key = await Lookups.findKey(call.runtime, call.string('key'));
    await call.runtime.keys.delete(key.id);
    return {'id': key.id, 'name': key.name};
  }
}
