import 'package:warpgate/features/settings/presentation/settings_constants.dart';

abstract final class McpPortParsing {
  static int parse(String text, {required int fallback}) =>
      int.tryParse(text)?.clamp(SettingsLimits.portMin, SettingsLimits.portMax) ??
      fallback;
}
