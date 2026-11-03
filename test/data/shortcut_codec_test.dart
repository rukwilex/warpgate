import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/shortcuts/shortcut_codec.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

void main() {
  test('shortcut encode and decode round trip', () {
    const activator = SingleActivator(
      LogicalKeyboardKey.keyK,
      meta: true,
      shift: true,
    );
    final decoded = ShortcutCodec.decode(ShortcutCodec.encode(activator))!;
    expect(decoded.trigger, LogicalKeyboardKey.keyK);
    expect(decoded.meta, isTrue);
    expect(decoded.shift, isTrue);
    expect(decoded.control, isFalse);
    expect(ShortcutCodec.decode(''), isNull);
  });

  test('settings survive json and patching', () {
    const settings = AppSettings();
    final patched = settings.patch({
      'transferConcurrency': 5,
      'mcpEnabled': true,
      'themeMode': 'dark',
    });
    expect(patched.transferConcurrency, 5);
    expect(patched.mcpEnabled, isTrue);
    expect(patched.themeMode.name, 'dark');
    expect(
      AppSettings.fromJson(const {'accent': 'nonsense'}).accent,
      settings.accent,
    );
  });
}
