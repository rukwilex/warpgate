import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PaletteMode { commands, switcher }

final paletteProvider = NotifierProvider<PaletteController, PaletteMode?>(
  PaletteController.new,
);

class PaletteController extends Notifier<PaletteMode?> {
  @override
  PaletteMode? build() => null;

  void open(PaletteMode value) {
    if (state != value) state = value;
  }

  void close() => state = null;

  void toggle(PaletteMode mode) => state = state == mode ? null : mode;
}

final shortcutsSuspendedProvider = NotifierProvider<ShortcutSuspension, int>(
  ShortcutSuspension.new,
);

class ShortcutSuspension extends Notifier<int> {
  @override
  int build() => 0;

  void suspend() => state += 1;

  void resume() => state = (state - 1).clamp(0, 1 << 20);
}
