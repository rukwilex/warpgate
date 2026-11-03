# Warpgate: plan, pass 2

## What I found

Baseline: `flutter analyze` reports no issues and `flutter test` passes (68 tests, 20 skipped: the SSH integration tests and the opt-in screen renders). Flutter 3.47.7, Dart 3.13 with primary constructors (`const new(...)`).

**Workspace and panes.** A workspace holds tabs. Each tab is a binary split tree (`LayoutNode`) of panes, and each pane has one `PaneContent`: `SshTerminalContent`, `LocalTerminalContent`, `SftpContent` (one or two sides) or `LogTailContent`. A terminal and its files are always separate panes. `sftp.here` (Cmd/Ctrl+Shift+F) opens a second, split SFTP pane at the terminal's cwd. `ConnectionPool` already multiplexes one SSH client and one SFTP channel per host, so a files panel reuses the terminal's login.

**cwd.** `TerminalSession` already parses OSC 7 into `cwd`, but there is no prompt hook installer, no `/proc/<pid>/cwd` fallback and no "follow" mode.

**Files.** `FileBrowser` (1,222 lines) handles list and grid views, sorting through a menu, a filter, breadcrumbs (not editable), Flutter `Draggable` between panes in one window, OS drop in through `desktop_drop`, and copy through `TransferActions.copy`. It has no columns, tree, favorites, recents, quick jump, clipboard, move between hosts, drag out to the OS, drag onto a terminal, or hover-to-switch tab.

**Transfers.** `TransferEngine` streams host to host through the app and has resume and conflict handling. It has no move semantics and no verification.

**Layout bugs, with causes.**
- `PaneFrame` header: the title is `Flexible` and is followed by `Spacer()`. Both have flex 1, so the free space is split in half and the actions land mid-header. The insets are also uneven: `left: sm, right: xs`.
- `WgEmptyState` is a `Center` inside the scrolling `ListView` of `WgPage`. The height is unbounded, so it centers in nothing, and the page is `Align(topLeft)` + `ConstrainedBox(maxWidth)`, so it centers in the 1200 column rather than in the area. Snippets also adds a `Padding(top: huge)` hack. The max width is `dialog` (440) instead of ~400 readable text.
- `WgPage` header: a `Wrap(spaceBetween)` holding a `Row(min)` shrinks to its children, so the actions are not pinned to the right edge when the window is wide.
- Title bar tabs: a horizontal `ReorderableListView` with `minWidth: tabMin` scrolls instead of shrinking evenly. Chips are `tabBar - sm` tall inside the 40 bar, and the list clips the top marker. The "+" sits after a `Flexible` list, so it drifts. The search button inset differs from the left inset.

**Terminal resize.** It is xterm.dart 4.0 with `autoResize: true`.
- Columns are `size.width ~/ cellWidth` and ignore horizontal padding, so the last column is clipped.
- After reflow the cursor is not remapped, so the prompt redraws on the wrong row.
- The trailing cells of a wrapped row are trimmed, so a space at the wrap point is lost when lines are joined.
- Every frame of a divider drag calls `resizeTerminal`, with no debounce.
- The scroll position is kept in pixels, not lines.
- Cell width is fractional, which causes seams and a blurry grid after a DPR change.
- Zoom changes the global font size, not the focused pane.

**Identifiers.** The Flutter template placeholder id is already gone. The current id is `dev.warpgate.app` (Android namespace/applicationId and Kotlin package, iOS/macOS bundle ids, Linux `APPLICATION_ID`). I will move everything to `eu.kwilex.warpgate`, which matches the `eu.kwilex.<app>` keychain group in the brief, and migrate data from the `dev.warpgate.app` folders.

**Keychain.** `SecureSecretStore` reads `flutter_secure_storage` (login keychain, `usesDataProtectionKeychain: false`) on every password, key and passphrase access. Debug builds are ad-hoc signed, so the item ACL stops matching after every rebuild and each read prompts.

**Icon.** `assets/logo.png` is 512×512 with alpha: a dark rounded square with a light mark, about 6% transparent margin. It is under the 1024 the brief asks for, so the 1024 outputs are upscaled. The platform icons are still the Flutter defaults.

## What I will change

1. **Terminal + files in one pane.** Add `AttachedFiles` (open, dock right/bottom, ratio, path, follow, tree) to terminal contents, persisted per pane. `SessionPane` lays out the terminal and a `FilesPanel` with a draggable, saved divider. Toggle it from the header button, the `sftp.here` shortcut (Cmd/Ctrl+Shift+F) and the menu. Follow terminal: OSC 7, an optional prompt hook for bash/zsh/fish installed over `exec`, and a `/proc/<pid>/cwd` fallback through the shell's child pid. Add "Open terminal here", "Copy path" and "Show in files". Opening a host offers Terminal, Files or Terminal + Files, and the last choice is remembered per host.
2. **Files panel rewrite.** Split `file_browser.dart` into a controller plus widgets: an editable path bar with autocomplete and Tab completion, a lazy tree, favorites, recents, a Cmd/Ctrl+P jump, columns (name, size, modified, permissions, owner) that sort and resize, full keyboard navigation, type-to-find, Space to preview, an instant filter, and refresh after every operation.
3. **Moving between sessions.** Add a shared `FileClipboard` (cut, copy, paste across hosts) and a drag that carries host and paths. Drop targets are files panels, terminals (upload to cwd) and tabs (600 ms hover switches). Show a cursor label naming the target folder and host, and let Alt switch between copy and move. Use `desktop_drop` for OS drop in, and `super_drag_and_drop` for drag out if it builds, otherwise state the limit. Add a `move` flag to jobs: delete the source only after the size check and, when both hosts have `sha256sum`, the checksum check.
4. **Host groups.** Collapsible, rename inline, drag hosts between groups.
5. **Layout.** Fix `PaneFrame`, `WgPage` (full width, a header row with Expanded, an `empty` slot that centers in the remaining area at 400 max), `WgEmptyState`, the title bar tabs (custom even-shrink row, centered in the bar), then audit every screen and dialog. Add goldens for 7 screens × 3 sizes × 2 themes.
6. **Terminal.** Size the grid ourselves (`autoResize: false`): cell size snapped to device pixels, floor columns and rows, even padding. Do our own main-buffer reflow, which keeps hard breaks, wide characters, trailing spaces and the cursor. Leave the alternate screen alone. Keep the view anchored by line. Send resizes throttled at 80 ms plus a trailing send, never with fewer than 2 columns. Add per-pane zoom (Cmd/Ctrl = - 0 and pinch) and unit tests.
7. **Icons.** Add `flutter_launcher_icons` config and generate macOS (824 artwork on a 1024 grid with shadow), Windows `.ico`, Linux PNGs and `.desktop` file, Android adaptive + monochrome, iOS (no alpha) and web. Show a small logo mark on About and first run.
8. **Keychain.** Add `VaultSecretStore`: one AES-GCM master key in the keychain (data-protection keychain plus access group), read once per launch, with secrets encrypted in SQLite. Migrate from the old items and delete them. Sign debug and profile builds through a git-ignored `Signing.xcconfig`. Document it in `docs/BUILD.md`.
9. **Rename** to `eu.kwilex.warpgate` everywhere, and migrate the app data folder on first launch.
10. **Finish:** analyzer, tests, goldens reviewed by eye, a grep for comments, builds, the skills passes, docs, and a summary.
