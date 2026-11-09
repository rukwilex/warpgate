part of 'file_browser.dart';

extension _FileBrowserContent on _FileBrowserState {
  Widget _content(BuildContext context, List<FileEntry> visible, String label) {
    final error = _error;
    if (error != null) {
      final message = error is FileOperationException
          ? error.message
          : SshErrorText.describe(error);
      final denied = message.toLowerCase().contains('permission');
      final offline = !denied && _hostId != null;
      return WgEmptyState(
        icon: denied
            ? WgIcons.lock
            : offline
            ? WgIcons.offline
            : WgIcons.error,
        title: denied ? 'Permission denied' : 'Could not open this folder',
        body: denied
            ? 'Your account on $label cannot read ${_path ?? 'this folder'}. Pick another folder or change its permissions.'
            : message,
        action: WgButton(
          label: 'Try again',
          icon: WgIcons.retry,
          onPressed: () => unawaited(_refresh()),
        ),
        secondary: _path == null
            ? null
            : WgButton.ghost(label: 'Go up', onPressed: _up),
      );
    }
    if (_entries == null) {
      return const WgSkeletonList(
        rows: FileBrowserConstants.folderSkeletonRows,
        label: 'Loading folder',
      );
    }
    if (visible.isEmpty) {
      return Stack(
        children: [
          GestureDetector(
            excludeFromSemantics: true,
            onSecondaryTapDown: (details) =>
                _menu(details.globalPosition, null),
            child: WgEmptyState(
              icon: WgIcons.folderOpen,
              title: _filter.isNotEmpty
                  ? 'Nothing matches "$_filter"'
                  : 'This folder is empty',
              body: _filter.isNotEmpty
                  ? 'Clear the filter to see everything here.'
                  : PlatformInfo.isDesktop
                  ? 'Drop files here, or paste with ${PlatformInfo.isApple ? 'Cmd' : 'Ctrl'}+V.'
                  : 'Upload files or copy them in from another pane.',
            ),
          ),
          if (_loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: WgProgressBar(label: 'Refreshing'),
            ),
        ],
      );
    }
    final widths = ref.watch(
      settingsProvider.select((settings) => settings.fileColumnWidths),
    );
    final clip = ref.watch(fileClipboardProvider);
    final cutPaths = clip != null && clip.cut && clip.hostId == _hostId
        ? {for (final entry in clip.entries) entry.path}
        : const <String>{};
    final list = _view == ViewMode.list
        ? FileColumnsView(
            entries: visible,
            selected: _selected.paths,
            focusedPath: _selected.anchor,
            sort: _sort,
            ascending: _ascending,
            onSort: (key) => _update(() {
              if (_sort == key) {
                _ascending = !_ascending;
              } else {
                _sort = key;
                _ascending = true;
              }
            }),
            widths: widths,
            onResize: (column, width) =>
                ref.read(settingsProvider.notifier).update({
                  'fileColumnWidths': {...widths, column.name: width},
                }),
            onTap: (entry) => PlatformInfo.isMobile
                ? _activateOrSelect(entry)
                : _tap(entry, visible),
            onOpen: _activate,
            onMenu: _menu,
            wrap: _wrap,
            scroll: _scroll,
            dropFolder: _dropFolder,
            cutPaths: cutPaths,
          )
        : _grid(visible, cutPaths);
    return Stack(
      children: [
        GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: (details) => _menu(details.globalPosition, null),
          child: list,
        ),
        if (_loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: WgProgressBar(label: 'Refreshing'),
          ),
      ],
    );
  }

  Widget _wrap(FileEntry entry, Widget row) {
    final payload = FileDragPayload(
      hostId: _hostId,
      entries: _selected.contains(entry.path) ? _selection : [entry],
      sourcePaneKey: widget.paneKey,
    );
    final hints = ref.read(dropHintProvider.notifier);
    final feedback = FileDragFeedback(payload: payload);
    var child = row;
    if (entry.isDirectory) {
      child = FileDropTarget(
        hostId: _hostId,
        hostLabel: _hostLabel,
        folder: entry.name,
        onDrop: (payload, {required move}) {
          _update(() => _dropFolder = null);
          unawaited(_deliver(payload, entry.path, move: move));
        },
        builder: (context, {required active}) {
          if (active && _dropFolder != entry.path) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _update(() => _dropFolder = entry.path);
            });
          } else if (!active && _dropFolder == entry.path) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _update(() => _dropFolder = null);
            });
          }
          return row;
        },
      );
    }
    void ended() => hints.clear();
    return PlatformInfo.isMobile
        ? LongPressDraggable<FileDragPayload>(
            data: payload,
            feedback: feedback,
            onDragEnd: (_) => ended(),
            child: child,
          )
        : Draggable<FileDragPayload>(
            data: payload,
            feedback: feedback,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedbackOffset: Offset(context.space.lg, context.space.lg),
            onDragEnd: (_) => ended(),
            child: child,
          );
  }

  Widget _grid(List<FileEntry> visible, Set<String> cutPaths) {
    final colors = context.colors;
    return GridView.builder(
      controller: _scroll,
      padding: EdgeInsets.all(context.space.sm),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: context.sizes.gridTile,
        mainAxisSpacing: context.space.xs,
        crossAxisSpacing: context.space.xs,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final entry = visible[index];
        final selected = _selected.contains(entry.path);
        final cut = cutPaths.contains(entry.path);
        return _wrap(
          entry,
          WgPressable(
            semanticLabel:
                '${entry.isDirectory ? 'Folder' : 'File'} ${entry.name}',
            selected: selected,
            onPressed: () => _tap(entry, visible),
            onSecondaryTapDown: (details) =>
                _menu(details.globalPosition, entry),
            builder: (context, state) => Container(
              padding: EdgeInsets.all(context.space.sm),
              decoration: BoxDecoration(
                color: _dropFolder == entry.path
                    ? colors.accentWash
                    : selected
                    ? colors.pressed
                    : state.highlighted
                    ? colors.raised
                    : colors.transparent,
                borderRadius: context.radii.mdAll,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    fileIcon(entry),
                    size: context.sizes.iconLarge,
                    color: cut ? colors.textMuted : colors.textSecondary,
                  ),
                  SizedBox(height: context.space.sm),
                  Text(
                    entry.name,
                    maxLines: FileBrowserConstants.gridNameLines,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      color: cut ? colors.textMuted : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
