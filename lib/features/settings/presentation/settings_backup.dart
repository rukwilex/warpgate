import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/keys/presentation/keys_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/snippets/presentation/snippets_controller.dart';
import 'package:warpgate_core/features/security/data/backup_service.dart';

class SettingsBackup {
  const new(this.ref);

  final WidgetRef ref;

  BackupService get _service => BackupService(
    ref.read(documentStoreProvider),
    ref.read(secretStoreProvider),
  );

  Future<String> export({
    required String passphrase,
    required bool includeSecrets,
  }) => _service.export(
    passphrase: passphrase,
    includeSecrets: includeSecrets,
  );

  Future<({int hosts, int keys, int snippets})> restore(
    String file,
    String passphrase,
  ) async {
    final counts = await _service.restore(file, passphrase);
    ref
      ..invalidate(hostsProvider)
      ..invalidate(keysProvider)
      ..invalidate(snippetsProvider);
    final restored = await SettingsController.load(
      ref.read(documentStoreProvider),
    );
    ref.read(settingsProvider.notifier).replace(restored);
    return counts;
  }
}
