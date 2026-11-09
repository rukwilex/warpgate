import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/features/shell/presentation/shell_destinations.dart';

String shellSection(String location) {
  if (location == Routes.workbench) return Routes.workbench;
  for (final destination in shellDestinations) {
    if (destination.route != Routes.workbench &&
        location.startsWith(destination.route)) {
      return destination.route;
    }
  }
  return Routes.workbench;
}
