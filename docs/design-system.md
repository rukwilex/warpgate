# Warpgate design system

Everything a widget paints comes from `lib/design_system`. Feature code never writes a color, size, radius, duration or text style. It reads them from theme extensions through `context.colors`, `context.space`, `context.radii`, `context.sizes`, `context.motion` and `context.type`.

## Direction

| | |
|---|---|
| Product | An SSH and SFTP workbench for people who run many servers and VMs at once |
| Character | Quiet, exact, fast |
| World | Terminals and instrument panels on a night shift |
| Moments | The terminal itself, and the live transfer between two machines |
| Signature | A small live status dot per session, used everywhere a session appears |

Rules that follow from it:

- The terminal and the files are the interface. Chrome is a thin tab bar (36, or the 40 title bar on macOS and Windows), a thin status bar (28), and a sidebar that collapses to a 52 rail.
- Graphite surfaces, one accent. Color carries meaning: the accent marks focus, selection, broadcast and live progress. Green and red only mean connected and failed.
- Depth comes from surface steps and hairlines, not shadows.
- One primary button per area. Everything else is secondary, ghost or an icon button.
- Every action lives in the command palette. Frequent actions have a shortcut, shown as a keycap in menus, tooltips and buttons.

## Tokens

### Color (`WgColors`, `tokens/wg_colors.dart`)

Raw values live only in `tokens/wg_palette.dart`.

| Role | Dark | Light | Use |
|---|---|---|---|
| `canvasDeep` | `#0F0F10` | `#F4F4F5` | Sidebar, tab bar, status bar, pane headers |
| `canvas` | `#141415` | `#FAFAFA` | Page and terminal background |
| `surface` | `#19191B` | `#FFFFFF` | Dialogs, cards, focused pane header |
| `raised` | `#202022` | `#F4F4F5` | Inputs, hover, secondary buttons |
| `pressed` | `#262628` | `#EDEDEF` | Selected rows, active segment |
| `hairline` / `hairlineStrong` | text at 8% / 14% | text at 9% / 16% | Borders and dividers |
| `textPrimary` | `#EDEDED` | `#171717` | Body text |
| `textSecondary` | `#A1A1A6` | `#525252` | Captions, inactive labels |
| `textMuted` | `#909096` | `#6B6B70` | Meta and figures, 4.5:1 or more on every surface |
| `accent` | amber `#E5A54B` | amber `#8F5400` | Focus ring, selection, broadcast, live progress |
| `positive` | `#4CC38A` | `#15803D` | Connected, succeeded |
| `negative` | `#F06A6E` | `#C62828` | Dropped, failed, destructive |
| `caution` | `#E0B252` | `#8A5A00` | Connecting, warnings |
| `primaryFill` | off-white | ink | Primary buttons |
| `veil` | canvas at 72% | canvas at 72% | Blocking overlay over a terminal |
| `negativeFill` · `onNegativeFill` | `#C62828` · white | `#C62828` · white | Close caption button on hover, 5.6:1 |

Accents are selectable in Settings: Amber (default), Cobalt, Teal and Moss. Each has a dark and a light value that reaches 4.5:1 as text.

### Space (`WgSpace`)

`hair 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 48`. Everything sits on the 4 grid. The 2 step is only for nudges inside controls.

### Radius (`WgRadii`)

`xs 4` keycaps and tags, `sm 6` rows and icon buttons, `md 8` inputs and buttons, `lg 12` dialogs and panels, `xl 16`. Nested radii follow inner = outer − padding, as in `WgSegmented`.

### Sizes (`WgSizes`)

| Token | Value | Use |
|---|---|---|
| `icon` | 16 | Every icon, Lucide at the 1.5 stroke weight |
| `dot` | 8 | Status dot |
| `row` / `control` | 36 comfortable, 32 compact, 44 on touch | List rows, buttons, fields |
| `touchTarget` | 44 | Minimum hit area on phones and tablets |
| `tabBar` · `statusBar` | 36 · 28 | Chrome |
| `rail` · `sidebar` | 52 · 264 | Navigation widths |
| `splitterHit` · `paneMin` | 8 · 120 | Split dividers |
| `stroke` · `hairline` · `markerBar` | 1.5 · 1 · 2 | Line weights |
| `palette` · `dialog` · `dialogWide` | 600 · 440 · 640 | Overlay widths |
| `titleBar` | 40 comfortable, 36 compact | Desktop title bar on macOS and Windows |
| `captionButton` · `captionGlyph` | 46 · 10 | Windows caption buttons and their glyphs |
| `trafficLights` | 80 | Left inset reserved for the macOS window buttons |

### Type (`WgType`)

Geist for the interface, JetBrains Mono for the terminal, paths, sizes, times and keycaps. Weights 400 and 500 only. Sentence case everywhere, no tracking on small text, tabular figures in mono.

| Style | Size / line | Weight | Use |
|---|---|---|---|
| `caption` | 12/16 | 400 | Helper text |
| `label` | 13/18 | 500 | Buttons, tabs, field labels |
| `body` · `bodyStrong` | 14/20 | 400 · 500 | Rows, paragraphs |
| `title` | 16/22 | 500 | Dialog titles, sections |
| `heading` | 20/26 | 500 | Page titles |
| `mono` · `monoSmall` | 13/18 · 12/16 | 400 | Commands, paths, figures |
| `keycap` | 11/14 | 400 | Shortcut keycaps |

### Motion (`WgMotion`)

One curve, `Cubic(0.22, 1, 0.36, 1)`. `fast 140ms` hover and press, `medium 200ms` menus and swipes, `slow 360ms` entrances. `live 1200ms` is the spin period of a connecting dot, the only looping motion, and it only runs while a connection is in progress. When the system asks for reduced motion, every duration drops to zero.

## Signature: the status dot

`WgStatusDot` shows a session's state. Each state has its own shape as well as its own color, so it reads without color vision:

| State | Shape | Color |
|---|---|---|
| Not connected | Hollow ring | muted |
| Connecting / Reconnecting | Spinning open arc | caution |
| Connected | Filled circle | positive |
| Busy (exec or transfer running on the connection) | Ring with a center dot | accent |
| Dropped | Filled rounded square | negative |

It appears in tabs (worst state of the tab's panes), pane headers, the sidebar host list, the hosts page, the palette switcher, the file browser location button, the forwards list, multi-exec result cards and the status bar. Screen readers hear "prod-db-1: connected".

## Components

| Component | File | Variants and states |
|---|---|---|
| `WgPressable` | `wg_pressable.dart` | Base for everything clickable: hover, press, focus ring (2px accent, outside), Enter and Space, semantics |
| `WgButton` | `wg_button.dart` | primary, secondary, ghost, danger; icon, keycap, loading, disabled |
| `WgIconButton` | `wg_button.dart` | regular, compact (pointer only, full 44 on touch), selected; tooltip with keycap |
| `WgTooltip` · `WgKeycap` | `wg_button.dart`, `wg_keycap.dart` | ⌘⇧ glyphs on Apple, words elsewhere; spoken label for screen readers |
| `WgListRow` | `wg_controls.dart` | title, mono subtitle, meta capped at 40% width, leading 16 column, trailing; selected, dense |
| `WgTextField` | `wg_controls.dart` | label, helper, error, mono, obscured with show/hide, leading icon |
| `WgSegmented` · `WgSwitch` · `WgCheckbox` · `WgCheckRow` | `wg_controls.dart` | Sized to content |
| `WgTag` · `WgSectionLabel` | `wg_controls.dart` | Quiet outlined text, sentence case |
| `WgInlineMessage` | `wg_feedback.dart` | info, positive, caution, negative, offline; live region for errors |
| `WgEmptyState` | `wg_feedback.dart` | Icon, title, body, one primary and one secondary action |
| `WgSkeleton` · `WgSkeletonList` | `wg_feedback.dart` | Static blocks instead of spinners |
| `WgProgressBar` | `wg_feedback.dart` | Determinate and indeterminate, tone override |
| `WgDialog` · `showWgConfirm` | `wg_overlays.dart` | Titles name the action, buttons say what they do |
| `showWgMenu` · `WgMenuButton` · `WgMenuEntry` | `wg_overlays.dart` | Context menus with icons, keycaps, dividers, destructive rows |
| `WgTabChip` | `wg_overlays.dart` | Dot, title, trailing marker, close on hover; top accent bar while broadcasting |
| `WgCaptionButton` | `wg_caption_button.dart` | minimize, maximize, restore, close; 10px glyphs drawn at the 1px hairline weight; hover `raised`, press `pressed`, close hover `negativeFill` with `onNegativeFill` glyph; not in the tab order, like native caption buttons |
| `WgSearchList` · `WgFloatingPanel` | `wg_search_list.dart` | Palette, switcher and pickers; arrow keys, Enter, Escape |
| `WgPage` | `wg_page.dart` | Page header with one primary action, content capped at 1200 |

Golden tests for these components, in both themes, are in `test/goldens`.

## Patterns

- **Panes**: a 32 header with dot, title, mono subtitle (such as `tmux wg-3f9a`), markers, and actions that show on hover or focus. The focused pane gets a 2px accent bar on its header. A broadcasting pane gets a 2px accent border and a `Broadcast` tag. A pane opened by Claude Code gets a `Claude Code` tag, and its tab gets a bot icon.
- **Connection states in a terminal**: connecting and dropped cover the pane with `veil` and a card. Reconnecting shows a card at the bottom with the attempt count and a countdown, so you can still read the old output.
- **Empty states** say what the place is for and how to fill it, with one action.
- **Errors** say what happened and what to do next. Raw exceptions are mapped to sentences in `SshErrorText`.
- **Window chrome** (macOS and Windows): the title bar and the tab bar are one 40 row in `canvasDeep`, the same surface as the sidebar, so the two read as one L-shaped frame with no seam. The only hairlines are the vertical one beside the sidebar and a horizontal one above the content. The row holds the workspace switcher, the session tabs, New terminal and the command palette. Empty parts of the row move the window, and double-clicking them maximizes it, or on macOS does what the user chose in System Settings. Right-clicking them on Windows opens the system menu. On macOS the native traffic lights stay, centered in the row, with an 80 inset that slides to 8 in full screen. On Windows the three caption buttons sit at the right edge in a layer above dialogs and the lock screen, so the window can always be minimized or closed. When the window loses focus, `WgColors.inactive()` fades primary and secondary text to `textMuted` over `motion.fast`. Linux, phones, tablets and the web keep the native frame and the in-page tab bar.
- **Diagnostic readouts** (Settings, Diagnostics): a settings row whose control is a figure in `mono` and `textSecondary`, like `p99 2.1 ms · worst 14 ms`. The caption says what is measured and over which period. Lists of terminals carry the status dot and a `monoSmall` muted figure. Values refresh at most every 10 seconds from one cached snapshot, so the page never redraws faster than the numbers change. Sizes use one format: one decimal under 10 MB, whole numbers above. Free memory and Export report are secondary buttons, since nothing here is the main task of the page.
- **Destructive actions** use `showWgConfirm(destructive: true)` and name the object: "Delete prod-db-1?".

## Accessibility

- Contrast: every text role reaches 4.5:1 on every surface in both themes. This was measured, and `textMuted` and `negative` on dark were adjusted to pass.
- Keyboard: everything clickable is focusable with a visible 2px focus ring. Dividers take arrow keys. Lists and the palette take arrows, Enter and Escape.
- Screen readers: every control has a label. Dots, keycaps and progress bars have spoken values. Errors are live regions.
- Touch: 44 minimum on phones and tablets, with compact icon buttons growing on touch.
- Window chrome: the drag area is hidden from screen readers. Moving and resizing come from the OS (Alt+Space and Win+arrows on Windows, the Window menu on macOS). Caption buttons have spoken names, and Maximize becomes Restore. The inactive title bar still reaches 4.8:1 in light and 6.0:1 in dark.
- Text scaling: layouts hold at 200%.
- `test/widgets/accessibility_test.dart` runs Flutter's labeled-tap-target, text-contrast and 44px tap-target guidelines, and a 200% text-scale overflow check, on the main screens.

## Audit

Last run: final milestone.

| Category | Defined | Hardcoded in widgets |
|---|---|---|
| Colors | 30 roles, 4 accents | 0 |
| Spacing | 9 steps | 0 |
| Sizes | 44 | 0 |
| Radii | 6 | 0 (nested radius derived from tokens) |
| Type | 10 styles | 0 |
| Motion | 1 curve, 4 durations | 0 (debounce and retry timers are behavior, not motion) |
| Icons | Lucide only, through `WgIcons` | 0 Material or Cupertino icons |

The audit is a grep over `lib/` outside `design_system/tokens` and `design_system/theme`. It looks for color literals, numeric paddings, sizes, radii, font sizes, alpha literals and multipliers on tokens.
