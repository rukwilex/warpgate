import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/multi_exec/domain/multi_exec_run.dart';
import 'package:warpgate/features/multi_exec/presentation/multi_exec_controller.dart';

class MultiExecScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<MultiExecScreen> createState() => _MultiExecScreenState();
}

class _MultiExecScreenState extends ConsumerState<MultiExecScreen> {
  final _command = TextEditingController();
  final _timeout = TextEditingController(text: '60');
  final Set<String> _hosts = {};
  RunFilter _filter = RunFilter.all;
  String? _runId;
  bool _running = false;

  @override
  void dispose() {
    _command.dispose();
    _timeout.dispose();
    super.dispose();
  }

  Future<void> _run([List<String>? only]) async {
    final command = _command.text.trim();
    final hosts = only ?? _hosts.toList();
    if (command.isEmpty || hosts.isEmpty) return;
    setState(() => _running = true);
    final future = ref
        .read(multiExecProvider.notifier)
        .run(
          command,
          hosts,
          timeout: Duration(
            seconds: int.tryParse(_timeout.text)?.clamp(1, 3600) ?? 60,
          ),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final latest = ref.read(multiExecProvider).firstOrNull;
      if (mounted && latest != null) setState(() => _runId = latest.id);
    });
    await future;
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(hostsProvider).value ?? const HostsCatalog();
    final runs = ref.watch(multiExecProvider);
    final run =
        runs.where((item) => item.id == _runId).firstOrNull ?? runs.firstOrNull;
    final space = context.space;
    final colors = context.colors;
    final runShortcut = SingleActivator(
      LogicalKeyboardKey.enter,
      meta: WgShortcutLabel.usesCommandKey,
      control: !WgShortcutLabel.usesCommandKey,
    );
    final canRun = !_running && _hosts.isNotEmpty;
    return WgPage(
      title: 'Run on many hosts',
      subtitle: 'Each host runs the command on its own exec channel. Your terminals are not touched',
      child: CallbackShortcuts(
        bindings: {runShortcut: () => unawaited(_run())},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WgTextField(
              controller: _command,
              label: 'Command',
              mono: true,
              minLines: 2,
              maxLines: 6,
              placeholder: 'uptime && df -h /',
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: space.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hosts · ${_hosts.length} selected',
                    style: context.type.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                WgButton.ghost(
                  label: _hosts.length == catalog.hosts.length
                      ? 'Select none'
                      : 'Select all',
                  onPressed: () => setState(() {
                    if (_hosts.length == catalog.hosts.length) {
                      _hosts.clear();
                    } else {
                      _hosts.addAll(catalog.hosts.map((host) => host.id));
                    }
                  }),
                ),
              ],
            ),
            SizedBox(height: space.xs),
            if (catalog.hosts.isEmpty)
              Text('Add hosts first.', style: context.type.caption)
            else
              Wrap(
                spacing: space.xs,
                runSpacing: space.xs,
                children: [
                  for (final group in catalog.groups)
                    if (catalog.inGroup(group.id).isNotEmpty)
                      _Chip(
                        label: group.name,
                        icon: WgIcons.group,
                        selected: catalog
                            .inGroup(group.id)
                            .every((host) => _hosts.contains(host.id)),
                        onPressed: () => setState(() {
                          final ids = catalog
                              .inGroup(group.id)
                              .map((host) => host.id);
                          if (ids.every(_hosts.contains)) {
                            _hosts.removeAll(ids);
                          } else {
                            _hosts.addAll(ids);
                          }
                        }),
                      ),
                  for (final host in catalog.hosts)
                    _Chip(
                      label: host.label,
                      selected: _hosts.contains(host.id),
                      onPressed: () => setState(() {
                        if (!_hosts.remove(host.id)) _hosts.add(host.id);
                      }),
                    ),
                ],
              ),
            SizedBox(height: space.lg),
            Row(
              children: [
                SizedBox(
                  width: context.sizes.fieldShort,
                  child: WgTextField(
                    controller: _timeout,
                    label: 'Timeout, s',
                    mono: true,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Spacer(),
                WgButton.primary(
                  label: _running
                      ? 'Running'
                      : 'Run on ${Format.plural(_hosts.length, 'host')}',
                  icon: WgIcons.play,
                  loading: _running,
                  shortcut: runShortcut,
                  onPressed: canRun && _command.text.trim().isNotEmpty
                      ? () => unawaited(_run())
                      : null,
                ),
              ],
            ),
            if (run != null) ...[
              SizedBox(height: space.xxl),
              _RunSummary(
                run: run,
                filter: _filter,
                onFilter: (value) => setState(() => _filter = value),
                onRerunFailed: run.failed == 0 || _running
                    ? null
                    : () {
                        _command.text = run.command;
                        unawaited(
                          _run([
                            for (final item in run.filtered(RunFilter.failed))
                              item.hostId,
                          ]),
                        );
                      },
              ),
              SizedBox(height: space.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      (constraints.maxWidth / context.sizes.resultCard)
                          .floor()
                          .clamp(1, 3);
                  final results = run.filtered(_filter);
                  if (results.isEmpty) {
                    return const WgEmptyState(title: 'No results in this view');
                  }
                  final width =
                      (constraints.maxWidth - space.sm * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: space.sm,
                    runSpacing: space.sm,
                    children: [
                      for (final result in results)
                        SizedBox(
                          width: width,
                          child: _ResultCard(
                            run: result,
                            label:
                                catalog.host(result.hostId)?.label ??
                                'Removed host',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ] else ...[
              SizedBox(height: space.huge),
              const WgEmptyState(
                icon: WgIcons.multiExec,
                title: 'Pick hosts and run a command',
                body: 'Results appear here as a grid with the exit code, duration and output of each host.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return WgPressable(
      semanticLabel: label,
      toggled: selected,
      onPressed: onPressed,
      borderRadius: context.radii.smAll,
      builder: (context, state) => Container(
        constraints: BoxConstraints(minHeight: context.sizes.control),
        padding: EdgeInsets.symmetric(horizontal: context.space.md),
        decoration: BoxDecoration(
          color: selected
              ? colors.accentWash
              : state.highlighted
              ? colors.raised
              : colors.transparent,
          borderRadius: context.radii.smAll,
          border: Border.all(
            color: selected ? colors.accent : colors.hairlineStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? WgIcons.check : (icon ?? WgIcons.server),
              size: context.sizes.icon,
              color: selected ? colors.accentInk : colors.textMuted,
            ),
            SizedBox(width: context.space.sm),
            Text(
              label,
              style: context.type.label.copyWith(
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunSummary extends StatelessWidget {
  const new({
    required this.run,
    required this.filter,
    required this.onFilter,
    required this.onRerunFailed,
  });

  final MultiExecRun run;
  final RunFilter filter;
  final ValueChanged<RunFilter> onFilter;
  final VoidCallback? onRerunFailed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.space.md,
      runSpacing: context.space.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          run.command,
          style: context.type.mono,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${run.succeeded} ok · ${run.failed} failed${run.pending > 0 ? ' · ${run.pending} running' : ''}',
          style: context.type.monoSmall,
        ),
        WgSegmented<RunFilter>(
          label: 'Show results',
          value: filter,
          onChanged: onFilter,
          segments: const [
            WgSegment(RunFilter.all, 'All'),
            WgSegment(RunFilter.failed, 'Failed'),
            WgSegment(RunFilter.succeeded, 'Succeeded'),
          ],
        ),
        if (onRerunFailed != null)
          WgButton(
            label: 'Run again on failed',
            icon: WgIcons.retry,
            onPressed: onRerunFailed,
          ),
      ],
    );
  }
}

class _ResultCard extends StatefulWidget {
  const new({required this.run, required this.label});

  final HostRun run;
  final String label;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final run = widget.run;
    final result = run.result;
    final dot = switch (run.state) {
      HostRunState.pending => WgDotState.idle,
      HostRunState.running => WgDotState.busy,
      HostRunState.succeeded => WgDotState.connected,
      HostRunState.failed => WgDotState.dropped,
    };
    final output = [
      if (result?.stdout.isNotEmpty ?? false) result!.stdout.trimRight(),
      if (result?.stderr.isNotEmpty ?? false) result!.stderr.trimRight(),
      ?result?.error,
      if (result?.timedOut ?? false) 'Timed out',
    ].join('\n');
    final status = switch (run.state) {
      HostRunState.pending => 'waiting',
      HostRunState.running => 'running',
      _ =>
        result?.exitCode == null ? 'no exit code' : 'exit ${result!.exitCode}',
    };
    return Container(
      padding: EdgeInsets.all(context.space.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radii.mdAll,
        border: Border.all(
          color: run.state == HostRunState.failed
              ? colors.line(colors.negative)
              : colors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WgStatusDot(state: dot, subject: widget.label),
              SizedBox(width: context.space.sm),
              Expanded(
                child: Text(
                  widget.label,
                  style: context.type.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                [
                  status,
                  if (result != null) Format.duration(result.duration),
                ].join(' · '),
                style: context.type.monoSmall.copyWith(
                  color: run.state == HostRunState.failed
                      ? colors.negative
                      : colors.textMuted,
                ),
              ),
            ],
          ),
          if (output.isNotEmpty) ...[
            SizedBox(height: context.space.sm),
            Container(
              padding: EdgeInsets.all(context.space.sm),
              decoration: BoxDecoration(
                color: colors.canvasDeep,
                borderRadius: context.radii.smAll,
              ),
              child: SelectableText(
                output,
                maxLines: _expanded ? null : 8,
                style: context.type.monoSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            if ('\n'.allMatches(output).length > 7)
              Align(
                alignment: Alignment.centerLeft,
                child: WgButton.ghost(
                  label: _expanded ? 'Show less' : 'Show all output',
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
