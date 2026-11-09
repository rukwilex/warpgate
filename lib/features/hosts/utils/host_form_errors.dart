import 'package:warpgate/features/hosts/presentation/hosts_constants.dart';

Map<String, String> hostFormErrors({
  required String address,
  required String user,
  required int? port,
  required bool missingKey,
  required bool cyclicJump,
}) => {
  if (address.isEmpty)
    'address': 'Enter an address, like 10.0.0.12 or db.example.com',
  if (user.isEmpty) 'user': 'Enter the user to sign in as',
  if (port == null ||
      port < HostsConstants.minPort ||
      port > HostsConstants.maxPort)
    'port': 'Use a port from 1 to 65535',
  if (missingKey) 'key': 'Pick a key, or add one in Keys',
  if (cyclicJump) 'jump': 'This jump host leads back to this host',
};
