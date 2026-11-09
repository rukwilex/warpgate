import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/security/presentation/app_lock_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_pin_setup_dialog.dart';

class SettingsLockToggle extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(settingsProvider.select((s) => s.appLock));
    return WgSwitch(
      value: enabled,
      label: 'Lock Warpgate',
      onChanged: (value) async {
        final lock = ref.read(appLockProvider.notifier);
        if (!value) {
          await lock.clearPin();
          ref.read(settingsProvider.notifier).update({
            SettingsKeys.appLock: false,
          });
          return;
        }
        final pin = await showDialog<String>(
          context: context,
          builder: (_) => const SettingsPinSetupDialog(),
        );
        if (pin == null) return;
        await lock.setPin(pin);
        ref.read(settingsProvider.notifier).update({
          SettingsKeys.appLock: true,
        });
        lock.touch();
      },
    );
  }
}
