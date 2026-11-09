import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:warpgate/design_system/design_system.dart';

SingleActivator hostSaveShortcut() => SingleActivator(
  LogicalKeyboardKey.enter,
  meta: WgShortcutLabel.usesCommandKey,
  control: !WgShortcutLabel.usesCommandKey,
);
