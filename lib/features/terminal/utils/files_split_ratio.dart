import 'dart:math' as math;

import 'package:warpgate/features/terminal/presentation/terminal_constants.dart';

double clampFilesSplitRatio(
  double ratio, {
  required double available,
  required double terminalMin,
  required double filesPanelMin,
}) {
  if (available <= 0) return ratio;
  const limit = TerminalConstants.filesRatioLimit;
  final low = math.min(terminalMin / available, limit);
  final high = math.max(1 - filesPanelMin / available, limit);
  return ratio.clamp(low, high);
}
