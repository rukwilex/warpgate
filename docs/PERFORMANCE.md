# Performance and long uptime

This is the record of the performance work: how it was measured, what was found, what changed, and the numbers before and after. The plan is in `PLAN-PERF.md`. Every number here comes from `build/perf/results.jsonl`, written by the harness described below, and can be reproduced with the commands in [How to rerun](#how-to-rerun).

Machine: Apple Silicon, 10 cores, 24 GB, macOS 27.2, Flutter 3.47.7 / Dart 3.13.5, Rust 1.98.1. SSH servers: OpenSSH 10.5 on the same machine (`tool/perf/sshd_fleet.sh`, 4 unprivileged `sshd` processes acting as 20 hosts). Loopback has no network latency, so throughput numbers show what the client can do, not what a real network allows.

## Summary

| | Before | After |
|---|---|---|
| Scrollback memory, 100k lines, 80 columns | 230 MB | 36 MB |
| Scrollback memory, 100k lines, 200 columns | 435 MB | 41 MB |
| Native glyph memory after a truecolor flood (one pane) | +700 MB, never returned | bounded: 4,096 shared glyphs, about 28 MB for all panes |
| SFTP download, 1 GB | 1.6 MB/s, 620 ms CPU per MB | 563 MB/s, 2.3 ms CPU per MB |
| Longest UI freeze during an SFTP download | 6.3 s | 2.3 ms |
| Longest UI freeze during `yes` in a terminal | 28.3 s | 4 ms |
| App, one pane flooding: frames per second | 0.1 | see [App](#app-in-profile-mode) |
| Transfer bookkeeping, one 2 GB file | 65,542 state updates, 13 million list copies | 8 updates, 1,608 copies |
| Sorting a folder of 100k files | 191 ms on every rebuild | 60 ms once per change |
| Dead connection after sleep or a frozen server | never noticed (0 of 4 in 90 s) | noticed in 6 to 16 s |
| File descriptors after closing local terminals | one PTY and one thread leaked per terminal, and the shell kept running | closed |

**Root cause of the 6 GB spike.** Three unbounded memory consumers, each enough on its own, stacked up:

1. **Scrollback stored 16 bytes per cell at full line width.** One line cost 2.4 KB at 80 columns and 4.4 KB at 200 columns, even when it held 20 characters. With the setting at its maximum of 100k lines, one wide pane held 435 MB, so 15 such panes reach 6.5 GB. At the default 10k lines, 20 wide panes still held 880 MB.
2. **Every pane kept up to 10,240 laid-out glyph paragraphs in native memory, and evicted ones were never disposed.** Output with many colors (truecolor prompts, `bat`, `delta`, editor themes, `lolcat`) cycled through that cache. A single truecolor flood grew the process by 700 MB of native memory that a garbage collection did not return, and each pane had its own cache.
3. **Leaks that grow with time:** local terminals were closed with `SIGTERM`, which interactive shells ignore, so the shell, its PTY, a reader thread and its file descriptor stayed alive for every local pane ever closed (`flutter_pty` also never closed the PTY master or detached its threads). Reconnects and churn grew open files from 109 to 617 in one run.

**Root cause of the freezes.** SSH ran entirely on the UI thread in pure Dart. `dartssh2` negotiated AES-256-GCM, which its Dart implementation decrypts at about 0.9 MB/s while using a full core. It decrypts everything that has arrived (up to a 2 MB window) before it yields, so the window thread stopped for 6 to 28 seconds during any large output or transfer. On top of that, every terminal chunk was parsed the moment it arrived with no limit per frame, transfers published a new state for every 32 KB acknowledgement, and the file list re-sorted 100k entries on every rebuild.

## Harness

| Layer | What | Where |
|---|---|---|
| 1. Engine benchmarks | Exact measurements of one mechanism at a time, with the Dart heap read through the VM service after a forced GC. Also CI gates with thresholds. | `test/perf/*.dart` (`flutter test --tags perf --enable-vmservice`), `packages/warpgate_core/test/perf/` (`dart test --tags perf`) |
| 2. SSH scenarios | The real `ConnectionPool` against the sshd fleet, on the main isolate like the app. Throughput, CPU per MB, event loop latency (a 1 ms timer probe), idle CPU, dead links, reconnect storms, exec loops. | `packages/warpgate_core/tool/perf_scenarios.dart` |
| 3. The app in profile mode | The real app driven over IPC and MCP. Frame build and raster times from `Flutter.Frame` events, event loop latency from IPC round trips, RSS, Dart heap, CPU, sockets, file descriptors by type, and a widget build trace. | `tool/perf/app_bench.sh`, `tool/perf/driver/` |
| Soak | Loops every scenario for hours and samples memory, handles, stalls and latency every 30 seconds. | `tool/perf/soak.sh` |

The baseline app was built from the original commit in a separate worktree. The only change made to it was the `WARPGATE_MASTER_KEY_FILE` support (below), so the benchmark could run without touching the user's keychain.

## Findings, one by one

### Memory

| Suspect | Finding | Evidence | Fix |
|---|---|---|---|
| Terminal scrollback | Bounded by line count, but 2.4 to 4.4 KB per line regardless of content | heap per line, table below | Lines that scroll off screen are packed into attribute runs plus 1 byte per cell for Latin-1 text (4 bytes otherwise). Accessors unpack lazily, a small LRU repacks lines you scroll back to, and freed cell buffers are reused for new lines. |
| Glyph paragraphs (native) | 10,240 per pane, keyed on a hash that included the background color, never disposed on eviction | +700 MB RSS after one truecolor flood, not released by GC | One cache shared by all panes with the same font, capped at 4,096, exact 64-bit key (font, code point, style, resolved color), `dispose()` on eviction. |
| Terminal output queue | None existed: data was parsed as it arrived, so there was no growth but no backpressure either | — | Bounded queue per pane (1 MB high water) that pauses the SSH channel or withholds the PTY read acknowledgement. |
| SSH channel buffers when the UI cannot keep up | `dartssh2` grants window as data arrives, so a slow consumer could not slow the server down | — | The Rust engine is pulled by Dart. When Dart stops reading, russh stops reading the socket. |
| Transfer chunks | Streamed, not held | — | No change needed. |
| `read_terminal` / MCP activity log | Capped at 500 rows | code | No change needed. |
| Transfer history | Never trimmed, and every finished file copied the job's whole `completedFiles` set (O(n²) for big folders) | 20,000 files: 60,004 publishes, 169 KB of JSON rewritten every 2 s | History capped at 500 finished jobs. One set per running job, progress published at most every 250 ms, big jobs saved every 15 s instead of 2 s. |
| In-app logs | Only `debugPrint` | — | Rotating log: 1 MB per file, 5 files, 14 days, plus a 500-entry ring for the diagnostics screen. |
| Preview, thumbnail and image caches | Previews are capped at 2 MB per file (`readAll`). Flutter's image cache uses its default limits. | code | The memory guard clears the image cache under pressure. |
| Leaks after closing things | Sessions, panes and file panels release their state (the 1,000-session churn ends with 0 live sessions). Two `TerminalSession` objects stay reachable through Flutter's `SliverMultiBoxAdaptorElement._currentBeforeChild` (bounded, not growing). An unfinished directory listing keeps a closed file panel alive until it completes. | retaining paths from the VM service | The file panel drops its listing and sorted cache on close. |
| Local terminals | `kill()` sent SIGTERM, which interactive shells ignore, so the shell kept running. `flutter_pty` never closed the PTY master, never detached its two threads, and on Windows never closed the pseudo console, thread handles or pipes. | open files 293 → 617 over 150 churn rounds | Close with SIGHUP, then SIGKILL after 3 s. `flutter_pty` vendored with a reference-counted close, detached threads, and a credit counter instead of unlocking a mutex from another thread. |
| Reconnect logic | The pool removes and closes the old client before a new one is made. The pool provider is not rebuilt when hosts change. | 15-round reconnect storm: sockets 0 → 0 | No change needed. |
| Whole files read into memory | Only `readAll` for previews (capped at 2 MB) and `warpgate edit` | code | No change needed. |

### CPU and freezes

| Suspect | Finding | Fix |
|---|---|---|
| SSH encryption on the UI isolate | The main cause of freezes, measured above | Rust engine (russh, ring) on a 2-thread Tokio runtime, off every Dart isolate. In the Dart fallback engine, ChaCha20-Poly1305 is preferred over AES-GCM (24× faster in Dart). |
| Terminal parsing | 30 to 50 MB/s, on the UI isolate | Parsing stays on the UI isolate because the painter reads the buffer directly. It is now time-sliced: at most 8 ms per run across all panes, round robin in 16 KB slices, then the loop yields so a frame can run. |
| Rebuilding for every chunk | The terminal widget is not rebuilt (0 widget rebuilds per output frame). Its render object is marked dirty and repaints once per frame. | No change needed. |
| Progress and speed indicators | Every SFTP acknowledgement copied the job list and pushed a new Riverpod state | At most 4 publishes per second per job. The status bar item was already its own small widget. |
| File list sorting | 100k entries filtered and sorted on every build and selection change | Memoized on (entries, filter, hidden, sort key, direction). The name keys are lowercased once. A worker isolate was measured and rejected: sending 100k entries there and back cost 150 to 180 ms and blocked the UI for 36 to 72 ms while copying, more than sorting in place. |
| Hashing | SHA-256 for verified transfers ran in Dart on the UI isolate | Rust (`sha256_file`), with a long-lived Dart worker isolate as the fallback. |
| Database | Already on drift's background isolate | No change needed. |
| JSON | Small documents, except the transfer job of a big folder | Saved less often (above). |
| `*Sync` calls | Only at startup and in the CLI. One worth noting: `Native.isProcessAlive` on Windows runs `tasklist` synchronously, and `flutter_pty` on Windows sleeps for 1 s inside `pty_create`. | Recorded under [Left to do](#left-to-do). |
| Never-completing futures | The keep-alive in `dartssh2` awaits a reply with no timeout, and a flag then blocks every later keep-alive, so a dead link was never noticed | The pool runs its own liveness timer: one periodic timer for the whole pool, running only while connections exist. It sends a ping with a 10 s timeout every keep-alive interval, and closes a client that does not answer. If the timer fires far too late, the computer was asleep, so every link is probed at once with a 5 s timeout. The app probes all links when it is shown or resumed. |
| Unhandled errors | Uncaught errors were only printed | `FlutterError.onError` and `PlatformDispatcher.onError` write to the rotating log. Sessions, transfers, IPC and MCP already caught errors at their boundaries. |
| Idle timers | See [Idle](#idle) | |

### Idle

| Suspect | Finding | Fix |
|---|---|---|
| A frame loop while the window is in the background | **Found, and the main idle cost.** When the Warpgate window was not the active window, macOS reports the app as inactive and Flutter suspends keyboard focus. The focused terminal pane asked for focus again in a post-frame callback on every build, the request changed focus state, that rebuilt the pane, and the loop ran at 60 frames per second for as long as the window stayed in the background: 10 to 15% CPU with nothing happening. A widget build trace of the idle app showed the same pane header buttons rebuilt in every frame. This is why the baseline idle runs varied between 1% and 13%: it depended on whether the window happened to be in front. | The pane asks for focus only while the app is resumed, at most once per frame, and once more when the app comes back to the front. |
| Status dot spinner | Runs only while a host is connecting or reconnecting (at most about 2.5 minutes with the backoff) | No change. Reconnects now have jitter, so many hosts do not retry in step. |
| Cursor blink | xterm does not blink the cursor, so it costs nothing at idle | No change. |
| Reconnect overlay | A 1-second ticker per pane, only while a reconnect countdown is shown | No change. |
| CLI bridge | Checks `PRAGMA data_version` once a second on drift's isolate | No change. It is measured inside the idle numbers below. |
| Keep-alive | One periodic timer for the whole pool, running only while connections exist, instead of one per connection | Changed (see dead links). |
| Folder tracking | Polls the shell's folder only while a files panel follows it and the shell has no prompt hook | No change. |

## Numbers

Layer 1 runs in `flutter test`, which is a JIT debug build, so its times are relative: compare before and after, not with the app. Memory is exact (Dart heap after a forced GC).

### Terminal scrollback (Dart heap held by one terminal)

| Width, lines | Before | After | Bytes per line, before → after |
|---|---|---|---|
| 80 columns, 10k (default) | 25.0 MB | 5.8 MB | 2,505 → 583 |
| 200 columns, 10k | 43.8 MB | 4.6 MB | 4,381 → 459 |
| 80 columns, 100k (maximum) | 230.2 MB | 36.1 MB | 2,302 → 361 |
| 200 columns, 100k | 435.1 MB | 40.7 MB | 4,351 → 407 |

At 10k lines the visible screen and the reuse pool dominate, so the cost per line looks higher than at 100k.

Resizing a pane with 7,918 lines of scrollback reflowed every line into new, unpacked lines: +31.5 MB that stayed until the pane closed. Now the scrollback is packed again right after the reflow: +1.8 MB, 7,878 of 7,918 lines packed. The resize takes 7 to 10 ms longer for that.

### Terminal output (parse throughput on the UI isolate, best of 3)

| Output | Before | After |
|---|---|---|
| `yes` (3 bytes per line) | 5.5 MB/s | 6.3 MB/s |
| `find /` style paths | 27.9 MB/s | 26.5 MB/s |
| Build log with colors | 32.2 MB/s | 28.1 MB/s |
| Full-screen 256-color redraws | 47.5 MB/s | 44.1 MB/s |
| Truecolor | 52.7 MB/s | 52.2 MB/s |

Packing costs up to 10% of parse speed on line-heavy output and buys 6 to 10 times less memory. Line buffer reuse makes `yes` faster. What matters for the UI is that parsing is now limited to 8 ms per frame across all panes, and that the source is paused when a pane falls 1 MB behind. A 40 MB flood through a fake backend stays under 1 MB + 64 KB queued (`test/data/terminal_ingest_test.dart`).

### Terminal drawing (one 1,400 × 900 pane at 2×, 300 frames of flood)

| Output | Average frame before → after | Worst frame before → after |
|---|---|---|
| `yes` | 4.0 → 3.5 ms | 5.7 → 5.2 ms |
| `find` | 1.2 → 1.2 ms | 4.5 → 2.1 ms |
| Build log | 1.6 → 1.5 ms | 9.3 → 5.2 ms |
| Full-screen redraws | 1.7 → 1.5 ms | 12.9 → 18.9 ms |
| Truecolor (unique color per cell) | 8.6 → 10.5 ms | 132 → 39 ms |
| Process memory after all five | 1,238 MB | 433 MB |

A cached glyph costs 7 KB of native memory. Before, every pane could keep 10,240 of them (70 MB) and evicted ones waited for a garbage collection that small Dart objects never trigger. Now all panes share at most 4,096 (28 MB), and evicted ones are disposed at once.

Rows are also cached: each visible line is recorded once as a picture and redrawn from it until it changes, so typing or a status line update re-records one row instead of drawing every cell again.

### Transfers (bookkeeping only, with endpoints that do no I/O)

| | Before | After |
|---|---|---|
| One 2 GB file, 200 old jobs in the list: time | 14.25 s | 0.06 s |
| State updates published | 65,542 (4,599 per second) | 8 (at most 4 per second per job) |
| Job list copies | 13,173,942 | 1,608 |
| 20,000 small files: time | 4.82 s | 0.10 s |
| State updates published | 60,004 (12,442 per second) | 6 |

Before, bookkeeping alone capped a transfer at 144 MB/s for one big file and 16 MB/s for small files, with every update rebuilding the transfer screens.

### File list

| 100k entries | Before | After |
|---|---|---|
| Filter and sort by name | 191 ms, on every build, selection change and key press | 60 ms, once per listing or change of sort or filter |
| Filter and sort by size | 38 ms, same | 18 ms, same |

### Churn (1,000 rounds of opening and closing a terminal, a split, and every tenth round a file panel, through the real workbench)

| | Result |
|---|---|
| Live terminal sessions after the run | 0 (registry and `LiveObjects`) |
| `TerminalSession` / `Terminal` instances still reachable | 2 / 2, held by Flutter's `SliverMultiBoxAdaptorElement._currentBeforeChild` (a bounded framework reference, not growing) |
| File panel controllers still reachable | Only while a local directory listing is unfinished, an artifact of `testWidgets` fake async where real I/O never completes. Real-time churn of the app is below. |

### SSH engine

See [Rust engine: the decision](#rust-engine-the-decision).

## Rust engine: the decision

The brief set three conditions, checked after the Dart fixes. Any one of them justified a Rust engine.

| Condition | After the Dart fixes | Met? |
|---|---|---|
| SSH or SFTP throughput below about 70% of OpenSSH, or CPU per MB several times higher | Best pure Dart cipher (ChaCha20-Poly1305, now preferred): SFTP 38.6 MB/s, 26.5 ms CPU per MB. OpenSSH `sftp` on the same machine: 625 to 737 MB/s, about 1.9 ms CPU per MB. That is 5 to 6% of the throughput at 14× the CPU. | **Yes, by a wide margin** |
| Terminal memory above about 50 MB per 100k scrollback lines, or a flood still causes jank | 36 to 41 MB per 100k lines after packing in Dart. Parsing is time-sliced. | No. The terminal stays in Dart. |
| Crypto or parsing still causes pauses the UI can feel | `dartssh2` decrypts on the UI isolate: 184 ms pauses during `cat` and 3.5 s pauses during `yes` even with ChaCha20 | **Yes** |

So the SSH and SFTP engine moved to Rust, and nothing else did. Terminal state and rendering stay in Dart, because the Dart fixes brought scrollback under the threshold and moving the screen model across an FFI boundary would cost more than it saves.

Measured on the same machine against the same servers:

| | dartssh2 (before) | dartssh2 with ChaCha20 | Rust engine | OpenSSH |
|---|---|---|---|---|
| SFTP download, MB/s | 1.6 | 38.6 | 500 to 563 | 625 to 737 |
| SFTP download, CPU ms per MB | 620 | 26.5 | 2.3 | about 1.9 |
| SFTP upload, MB/s | 1.4 | 37.9 | 381 | |
| Longest event loop pause during SFTP | 6,276 ms | 239 ms | 2.3 ms | |
| `cat \| base64` through a shell, MB/s | 1.0 | 32.7 | 92.1 | |
| Longest event loop pause during that flood | 10,738 ms | 184 ms | 2.3 ms | |
| `yes` through a PTY, MB/s | 0.4 | 3.3 | 2.7 | 2.2 (`ssh -tt`) |
| Longest event loop pause during `yes` | 28,326 ms | 3,499 ms | 4 ms | |
| 20 idle sessions, CPU | 0.05% | | 0.006% | |
| Dead server noticed | never | 15.9 s | 6.3 s | |

The Rust engine reaches 80 to 90% of OpenSSH's SFTP throughput at 1.2× its CPU, and SSH never runs on a Dart isolate. `yes` is slow for every client, OpenSSH included: macOS `yes` writes one line per `write()`, so the server sends a stream of tiny packets.

**What was built.** `russh` 0.65 and `russh-sftp` 2.4 on a Tokio runtime with 2 worker threads, through `flutter_rust_bridge` 2.12 and cargokit, for macOS (universal), iOS, Android (all ABIs), Windows and Linux. Dart classes in `warpgate_core` implement the `dartssh2` interfaces on top of it, so `ConnectionPool` returns either engine behind the same `SSHClient` type, and the UI, CLI and MCP did not change. Both engines run the same 23 CLI integration tests (exec, interactive shell, copy, local, remote and SOCKS forwards, jump hosts, ssh-agent, bad credentials), and CI runs them against both. The CLI loads the same library through FFI. Build details are in `docs/BUILD.md`.

**Memory across the boundary.** Dart pulls data from Rust in batches of at most 256 KB, so no queue between them can grow. A channel that Dart stops reading stops russh from reading that connection, and the server stops sending once the 2 MB window is used. One limit to know about: russh grants window when data arrives, not when it is read, so a paused pane holds up the other channels of the same connection until it drains. Memory stays bounded either way. SFTP keeps at most 32 reads or 16 writes of 255 KB in flight per file. `connect` takes a cancel token, and every Rust handle is closed when its Dart wrapper closes or is collected.

## Uptime machinery

| Piece | What it does | Where |
|---|---|---|
| Watchdog | A background isolate reads a heartbeat that the UI isolate writes every 250 ms into shared native memory, so it sees a stall while the UI is blocked. A stall over 2 s is recorded with what was running (terminal output, resize, transfers, file list, database, IPC, MCP, memory trim) and, in profile and debug builds, the stack of the UI isolate taken through the VM service. When the UI recovers it shows a notice. If the watchdog's own timer was late too, the computer was asleep, which is not counted. | `packages/warpgate_core/lib/core/diagnostics/watchdog.dart`, `lib/core/diagnostics/app_health.dart` |
| Event loop latency | How late the 250 ms heartbeat fires, as p50, p99 and worst over the last minute | same |
| Frame statistics | Frames, frames over 16 ms, worst build and raster, from `FrameTiming` | same |
| Memory guard | Checks RSS every 10 s. Above the limit (Settings, Diagnostics, Memory limit, default 1,536 MB) it trims the glyph cache to 256 entries, frees the line buffer pool, clears the image cache, compacts all scrollback, and drops all but the last 1,000 lines of panes you are not looking at. At most once a minute, logged. | `AppHealth.freeMemory` |
| Dead links, sleep and network changes | Pool liveness timer with probe timeouts, sleep detection, and a probe of every link when the window comes back. Reconnect backoff has ±20% jitter. | `ConnectionPool` |
| Logs | 1 MB per file, 5 files, deleted after 14 days. Uncaught errors go there. | `packages/warpgate_core/lib/core/diagnostics/app_log.dart` |
| Live objects | Counters of terminal sessions, SSH connections, channels, SFTP sessions and files, and closing shells. Shown in diagnostics, checked by the churn test. | `live_objects.dart` |
| Diagnostics screen | Settings, Diagnostics: memory (total and per terminal), CPU, responsiveness, frames, connections, terminals and transfers, background isolates, recent stalls, SSH engine, memory limit, Free memory and Export report. Values refresh every 10 s from one cached snapshot. | `lib/features/settings/presentation/diagnostics_panel.dart` |
| CLI | `warpgate doctor --perf` adds memory, CPU, responsiveness, stalls and frames from the running app. `warpgate diagnostics export [file]` saves the full report with recent log lines. | `packages/warpgate_cli/lib/src/commands/misc.dart` |
| IPC | A call that gets no answer now times out after 60 s and drops the connection, instead of blocking every later call. Replies are matched by id. This hung the benchmark driver once. | `packages/warpgate_core/lib/ipc/ipc.dart` |
| Headless runs | The app reads `WARPGATE_MASTER_KEY_FILE` like the CLI, so it can run without the keychain (used by the benchmarks). | `lib/core/data/vault_secret_store.dart` |

## How to rerun

```sh
tool/perf/sshd_fleet.sh start 4                     # 4 local sshd on 127.0.0.1:2300-2303

flutter test --tags perf --enable-vmservice          # layer 1, app side
(cd packages/warpgate_core && dart test --tags perf) # layer 1, transfers

cd rust && cargo build --release && cd ..            # layer 2 needs the engine library
(cd packages/warpgate_core && \
  WARPGATE_ENGINE_LIBRARY=$PWD/../../rust/target/release/libwarpgate_engine.dylib \
  WARPGATE_PERF_KEY=$PWD/../../build/perf/key WARPGATE_PERF_USER=$(id -un) \
  WARPGATE_PERF_FILE=/path/to/a/1g/file \
  dart run tool/perf_scenarios.dart all)             # WARPGATE_ENGINE=dart for dartssh2

flutter build macos --profile                        # layer 3
tool/perf/app_bench.sh build/macos/Build/Products/Profile/Warpgate.app mylabel \
  idle flood1 flood8 full storm churn requests

tool/perf/soak.sh build/macos/Build/Products/Profile/Warpgate.app 720   # minutes; any length

(cd tool/perf/driver && dart run bin/report.dart)    # tables from build/perf/results.jsonl
```

The app benchmark uses its own data folder (`build/perf/home-<label>`), its own master key file and its own `ssh-agent`, so it never touches your hosts, keys or keychain.

## Left to do

Things measured or found but not fixed, and things this machine could not verify.

| Item | Why it is left | What to do |
|---|---|---|
| Windows, Linux, Android and iOS builds were not run here | No Windows or Linux machine, no Android SDK, no iOS simulator runtime. CI builds them, with a Rust toolchain on every runner. | Watch the first CI run. The `flutter_pty` Windows changes (pseudo console, pipe and thread handle cleanup) have only been read, not compiled. |
| `flutter_pty` on Windows sleeps 1 s inside `pty_create`, on the UI isolate | Present in the original plugin. Without Windows here, removing it could not be tested. | Remove the `Sleep(1000)` and test on Windows. |
| `Native.isProcessAlive` on Windows runs `tasklist` synchronously | Used when transfers are restored at startup, not in a loop | Replace with `OpenProcess` through FFI. |
| russh grants channel window when data arrives, not when it is read | Memory stays bounded (russh's channel queue holds at most 64 packets, and Dart pulls at most 256 KB at a time), but a paused pane can hold up other channels on the same connection while it catches up | Upstream: consumption-based window adjustment in russh, or one connection per busy pane. |
| `yes` through a PTY costs 2.4× OpenSSH's CPU per MB | Many tiny packets, each a hop from Rust to Dart | Batch small packets on the Rust side with a 1 ms window. |
| Terminal parsing stays on the UI isolate | It is time-sliced to 8 ms per frame, and memory is under the threshold. Moving the screen model off the isolate would mean moving rendering data across isolates every frame. | Revisit only if a parser profile shows it. |
| A 100k-entry folder still sorts on the UI isolate once per listing (about 60 ms in JIT, less in AOT) | A worker isolate was measured and was slower because of copying | Sort in Rust as part of the SFTP listing. |
| Per-cell glyph drawing in very colorful output | A synthetic gradient with a unique color in every cell (4,800 per screen) exceeds the 4,096-glyph cache and averaged about 10 ms per frame in the debug-mode benchmark | Draw runs of same-style text as one paragraph, or use a glyph atlas. |
| `leak_tracker` | The project uses its own counters (`LiveObjects`) and VM-service instance counts in the churn test instead | Optional. |
