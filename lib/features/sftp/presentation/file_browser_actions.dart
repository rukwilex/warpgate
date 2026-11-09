part of 'file_browser.dart';

extension _FileBrowserActions on _FileBrowserState {
  Future<void> _guard(Future<void> Function() action, String failure) async {
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        showWgToast(
          context,
          '$failure: ${error is FileOperationException ? error.message : error}',
        );
      }
    }
    await _refresh();
  }

  Future<void> _newFolder() async {
    final endpoint = _endpoint;
    final path = _path;
    if (endpoint == null || path == null) return;
    final name = await showTextPrompt(
      context,
      title: 'New folder',
      label: 'Name',
      confirm: 'Create folder',
    );
    if (name == null) return;
    await _guard(
      () => endpoint.createDirectory(endpoint.paths.join(path, name)),
      'Could not create the folder',
    );
  }

  Future<void> _rename(FileEntry entry) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final name = await showTextPrompt(
      context,
      title: 'Rename ${entry.name}',
      label: 'New name',
      initial: entry.name,
      confirm: 'Rename',
    );
    if (name == null || name == entry.name) return;
    await _guard(
      () => endpoint.rename(
        entry.path,
        endpoint.paths.join(endpoint.paths.dirname(entry.path), name),
      ),
      'Could not rename',
    );
  }

  Future<void> _move(List<FileEntry> entries) async {
    final endpoint = _endpoint;
    final path = _path;
    if (endpoint == null || path == null || entries.isEmpty) return;
    final target = await showTextPrompt(
      context,
      title: entries.length == 1
          ? 'Move ${entries.first.name}'
          : 'Move ${entries.length} items',
      label: 'Destination folder',
      initial: path,
      confirm: 'Move',
      mono: true,
    );
    if (target == null || target == path) return;
    await _guard(() async {
      final resolved = await endpoint.resolve(target);
      for (final entry in entries) {
        await endpoint.rename(
          entry.path,
          endpoint.paths.join(resolved, entry.name),
        );
      }
    }, 'Could not move');
  }

  Future<void> _delete(List<FileEntry> entries) async {
    final endpoint = _endpoint;
    if (endpoint == null || entries.isEmpty) return;
    final folders = entries.where((entry) => entry.isDirectory).length;
    final title = entries.length == 1
        ? 'Delete ${entries.first.name}?'
        : 'Delete ${entries.length} items?';
    final ok = await showWgConfirm(
      context,
      title: title,
      message: [
        'This removes them from ${endpoint.label} for good.',
        if (folders > 0) 'Folders are deleted with everything inside.',
      ].join(' '),
      confirmLabel: entries.length == 1
          ? 'Delete'
          : 'Delete ${entries.length} items',
      destructive: true,
    );
    if (!ok) return;
    await _guard(() async {
      for (final entry in entries) {
        if (entry.isDirectory && !entry.isLink) {
          await endpoint.deleteDirectory(entry.path);
        } else {
          await endpoint.deleteFile(entry.path);
        }
      }
    }, 'Could not delete');
  }

  Future<void> _chmod(FileEntry entry) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final mode = await showPermissionsDialog(context, entry);
    if (mode == null) return;
    await _guard(
      () => endpoint.setMode(entry.path, mode),
      'Could not change permissions',
    );
  }

  Future<void> _edit(FileEntry entry) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final saved = await showFileEditor(context, endpoint, entry);
    if (saved && mounted) {
      showWgToast(context, 'Saved ${entry.name}');
      await _refresh();
    }
  }

  Future<void> _deliver(
    FileDragPayload payload,
    String folder, {
    required bool move,
  }) async {
    try {
      final count = await FileDelivery.deliver(
        context,
        ref,
        fromHostId: payload.hostId,
        entries: payload.entries,
        toHostId: _hostId,
        toDirectory: folder,
        move: move,
      );
      if (!mounted || count == 0) return;
      final sameHost = payload.hostId == _hostId;
      showWgToast(
        context,
        move && sameHost
            ? 'Moved ${Format.plural(count, 'item')}'
            : '${move ? 'Moving' : 'Copying'} ${Format.plural(count, 'item')} to $_hostLabel. Progress is in Transfers',
      );
    } on Object catch (error) {
      if (mounted) {
        showWgToast(
          context,
          'Could not ${move ? 'move' : 'copy'}: ${error is FileOperationException ? error.message : error}',
        );
      }
    }
    await _refresh();
  }

  Future<void> _copyTo(List<FileEntry> entries, SftpSide target) async {
    final destination = await ref
        .read(endpointResolverProvider)
        .resolve(target.hostId);
    final dir = await destination.resolve(target.path ?? '~');
    if (!mounted) return;
    final count = await TransferActions.copy(
      context,
      ref,
      fromHostId: _hostId,
      entries: entries,
      toHostId: target.hostId,
      toDirectory: dir,
      join: destination.paths.join,
    );
    if (count > 0 && mounted) {
      showWgToast(context, 'Queued ${Format.plural(count, 'item')}');
    }
  }

  Future<void> _receiveOsFiles(List<String> paths, {String? folder}) async {
    final target = folder ?? _path;
    if (target == null) return;
    final local = await ref.read(endpointResolverProvider).resolve(null);
    final entries = <FileEntry>[];
    for (final path in paths) {
      final entry = await local.stat(path);
      if (entry != null) entries.add(entry);
    }
    if (entries.isEmpty || !mounted) return;
    await _deliver(
      FileDragPayload(
        hostId: null,
        entries: entries,
        sourcePaneKey: FileBrowserConstants.osDropSource,
      ),
      target,
      move: false,
    );
  }

  Future<void> _upload() async {
    final files = await openFiles();
    if (files.isEmpty) return;
    await _receiveOsFiles([for (final file in files) file.path]);
  }

  Future<void> _download(List<FileEntry> entries) async {
    final directory = await getDirectoryPath(
      confirmButtonText: 'Download here',
    );
    if (directory == null || !mounted) return;
    await _copyTo(entries, SftpSide(path: directory));
  }

  void _clip({required bool cut}) {
    final selection = _selection;
    if (selection.isEmpty) return;
    ref.read(fileClipboardProvider.notifier).put(_hostId, selection, cut: cut);
    showWgToast(
      context,
      '${Format.plural(selection.length, 'item')} ready to ${cut ? 'move' : 'copy'}. Paste in any files panel',
    );
  }

  Future<void> _paste() async {
    final clip = ref.read(fileClipboardProvider);
    final path = _path;
    if (clip == null || path == null) return;
    await _deliver(
      FileDragPayload(
        hostId: clip.hostId,
        entries: clip.entries,
        sourcePaneKey: FileBrowserConstants.clipboardSource,
      ),
      path,
      move: clip.cut,
    );
    if (clip.cut) ref.read(fileClipboardProvider.notifier).clear();
  }

  void _openTerminalHere(String path, {bool split = false}) {
    final link = widget.link;
    if (link != null && !split) {
      link.cdHere(path);
      return;
    }
    final bench = ref.read(workbenchProvider.notifier);
    if (_hostId == null) {
      if (PlatformInfo.supportsLocalTerminal) {
        bench.openPane(
          LocalTerminalContent(directory: path),
          placement: PanePlacement.splitDown,
        );
      }
      return;
    }
    bench.openPane(
      SshTerminalContent(hostId: _hostId!, directory: path),
      placement: PanePlacement.splitDown,
    );
  }

  Future<void> _pickEndpoint() async {
    final pick = await showEndpointPicker(context, title: 'Show files from');
    if (pick == null) return;
    widget.onSideChanged(SftpSide(hostId: pick.host?.id));
    if (pick.host?.id == _hostId) {
      unawaited(_open(SftpSide(hostId: pick.host?.id)));
    }
  }

  Future<void> _quickJump() async {
    final endpoint = _endpoint;
    final path = _path;
    if (endpoint == null || path == null) return;
    final places = ref.read(filePlacesProvider.notifier).of(_hostId);
    final subfolders = [
      for (final entry in _visible)
        if (entry.isDirectory) entry.path,
    ];
    final picked = await showQuickJump(
      context,
      favorites: places.favorites,
      recents: places.recents.where((item) => item != path).toList(),
      subfolders: subfolders,
      hostLabel: _hostLabel,
    );
    if (picked != null) unawaited(_list(picked));
  }

  void _toggleFavorite() {
    final path = _path;
    if (path == null) return;
    ref.read(filePlacesProvider.notifier).toggleFavorite(_hostId, path);
  }
}
