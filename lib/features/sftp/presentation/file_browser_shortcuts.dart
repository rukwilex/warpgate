import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:warpgate/core/platform/platform_info.dart';

class FileBrowserShortcuts {
  const new({required this.cut, required this.copy, required this.paste});

  factory of() {
    final apple = PlatformInfo.isApple;
    SingleActivator key(LogicalKeyboardKey key) =>
        SingleActivator(key, meta: apple, control: !apple);
    return FileBrowserShortcuts(
      cut: key(LogicalKeyboardKey.keyX),
      copy: key(LogicalKeyboardKey.keyC),
      paste: key(LogicalKeyboardKey.keyV),
    );
  }

  final SingleActivator cut;
  final SingleActivator copy;
  final SingleActivator paste;
}
