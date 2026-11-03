import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/data/direct_transfer.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

@immutable
class FileDragPayload {
  const new({
    required this.hostId,
    required this.entries,
    required this.sourcePaneKey,
  });

  final String? hostId;
  final List<FileEntry> entries;
  final String sourcePaneKey;
}

abstract final class TransferActions {
  static Future<int> copy(
    BuildContext context,
    WidgetRef ref, {
    required String? fromHostId,
    required List<FileEntry> entries,
    required String? toHostId,
    required String toDirectory,
    required String Function(String directory, String name) join,
    bool move = false,
  }) async {
    if (entries.isEmpty) return 0;
    var mode = TransferMode.stream;
    final hostToHost =
        fromHostId != null && toHostId != null && fromHostId != toHostId;
    if (!move && hostToHost && ref.read(settingsProvider).offerDirectMode) {
      final chosen = await showDialog<TransferMode>(
        context: context,
        builder: (_) => _ModeDialog(
          fromHostId: fromHostId,
          toHostId: toHostId,
          entries: entries,
        ),
      );
      if (chosen == null) return 0;
      mode = chosen;
    }
    final queue = ref.read(transferQueueProvider.notifier);
    for (final entry in entries) {
      queue.enqueue(
        source: TransferRef(hostId: fromHostId, path: entry.path),
        target: TransferRef(
          hostId: toHostId,
          path: join(toDirectory, entry.name),
        ),
        name: entry.name,
        isDirectory: entry.isDirectory,
        mode: mode,
        move: move,
      );
    }
    return entries.length;
  }
}

class _ModeDialog extends ConsumerStatefulWidget {
  const new({
    required this.fromHostId,
    required this.toHostId,
    required this.entries,
  });

  final String fromHostId;
  final String toHostId;
  final List<FileEntry> entries;

  @override
  ConsumerState<_ModeDialog> createState() => _ModeDialogState();
}

class _ModeDialogState extends ConsumerState<_ModeDialog> {
  TransferMode _mode = TransferMode.stream;
  DirectProbe? _probe;
  bool _probing = false;

  Future<void> _check() async {
    final catalog = ref.read(hostsProvider).value;
    final source = catalog?.host(widget.fromHostId);
    final target = catalog?.host(widget.toHostId);
    if (source == null || target == null) return;
    setState(() => _probing = true);
    final probe = await DirectTransfer(ref.read(connectionPoolProvider))
        .probe(source, target);
    if (!mounted) return;
    setState(() {
      _probe = probe;
      _probing = false;
      if (probe.reachable) _mode = TransferMode.direct;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(hostsProvider).value;
    final source = catalog?.host(widget.fromHostId)?.label ?? 'source';
    final target = catalog?.host(widget.toHostId)?.label ?? 'target';
    final count = widget.entries.length;
    final bytes = widget.entries.fold<int>(0, (sum, entry) => sum + entry.size);
    final what = count == 1
        ? widget.entries.first.name
        : Format.plural(count, 'item');
    return WgDialog(
      title: 'Copy $what to $target',
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: 'Copy',
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(_mode),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'From $source${bytes > 0 ? ', ${Format.bytes(bytes)} in files' : ''}.',
            style: context.type.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          SizedBox(height: context.space.lg),
          RadioGroup<TransferMode>(
            groupValue: _mode,
            onChanged: (value) => setState(() => _mode = value ?? _mode),
            child: Column(
              children: [
                RadioListTile<TransferMode>(
                  value: TransferMode.stream,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Through Warpgate', style: context.type.body),
                  subtitle: Text(
                    'Streams through this device without saving a copy here. Works between any two hosts.',
                    style: context.type.caption,
                  ),
                ),
                RadioListTile<TransferMode>(
                  value: TransferMode.direct,
                  enabled: _probe?.reachable ?? false,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Directly from $source',
                    style: context.type.body,
                  ),
                  subtitle: Text(
                    _probe == null
                        ? 'Runs rsync or scp on $source. Faster for large data, if $source can sign in to $target on its own.'
                        : _probe!.reachable
                        ? '$source can reach $target. Uses ${_probe!.tool!.name}.'
                        : _probe!.reason ?? 'Not available',
                    style: context.type.caption,
                  ),
                ),
              ],
            ),
          ),
          if (_probe == null)
            Padding(
              padding: EdgeInsets.only(top: context.space.sm),
              child: WgButton(
                label: _probing ? 'Checking' : 'Check direct connection',
                loading: _probing,
                icon: WgIcons.plug,
                onPressed: _probing ? null : () => unawaited(_check()),
              ),
            ),
        ],
      ),
    );
  }
}
