import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/util/clipboard_guard.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/host_picker.dart';
import 'package:warpgate/features/keys/data/key_codec.dart';
import 'package:warpgate/features/keys/domain/ssh_key.dart';
import 'package:warpgate/features/keys/presentation/keys_controller.dart';
import 'package:warpgate/features/shell/presentation/prompts.dart';

class KeysScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _install(BuildContext context, WidgetRef ref, SshKey key) async {
    final host = await showHostPicker(context, title: 'Install ${key.name} on');
    if (host == null || !context.mounted) return;
    final ok = await showWgConfirm(
      context,
      title: 'Add ${key.name} to ${host.label}?',
      message:
          'Appends the public key to ~/.ssh/authorized_keys for ${host.username}, unless it is already there.',
      confirmLabel: 'Install key',
    );
    if (!ok) return;
    final result = await ref
        .read(connectionPoolProvider)
        .exec(host.id, KeyCodec.installCommand(key.publicKey));
    if (!context.mounted) return;
    showWgToast(
      context,
      result.succeeded
          ? 'Installed on ${host.label}. You can switch the host to key sign-in'
          : 'Could not install: ${result.error ?? result.stderr.trim()}',
    );
  }

  Future<void> _export(BuildContext context, SshKey key) async {
    final location = await getSaveLocation(
      suggestedName: '${key.name.replaceAll(' ', '_')}.pub',
    );
    if (location == null) return;
    await XFile.fromData(
      Uint8List.fromList(utf8.encode('${key.publicKey}\n')),
      mimeType: 'text/plain',
    ).saveTo(location.path);
    if (context.mounted) showWgToast(context, 'Saved ${location.path}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(keysProvider);
    final list = keys.value;
    Widget? body;
    Widget? empty;
    if (list == null) {
      body = const WgSkeletonList(rows: 4, label: 'Loading keys');
    } else if (list.isEmpty) {
      empty = WgEmptyState(
        icon: WgIcons.key,
        title: 'No keys yet',
        body: 'Keys sign you in without a password. Generate a new one here, or bring an existing private key.',
        action: WgButton.primary(
          label: 'Generate key',
          icon: WgIcons.plus,
          onPressed: () => unawaited(_showGenerate(context)),
        ),
        secondary: WgButton.ghost(
          label: 'Import key',
          onPressed: () => unawaited(_showImport(context)),
        ),
      );
    } else {
      body = Column(
        children: [
          for (final key in list)
            WgListRow(
              title: key.name,
              subtitle: key.fingerprint,
              meta:
                  '${key.algorithm.label}${key.hasPassphrase ? ' · passphrase' : ''} · ${Format.time(key.createdAt)}',
              leading: const Icon(WgIcons.key),
              onPressed: () => unawaited(
                ClipboardGuard.copy(key.publicKey).then((_) {
                  if (context.mounted) {
                    showWgToast(
                      context,
                      'Copied the public key of ${key.name}',
                    );
                  }
                }),
              ),
              semanticLabel:
                  '${key.name}, ${key.algorithm.label}. Copy public key',
              trailing: WgMenuButton(
                icon: WgIcons.more,
                compact: true,
                label: 'More for ${key.name}',
                entries: () => [
                  WgMenuEntry(
                    label: 'Copy public key',
                    icon: WgIcons.copy,
                    onSelected: () =>
                        unawaited(ClipboardGuard.copy(key.publicKey)),
                  ),
                  WgMenuEntry(
                    label: 'Install on a host…',
                    icon: WgIcons.upload,
                    onSelected: () => unawaited(_install(context, ref, key)),
                  ),
                  if (!PlatformInfo.isWeb)
                    WgMenuEntry(
                      label: 'Save public key as…',
                      icon: WgIcons.export,
                      onSelected: () => unawaited(_export(context, key)),
                    ),
                  WgMenuEntry(
                    label: 'Rename',
                    icon: WgIcons.edit,
                    onSelected: () async {
                      final name = await showTextPrompt(
                        context,
                        title: 'Rename key',
                        label: 'Name',
                        initial: key.name,
                        confirm: 'Rename',
                      );
                      if (name != null) {
                        await ref.read(keysProvider.notifier).rename(key, name);
                      }
                    },
                  ),
                  const WgMenuEntry.divider(),
                  WgMenuEntry(
                    label: 'Delete',
                    icon: WgIcons.trash,
                    destructive: true,
                    onSelected: () async {
                      final ok = await showWgConfirm(
                        context,
                        title: 'Delete ${key.name}?',
                        message: 'The private key is erased from this device. Hosts that sign in with it will need another key or a password.',
                        confirmLabel: 'Delete key',
                        destructive: true,
                      );
                      if (ok) {
                        await ref.read(keysProvider.notifier).delete(key.id);
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return WgPage(
      title: 'Keys',
      subtitle: 'Private keys stay in the system keychain and never leave this device unless you export a backup with keys',
      actions: [
        if (list?.isNotEmpty ?? false) ...[
          WgButton(
            label: 'Import key',
            icon: WgIcons.import,
            onPressed: () => unawaited(_showImport(context)),
          ),
          WgButton.primary(
            label: 'Generate key',
            icon: WgIcons.plus,
            onPressed: () => unawaited(_showGenerate(context)),
          ),
        ],
      ],
      empty: empty,
      child: body,
    );
  }

  Future<void> _showGenerate(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _GenerateDialog(),
  );

  Future<void> _showImport(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ImportDialog(),
  );
}

class _GenerateDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends ConsumerState<_GenerateDialog> {
  final _name = TextEditingController(text: 'warpgate');
  final _passphrase = TextEditingController();
  KeyAlgorithm _algorithm = KeyAlgorithm.ed25519;
  int _bits = 3072;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final material = await KeyCodec.generate(
        algorithm: _algorithm,
        comment: _name.text.trim(),
        passphrase: _passphrase.text,
        rsaBits: _bits,
      );
      await ref
          .read(keysProvider.notifier)
          .add(
            name: _name.text.trim().isEmpty ? 'warpgate' : _name.text.trim(),
            material: material,
            passphrase: _passphrase.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: context.space.lg);
    return WgDialog(
      title: 'Generate key',
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: _busy ? 'Generating' : 'Generate',
          loading: _busy,
          onPressed: () => unawaited(_generate()),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            WgInlineMessage(tone: WgTone.negative, message: _error!),
            gap,
          ],
          WgTextField(controller: _name, label: 'Name', autofocus: true),
          gap,
          WgSegmented<KeyAlgorithm>(
            label: 'Type',
            value: _algorithm,
            onChanged: (value) => setState(() => _algorithm = value),
            segments: const [
              WgSegment(KeyAlgorithm.ed25519, 'Ed25519'),
              WgSegment(KeyAlgorithm.rsa, 'RSA'),
            ],
          ),
          SizedBox(height: context.space.xs),
          Text(
            _algorithm == KeyAlgorithm.ed25519
                ? 'Short, fast and supported by OpenSSH 6.5 and later. The right choice for most servers.'
                : 'For older servers and appliances that do not accept Ed25519. Generating can take a few seconds.',
            style: context.type.caption,
          ),
          if (_algorithm == KeyAlgorithm.rsa) ...[
            gap,
            WgSegmented<int>(
              label: 'Key size',
              value: _bits,
              onChanged: (value) => setState(() => _bits = value),
              segments: const [
                WgSegment(3072, '3072 bits'),
                WgSegment(4096, '4096 bits'),
              ],
            ),
          ],
          gap,
          WgTextField(
            controller: _passphrase,
            label: 'Passphrase',
            obscure: true,
            helper: 'Optional. Stored in the keychain so you are not asked on every connection.',
          ),
        ],
      ),
    );
  }
}

class _ImportDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  final _name = TextEditingController();
  final _pem = TextEditingController();
  final _passphrase = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _pem.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await openFile();
    if (file == null) return;
    final text = await file.readAsString();
    setState(() {
      _pem.text = text;
      if (_name.text.isEmpty) _name.text = file.name;
    });
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final material = KeyCodec.parse(_pem.text, passphrase: _passphrase.text);
      await ref
          .read(keysProvider.notifier)
          .add(
            name: _name.text.trim().isEmpty
                ? material.algorithm.label
                : _name.text.trim(),
            material: material,
            passphrase: _passphrase.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on KeyFormatException catch (error) {
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: context.space.lg);
    final encrypted = KeyCodec.needsPassphrase(_pem.text);
    return WgDialog(
      title: 'Import key',
      wide: true,
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: 'Import',
          loading: _busy,
          onPressed: _pem.text.trim().isEmpty
              ? null
              : () => unawaited(_import()),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            WgInlineMessage(tone: WgTone.negative, message: _error!),
            gap,
          ],
          WgTextField(
            controller: _name,
            label: 'Name',
            placeholder: 'id_ed25519',
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: Text(
                  'Private key',
                  style: context.type.label.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              if (!PlatformInfo.isWeb)
                WgButton.ghost(
                  label: 'Choose file',
                  icon: WgIcons.folderOpen,
                  onPressed: () => unawaited(_pick()),
                ),
            ],
          ),
          SizedBox(height: context.space.xs),
          WgTextField(
            controller: _pem,
            mono: true,
            maxLines: 8,
            minLines: 6,
            placeholder: '-----BEGIN OPENSSH PRIVATE KEY-----',
            onChanged: (_) => setState(() {}),
          ),
          if (encrypted) ...[
            gap,
            WgTextField(
              controller: _passphrase,
              label: 'Passphrase',
              obscure: true,
              helper: 'This key is protected.',
            ),
          ],
        ],
      ),
    );
  }
}
