part of 'file_browser.dart';

extension _FileBrowserMenu on _FileBrowserState {
  void _menu(Offset position, FileEntry? entry) {
    if (entry != null && !_selected.contains(entry.path)) {
      _update(() => _selected.only(entry.path));
    }
    final selection = _selection;
    final single = selection.length == 1 ? selection.first : null;
    final target = widget.copyTarget;
    final clip = ref.read(fileClipboardProvider);
    final keys = FileBrowserShortcuts.of();
    final folder = single?.isDirectory ?? false ? single!.path : _path;
    unawaited(
      showWgMenu(
        context,
        position: position,
        entries: [
          if (single != null && single.isDirectory)
            WgMenuEntry(
              label: 'Open',
              icon: WgIcons.folderOpen,
              onSelected: () => _activate(single),
            ),
          if (single != null && !single.isDirectory) ...[
            WgMenuEntry(
              label: 'Quick look',
              icon: WgIcons.eye,
              shortcut: const SingleActivator(LogicalKeyboardKey.space),
              onSelected: () => _activate(single),
            ),
            if (single.looksLikeText)
              WgMenuEntry(
                label: 'Edit',
                icon: WgIcons.edit,
                onSelected: () => unawaited(_edit(single)),
              ),
          ],
          if (selection.isNotEmpty) ...[
            WgMenuEntry(
              label: 'Cut',
              icon: WgIcons.cut,
              shortcut: keys.cut,
              onSelected: () => _clip(cut: true),
            ),
            WgMenuEntry(
              label: 'Copy',
              icon: WgIcons.copy,
              shortcut: keys.copy,
              onSelected: () => _clip(cut: false),
            ),
          ],
          if (clip != null)
            WgMenuEntry(
              label: clip.cut
                  ? 'Move ${Format.plural(clip.entries.length, 'item')} here'
                  : 'Paste ${Format.plural(clip.entries.length, 'item')}',
              icon: WgIcons.paste,
              shortcut: keys.paste,
              onSelected: () => unawaited(_paste()),
            ),
          if (selection.isNotEmpty && target != null)
            WgMenuEntry(
              label: 'Copy to ${widget.copyLabel ?? 'other side'}',
              icon: WgIcons.arrowRight,
              onSelected: () => unawaited(_copyTo(selection, target)),
            ),
          if (selection.isNotEmpty && !widget.side.isLocal)
            WgMenuEntry(
              label: 'Download to…',
              icon: WgIcons.download,
              onSelected: () => unawaited(_download(selection)),
            ),
          const WgMenuEntry.divider(),
          if (single != null)
            WgMenuEntry(
              label: 'Rename',
              icon: WgIcons.edit,
              shortcut: const SingleActivator(LogicalKeyboardKey.f2),
              onSelected: () => unawaited(_rename(single)),
            ),
          if (selection.isNotEmpty)
            WgMenuEntry(
              label: 'Move to…',
              icon: WgIcons.move,
              onSelected: () => unawaited(_move(selection)),
            ),
          if (single != null)
            WgMenuEntry(
              label: 'Permissions',
              icon: WgIcons.permissions,
              onSelected: () => unawaited(_chmod(single)),
            ),
          if (single != null)
            WgMenuEntry(
              label: 'Properties',
              icon: WgIcons.info,
              onSelected: () =>
                  unawaited(showProperties(context, _endpoint!, single)),
            ),
          WgMenuEntry(
            label: 'Copy path',
            icon: WgIcons.copy,
            onSelected: () => unawaited(
              Clipboard.setData(ClipboardData(text: single?.path ?? _path!)),
            ),
          ),
          if (folder != null) ...[
            WgMenuEntry(
              label: widget.link == null
                  ? 'Open terminal here'
                  : 'Change the terminal to this folder',
              icon: WgIcons.terminal,
              enabled:
                  !widget.side.isLocal || PlatformInfo.supportsLocalTerminal,
              onSelected: () => _openTerminalHere(folder),
            ),
            if (widget.link != null)
              WgMenuEntry(
                label: 'Open a new terminal here',
                icon: WgIcons.splitVertical,
                onSelected: () => _openTerminalHere(folder, split: true),
              ),
          ],
          const WgMenuEntry.divider(),
          WgMenuEntry(
            label: 'New folder',
            icon: WgIcons.folderPlus,
            onSelected: () => unawaited(_newFolder()),
          ),
          if (selection.isNotEmpty)
            WgMenuEntry(
              label: selection.length == 1
                  ? 'Delete'
                  : 'Delete ${selection.length} items',
              icon: WgIcons.trash,
              destructive: true,
              shortcut: const SingleActivator(LogicalKeyboardKey.delete),
              onSelected: () => unawaited(_delete(selection)),
            ),
        ],
      ),
    );
  }
}
