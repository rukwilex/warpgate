import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';

class SettingsPinSetupDialog extends StatefulWidget {
  const new({super.key});

  @override
  State<SettingsPinSetupDialog> createState() => _SettingsPinSetupDialogState();
}

class _SettingsPinSetupDialogState extends State<SettingsPinSetupDialog> {
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  void _save() {
    if (_pin.text.length < SettingsLimits.pinMinLength) {
      setState(() => _error = 'Use at least 4 digits');
    } else if (_pin.text != _again.text) {
      setState(() => _error = 'The two PINs are different');
    } else {
      Navigator.of(context).pop(_pin.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(SettingsLimits.pinMaxLength),
    ];
    return WgDialog(
      title: 'Set a PIN',
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(label: 'Set PIN', onPressed: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WgTextField(
            controller: _pin,
            label: 'PIN',
            obscure: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
          ),
          SizedBox(height: context.space.lg),
          WgTextField(
            controller: _again,
            label: 'Repeat PIN',
            obscure: true,
            error: _error,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}
