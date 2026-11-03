import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';

export 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';

final endpointResolverProvider = Provider<EndpointResolver>(
  (ref) => EndpointResolver(
    pool: ref.read(connectionPoolProvider),
    labelOf: (hostId) => ref.read(hostsProvider).value?.host(hostId)?.label,
    ready: () => ref.read(hostsProvider.future),
  ),
);
