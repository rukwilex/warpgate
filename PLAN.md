# Warpgate — plan

An SSH and SFTP workbench for people who run many servers and VMs at once. Flutter, all platforms.

## Architecture

- `lib/core`: storage (drift, secure storage), platform info, ids, clocks, formatting, shortcuts, routing.
- `lib/design_system`: tokens as `ThemeExtension`s, themes (dark first, light equal), core components.
- `lib/features/<feature>/{data,domain,presentation}`:
  - `hosts`: hosts, groups, tags, `~/.ssh/config` import, known hosts.
  - `keys`: key manager, generation, import, export, install on host.
  - `connection`: SSH connection pool (one multiplexed connection per host, many channels), reconnect with backoff, keep-alive, jump hosts, port forwards.
  - `terminal`: PTY sessions on top of pooled connections, local terminal on desktop, tmux attach.
  - `workspace`: workspaces, tabs, split layout tree, presets, saved layouts, broadcast.
  - `sftp`: SFTP browser, dual pane, preview, editor.
  - `transfers`: global queue, host-to-host streaming, direct mode (rsync/scp), resume, conflicts.
  - `multi_exec`: run one command on many hosts with a result grid.
  - `snippets`: snippets with variables.
  - `palette`: command palette and quick switcher.
  - `settings`, `security` (app lock, backup), `mcp` (server, tools, approvals, activity log).

State: Riverpod `Notifier`s. Navigation: go_router. Data: drift (document tables, no code generation so the repo has no generated comment headers). Secrets: flutter_secure_storage.

## Milestones (all done, see Status)

1. Foundation: lints, packages, fonts, design system tokens, theme extensions, core components, app shell, golden tests, `docs/design-system.md`.
2. Hosts and keys: host CRUD, groups and tags, key manager, known hosts dialog, ssh config import.
3. Single SSH terminal: connection pool, PTY, xterm view, status dot, reconnect.
4. Tabs, splits, workspaces: layout tree, dividers, keyboard resize, maximize, swap, presets, palette.
5. Session persistence and tmux: snapshot and restore, auto-reconnect pane by pane, tmux attach.
6. SFTP and dual pane: browser, operations, preview, editor, local side.
7. Transfers and queue: host-to-host streaming, recursive, resume, conflicts, direct mode, queue UI.
8. Broadcast and multi-exec: broadcast markers, multi-exec grid, snippets, port forwards.
9. Settings and security: searchable settings, app lock, encrypted backup, clipboard clearing, shortcut rebinding.
10. MCP server: JSON-RPC 2.0 over streamable HTTP on 127.0.0.1, bearer token, tools, permissions, approvals, activity log, stdio companion.
11. Platform polish: mobile key row, pinch zoom, swipe, desktop menus, drag and drop, README.

After each milestone: `flutter analyze`, tests, unslop and accessibility review on new screens.

## Status

| Milestone | State | Verified by |
|---|---|---|
| Foundation and design system | Done | Goldens in both themes, `docs/design-system.md`, audit with no hardcoded values |
| Hosts and keys | Done | Unit tests (hosts, ssh config, key codec), widget test for the host editor |
| Single SSH terminal | Done | Integration test against a real sshd; live app |
| Tabs, splits, workspaces | Done | Layout unit tests, palette widget test, live 3-pane split |
| Persistence and tmux | Done | Live restore after relaunch; tmux-missing path tested; tmux-present path not tested on a real tmux host |
| SFTP and dual pane | Done | Integration test (write, list, chmod, delete), live dual pane |
| Transfers and queue | Done | Integration test of a recursive host-to-host stream with permissions; live MCP transfer |
| Broadcast and multi-exec | Done | Live `run_on_hosts`; broadcast fan-out in the session registry |
| Settings and security | Done | Backup and PIN unit tests, settings search widget test |
| MCP server | Done | Dispatcher and HTTP transport tests; live end to end through the stdio companion |
| Platform polish | Done except multiple windows | macOS menus, mobile key row, pinch zoom, swipe, OS drop into SFTP |
