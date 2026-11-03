import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/snippets/presentation/snippet_runner.dart';
import 'package:warpgate/features/snippets/presentation/snippets_controller.dart';
import 'package:warpgate_core/features/snippets/domain/snippet.dart';

class SnippetsScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _edit(BuildContext context, [Snippet? snippet]) =>
      showDialog<void>(
        context: context,
        builder: (_) => _SnippetEditor(snippet: snippet),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snippets = ref.watch(snippetsProvider).value;
    final keys = ref.watch(shortcutMapProvider);
    return WgPage(
      title: 'Snippets',
      subtitle: 'Commands with {{variables}}. Send one to the focused pane, or to every pane in a broadcast',
      actions: [
        if (snippets?.isNotEmpty ?? false) ...[
          WgButton(
            label: 'Run snippet',
            icon: WgIcons.play,
            shortcut: keys['snippets.run'],
            onPressed: () => unawaited(showSnippetRunner(context)),
          ),
          WgButton.primary(
            label: 'Add snippet',
            icon: WgIcons.plus,
            onPressed: () => unawaited(_edit(context)),
          ),
        ],
      ],
      empty: snippets != null && snippets.isEmpty
          ? WgEmptyState(
              icon: WgIcons.snippet,
              title: 'No snippets yet',
              body: 'Save commands you run often. Write {{name}} for a part that changes, or {{name|default}} to prefill it.',
              action: WgButton.primary(
                label: 'Add snippet',
                icon: WgIcons.plus,
                onPressed: () => unawaited(_edit(context)),
              ),
            )
          : null,
      child: snippets == null
          ? const WgSkeletonList(rows: 4)
          : snippets.isEmpty
          ? null
          : Column(
              children: [
                for (final snippet in snippets)
                  WgListRow(
                    title: snippet.name,
                    subtitle: snippet.body.split('\n').first,
                    meta: snippet.variables.isEmpty
                        ? null
                        : snippet.variables.map((v) => v.name).join(', '),
                    leading: const Icon(WgIcons.snippet),
                    onPressed: () => unawaited(
                      showDialog<void>(
                        context: context,
                        builder: (_) => SnippetRunDialog(snippet: snippet),
                      ),
                    ),
                    trailing: WgMenuButton(
                      icon: WgIcons.more,
                      compact: true,
                      label: 'More for ${snippet.name}',
                      entries: () => [
                        WgMenuEntry(
                          label: 'Edit',
                          icon: WgIcons.edit,
                          onSelected: () => unawaited(_edit(context, snippet)),
                        ),
                        WgMenuEntry(
                          label: 'Delete',
                          icon: WgIcons.trash,
                          destructive: true,
                          onSelected: () => unawaited(
                            ref
                                .read(snippetsProvider.notifier)
                                .delete(snippet.id),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SnippetEditor extends ConsumerStatefulWidget {
  const new({this.snippet});

  final Snippet? snippet;

  @override
  ConsumerState<_SnippetEditor> createState() => _SnippetEditorState();
}

class _SnippetEditorState extends ConsumerState<_SnippetEditor> {
  late final _name = TextEditingController(text: widget.snippet?.name);
  late final _body = TextEditingController(text: widget.snippet?.body);

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = Snippet(id: '', name: '', body: _body.text);
    final valid = _name.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;
    return WgDialog(
      title: widget.snippet == null ? 'Add snippet' : 'Edit snippet',
      wide: true,
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: 'Save',
          onPressed: valid
              ? () async {
                  await ref
                      .read(snippetsProvider.notifier)
                      .save(
                        name: _name.text,
                        body: _body.text,
                        id: widget.snippet?.id,
                      );
                  if (context.mounted) Navigator.of(context).pop();
                }
              : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WgTextField(
            controller: _name,
            label: 'Name',
            placeholder: 'Restart service',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.space.lg),
          WgTextField(
            controller: _body,
            label: 'Command',
            mono: true,
            minLines: 3,
            maxLines: 10,
            placeholder: 'sudo systemctl restart {{service|nginx}}',
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.space.sm),
          Text(
            preview.variables.isEmpty
                ? 'No variables'
                : 'Variables: ${preview.variables.map((v) => v.fallback == null ? v.name : '${v.name} = ${v.fallback}').join(', ')}',
            style: context.type.monoSmall.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
