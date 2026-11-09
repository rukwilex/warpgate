import 'package:flutter/widgets.dart';
import 'package:warpgate/design_system/design_system.dart';

enum ShellLayout { phone, tablet, desktop }

ShellLayout shellLayoutOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < WgBreakpoints.medium) return ShellLayout.phone;
  if (width < WgBreakpoints.expanded) return ShellLayout.tablet;
  return ShellLayout.desktop;
}
