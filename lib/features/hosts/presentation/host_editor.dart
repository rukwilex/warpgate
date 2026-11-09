import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_constants.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/hosts/presentation/widgets/host_dropdown.dart';
import 'package:warpgate/features/hosts/presentation/widgets/host_field_label.dart';
import 'package:warpgate/features/hosts/presentation/widgets/host_field_row.dart';
import 'package:warpgate/features/hosts/presentation/widgets/host_mcp_access_hint.dart';
import 'package:warpgate/features/hosts/presentation/widgets/host_route_preview.dart';
import 'package:warpgate/features/hosts/presentation/widgets/host_toggle_row.dart';
import 'package:warpgate/features/hosts/presentation/widgets/port_forward_dialog.dart';
import 'package:warpgate/features/hosts/presentation/widgets/port_forward_row.dart';
import 'package:warpgate/features/hosts/presentation/widgets/port_forwards_header.dart';
import 'package:warpgate/features/hosts/utils/host_form_errors.dart';
import 'package:warpgate/features/hosts/utils/host_save_shortcut.dart';
import 'package:warpgate/features/hosts/utils/host_tags.dart';
import 'package:warpgate/features/hosts/utils/host_test_message.dart';
import 'package:warpgate/features/keys/presentation/keys_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate_core/core/util/ids.dart';
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
  late final _port = TextEditingController(
    text: '${_original?.port ?? HostsConstants.defaultPort}',
  );
  late final _user = TextEditingController(text: _original?.username);
  final _password = TextEditingController();
  late final _tags = TextEditingController(text: _original?.tags.join(', '));
  late final _directory = TextEditingController(
    text: _original?.startDirectory,
  );
  late final _keepAlive = TextEditingController(
    text: '${_original?.keepAliveSeconds ?? HostsConstants.defaultKeepAliveSeconds}',
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
    final address = _address.text.trim();
    final user = _user.text.trim();
    final port = int.tryParse(_port.text.trim());
    final id = _original?.id ?? Ids.next();
    final byId = ref.read(hostsProvider).value?.byId ?? const {};
    _errors
      ..clear()
      ..addAll(
        hostFormErrors(
          address: address,
          user: user,
          port: port,
          missingKey: _auth == AuthMethod.key && _keyId == null,
          cyclicJump: HostChain.wouldCycle(id, _jumpId, byId),
        ),
      );
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
      tags: parseHostTags(_tags.text),
      jumpHostId: _jumpId,
      tmuxPersistence: _tmux,
      mcpPermission: _mcp,
      forwards: _forwards,
      keepAliveSeconds:
          int.tryParse(_keepAlive.text.trim())?.clamp(
            0,
            HostsConstants.maxKeepAliveSeconds,
          ) ??
          HostsConstants.defaultKeepAliveSeconds,
      startDirectory: _directory.text.trim().isEmpty
          ? null
          : _directory.text.trim(),
    );
  }

  Future<void> _persist(Host host) => ref
      .read(hostsProvider.notifier)
      .saveHost(
        host,
        password: _auth == AuthMethod.password ? _password.text : null,
        clearPassword: _clearPassword,
      );

  Future<void> _save() async {
    final host = _build();
    if (host == null) return;
    setState(() => _saving = true);
    await _persist(host);
    if (mounted) Navigator.of(context).pop(host);
  }

  Future<void> _test() async {
    final host = _build();
    if (host == null) return;
    setState(() {
      _testResult = 'Connecting';
      _testOk = null;
    });
    await _persist(host);
    final pool = ref.read(connectionPoolProvider);
    await pool.disconnect(host.id);
    final result = await pool.exec(host.id, HostsConstants.testCommand);
    if (!mounted) return;
    setState(() {
      _testOk = result.succeeded;
      _testResult = hostTestMessage(result, tmuxWanted: _tmux);
    });
  }

  Future<void> _addForward() async {
    final spec = await showDialog<PortForwardSpec>(
      context: context,
      builder: (_) => const PortForwardDialog(),
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
          shortcut: hostSaveShortcut(),
          onPressed: () => unawaited(_save()),
        ),
      ],
      child: CallbackShortcuts(
        bindings: {hostSaveShortcut(): () => unawaited(_save())},
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
            HostFieldRow(
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
            const HostFieldLabel('Sign in with'),
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
              HostDropdown<String?>(
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
            HostFieldRow(
              children: [
                (
                  1,
                  HostDropdown<String?>(
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
            HostDropdown<String?>(
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
              HostRoutePreview(
                label: _label.text,
                jumpHostId: _jumpId!,
                byId: catalog.byId,
              ),
            gap,
            HostToggleRow(
              title: 'Keep sessions alive with tmux',
              body: 'Each pane attaches to its own tmux session on the server. Programs keep running when the app closes or the network drops, and the pane reattaches on reconnect.',
              value: _tmux,
              onChanged: (value) => setState(() => _tmux = value),
            ),
            gap,
            const HostFieldLabel('Claude Code access'),
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
            HostMcpAccessHint(permission: _mcp),
            gap,
            HostFieldRow(
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
            PortForwardsHeader(onAdd: () => unawaited(_addForward())),
            if (_forwards.isEmpty)
              Text(
                'None',
                style: context.type.caption.copyWith(
                  color: context.colors.textMuted,
                ),
              )
            else
              for (final forward in _forwards)
                PortForwardRow(
                  forward: forward,
                  onRemove: () => setState(
                    () => _forwards = _forwards
                        .where((item) => item.id != forward.id)
                        .toList(),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
