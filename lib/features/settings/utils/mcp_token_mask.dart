import 'package:warpgate/features/settings/presentation/settings_constants.dart';

abstract final class McpTokenMask {
  static String mask(String token) {
    const visible = SettingsLimits.tokenVisibleChars;
    return token.length > SettingsLimits.tokenMaskMinLength
        ? '${token.substring(0, visible)}${'•' * SettingsLimits.tokenMaskDots}${token.substring(token.length - visible)}'
        : token;
  }
}
