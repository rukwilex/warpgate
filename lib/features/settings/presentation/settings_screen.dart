import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/shortcuts/shortcut_codec.dart';
import 'package:warpgate/core/util/clipboard_guard.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/cli/presentation/command_line_settings.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/keys/presentation/keys_controller.dart';
import 'package:warpgate/features/mcp/presentation/mcp_service.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/security/presentation/app_lock_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/ui_state.dart';
import 'package:warpgate/features/snippets/presentation/snippets_controller.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/security/data/backup_service.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

class _Item {
  const new(
    this.title,
    this.control, {
    this.description,
    this.keywords = '',
    this.stacked = false,
    this.leading,
  });

  final String title;
  final Widget? leading;
  final String? description;
  final Widget control;
  final String keywords;
  final bool stacked;

  bool matches(String query) => '$title ${description ?? ''} $keywords'
      .toLowerCase()
      .contains(query.toLowerCase());
}

class _Section {
  const new(this.id, this.title, this.icon, this.items);

  final String id;
  final String title;
  final IconData icon;
  final List<_Item> items;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _query = '';
  String _section = 'appearance';

  void _set(Map<String, Object?> changes) =>
      ref.read(settingsProvider.notifier).update(changes);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sections = _sections(context, settings);
    final query = _query.trim();
    final wide = MediaQuery.sizeOf(context).width >= WgBreakpoints.expanded;
    final visible = query.isEmpty
        ? (wide
              ? sections.where((section) => section.id == _section).toList()
              : sections)
        : [
            for (final section in sections)
              if (section.items.any((item) => item.matches(query)))
                _Section(
                  section.id,
                  section.title,
                  section.icon,
                  section.items.where((item) => item.matches(query)).toList(),
                ),
          ];
    final content = ListView(
      padding: EdgeInsets.fromLTRB(
        context.space.xxl,
        context.space.xl,
        context.space.xxl,
        context.space.huge,
      ),
      children: [
        if (!wide) ...[
          Semantics(
            header: true,
            child: Text('Settings', style: context.type.heading),
          ),
          SizedBox(height: context.space.lg),
          _search(),
        ],
        if (visible.isEmpty)
          WgEmptyState(
            title: 'No settings match "$query"',
            body: 'Try a shorter word, like theme, tmux or port.',
          ),
        for (final section in visible) ...[
          Padding(
            padding: EdgeInsets.only(
              top: context.space.xl,
              bottom: context.space.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(section.title, style: context.type.title),
            ),
          ),
          for (final item in section.items) _SettingRow(item: item),
        ],
      ],
    );
    if (!wide) return content;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: context.sizes.sidebar,
          child: ListView(
            padding: EdgeInsets.all(context.space.md),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.space.sm,
                  context.space.sm,
                  0,
                  context.space.lg,
                ),
                child: Semantics(
                  header: true,
                  child: Text('Settings', style: context.type.heading),
                ),
              ),
              _search(),
              SizedBox(height: context.space.md),
              for (final section in sections)
                Padding(
                  padding: EdgeInsets.only(bottom: context.space.hair),
                  child: WgListRow(
                    title: section.title,
                    dense: true,
                    leading: Icon(section.icon),
                    selected: query.isEmpty && section.id == _section,
                    onPressed: () => setState(() {
                      _section = section.id;
                      _query = '';
                    }),
                  ),
                ),
            ],
          ),
        ),
        const WgHairline(vertical: true),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.sizes.sheetMax + context.space.huge,
              ),
              child: content,
            ),
          ),
        ),
      ],
    );
  }

  Widget _search() => WgTextField(
    key: const ValueKey('settings-search'),
    placeholder: 'Search settings',
    leadingIcon: WgIcons.search,
    onChanged: (value) => setState(() => _query = value),
  );

  List<_Section> _sections(BuildContext context, AppSettings s) {
    Widget toggle(String key, String label, {required bool value}) => WgSwitch(
      value: value,
      label: label,
      onChanged: (next) => _set({key: next}),
    );
    Widget segmented<T>(
      T value,
      List<(T, String)> options,
      ValueChanged<T> onChanged,
      String label,
    ) => WgSegmented<T>(
      label: label,
      value: value,
      onChanged: onChanged,
      segments: [for (final (v, text) in options) WgSegment(v, text)],
    );
    return [
      _Section('appearance', 'Appearance', WgIcons.monitor, [
        _Item(
          'Theme',
          segmented(
            s.themeMode,
            const [
              (AppThemeMode.system, 'System'),
              (AppThemeMode.dark, 'Dark'),
              (AppThemeMode.light, 'Light'),
            ],
            (v) => _set({'themeMode': v.name}),
            'Theme',
          ),
          keywords: 'dark light mode',
        ),
        _Item(
          'Accent',
          segmented(
            s.accent,
            [for (final accent in WgAccent.values) (accent, accent.label)],
            (v) => _set({'accent': v.name}),
            'Accent',
          ),
          description:
              'Used for focus, selection and the live parts of the interface',
          keywords: 'color',
        ),
        _Item(
          'Terminal colors',
          segmented(
            s.terminalScheme,
            [
              for (final scheme in WgTerminalScheme.values)
                (scheme, scheme.label),
            ],
            (v) => _set({'terminalScheme': v.name}),
            'Terminal colors',
          ),
          keywords: 'theme scheme palette',
        ),
        _Item(
          'Terminal text size',
          _Stepper(
            value: s.terminalFontSize.round(),
            min: WgTerminalZoom.min.round(),
            max: WgTerminalZoom.max.round(),
            unit: 'pt',
            label: 'Terminal text size',
            onChanged: (v) => _set({'terminalFontSize': v.toDouble()}),
          ),
          description:
              'Default for every terminal. To zoom one pane, press ${PlatformInfo.isApple ? 'Cmd' : 'Ctrl'} with + or −, or 0 to reset',
          keywords: 'font zoom',
        ),
        _Item(
          'Density',
          segmented(
            s.density,
            const [
              (WgDensity.compact, 'Compact'),
              (WgDensity.comfortable, 'Comfortable'),
            ],
            (v) => _set({'density': v.name}),
            'Density',
          ),
          description:
              'Row height in lists and menus. Touch screens always use 44',
        ),
      ]),
      _Section('terminal', 'Terminal', WgIcons.terminal, [
        _Item(
          'Scrollback',
          _Stepper(
            value: s.scrollbackLines,
            min: 1000,
            max: 100000,
            step: 1000,
            unit: 'lines',
            label: 'Scrollback',
            onChanged: (v) => _set({'scrollbackLines': v}),
          ),
          description: 'Lines kept per pane. Applies to new panes',
          keywords: 'history buffer',
        ),
        _Item(
          'Cursor',
          segmented(
            s.cursorShape,
            [for (final c in CursorShape.values) (c, c.label)],
            (v) => _set({'cursorShape': v.name}),
            'Cursor',
          ),
        ),
        _Item(
          'Bell',
          segmented(
            s.bell,
            [for (final b in BellMode.values) (b, b.label)],
            (v) => _set({'bell': v.name}),
            'Bell',
          ),
        ),
        _Item(
          'Copy on select',
          toggle('copyOnSelect', 'Copy on select', value: s.copyOnSelect),
          description: 'Selected text goes to the clipboard right away',
          keywords: 'clipboard',
        ),
        _Item(
          'Confirm multi-line paste',
          toggle(
            'confirmMultilinePaste',
            'Confirm multi-line paste',
            value: s.confirmMultilinePaste,
          ),
          description: 'Shows what will be pasted when it has more than one line, since each line can run as a command',
          keywords: 'clipboard safety',
        ),
      ]),
      _Section('sessions', 'Sessions', WgIcons.history, [
        _Item(
          'Restore on launch',
          toggle(
            'restoreOnLaunch',
            'Restore on launch',
            value: s.restoreOnLaunch,
          ),
          description: 'Reopens workspaces, tabs, splits and file paths, then reconnects pane by pane',
          keywords: 'persistence startup',
        ),
        _Item(
          'Reconnect automatically',
          toggle(
            'autoReconnect',
            'Reconnect automatically',
            value: s.autoReconnect,
          ),
          description: 'Retries with growing delays, up to 10 times, after the network drops',
        ),
        _Item(
          'Keep scrollback between launches',
          toggle(
            'persistScrollback',
            'Keep scrollback between launches',
            value: s.persistScrollback,
          ),
          description:
              'Saves the last ${s.persistedScrollbackLines} lines of each pane on this device. Turn off for sensitive output',
        ),
        _Item(
          'Use tmux for new hosts',
          toggle(
            'tmuxByDefault',
            'Use tmux for new hosts',
            value: s.tmuxByDefault,
          ),
          description: 'New hosts start with server-side persistence on. Each host can change it',
          keywords: 'persistence server',
        ),
      ]),
      _Section('files', 'Files and transfers', WgIcons.transfer, [
        _Item(
          'Transfers at once',
          _Stepper(
            value: s.transferConcurrency,
            min: 1,
            max: 16,
            label: 'Transfers at once',
            onChanged: (v) {
              _set({'transferConcurrency': v});
              ref
                  .read(transferQueueProvider.notifier)
                  .rescheduleAfterSettingsChange();
            },
          ),
          keywords: 'concurrency parallel',
        ),
        _Item(
          'When a file already exists',
          segmented(
            s.conflictPolicy,
            [for (final p in ConflictPolicy.values) (p, p.label)],
            (v) => _set({'conflictPolicy': v.name}),
            'When a file already exists',
          ),
          keywords: 'conflict overwrite skip rename',
          stacked: true,
        ),
        _Item(
          'Offer direct copy between hosts',
          toggle(
            'offerDirectMode',
            'Offer direct copy between hosts',
            value: s.offerDirectMode,
          ),
          description: 'When you copy from one host to another, check whether the source can reach the target with rsync or scp',
          keywords: 'rsync scp direct',
        ),
        _Item(
          'Show hidden files',
          toggle(
            'showHiddenFiles',
            'Show hidden files',
            value: s.showHiddenFiles,
          ),
          description: 'Default for new file panes',
          keywords: 'dotfiles',
        ),
        _Item(
          'Start remote panes in',
          _InlineText(
            initial: s.defaultRemotePath,
            label: 'Start remote panes in',
            onSubmitted: (v) =>
                _set({'defaultRemotePath': v.isEmpty ? '~' : v}),
          ),
          keywords: 'default path',
          stacked: true,
        ),
        _Item(
          'Start local panes in',
          _InlineText(
            initial: s.defaultLocalPath ?? '~',
            label: 'Start local panes in',
            onSubmitted: (v) =>
                _set({'defaultLocalPath': v.isEmpty ? null : v}),
          ),
          keywords: 'default path',
          stacked: true,
        ),
      ]),
      const _Section('shortcuts', 'Shortcuts', WgIcons.keyboard, [
        _Item(
          'Keyboard shortcuts',
          _ShortcutList(),
          keywords: 'keys bindings rebind hotkeys',
          stacked: true,
        ),
      ]),
      _Section('security', 'Security', WgIcons.shield, [
        const _Item(
          'Lock Warpgate',
          _LockToggle(),
          description: 'Asks for a PIN or biometrics when you return',
          keywords: 'pin biometrics face touch',
        ),
        if (s.appLock) ...[
          _Item(
            'Unlock with biometrics',
            toggle(
              'biometricUnlock',
              'Unlock with biometrics',
              value: s.biometricUnlock,
            ),
            keywords: 'face touch fingerprint',
          ),
          _Item(
            'Lock after',
            segmented(
              s.autoLockMinutes,
              const [
                (1, '1 min'),
                (5, '5 min'),
                (15, '15 min'),
                (60, '1 hour'),
              ],
              (v) => _set({'autoLockMinutes': v}),
              'Lock after',
            ),
            description: 'Of inactivity or time in the background',
            keywords: 'timeout auto',
          ),
        ],
        _Item(
          'Clear copied secrets after',
          segmented(
            s.clipboardClearSeconds,
            const [(15, '15 s'), (30, '30 s'), (60, '1 min'), (0, 'Never')],
            (v) => _set({'clipboardClearSeconds': v}),
            'Clear copied secrets after',
          ),
          description: 'Applies to tokens and keys copied from Warpgate',
          keywords: 'clipboard',
          stacked: true,
        ),
        const _Item(
          'Known hosts',
          _KnownHosts(),
          keywords: 'fingerprint host key trust',
          stacked: true,
        ),
      ]),
      _Section('integrations', 'Claude Code', WgIcons.bot, [
        _Item(
          'Let Claude Code use Warpgate',
          toggle(
            'mcpEnabled',
            'Let Claude Code use Warpgate',
            value: s.mcpEnabled,
          ),
          description: PlatformInfo.isMobile
              ? 'Runs an MCP server on this device. On phones and tablets it only runs while Warpgate is on screen'
              : 'Runs an MCP server on 127.0.0.1. Each host decides what Claude Code may do with it',
          keywords: 'mcp integration ai server',
        ),
        _Item(
          'Port',
          _InlineText(
            initial: '${s.mcpPort}',
            label: 'Port',
            digits: true,
            onSubmitted: (v) => _set({
              'mcpPort': int.tryParse(v)?.clamp(1024, 65535) ?? s.mcpPort,
            }),
          ),
          keywords: 'mcp',
        ),
        _Item(
          'Ask before every change',
          toggle(
            'mcpAskBeforeMutating',
            'Ask before every change',
            value: s.mcpAskBeforeMutating,
          ),
          description: 'Shows the exact command or path and waits for you before Claude Code runs or changes anything',
          keywords: 'approval confirm mcp',
        ),
        const _Item(
          'Connect Claude Code',
          _McpConnect(),
          keywords: 'token command mcp.json',
          stacked: true,
        ),
      ]),
      if (PlatformInfo.isDesktop)
        const _Section('command-line', 'Command line', WgIcons.commandLine, [
          _Item(
            'warpgate command',
            CommandLineSettings(),
            description: 'Use your hosts, files and sessions from a terminal',
            keywords: 'cli install path shell terminal',
            stacked: true,
          ),
        ]),
      const _Section('backup', 'Backup', WgIcons.archive, [
        _Item(
          'Encrypted backup',
          _BackupActions(),
          description: 'Hosts, snippets, workspaces and settings, locked with a passphrase you choose',
          keywords: 'export import restore',
          stacked: true,
        ),
      ]),
      _Section('about', 'About', WgIcons.info, [
        _Item(
          'Warpgate',
          Text('1.0.0', style: context.type.mono),
          leading: WgLogoMark(size: context.sizes.iconLarge),
          description: 'SSH and SFTP for many servers at once. Made by kwilex',
          keywords: 'version about logo',
        ),
        _Item(
          'Licenses',
          WgButton.ghost(
            label: 'Show licenses',
            onPressed: () =>
                showLicensePage(context: context, applicationName: 'Warpgate'),
          ),
          description: 'Geist and JetBrains Mono are under the SIL Open Font License. Icons by Lucide',
        ),
      ]),
    ];
  }
}

class _SettingRow extends StatelessWidget {
  const new({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: context.type.body),
        if (item.description != null) ...[
          SizedBox(height: space.hair),
          Text(item.description!, style: context.type.caption),
        ],
      ],
    );
    if (item.leading != null) {
      text = Row(
        children: [
          item.leading!,
          SizedBox(width: space.md),
          Expanded(child: text),
        ],
      );
    }
    final narrow = MediaQuery.sizeOf(context).width < WgBreakpoints.medium;
    return Container(
      padding: EdgeInsets.symmetric(vertical: space.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.hairline)),
      ),
      child: item.stacked || narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                SizedBox(height: space.sm),
                Align(alignment: Alignment.centerLeft, child: item.control),
              ],
            )
          : Row(
              children: [
                Expanded(child: text),
                SizedBox(width: space.lg),
                item.control,
              ],
            ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const new({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    this.step = 1,
    this.unit = '',
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '$value $unit',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WgIconButton(
          icon: WgIcons.minus,
          label: 'Decrease $label',
          onPressed: value <= min
              ? null
              : () => onChanged((value - step).clamp(min, max)),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: context.sizes.metaColumn),
          child: Text(
            '$value${unit.isEmpty ? '' : ' $unit'}',
            textAlign: TextAlign.center,
            style: context.type.mono,
          ),
        ),
        WgIconButton(
          icon: WgIcons.plus,
          label: 'Increase $label',
          onPressed: value >= max
              ? null
              : () => onChanged((value + step).clamp(min, max)),
        ),
      ],
    ),
  );
}

class _InlineText extends StatefulWidget {
  const new({
    required this.initial,
    required this.onSubmitted,
    required this.label,
    this.digits = false,
  });

  final String initial;
  final String label;
  final ValueChanged<String> onSubmitted;
  final bool digits;

  @override
  State<_InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<_InlineText> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSubmitted(_controller.text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.digits ? context.sizes.fieldShort : context.sizes.sidebar,
    child: Semantics(
      label: widget.label,
      child: WgTextField(
        controller: _controller,
        focusNode: _focus,
        mono: true,
        keyboardType: widget.digits ? TextInputType.number : null,
        inputFormatters: widget.digits
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        onSubmitted: (value) => widget.onSubmitted(value.trim()),
      ),
    ),
  );
}

class _ShortcutList extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref
        .read(commandRegistryProvider)
        .commands()
        .where((command) => command.rebindable)
        .toList();
    final overrides = ref.watch(
      settingsProvider.select((s) => s.shortcutOverrides),
    );
    final keys = ref.watch(shortcutMapProvider);
    return Column(
      children: [
        for (final command in commands)
          WgListRow(
            title: command.title,
            dense: true,
            meta: overrides.containsKey(command.id) ? 'changed' : null,
            semanticLabel:
                '${command.title}, ${keys[command.id] == null ? 'no shortcut' : WgShortcutLabel.spoken(keys[command.id]!)}. Change',
            onPressed: () =>
                unawaited(_record(context, ref, command.id, command.title)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (keys[command.id] != null)
                  WgKeycap(keys[command.id]!)
                else
                  Text(
                    'None',
                    style: context.type.monoSmall.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                if (overrides.containsKey(command.id))
                  WgIconButton(
                    icon: WgIcons.retry,
                    label: 'Reset ${command.title}',
                    compact: true,
                    onPressed: () {
                      final next = {...overrides}..remove(command.id);
                      ref.read(settingsProvider.notifier).update({
                        'shortcutOverrides': next,
                      });
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    String id,
    String title,
  ) async {
    ref.read(shortcutsSuspendedProvider.notifier).suspend();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RecordDialog(title: title),
    );
    ref.read(shortcutsSuspendedProvider.notifier).resume();
    if (result == null) return;
    final overrides = ref.read(settingsProvider).shortcutOverrides;
    ref.read(settingsProvider.notifier).update({
      'shortcutOverrides': {...overrides, id: result},
    });
  }
}

class _RecordDialog extends StatefulWidget {
  const new({required this.title});

  final String title;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  SingleActivator? _captured;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WgDialog(
    title: 'Shortcut for ${widget.title}',
    actions: [
      WgButton.ghost(
        label: 'Remove shortcut',
        onPressed: () => Navigator.of(context).pop(''),
      ),
      WgButton.ghost(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      WgButton.primary(
        label: 'Save',
        onPressed: _captured == null
            ? null
            : () => Navigator.of(context).pop(ShortcutCodec.encode(_captured!)),
      ),
    ],
    child: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, event) {
        final activator = ShortcutCodec.fromEvent(event);
        if (activator == null) return KeyEventResult.ignored;
        if (activator.trigger == LogicalKeyboardKey.escape &&
            !activator.control &&
            !activator.meta) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        setState(() => _captured = activator);
        return KeyEventResult.handled;
      },
      child: Container(
        height: context.sizes.keyRecorder,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.canvasDeep,
          borderRadius: context.radii.mdAll,
          border: Border.all(color: context.colors.focusRing),
        ),
        child: _captured == null
            ? Text(
                'Press the keys',
                style: context.type.body.copyWith(
                  color: context.colors.textMuted,
                ),
              )
            : WgKeycap(_captured!),
      ),
    ),
  );
}

class _LockToggle extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(settingsProvider.select((s) => s.appLock));
    return WgSwitch(
      value: enabled,
      label: 'Lock Warpgate',
      onChanged: (value) async {
        final lock = ref.read(appLockProvider.notifier);
        if (!value) {
          await lock.clearPin();
          ref.read(settingsProvider.notifier).update({'appLock': false});
          return;
        }
        final pin = await showDialog<String>(
          context: context,
          builder: (_) => const _PinSetup(),
        );
        if (pin == null) return;
        await lock.setPin(pin);
        ref.read(settingsProvider.notifier).update({'appLock': true});
        lock.touch();
      },
    );
  }
}

class _PinSetup extends StatefulWidget {
  const new();

  @override
  State<_PinSetup> createState() => _PinSetupState();
}

class _PinSetupState extends State<_PinSetup> {
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  void _save() {
    if (_pin.text.length < 4) {
      setState(() => _error = 'Use at least 4 digits');
    } else if (_pin.text != _again.text) {
      setState(() => _error = 'The two PINs are different');
    } else {
      Navigator.of(context).pop(_pin.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(12),
    ];
    return WgDialog(
      title: 'Set a PIN',
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(label: 'Set PIN', onPressed: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WgTextField(
            controller: _pin,
            label: 'PIN',
            obscure: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
          ),
          SizedBox(height: context.space.lg),
          WgTextField(
            controller: _again,
            label: 'Repeat PIN',
            obscure: true,
            error: _error,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}

class _KnownHosts extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_KnownHosts> createState() => _KnownHostsState();
}

class _KnownHostsState extends ConsumerState<_KnownHosts> {
  late Future<List<KnownHost>> _future = ref
      .read(hostRepositoryProvider)
      .knownHosts();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<KnownHost>>(
    future: _future,
    builder: (context, snapshot) {
      final hosts = snapshot.data;
      if (hosts == null) return const WgSkeletonList(rows: 2);
      if (hosts.isEmpty) {
        return Text(
          'No trusted host keys yet. They are added when you trust a server on first connect.',
          style: context.type.caption,
        );
      }
      return Column(
        children: [
          for (final host in hosts)
            WgListRow(
              title: host.endpoint,
              subtitle: '${host.keyType}  ${host.fingerprint}',
              dense: true,
              leading: const Icon(WgIcons.fingerprint),
              trailing: WgButton.ghost(
                label: 'Forget',
                onPressed: () async {
                  await ref.read(hostRepositoryProvider).forget(host.endpoint);
                  setState(
                    () =>
                        _future = ref.read(hostRepositoryProvider).knownHosts(),
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}

class _McpConnect extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final server = ref.watch(mcpServerProvider);
    final token = server.token ?? '…';
    final url = server.endpoint(settings.mcpPort);
    final command =
        'claude mcp add --transport http warpgate $url --header "Authorization: Bearer $token"';
    final json = const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        'warpgate': {
          'type': 'http',
          'url': url,
          'headers': {'Authorization': 'Bearer $token'},
        },
      },
    });
    final clear = Duration(seconds: settings.clipboardClearSeconds);
    final status = server.running
        ? WgInlineMessage(tone: WgTone.positive, message: 'Listening on $url')
        : server.error != null
        ? WgInlineMessage(tone: WgTone.negative, message: server.error!)
        : const WgInlineMessage(
            message: 'Off. Turn it on above to let Claude Code connect.',
          );
    Widget block(String label, String text, {required bool secret}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: context.space.md),
        Row(
          children: [
            Expanded(child: Text(label, style: context.type.caption)),
            WgButton.ghost(
              label: 'Copy',
              icon: WgIcons.copy,
              onPressed: () async {
                await ClipboardGuard.copySecret(
                  text,
                  clearAfter: secret ? clear : Duration.zero,
                );
                if (context.mounted) {
                  showWgToast(
                    context,
                    secret && clear > Duration.zero
                        ? 'Copied. The clipboard clears in ${Format.duration(clear)}'
                        : 'Copied',
                  );
                }
              },
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.all(context.space.md),
          decoration: BoxDecoration(
            color: context.colors.canvasDeep,
            borderRadius: context.radii.mdAll,
            border: Border.all(color: context.colors.hairline),
          ),
          child: SelectableText(
            text,
            style: context.type.monoSmall.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
    final masked = token.length > 8
        ? '${token.substring(0, 4)}${'•' * 12}${token.substring(token.length - 4)}'
        : token;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        status,
        SizedBox(height: context.space.md),
        Row(
          children: [
            Text('Token', style: context.type.body),
            SizedBox(width: context.space.md),
            Expanded(child: Text(masked, style: context.type.mono)),
            WgButton.ghost(
              label: 'Copy',
              icon: WgIcons.copy,
              onPressed: () => unawaited(
                ClipboardGuard.copySecret(token, clearAfter: clear),
              ),
            ),
            WgButton.ghost(
              label: 'Regenerate',
              icon: WgIcons.refresh,
              onPressed: () async {
                final ok = await showWgConfirm(
                  context,
                  title: 'Regenerate the token?',
                  message: 'Claude Code stops working with Warpgate until you add the new token to it.',
                  confirmLabel: 'Regenerate',
                  destructive: true,
                );
                if (ok) {
                  await ref.read(mcpServerProvider.notifier).regenerateToken();
                }
              },
            ),
          ],
        ),
        block('Run this in a terminal', command, secret: true),
        block('Or add this to .mcp.json', json, secret: true),
        if (PlatformInfo.isDesktop)
          block(
            'For stdio, build the companion in tool/mcp_stdio and register it',
            'claude mcp add warpgate -e WARPGATE_MCP_TOKEN=$token -- warpgate-mcp --port ${settings.mcpPort}',
            secret: true,
          ),
        SizedBox(height: context.space.md),
        Align(
          alignment: Alignment.centerLeft,
          child: WgButton(
            label: 'Activity log',
            icon: WgIcons.scrollText,
            onPressed: () => GoRouter.of(context).go(Routes.mcpActivity),
          ),
        ),
      ],
    );
  }
}

class _BackupActions extends ConsumerWidget {
  const new();

  BackupService _service(WidgetRef ref) => BackupService(
    ref.read(documentStoreProvider),
    ref.read(secretStoreProvider),
  );

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final options = await showDialog<({String passphrase, bool secrets})>(
      context: context,
      builder: (_) => const _BackupPassphrase(export: true),
    );
    if (options == null || !context.mounted) return;
    final location = await getSaveLocation(
      suggestedName:
          'warpgate-${DateTime.now().toIso8601String().substring(0, 10)}.wgbackup',
    );
    if (location == null) return;
    final file = await _service(
      ref,
    ).export(passphrase: options.passphrase, includeSecrets: options.secrets);
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(file)),
      mimeType: 'application/json',
    ).saveTo(location.path);
    if (context.mounted) {
      showWgToast(context, 'Backup saved to ${location.path}');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await openFile();
    if (picked == null || !context.mounted) return;
    final options = await showDialog<({String passphrase, bool secrets})>(
      context: context,
      builder: (_) => const _BackupPassphrase(export: false),
    );
    if (options == null) return;
    try {
      final counts = await _service(ref)
          .restore(await picked.readAsString(), options.passphrase);
      ref
        ..invalidate(hostsProvider)
        ..invalidate(keysProvider)
        ..invalidate(snippetsProvider);
      final restored = await SettingsController.load(
        ref.read(documentStoreProvider),
      );
      ref.read(settingsProvider.notifier).replace(restored);
      if (context.mounted) {
        showWgToast(
          context,
          'Restored ${Format.plural(counts.hosts, 'host')}, ${Format.plural(counts.keys, 'key')} and ${Format.plural(counts.snippets, 'snippet')}. Workspaces return on next launch',
        );
      }
    } on Object catch (error) {
      if (context.mounted) showWgToast(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: context.space.sm,
    runSpacing: context.space.sm,
    children: [
      WgButton(
        label: 'Export backup',
        icon: WgIcons.export,
        onPressed: PlatformInfo.isWeb
            ? null
            : () => unawaited(_export(context, ref)),
      ),
      WgButton.ghost(
        label: 'Restore from file',
        icon: WgIcons.import,
        onPressed: PlatformInfo.isWeb
            ? null
            : () => unawaited(_import(context, ref)),
      ),
    ],
  );
}

class _BackupPassphrase extends StatefulWidget {
  const new({required this.export});

  final bool export;

  @override
  State<_BackupPassphrase> createState() => _BackupPassphraseState();
}

class _BackupPassphraseState extends State<_BackupPassphrase> {
  final _passphrase = TextEditingController();
  bool _secrets = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.export && _passphrase.text.length < 8) {
      setState(
        () => _error =
            'Use at least 8 characters. Without it the backup cannot be opened',
      );
      return;
    }
    Navigator.of(context)
        .pop((passphrase: _passphrase.text, secrets: _secrets));
  }

  @override
  Widget build(BuildContext context) => WgDialog(
    title: widget.export ? 'Export backup' : 'Restore backup',
    actions: [
      WgButton.ghost(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      WgButton.primary(
        label: widget.export ? 'Choose where to save' : 'Restore',
        onPressed: _submit,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WgTextField(
          controller: _passphrase,
          label: 'Passphrase',
          obscure: true,
          autofocus: true,
          error: _error,
          helper: widget.export
              ? 'Encrypts the file with AES-256-GCM. There is no way to recover it if you forget it.'
              : null,
          onSubmitted: (_) => _submit(),
        ),
        if (widget.export) ...[
          SizedBox(height: context.space.sm),
          WgCheckRow(
            label: 'Include private keys and saved passwords',
            value: _secrets,
            onChanged: (value) => setState(() => _secrets = value),
          ),
        ] else ...[
          SizedBox(height: context.space.sm),
          Text(
            'Restoring adds to and replaces matching items. Nothing is deleted.',
            style: context.type.caption,
          ),
        ],
      ],
    ),
  );
}
