import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate/design_system/design_system.dart';

enum CliInstallState { checking, missingBinary, notInstalled, installed }

class CliInstaller {
  const new();

  String get binary => p.join(
    p.dirname(Platform.resolvedExecutable),
    Platform.isWindows ? 'warpgate-cli.exe' : 'warpgate-cli',
  );

  bool get isBundled => File(binary).existsSync();

  Future<Map<String, Object?>> _run(List<String> arguments) async {
    final result = await Process.run(binary, [...arguments, '--json', '--no-app']);
    final text = result.stdout.toString().trim();
    if (text.isEmpty) {
      final error = result.stderr.toString().trim();
      Object? decoded;
      try {
        decoded = jsonDecode(error);
      } on FormatException {
        decoded = null;
      }
      throw StateError(
        decoded is Map ? '${decoded['message']}' : 'The command did not finish',
      );
    }
    return (jsonDecode(text) as Map).cast<String, Object?>();
  }

  Future<String?> installedPath() async {
    final report = await _run(['doctor']);
    for (final check in (report['checks']! as List).cast<Map<Object?, Object?>>()) {
      if (check['name'] == 'Installed') {
        return check['ok'] == true ? check['detail'] as String? : null;
      }
    }
    return null;
  }

  Future<String> install() async => (await _run(['install']))['path']! as String;

  Future<void> uninstall() => _run(['uninstall', '--yes']);

  Future<bool> installWithAdmin() async {
    const directory = '/usr/local/bin';
    final link = 'mkdir -p $directory && ln -sf "$binary" $directory/warpgate';
    final ProcessResult result;
    if (Platform.isMacOS) {
      final script = link.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      result = await Process.run('osascript', [
        '-e',
        'do shell script "$script" with administrator privileges',
      ]);
    } else {
      result = await Process.run('pkexec', ['sh', '-c', link]);
    }
    return result.exitCode == 0;
  }
}

class CommandLineSettings extends StatefulWidget {
  const new({super.key, this.installer = const CliInstaller()});

  final CliInstaller installer;

  @override
  State<CommandLineSettings> createState() => _CommandLineSettingsState();
}

class _CommandLineSettingsState extends State<CommandLineSettings> {
  CliInstallState _state = CliInstallState.checking;
  String? _path;
  String? _error;
  bool _busy = false;

  bool get _needsPath =>
      _path != null && !_path!.startsWith('/usr/local/bin') && !Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (widget.installer.isBundled) {
      unawaited(_refresh());
    } else {
      _state = CliInstallState.missingBinary;
    }
  }

  Future<void> _refresh() async {
    try {
      final path = await widget.installer.installedPath();
      if (!mounted) return;
      setState(() {
        _path = path;
        _state = path == null
            ? CliInstallState.notInstalled
            : CliInstallState.installed;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _state = CliInstallState.notInstalled;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _do(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
      await _refresh();
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final installer = widget.installer;
    final dot = switch (_state) {
      CliInstallState.installed => WgDotState.connected,
      CliInstallState.checking => WgDotState.connecting,
      _ => WgDotState.idle,
    };
    final summary = switch (_state) {
      CliInstallState.checking => 'Checking',
      CliInstallState.missingBinary => 'This build does not include the command',
      CliInstallState.notInstalled => 'Not on your PATH yet',
      CliInstallState.installed => 'Installed at',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            WgStatusDot(state: dot),
            SizedBox(width: space.sm),
            Text(summary, style: context.type.body),
            if (_path != null) ...[
              SizedBox(width: space.sm),
              Flexible(
                child: SelectableText(_path!, style: context.type.mono),
              ),
            ],
          ],
        ),
        if (_needsPath) ...[
          SizedBox(height: space.sm),
          Text(
            'Add ${p.dirname(_path!)} to your PATH, or install for all users',
            style: context.type.caption,
          ),
        ],
        if (_error != null) ...[
          SizedBox(height: space.sm),
          Text(
            _error!,
            style: context.type.caption.copyWith(color: context.colors.negative),
          ),
        ],
        if (_state == CliInstallState.notInstalled ||
            _state == CliInstallState.installed) ...[
          SizedBox(height: space.md),
          Wrap(
            spacing: space.sm,
            runSpacing: space.sm,
            children: [
              if (_state == CliInstallState.notInstalled)
                WgButton.primary(
                  label: 'Install warpgate command',
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          _do(() async {
                            await installer.install();
                          }),
                        ),
                ),
              if (_needsPath)
                WgButton(
                  label: 'Install for all users',
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          _do(() async {
                            if (!await installer.installWithAdmin()) {
                              throw StateError('The install was cancelled');
                            }
                          }),
                        ),
                ),
              if (_state == CliInstallState.installed)
                WgButton.ghost(
                  label: 'Uninstall',
                  onPressed: _busy
                      ? null
                      : () => unawaited(_do(installer.uninstall)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
