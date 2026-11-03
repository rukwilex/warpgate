import 'dart:io';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/hosts/data/hosts_service.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

@immutable
class PathRef {
  const new(this.path, {this.host});

  factory parse(String value, {bool? windows}) {
    final isWindows = windows ?? Platform.isWindows;
    if (value.startsWith('/') ||
        value.startsWith('./') ||
        value.startsWith('../') ||
        value.startsWith('~') ||
        value.startsWith(r'.\') ||
        value.startsWith(r'..\')) {
      return PathRef(value);
    }
    if (isWindows && RegExp(r'^[A-Za-z]:([\\/]|$)').hasMatch(value)) {
      return PathRef(value);
    }
    final colon = _hostColon(value);
    if (colon < 0) return PathRef(value);
    final path = value.substring(colon + 1);
    return PathRef(path.isEmpty ? '~' : path, host: value.substring(0, colon));
  }

  static int _hostColon(String value) {
    final slash = value.indexOf('/');
    final bracket = value.indexOf('[');
    if (bracket == 0 || (bracket > 0 && value[bracket - 1] == '@')) {
      final close = value.indexOf(']');
      if (close < 0) return -1;
      final colon = value.indexOf(':', close);
      if (colon < 0) return -1;
      final next = value.indexOf(':', colon + 1);
      return next < 0 ? colon : next;
    }
    final first = value.indexOf(':');
    if (first < 0 || (slash >= 0 && slash < first)) return -1;
    final second = value.indexOf(':', first + 1);
    final digits = second > 0 && RegExp(r'^\d+$').hasMatch(
      value.substring(first + 1, second),
    );
    if (digits && value.substring(0, first).contains('@')) return second;
    return first;
  }

  final String path;
  final String? host;

  bool get isRemote => host != null;

  @override
  String toString() => host == null ? path : '$host:$path';
}

abstract final class HostTargets {
  static const adHocPrefix = 'adhoc:';

  static ({String user, String address, int port})? parseEndpoint(
    String value,
  ) {
    final match = RegExp(
      r'^(?:([^@\s]+)@)?(\[[^\]]+\]|[^:\s\[\]]+)(?::(\d+))?$',
    ).firstMatch(value);
    if (match == null) return null;
    final user = match.group(1);
    if (user == null && match.group(3) == null) return null;
    final address = match.group(2)!.replaceAll(RegExp(r'[\[\]]'), '');
    final port = int.parse(match.group(3) ?? '22');
    if (port < 1 || port > 65535) return null;
    return (
      user: user ?? Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? 'root',
      address: address,
      port: port,
    );
  }

  static Host? find(HostsCatalog catalog, String reference) {
    final exact =
        catalog.host(reference) ??
        catalog.hosts.firstWhereOrNull((host) => host.label == reference);
    if (exact != null) return exact;
    final folded = reference.toLowerCase();
    final byLabel = catalog.hosts
        .where((host) => host.label.toLowerCase() == folded)
        .toList();
    if (byLabel.length == 1) return byLabel.single;
    final byPrefix = catalog.hosts
        .where((host) => host.id.startsWith(reference))
        .toList();
    return byPrefix.length == 1 && reference.length >= 4 ? byPrefix.single : null;
  }

  static Host resolve(HostsCatalog catalog, String reference) {
    final found = find(catalog, reference);
    if (found != null) return found;
    final endpoint = parseEndpoint(reference);
    if (endpoint != null) {
      final saved = catalog.hosts.firstWhereOrNull(
        (host) =>
            host.address == endpoint.address &&
            host.port == endpoint.port &&
            host.username == endpoint.user,
      );
      return saved ??
          Host(
            id: '$adHocPrefix${endpoint.user}@${endpoint.address}:${endpoint.port}',
            label: reference,
            address: endpoint.address,
            port: endpoint.port,
            username: endpoint.user,
            auth: AuthMethod.agent,
          );
    }
    throw ActionFailure(
      'No host called "$reference"',
      kind: ExitKind.notFound,
      hint: suggestion(catalog, reference) ?? 'Run warpgate hosts list to see saved hosts',
    );
  }

  static String? suggestion(HostsCatalog catalog, String reference) {
    final folded = reference.toLowerCase();
    final close = catalog.hosts
        .where((host) => host.label.toLowerCase().contains(folded))
        .map((host) => host.label)
        .take(3)
        .toList();
    return close.isEmpty ? null : 'Did you mean ${close.join(', ')}?';
  }

  static HostGroup group(HostsCatalog catalog, String reference) {
    final name = reference.startsWith('@') ? reference.substring(1) : reference;
    final found =
        catalog.group(name) ??
        catalog.groups.firstWhereOrNull(
          (group) => group.name.toLowerCase() == name.toLowerCase(),
        );
    if (found != null) return found;
    throw ActionFailure(
      'No group called "$name"',
      kind: ExitKind.notFound,
      hint: 'Run warpgate groups list to see groups',
    );
  }

  static List<Host> resolveMany(HostsCatalog catalog, String targets) {
    final hosts = <String, Host>{};
    for (final part in targets.split(',').map((item) => item.trim())) {
      if (part.isEmpty) continue;
      if (part.startsWith('@')) {
        final group = HostTargets.group(catalog, part);
        final members = catalog.inGroup(group.id);
        if (members.isEmpty) {
          throw ActionFailure(
            'Group "${group.name}" has no hosts',
            kind: ExitKind.notFound,
          );
        }
        for (final host in members) {
          hosts[host.id] = host;
        }
      } else {
        final host = resolve(catalog, part);
        hosts[host.id] = host;
      }
    }
    if (hosts.isEmpty) {
      throw const ActionFailure('Name at least one host', kind: ExitKind.usage);
    }
    return hosts.values.toList();
  }
}
