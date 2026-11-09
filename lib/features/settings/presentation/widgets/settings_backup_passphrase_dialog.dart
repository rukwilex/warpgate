import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';

class SettingsBackupPassphraseDialog extends StatefulWidget {
  const new({required this.export, super.key});

  final bool export;

  @override
  State<SettingsBackupPassphraseDialog> createState() =>
      _SettingsBackupPassphraseDialogState();
}

class _SettingsBackupPassphraseDialogState
    extends State<SettingsBackupPassphraseDialog> {
  final _passphrase = TextEditingController();
  bool _secrets = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.export &&
        _passphrase.text.length < SettingsLimits.passphraseMinLength) {
      setState(
        () => _error =
            'Use at least 8 characters. Without it the backup cannot be opened',
      );
      return;
    }
    Navigator.of(context)
        .pop((passphrase: _passphrase.text, secrets: _secrets));
  }

  @override
  Widget build(BuildContext context) => WgDialog(
    title: widget.export ? 'Export backup' : 'Restore backup',
    actions: [
      WgButton.ghost(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      WgButton.primary(
        label: widget.export ? 'Choose where to save' : 'Restore',
        onPressed: _submit,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WgTextField(
          controller: _passphrase,
          label: 'Passphrase',
          obscure: true,
          autofocus: true,
          error: _error,
          helper: widget.export
              ? 'Encrypts the file with AES-256-GCM. There is no way to recover it if you forget it.'
              : null,
          onSubmitted: (_) => _submit(),
        ),
        if (widget.export) ...[
          SizedBox(height: context.space.sm),
          WgCheckRow(
            label: 'Include private keys and saved passwords',
            value: _secrets,
            onChanged: (value) => setState(() => _secrets = value),
          ),
        ] else ...[
          SizedBox(height: context.space.sm),
          Text(
            'Restoring adds to and replaces matching items. Nothing is deleted.',
            style: context.type.caption,
          ),
        ],
      ],
    ),
  );
}
