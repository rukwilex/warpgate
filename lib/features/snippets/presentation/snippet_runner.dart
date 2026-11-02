import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/snippets/domain/snippet.dart';
import 'package:warpgate/features/snippets/presentation/snippets_controller.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

Future<void> showSnippetRunner(BuildContext context) async {
  final snippet = await showGeneralDialog<Snippet>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: context.colors.scrim,
    pageBuilder: (dialogContext, _, _) => WgFloatingPanel(
      child: Consumer(
        builder: (context, ref, _) {
          final snippets = ref.watch(snippetsProvider).value ?? const [];
          return WgSearchList<Snippet>(
            placeholder: 'Snippet',
            emptyTitle: snippets.isEmpty
                ? 'No snippets yet'
                : 'No snippets match',
            emptyBody: snippets.isEmpty
                ? 'Save commands you type often, with {{variables}} for the parts that change.'
                : null,
            emptyAction: snippets.isEmpty
                ? WgButton(
                    label: 'Add snippet',
                    icon: WgIcons.plus,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      GoRouter.of(context).go(Routes.snippets);
                    },
                  )
                : null,
            onCancel: () => Navigator.of(dialogContext).pop(),
            onSelected: (value) => Navigator.of(dialogContext).pop(value),
            items: (query) => [
              for (final snippet in snippets)
                if (snippet.name.toLowerCase().contains(query.toLowerCase()) ||
                    snippet.body.toLowerCase().contains(query.toLowerCase()))
                  WgSearchItem(
                    value: snippet,
                    title: snippet.name,
                    subtitle: snippet.body.split('\n').first,
                    leading: const Icon(WgIcons.snippet),
                  ),
            ],
          );
        },
      ),
    ),
  );
  if (snippet == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => SnippetRunDialog(snippet: snippet),
  );
}

class SnippetRunDialog extends ConsumerStatefulWidget {
  const new({required this.snippet, super.key});

  final Snippet snippet;

  @override
  ConsumerState<SnippetRunDialog> createState() => _SnippetRunDialogState();
}

class _SnippetRunDialogState extends ConsumerState<SnippetRunDialog> {
  late final Map<String, TextEditingController> _fields = {
    for (final variable in widget.snippet.variables)
      variable.name: TextEditingController(text: variable.fallback),
  };
  bool _pressEnter = true;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _rendered => widget.snippet.render({
    for (final MapEntry(:key, :value) in _fields.entries) key: value.text,
  });

  void _run() {
    final bench = ref.read(workbenchProvider);
    final sessions = ref.read(terminalSessionsProvider);
    final text = '$_rendered${_pressEnter ? '\r' : ''}';
    final targets = bench.broadcastPaneIds.length > 1
        ? bench.broadcastPaneIds
        : {?bench.activeTab?.focusedPaneId};
    sessions.broadcastText(text.replaceAll('\n', '\r'), paneIds: targets);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bench = ref.watch(workbenchProvider);
    final broadcast = bench.broadcastPaneIds.length > 1;
    final focused = bench.activeTab?.focusedPaneId;
    final hasTarget =
        broadcast ||
        (focused != null &&
            ref.read(terminalSessionsProvider)[focused] != null);
    return WgDialog(
      title: widget.snippet.name,
      wide: true,
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: broadcast
              ? 'Send to ${bench.broadcastPaneIds.length} panes'
              : 'Send to focused pane',
          onPressed: hasTarget ? _run : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final variable in widget.snippet.variables) ...[
            WgTextField(
              controller: _fields[variable.name],
              label: variable.name,
              mono: true,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: context.space.md),
          ],
          Text(
            'Will send',
            style: context.type.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
          SizedBox(height: context.space.xs),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.space.md),
            decoration: BoxDecoration(
              color: context.colors.canvasDeep,
              borderRadius: context.radii.mdAll,
              border: Border.all(color: context.colors.hairline),
            ),
            child: SelectableText(_rendered, style: context.type.mono),
          ),
          SizedBox(height: context.space.sm),
          WgCheckRow(
            label: 'Press Enter after sending',
            value: _pressEnter,
            onChanged: (value) => setState(() => _pressEnter = value),
          ),
          if (!hasTarget)
            Padding(
              padding: EdgeInsets.only(top: context.space.sm),
              child: const WgInlineMessage(
                tone: WgTone.caution,
                message: 'Focus a terminal pane or turn on broadcast first.',
              ),
            ),
        ],
      ),
    );
  }
}
