import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/keys/presentation/keys_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/connection/data/port_forwarder.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

Future<Host?> showHostEditor(BuildContext context, {Host? host}) =>
    showDialog<Host>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HostEditor(host: host),
    );

class HostEditor extends ConsumerStatefulWidget {
  const new({super.key, this.host});

  final Host? host;

  @override
  ConsumerState<HostEditor> createState() => _HostEditorState();
}

class _HostEditorState extends ConsumerState<HostEditor> {
  late final Host? _original = widget.host;
  late final _label = TextEditingController(text: _original?.label);
  late final _address = TextEditingController(text: _original?.address);
  late final _port = TextEditingController(text: '${_original?.port ?? 22}');
  late final _user = TextEditingController(text: _original?.username);
  final _password = TextEditingController();
  late final _tags = TextEditingController(text: _original?.tags.join(', '));
  late final _directory = TextEditingController(
    text: _original?.startDirectory,
  );
  late final _keepAlive = TextEditingController(
    text: '${_original?.keepAliveSeconds ?? 15}',
  );
  late AuthMethod _auth = _original?.auth ?? AuthMethod.password;
  late String? _keyId = _original?.keyId;
  late String? _groupId = _original?.groupId;
  late String? _jumpId = _original?.jumpHostId;
  late bool _tmux =
      _original?.tmuxPersistence ?? ref.read(settingsProvider).tmuxByDefault;
  late McpPermission _mcp = _original?.mcpPermission ?? McpPermission.off;
  late List<PortForwardSpec> _forwards = [...?_original?.forwards];
  bool _clearPassword = false;
  bool _saving = false;
  String? _testResult;
  bool? _testOk;
  final Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final controller in [
      _label,
      _address,
      _port,
      _user,
      _password,
      _tags,
      _directory,
      _keepAlive,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Host? _build() {
    _errors.clear();
    final address = _address.text.trim();
    final user = _user.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (address.isEmpty) {
      _errors['address'] = 'Enter an address, like 10.0.0.12 or db.example.com';
    }
    if (user.isEmpty) _errors['user'] = 'Enter the user to sign in as';
    if (port == null || port < 1 || port > 65535) {
      _errors['port'] = 'Use a port from 1 to 65535';
    }
    if (_auth == AuthMethod.key && _keyId == null) {
      _errors['key'] = 'Pick a key, or add one in Keys';
    }
    final id = _original?.id ?? Ids.next();
    final byId = ref.read(hostsProvider).value?.byId ?? const {};
    if (HostChain.wouldCycle(id, _jumpId, byId)) {
      _errors['jump'] = 'This jump host leads back to this host';
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return null;
    }
    return Host(
      id: id,
      label: _label.text.trim().isEmpty ? address : _label.text.trim(),
      address: address,
      port: port!,
      username: user,
      auth: _auth,
      keyId: _auth == AuthMethod.key ? _keyId : null,
      groupId: _groupId,
      tags: _tags.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      jumpHostId: _jumpId,
      tmuxPersistence: _tmux,
      mcpPermission: _mcp,
      forwards: _forwards,
      keepAliveSeconds:
          int.tryParse(_keepAlive.text.trim())?.clamp(0, 3600) ?? 15,
      startDirectory: _directory.text.trim().isEmpty
          ? null
          : _directory.text.trim(),
    );
  }

  Future<void> _save() async {
    final host = _build();
    if (host == null) return;
    setState(() => _saving = true);
    await ref
        .read(hostsProvider.notifier)
        .saveHost(
          host,
          password: _auth == AuthMethod.password ? _password.text : null,
          clearPassword: _clearPassword,
        );
    if (mounted) Navigator.of(context).pop(host);
  }

  Future<void> _test() async {
    final host = _build();
    if (host == null) return;
    setState(() {
      _testResult = 'Connecting';
      _testOk = null;
    });
    await ref
        .read(hostsProvider.notifier)
        .saveHost(
          host,
          password: _auth == AuthMethod.password ? _password.text : null,
          clearPassword: _clearPassword,
        );
    final pool = ref.read(connectionPoolProvider);
    await pool.disconnect(host.id);
    final result = await pool.exec(
      host.id,
      'uname -sr; command -v tmux >/dev/null && echo tmux-ok || echo tmux-missing',
    );
    if (!mounted) return;
    setState(() {
      _testOk = result.succeeded;
      if (result.succeeded) {
        final lines = result.stdout.trim().split('\n');
        final tmux = lines.contains('tmux-ok');
        _testResult =
            'Connected. ${lines.first}${_tmux && !tmux ? '. tmux is not installed, so sessions will not survive a disconnect' : ''}';
      } else {
        _testResult =
            result.error ??
            (result.stderr.trim().isEmpty
                ? 'The test command failed'
                : result.stderr.trim());
      }
    });
  }

  Future<void> _addForward() async {
    final spec = await showDialog<PortForwardSpec>(
      context: context,
      builder: (_) => const _ForwardDialog(),
    );
    if (spec != null) setState(() => _forwards = [..._forwards, spec]);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(hostsProvider).value ?? const HostsCatalog();
    final keys = ref.watch(keysProvider).value ?? const [];
    final space = context.space;
    final gap = SizedBox(height: space.lg);
    final jumpOptions = catalog.hosts
        .where((host) => host.id != _original?.id)
        .toList();
    return WgDialog(
      title: _original == null ? 'Add host' : 'Edit ${_original.label}',
      wide: true,
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton(
          label: 'Test connection',
          icon: WgIcons.plug,
          onPressed: () => unawaited(_test()),
        ),
        WgButton.primary(
          label: _original == null ? 'Add host' : 'Save',
          loading: _saving,
          shortcut: SingleActivator(
            LogicalKeyboardKey.enter,
            meta: WgShortcutLabel.usesCommandKey,
            control: !WgShortcutLabel.usesCommandKey,
          ),
          onPressed: () => unawaited(_save()),
        ),
      ],
      child: CallbackShortcuts(
        bindings: {
          SingleActivator(
            LogicalKeyboardKey.enter,
            meta: WgShortcutLabel.usesCommandKey,
            control: !WgShortcutLabel.usesCommandKey,
          ): () =>
              unawaited(_save()),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_testResult != null) ...[
              WgInlineMessage(
                tone: _testOk == null
                    ? WgTone.info
                    : (_testOk! ? WgTone.positive : WgTone.negative),
                message: _testResult!,
              ),
              gap,
            ],
            WgTextField(
              controller: _label,
              label: 'Name',
              placeholder: 'prod-db-1',
              autofocus: _original == null,
            ),
            gap,
            _Row(
              children: [
                (
                  3,
                  WgTextField(
                    controller: _address,
                    label: 'Address',
                    placeholder: '10.0.0.12',
                    mono: true,
                    error: _errors['address'],
                    keyboardType: TextInputType.url,
                  ),
                ),
                (
                  1,
                  WgTextField(
                    controller: _port,
                    label: 'Port',
                    mono: true,
                    error: _errors['port'],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            gap,
            WgTextField(
              controller: _user,
              label: 'User',
              placeholder: 'root',
              mono: true,
              error: _errors['user'],
              autofillHints: const [AutofillHints.username],
            ),
            gap,
            const _Label('Sign in with'),
            WgSegmented<AuthMethod>(
              label: 'Sign in with',
              value: _auth,
              onChanged: (value) => setState(() => _auth = value),
              segments: [
                for (final method in AuthMethod.values)
                  WgSegment(method, method.label),
              ],
            ),
            SizedBox(height: space.md),
            if (_auth == AuthMethod.password) ...[
              WgTextField(
                controller: _password,
                label: 'Password',
                obscure: true,
                helper: _original == null
                    ? 'Stored in the system keychain. Leave empty to be asked each time.'
                    : 'Leave empty to keep the saved password.',
              ),
              if (_original != null)
                WgCheckRow(
                  label: 'Forget the saved password',
                  value: _clearPassword,
                  onChanged: (value) => setState(() => _clearPassword = value),
                ),
            ],
            if (_auth == AuthMethod.key)
              _Dropdown<String?>(
                label: 'Key',
                value: keys.any((key) => key.id == _keyId) ? _keyId : null,
                error: _errors['key'],
                items: [
                  for (final key in keys)
                    (key.id, '${key.name}  ·  ${key.algorithm.label}'),
                ],
                empty: 'No keys yet. Add one in Keys',
                onChanged: (value) => setState(() => _keyId = value),
              ),
            if (_auth == AuthMethod.agent)
              Text(
                'Uses the keys loaded in ssh-agent or Pageant. Asks for a password if none of them work.',
                style: context.type.caption,
              ),
            if (_auth == AuthMethod.keyboardInteractive)
              Text(
                'The server will ask its own questions, such as a one-time code, when you connect.',
                style: context.type.caption,
              ),
            gap,
            _Row(
              children: [
                (
                  1,
                  _Dropdown<String?>(
                    label: 'Group',
                    value: _groupId,
                    items: [
                      (null, 'No group'),
                      for (final group in catalog.groups)
                        (group.id, group.name),
                    ],
                    onChanged: (value) => setState(() => _groupId = value),
                  ),
                ),
                (
                  1,
                  WgTextField(
                    controller: _tags,
                    label: 'Tags',
                    placeholder: 'db, eu-west',
                    helper: 'Separate with commas',
                  ),
                ),
              ],
            ),
            gap,
            _Dropdown<String?>(
              label: 'Jump host',
              value: _jumpId,
              error: _errors['jump'],
              items: [
                (null, 'Connect directly'),
                for (final host in jumpOptions) (host.id, host.label),
              ],
              onChanged: (value) => setState(() => _jumpId = value),
            ),
            if (_jumpId != null)
              Padding(
                padding: EdgeInsets.only(top: space.xs),
                child: Text(
                  'Route: ${[for (final hop in HostChain.resolve(Host(id: '_', label: _label.text.isEmpty ? 'this host' : _label.text, address: '', username: '', jumpHostId: _jumpId), catalog.byId)) hop.label].join(' → ')}',
                  style: context.type.monoSmall.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ),
            gap,
            _ToggleRow(
              title: 'Keep sessions alive with tmux',
              body: 'Each pane attaches to its own tmux session on the server. Programs keep running when the app closes or the network drops, and the pane reattaches on reconnect.',
              value: _tmux,
              onChanged: (value) => setState(() => _tmux = value),
            ),
            gap,
            const _Label('Claude Code access'),
            WgSegmented<McpPermission>(
              label: 'Claude Code access',
              value: _mcp,
              onChanged: (value) => setState(() => _mcp = value),
              segments: [
                for (final level in McpPermission.values)
                  WgSegment(level, level.label),
              ],
            ),
            SizedBox(height: space.xs),
            Text(switch (_mcp) {
              McpPermission.off => 'Claude Code cannot see this host.',
              McpPermission.readOnly => 'Claude Code can list files, read files and read terminals. It cannot run commands or change anything.',
              McpPermission.full => 'Claude Code can run commands, type into terminals and change files. Passwords and keys are never shared.',
            }, style: context.type.caption),
            gap,
            _Row(
              children: [
                (
                  1,
                  WgTextField(
                    controller: _directory,
                    label: 'Start in folder',
                    placeholder: '~',
                    mono: true,
                  ),
                ),
                (
                  1,
                  WgTextField(
                    controller: _keepAlive,
                    label: 'Keep-alive, seconds',
                    mono: true,
                    keyboardType: TextInputType.number,
                    helper: '0 turns it off',
                  ),
                ),
              ],
            ),
            gap,
            Row(
              children: [
                const Expanded(child: _Label('Port forwards')),
                WgButton.ghost(
                  label: 'Add forward',
                  icon: WgIcons.plus,
                  onPressed: () => unawaited(_addForward()),
                ),
              ],
            ),
            if (_forwards.isEmpty)
              Text(
                'None',
                style: context.type.caption.copyWith(
                  color: context.colors.textMuted,
                ),
              )
            else
              for (final forward in _forwards)
                WgListRow(
                  title: forward.summary,
                  meta: [
                    forward.kind.label,
                    if (forward.autoStart) 'starts on connect',
                  ].join(' · '),
                  leading: const Icon(WgIcons.forward),
                  trailing: WgIconButton(
                    icon: WgIcons.trash,
                    label: 'Remove forward',
                    compact: true,
                    onPressed: () => setState(
                      () => _forwards = _forwards
                          .where((item) => item.id != forward.id)
                          .toList(),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.space.xs),
    child: Text(
      text,
      style: context.type.label.copyWith(color: context.colors.textSecondary),
    ),
  );
}

class _Row extends StatelessWidget {
  const new({required this.children});

  final List<(int, Widget)> children;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < WgBreakpoints.medium;
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (_, child)) in children.indexed) ...[
            if (index > 0) SizedBox(height: context.space.lg),
            child,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, (flex, child)) in children.indexed) ...[
          if (index > 0) SizedBox(width: context.space.md),
          Expanded(flex: flex, child: child),
        ],
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.error,
    this.empty,
  });

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final String? error;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: context.radii.mdAll,
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        DropdownButtonFormField<T>(
          initialValue: items.any((item) => item.$1 == value) ? value : null,
          isExpanded: true,
          style: context.type.body,
          dropdownColor: colors.surface,
          icon: Icon(
            WgIcons.chevronDown,
            size: context.sizes.icon,
            color: colors.textMuted,
          ),
          hint: Text(
            empty ?? 'Choose',
            style: context.type.body.copyWith(color: colors.textMuted),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: colors.raised,
            errorText: error,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.space.md,
              vertical: context.space.sm,
            ),
            border: border(colors.hairline),
            enabledBorder: border(colors.hairline),
            focusedBorder: border(colors.focusRing),
          ),
          items: [
            for (final (itemValue, text) in items)
              DropdownMenuItem<T>(
                value: itemValue,
                child: Text(text, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (next) => onChanged(next as T),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.type.bodyStrong),
              SizedBox(height: context.space.hair),
              Text(body, style: context.type.caption),
            ],
          ),
        ),
        SizedBox(width: context.space.md),
        WgSwitch(value: value, onChanged: onChanged, label: title),
      ],
    ),
  );
}

class _ForwardDialog extends StatefulWidget {
  const new();

  @override
  State<_ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<_ForwardDialog> {
  ForwardKind _kind = ForwardKind.local;
  final _bind = TextEditingController(text: '8080');
  final _host = TextEditingController(text: 'localhost');
  final _target = TextEditingController(text: '80');
  bool _auto = false;

  @override
  void dispose() {
    _bind.dispose();
    _host.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: context.space.lg);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return WgDialog(
      title: 'Add port forward',
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: 'Add',
          onPressed: () {
            final bind = int.tryParse(_bind.text);
            final target = int.tryParse(_target.text) ?? 0;
            if (bind == null) return;
            Navigator.of(context).pop(
              PortForwardSpec(
                id: Ids.short(),
                kind: _kind,
                bindPort: bind,
                targetHost: _host.text.trim(),
                targetPort: target,
                autoStart: _auto,
              ),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WgSegmented<ForwardKind>(
            label: 'Forward type',
            value: _kind,
            onChanged: (value) => setState(() => _kind = value),
            segments: [
              for (final kind in ForwardKind.values)
                WgSegment(kind, kind.label),
            ],
          ),
          SizedBox(height: context.space.sm),
          Text(switch (_kind) {
            ForwardKind.local => 'A port on this device reaches a host and port seen from the server.',
            ForwardKind.remote => 'A port on the server reaches a host and port seen from this device.',
            ForwardKind.dynamic => 'A SOCKS proxy on this device sends traffic out through the server.',
          }, style: context.type.caption),
          gap,
          WgTextField(
            controller: _bind,
            label: _kind == ForwardKind.remote
                ? 'Port on the server'
                : 'Port on this device',
            mono: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
          ),
          if (_kind != ForwardKind.dynamic) ...[
            gap,
            WgTextField(controller: _host, label: 'Target host', mono: true),
            gap,
            WgTextField(
              controller: _target,
              label: 'Target port',
              mono: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
            ),
          ],
          gap,
          WgCheckRow(
            label: 'Start when the host connects',
            value: _auto,
            onChanged: (value) => setState(() => _auto = value),
          ),
        ],
      ),
    );
  }
}

extension ForwardLookup on List<ActiveForward> {
  ActiveForward? find(String hostId, String specId) => firstWhereOrNull(
    (forward) => forward.hostId == hostId && forward.spec.id == specId,
  );
}
