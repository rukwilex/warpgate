part of 'file_browser.dart';

extension _FileBrowserLoading on _FileBrowserState {
  Future<void> _open(SftpSide side) async {
    final generation = ++_generation;
    _update(() {
      _loading = true;
      _error = null;
      _entries = null;
      _selected.clear();
    });
    try {
      final endpoint = await ref
          .read(endpointResolverProvider)
          .resolve(side.hostId);
      final settings = ref.read(settingsProvider);
      final fallback = side.isLocal
          ? (settings.defaultLocalPath ?? '~')
          : settings.defaultRemotePath;
      final link = widget.link;
      final followed = link != null && link.follow ? link.cwd.value : null;
      final path = await endpoint.resolve(followed ?? side.path ?? fallback);
      if (generation != _generation) return;
      _endpoint = endpoint;
      await _list(path);
    } on Object catch (error) {
      if (generation != _generation || !mounted) return;
      _update(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _list(String path, {bool remember = true}) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final generation = ++_generation;
    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      final resolved = await endpoint.resolve(path);
      final entries = await endpoint.list(resolved);
      if (generation != _generation || !mounted) return;
      final changed = resolved != _path;
      _update(() {
        _path = resolved;
        _entries = entries;
        _loading = false;
        if (changed) {
          _selected.reset();
        } else {
          _selected.retainIn(entries);
        }
      });
      if (changed && _scroll.hasClients) _scroll.jumpTo(0);
      if (remember) {
        ref.read(filePlacesProvider.notifier).visit(_hostId, resolved);
        widget.onSideChanged(SftpSide(hostId: _hostId, path: resolved));
      }
    } on Object catch (error) {
      if (generation != _generation || !mounted) return;
      if (!widget.side.isLocal) {
        ref.read(endpointResolverProvider).invalidate(_hostId!);
      }
      _update(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _goTo(String path) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final resolved = await endpoint.resolve(path);
    final entry = await endpoint.stat(resolved);
    if (!mounted) return;
    if (entry != null && !entry.isDirectory) {
      await _list(endpoint.paths.dirname(resolved));
      if (!mounted) return;
      _update(() => _selected.only(resolved));
      final index = _visible.indexWhere((item) => item.path == resolved);
      if (index >= 0) _reveal(index);
      return;
    }
    await _list(resolved);
  }

  Future<void> _refresh() async {
    if (_endpoint == null) {
      await _open(widget.side);
    } else if (_path != null) {
      await _list(_path!, remember: false);
    }
  }
}
