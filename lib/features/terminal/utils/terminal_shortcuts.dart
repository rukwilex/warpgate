import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:warpgate/core/platform/platform_info.dart';

SingleActivator terminalCopyActivator() => PlatformInfo.isApple
    ? const SingleActivator(LogicalKeyboardKey.keyC, meta: true)
    : const SingleActivator(
        LogicalKeyboardKey.keyC,
        control: true,
        shift: true,
      );

SingleActivator terminalPasteActivator() => PlatformInfo.isApple
    ? const SingleActivator(LogicalKeyboardKey.keyV, meta: true)
    : const SingleActivator(
        LogicalKeyboardKey.keyV,
        control: true,
        shift: true,
      );
