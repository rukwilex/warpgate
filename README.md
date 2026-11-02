# Warpgate

An SSH and SFTP workbench for people who run many servers and VMs at once. Many terminals and file panes side by side, one multiplexed connection per host, copies that stream from one server straight to another, and everything reachable from one command palette. Built with Flutter for macOS, Windows, Linux, iOS and Android.

## Setup

Requirements: Flutter 3.47 or later (Dart 3.13), and CocoaPods for macOS and iOS (`brew install cocoapods`).

```sh
flutter pub get
flutter run -d macos          # or windows, linux, an iOS or Android device
```

Checks:

```sh
flutter analyze               # zero issues
flutter test                  # unit, widget, golden, accessibility and screen tests
```

The SSH integration tests in `test/integration` run against a real server. A throwaway user-level `sshd` is enough:

```sh
ssh-keygen -t ed25519 -N "" -f /tmp/wg/host_key
ssh-keygen -t ed25519 -N "" -f /tmp/wg/client_key
cp /tmp/wg/client_key.pub /tmp/wg/authorized_keys
cat > /tmp/wg/sshd_config <<EOF
Port 2222
ListenAddress 127.0.0.1
HostKey /tmp/wg/host_key
AuthorizedKeysFile /tmp/wg/authorized_keys
PasswordAuthentication no
UsePAM no
StrictModes no
Subsystem sftp /usr/libexec/sftp-server
EOF
/usr/sbin/sshd -f /tmp/wg/sshd_config
WARPGATE_TEST_KEY=/tmp/wg/client_key WARPGATE_TEST_PORT=2222 flutter test test/integration
```

Builds:

```sh
flutter build macos --release
flutter build ios --release --no-codesign
flutter build apk --release
flutter build windows --release
flutter build linux --release
flutter build web -t lib/main_web.dart
```

## Platform notes

| Platform | Notes |
|---|---|
| macOS | App Sandbox is off, because the local terminal spawns your login shell and `~/.ssh/config` import reads your home folder. Secrets use the login keychain. Unsigned debug builds get a new code signature on every build, so macOS may ask once for keychain access after a rebuild. Native menu bar with the same commands and shortcuts as the palette. |
| Windows, Linux | Local terminal through a PTY. Ctrl+Shift is the primary modifier, so Ctrl+C, Ctrl+D and Ctrl+W still go to the shell. Secrets in Credential Manager or libsecret. |
| iOS, Android | Bottom bar, full-screen sessions, swipe between sessions, pinch to zoom the terminal, an extra key row (Esc, Tab, sticky Ctrl and Alt, arrows, `|`, `~`, `/`, `-`, Paste). The OS suspends network sockets when the app goes to the background. A note under the content says so while sessions or transfers are active, and sessions reconnect when you return. No local terminal. |
| Web | Not supported: a clean screen explains why. Browsers cannot open raw TCP sockets, and a WebSocket-to-SSH proxy would move every key and password through a server you would also have to run and secure. That defeats the point of a local workbench, so the web build (`lib/main_web.dart`) only shows that notice. |

## Multitasking

The architecture is built around many sessions at once.

- **Workspaces** are named sets of tabs ("prod cluster", "home lab"). Switch with ⌘1…⌘9 (Ctrl+1…9), from the workspace menu in the tab bar, or from the palette.
- **Tabs** each hold a split tree of any depth. Splits are horizontal or vertical. Drag a divider or move it with the keyboard, and double-click it to reset.
- **Panes** hold an SSH terminal, an SFTP browser (one or two sides), a local terminal (desktop) or a log tail. Every pane on the same host shares one SSH connection. Each pane is its own channel, and each has its own status dot.
- **Layouts**: presets for two columns, two rows, 2×2 grid, and main plus side stack. "Save layout as…" stores a tab with its hosts so you can reopen it later.
- **Host groups and tags**: open a whole group in a grid with one click from the sidebar, the hosts page or the palette.
- **Broadcast**: type into several panes at once. Broadcasting panes get an accent border and a `Broadcast` tag, the tab gets an accent bar, and the status bar shows the count with a one-click stop.
- **Run on many hosts**: one command, many hosts, each on its own exec channel. Results appear in a grid with exit code, duration and output, filterable by failed or succeeded, with "Run again on failed".
- **Snippets** with `{{variables}}` and `{{name|default}}`, sent to the focused pane or to everything in a broadcast.
- **Port forwards** (local, remote, dynamic SOCKS) per host, started by hand or when the host connects, with live connection counts.
- **Jump hosts**, chained to any depth. The editor shows the route and refuses loops.
- **Quick switcher** (⌘P / Ctrl+Shift+P) across every pane in every workspace, plus "connect to" for saved hosts.

### Shortcuts

On macOS the primary modifier is ⌘. On Windows and Linux it is Ctrl+Shift, so terminal control keys still reach the shell. Every shortcut can be changed in Settings → Shortcuts.

| Action | macOS | Windows, Linux |
|---|---|---|
| Command palette | ⌘K | Ctrl+Shift+K |
| Switch to session | ⌘P | Ctrl+Shift+P |
| New terminal | ⌘T | Ctrl+Shift+T |
| New local terminal | ⌘⇧T | Ctrl+Shift+Alt+T |
| Browse files | ⌘O | Ctrl+Shift+O |
| Open files at the terminal's folder | ⌘⇧F | Ctrl+Shift+Alt+F |
| Split right / down | ⌘D / ⌘⇧D | Ctrl+Shift+D / Ctrl+Shift+Alt+D |
| Close pane | ⌘W | Ctrl+Shift+W |
| Maximize or restore pane | ⌘⇧↩ | Ctrl+Shift+Alt+Enter |
| Focus pane left, right, up, down | ⌘⌥ + arrow | Ctrl+Alt + arrow |
| Move divider | ⌘⌥⇧ + arrow | Ctrl+Alt+Shift + arrow |
| Next / previous tab | ⌃Tab / ⌃⇧Tab | Ctrl+Tab / Ctrl+Shift+Tab |
| Workspace 1–9 | ⌘1–⌘9 | Ctrl+1–9 |
| Broadcast to tab | ⌘⇧B | Ctrl+Shift+Alt+B |
| Run on many hosts | ⌘⇧E | Ctrl+Shift+Alt+E |
| Run snippet | ⌘⇧S | Ctrl+Shift+Alt+S |
| Transfers | ⌘⇧J | Ctrl+Shift+Alt+J |
| Save layout | ⌘⇧L | Ctrl+Shift+Alt+L |
| Toggle sidebar | ⌘B | Ctrl+Shift+B |
| Settings | ⌘, | Ctrl+Shift+, |
| Terminal text size | ⌘= / ⌘- | Ctrl+Shift+= / Ctrl+Shift+- |
| Copy / paste in a terminal | ⌘C / ⌘V | Ctrl+Shift+C / Ctrl+Shift+V |
| In file panes | ↑ ↓ ↩, ⌫ up, Delete, F2 rename, F5 copy to the other side | same |

## Persistence and tmux

- Workspaces, tabs, split trees, the host and tmux session of every pane, SFTP paths and the transfer queue are saved as you work, in a local drift (SQLite) database.
- On launch the app restores everything and reconnects pane by pane. Each pane shows its dot while it connects.
- Scrollback: the last 2,000 lines of each pane are kept between launches and shown dimmed above the new session. You can turn this off in Settings → Sessions.
- Auto-reconnect: after a network drop a pane retries at 1, 2, 4, 8, 15 and 30 seconds, up to 10 times, with a countdown and "Retry now". Authentication and host-key failures stop at once with a clear message. A shell that exits normally says so and restarts on Enter.
- **tmux persistence** is a per-host switch, with a default for new hosts in Settings. When it is on, each pane attaches to its own tmux session (`tmux new-session -A -s wg-<id>`, created if missing). Programs keep running when the app closes or the network drops, and the pane reattaches on reconnect. If tmux is not installed, the pane says so plainly and falls back to a normal shell. "Test connection" in the host editor checks for tmux too.

## Transfers between hosts

- File panes can show this device or any saved host on either side. Drag files from one side to the other, between any two panes, or from the desktop into a pane. Shift-click and ⌘/Ctrl-click select several.
- Host-to-host copies stream chunk by chunk from the source SFTP channel into the target SFTP channel. Nothing is written to this device's disk. Folders copy recursively and keep their structure and permission bits.
- **Direct mode**: when copying between two hosts, Warpgate can check whether the source can reach the target by itself. It looks for rsync or scp on the source and tries a batch-mode SSH login. Only if that works does it offer to run `rsync -a --partial` (or `scp -rp`) on the source, which is faster for large data. It never assumes it.
- **Queue**: one global queue for all workspaces, with a configurable concurrency limit (3 by default). It shows progress, speed and time left, and supports pause, resume, cancel and retry. Pausing keeps the partial file, so large files resume from their offset, and folders resume from the files they had not finished. Conflicts follow the policy you choose: ask, overwrite, skip, or keep both. The "ask" dialog offers resume when the target is a shorter copy.
- Transfers run in the background while you work in other panes. The status bar indicator opens the queue. Interrupted transfers are re-queued on the next launch.
- "Open files here" in a terminal opens a file pane at the shell's current folder. This works when the shell reports it with OSC 7, which most modern shell prompts do; otherwise the pane opens at the home folder. "Open terminal here" on any folder opens a terminal in that folder.

## Security model

- Passwords, private keys, key passphrases, the app PIN hash and the MCP token are stored only in the system's secure storage (Keychain, Credential Manager, libsecret, Android Keystore). The database holds no secrets.
- **Host keys**: unknown keys open a dialog showing the SHA-256 fingerprint, with "Trust and save", "Trust once" and "Disconnect". A key that differs from the saved one gets a red warning showing both fingerprints. Saved keys can be reviewed and forgotten in Settings → Security.
- **Keys**: generate Ed25519 or RSA (3072 or 4096) with an optional passphrase. Import from a file or by pasting OpenSSH or PEM. Copy or save the public key, and install it on a host with one action (appended to `authorized_keys` only if it is missing).
- **App lock**: PIN (PBKDF2-SHA256, 120,000 rounds) and optional biometrics, locking after 1, 5, 15 or 60 minutes of inactivity or in the background. Sessions keep running behind the lock.
- **Clipboard**: copied tokens and keys are cleared after 15, 30 or 60 seconds, if nothing else was copied since. Multi-line pastes into a terminal ask first.
- **Backup**: one encrypted file (AES-256-GCM, key from PBKDF2-SHA256 with 150,000 rounds) containing hosts, groups, known hosts, snippets, workspaces, saved layouts and settings. Private keys and saved passwords are included only if you tick the box.
- `~/.ssh/config` import (desktop) reads `Host`, `HostName`, `User`, `Port`, `IdentityFile` and `ProxyJump`, with `Host *` defaults, and skips patterns and `Match` blocks.

## Connecting Claude Code over MCP

Warpgate can expose an MCP server so Claude Code can work with your hosts. It is **off by default**.

1. Open Settings → Claude Code and turn on **Let Claude Code use Warpgate**. The server listens on `127.0.0.1:7823` (the port is configurable).
2. In each host's editor, set **Claude Code access**:
   - Off: the host is invisible to Claude Code.
   - Read only: list files, read files and read terminals.
   - Full: also run commands, type into terminals, write files and transfer.
3. Copy the command shown in Settings and run it:

   ```sh
   claude mcp add --transport http warpgate http://127.0.0.1:7823/mcp --header "Authorization: Bearer <token>"
   ```

   or add the `.mcp.json` snippet shown there:

   ```json
   {
     "mcpServers": {
       "warpgate": {
         "type": "http",
         "url": "http://127.0.0.1:7823/mcp",
         "headers": { "Authorization": "Bearer <token>" }
       }
     }
   }
   ```

4. For stdio, build the companion and register it:

   ```sh
   cd tool/mcp_stdio && dart compile exe bin/warpgate_mcp.dart -o build/warpgate-mcp
   claude mcp add warpgate -e WARPGATE_MCP_TOKEN=<token> -- /path/to/warpgate-mcp --port 7823
   ```

**Protocol.** JSON-RPC 2.0 over Streamable HTTP with plain JSON responses. It supports MCP `2026-07-28`, where each request carries its version and there is no handshake, and the earlier `2025-11-25`, `2025-06-18` and `2025-03-26`, which negotiate with `initialize`. Notifications get `202`. `GET` and `DELETE` get `405`. Requests with a non-local `Origin` get `403`. Requests without the bearer token get `401`. The token is compared in constant time and can be copied or regenerated in Settings.

**Tools.** `list_hosts`, `list_groups`, `list_workspaces`, `list_sessions`, `open_session`, `close_session`, `run_command` (on a separate exec channel, never the user's terminal), `run_on_hosts`, `read_terminal`, `send_input`, `sftp_list`, `sftp_read_file` (up to 1 MB), `sftp_write_file`, `sftp_upload`, `sftp_download`, `transfer_between_hosts`, `list_transfers`, `cancel_transfer`.

**Safety.**
- The per-host permission level is enforced on every call.
- With **Ask before every change** on (the default), every call that changes something shows an in-app dialog with the exact command or path, and waits for Allow or Deny.
- Every call is recorded in Settings → Claude Code → Activity log with its time, tool, arguments and result.
- Passwords and private keys are never exposed through MCP.
- Sessions that Claude Code opens get a `Claude Code` tag in the pane and a bot icon in their tab.
- On iOS and Android the server only runs while Warpgate is on screen, and Settings says so.

## Project layout

```
lib/
  app/                 app root, router, app-wide effects
  core/                storage (drift, secure storage), interaction broker, shortcuts, formatting
  design_system/       tokens, theme extensions, components (see docs/design-system.md)
  features/<feature>/{data,domain,presentation}
    hosts keys connection terminal workspace sftp transfers multi_exec
    snippets palette settings security mcp shell
test/                  unit, data, widget, golden, accessibility, screens, integration
tool/mcp_stdio/        stdio bridge for Claude Code
docs/design-system.md  direction, tokens, components, patterns, audit
```
