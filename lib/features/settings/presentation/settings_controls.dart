import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';

class SettingsControls {
  const new(this.ref);

  final WidgetRef ref;

  void set(Map<String, Object?> changes) =>
      ref.read(settingsProvider.notifier).update(changes);

  Widget toggle(String key, String label, {required bool value}) => WgSwitch(
    value: value,
    label: label,
    onChanged: (next) => set({key: next}),
  );

  Widget segmented<T>(
    T value,
    List<(T, String)> options,
    ValueChanged<T> onChanged,
    String label,
  ) => WgSegmented<T>(
    label: label,
    value: value,
    onChanged: onChanged,
    segments: [for (final (v, text) in options) WgSegment(v, text)],
  );
}
