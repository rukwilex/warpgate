import 'package:flutter/foundation.dart';

abstract final class PlatformInfo {
  static bool get isWeb => kIsWeb;

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static bool get supportsLocalTerminal => isDesktop;

  static bool get supportsSshConfigImport => isDesktop;

  static bool get isApple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
