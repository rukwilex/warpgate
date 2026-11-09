import 'package:warpgate_core/features/hosts/domain/host.dart';

String hostRoute({
  required String label,
  required String jumpHostId,
  required Map<String, Host> byId,
}) => [
  for (final hop in HostChain.resolve(
    Host(
      id: '_',
      label: label.isEmpty ? 'this host' : label,
      address: '',
      username: '',
      jumpHostId: jumpHostId,
    ),
    byId,
  ))
    hop.label,
].join(' → ');
