import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_backup.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_backup_passphrase_dialog.dart';
import 'package:warpgate/features/settings/utils/export_file_names.dart';
import 'package:warpgate_core/core/util/format.dart';

class SettingsBackupActions extends ConsumerWidget {
  const new({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final options = await showDialog<({String passphrase, bool secrets})>(
      context: context,
      builder: (_) => const SettingsBackupPassphraseDialog(export: true),
    );
    if (options == null || !context.mounted) return;
    final location = await getSaveLocation(
      suggestedName: ExportFileNames.backup(DateTime.now()),
    );
    if (location == null) return;
    final file = await SettingsBackup(
      ref,
    ).export(passphrase: options.passphrase, includeSecrets: options.secrets);
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(file)),
      mimeType: 'application/json',
    ).saveTo(location.path);
    if (context.mounted) {
      showWgToast(context, 'Backup saved to ${location.path}');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await openFile();
    if (picked == null || !context.mounted) return;
    final options = await showDialog<({String passphrase, bool secrets})>(
      context: context,
      builder: (_) => const SettingsBackupPassphraseDialog(export: false),
    );
    if (options == null) return;
    try {
      final counts = await SettingsBackup(ref)
          .restore(await picked.readAsString(), options.passphrase);
      if (context.mounted) {
        showWgToast(
          context,
          'Restored ${Format.plural(counts.hosts, 'host')}, ${Format.plural(counts.keys, 'key')} and ${Format.plural(counts.snippets, 'snippet')}. Workspaces return on next launch',
        );
      }
    } on Object catch (error) {
      if (context.mounted) showWgToast(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: context.space.sm,
    runSpacing: context.space.sm,
    children: [
      WgButton(
        label: 'Export backup',
        icon: WgIcons.export,
        onPressed: PlatformInfo.isWeb
            ? null
            : () => unawaited(_export(context, ref)),
      ),
      WgButton.ghost(
        label: 'Restore from file',
        icon: WgIcons.import,
        onPressed: PlatformInfo.isWeb
            ? null
            : () => unawaited(_import(context, ref)),
      ),
    ],
  );
}
