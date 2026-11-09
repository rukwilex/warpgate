part of 'file_browser.dart';

extension _FileBrowserInput on _FileBrowserState {
  void _tap(FileEntry entry, List<FileEntry> visible) {
    _focus.requestFocus();
    final now = DateTime.now();
    final keyboard = HardwareKeyboard.instance;
    final repeat = _taps.repeats(
      entry.path,
      now: now,
      modified:
          keyboard.isShiftPressed ||
          keyboard.isMetaPressed ||
          keyboard.isControlPressed,
    );
    if (repeat) {
      _activate(entry);
      return;
    }
    _update(() {
      if (keyboard.isShiftPressed &&
          _selected.anchor != null &&
          _selected.selectRange(visible, entry)) {
        return;
      }
      if (keyboard.isMetaPressed || keyboard.isControlPressed) {
        _selected
          ..toggle(entry.path)
          ..anchor = entry.path;
      } else {
        _selected.only(entry.path);
      }
    });
  }

  void _activate(FileEntry entry) {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    if (entry.isDirectory) {
      unawaited(_list(entry.path));
    } else if (entry.looksLikeImage || entry.looksLikeText) {
      unawaited(showFilePreview(context, endpoint, entry));
    }
  }

  void _activateOrSelect(FileEntry entry) {
    if (_selected.isNotEmpty) {
      _update(() => _selected.toggle(entry.path));
      return;
    }
    _activate(entry);
  }

  void _up() {
    final endpoint = _endpoint;
    final path = _path;
    if (endpoint == null || path == null) return;
    final parent = endpoint.paths.dirname(path);
    if (parent != path) unawaited(_list(parent));
  }

  void _select(List<FileEntry> visible, int index, {bool extend = false}) {
    if (visible.isEmpty) return;
    final next = index.clamp(0, visible.length - 1);
    final entry = visible[next];
    _update(() {
      if (extend && _selected.anchor != null) {
        _selected.extend(entry.path);
      } else {
        _selected.only(entry.path);
      }
    });
    _reveal(next);
  }

  void _reveal(int index) {
    if (!_scroll.hasClients || _view != ViewMode.list) return;
    final extent = context.sizes.rowCompact;
    final top = index * extent;
    final position = _scroll.position;
    var target = position.pixels;
    if (top < target) target = top;
    if (top + extent > target + position.viewportDimension) {
      target = top + extent - position.viewportDimension;
    }
    _scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
  }

  void _typeAhead(String character, List<FileEntry> visible) {
    final typed = _typeAheadBuffer.add(
      character,
      now: DateTime.now(),
      window: context.motion.typeAhead,
    );
    final index = visible.indexWhere(
      (entry) => entry.name.toLowerCase().startsWith(typed),
    );
    if (index >= 0) _select(visible, index);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final visible = _visible;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final primary = PlatformInfo.isApple
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
    final shift = keyboard.isShiftPressed;
    final index = visible.indexWhere((entry) => entry.path == _selected.anchor);
    final focused = index >= 0 ? visible[index] : null;
    final page = _scroll.hasClients
        ? (_scroll.position.viewportDimension / context.sizes.rowCompact)
              .floor()
        : FileBrowserConstants.fallbackPageRows;
    if (primary && key == LogicalKeyboardKey.arrowUp) {
      _up();
    } else if (primary && key == LogicalKeyboardKey.arrowDown) {
      if (focused != null) _activate(focused);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _select(visible, index + 1, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _select(visible, index <= 0 ? 0 : index - 1, extend: shift);
    } else if (key == LogicalKeyboardKey.home) {
      _select(visible, 0);
    } else if (key == LogicalKeyboardKey.end) {
      _select(visible, visible.length - 1);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _select(visible, index + page);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _select(visible, index - page);
    } else if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        focused != null) {
      _activate(focused);
    } else if (key == LogicalKeyboardKey.space && focused != null) {
      if (!focused.isDirectory && _endpoint != null) {
        unawaited(showFilePreview(context, _endpoint!, focused));
      }
    } else if (key == LogicalKeyboardKey.backspace && !primary) {
      _up();
    } else if (key == LogicalKeyboardKey.delete ||
        (key == LogicalKeyboardKey.backspace && primary)) {
      unawaited(_delete(_selection));
    } else if (key == LogicalKeyboardKey.f2 && focused != null) {
      unawaited(_rename(focused));
    } else if (key == LogicalKeyboardKey.f5 && widget.copyTarget != null) {
      unawaited(_copyTo(_selection, widget.copyTarget!));
    } else if (primary && key == LogicalKeyboardKey.keyA) {
      _update(() => _selected.addAll(visible));
    } else if (primary && key == LogicalKeyboardKey.keyC) {
      _clip(cut: false);
    } else if (primary && key == LogicalKeyboardKey.keyX) {
      _clip(cut: true);
    } else if (primary && key == LogicalKeyboardKey.keyV) {
      unawaited(_paste());
    } else if (primary && key == LogicalKeyboardKey.keyP) {
      unawaited(_quickJump());
    } else if (primary && key == LogicalKeyboardKey.keyL) {
      _pathBar.edit();
    } else if (primary && key == LogicalKeyboardKey.keyF) {
      _update(() => _filtering = true);
    } else if (key == LogicalKeyboardKey.escape && _selected.isNotEmpty) {
      _update(_selected.clear);
    } else if (isTypeAheadKey(event)) {
      _typeAhead(event.character!, visible);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}
