import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/commands/install.dart';
import 'package:warpgate_cli/src/secrets/platform_vault.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/vault_secret_store.dart';
import 'package:warpgate_core/core/diagnostics/perf_checks.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/connection/data/ssh_agent_client.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/ipc/ipc.dart';

abstract final class DoctorCommands {
  static final Map<String, LocalCommand> all = {
    'doctor': _doctor,
    'diagnostics.export': _diagnosticsExport,
  };

  static Future<JsonMap?> _diagnosticsExport(CliContext context, ActionSpec action, JsonMap args) async {
    final client = await context.client();
    if (client == null) {
      throw const ActionFailure(
        'Warpgate is not running',
        hint: 'Open Warpgate, then run warpgate diagnostics export again',
      );
    }
    final report = await client.call('diagnostics.snapshot', {'log': true});
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final path = p.absolute((args['file'] as String?) ?? 'warpgate-diagnostics-$stamp.json');
    await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    final memory = (report['memory'] as Map?) ?? const {};
    return {
      'path': path,
      'stalls': ((report['stalls'] as List?) ?? const []).length,
      'rss_mb': memory['rss_mb'] as int? ?? 0,
    };
  }

  static Future<JsonMap?> _doctor(CliContext context, ActionSpec action, JsonMap args) async {
    final checks = <JsonMap>[];
    void check(String name, {required bool ok, required String detail, String? fix}) {
      checks.add({'name': name, 'ok': ok, 'detail': detail, 'fix': fix});
    }

    final executable = Platform.resolvedExecutable;
    check('Program', ok: true, detail: executable);
    final installed = InstallCommands.installPlaces().where((place) => Link(place).existsSync() || File(place).existsSync()).toList();
    check(
      'Installed',
      ok: installed.isNotEmpty,
      detail: installed.isEmpty ? 'No warpgate command found' : installed.first,
      fix: installed.isEmpty ? 'Run warpgate-cli --install, or use Settings, Command line' : null,
    );
    final linked = installed.isEmpty || InstallCommands.onPath(p.dirname(installed.first));
    check(
      'On PATH',
      ok: installed.isNotEmpty && linked,
      detail: installed.isEmpty
          ? 'Not installed'
          : linked
          ? '${p.dirname(installed.first)} is on PATH'
          : '${p.dirname(installed.first)} is not on PATH',
      fix: linked ? null : 'Add ${installed.isEmpty ? '' : p.dirname(installed.first)} to PATH',
    );
    final paths = context.paths;
    try {
      final hosts = await context.store.all('hosts');
      check('Database', ok: true, detail: '${paths.database}, ${hosts.length} hosts');
    } on Object catch (error) {
      check('Database', ok: false, detail: '$error', fix: 'Check that ${paths.root} can be written');
    }
    final client = await context.client();
    final stuck = client == null && !context.globals.noApp && await AppInstance.isRunning(paths);
    check(
      'App connection',
      ok: !stuck,
      detail: context.globals.noApp
          ? 'Skipped, --no-app was passed'
          : client != null
          ? 'Connected to the running app'
          : stuck
          ? 'The app is running but not answering'
          : 'The app is not running. Commands that show things in the app will start it',
      fix: stuck ? 'Quit and reopen Warpgate' : null,
    );
    final keyFile = Platform.environment['WARPGATE_MASTER_KEY_FILE'];
    if (keyFile != null) {
      final vault = FileKeyVault(keyFile);
      try {
        await vault.read(MasterKeySource.itemName);
        check('Secure storage', ok: true, detail: 'Using the key file $keyFile');
      } on VaultUnavailable catch (error) {
        check('Secure storage', ok: false, detail: error.message);
      }
    } else if (client != null) {
      check('Secure storage', ok: true, detail: 'Secrets come from the running app');
    } else if (Platform.isMacOS) {
      final present = MacKeychain().hasItem;
      check(
        'Secure storage',
        ok: present,
        detail: present
            ? 'The keychain has the Warpgate key. macOS may ask to allow access'
            : 'No Warpgate key in the keychain yet',
        fix: present ? null : 'Open Warpgate once, or keep it open while using saved secrets',
      );
    } else if (Platform.isLinux) {
      final result = await Process.run('which', ['secret-tool']);
      check(
        'Secure storage',
        ok: result.exitCode == 0,
        detail: result.exitCode == 0 ? 'secret-tool is available' : 'secret-tool is missing',
        fix: result.exitCode == 0 ? null : 'Install libsecret-tools, or keep Warpgate open',
      );
    } else {
      check('Secure storage', ok: true, detail: 'Windows data protection');
    }
    final native = await NativeEngine.ensureLoaded();
    check(
      'SSH engine',
      ok: native,
      detail: native ? NativeEngine.version ?? 'native' : 'dartssh2, slower: ${NativeEngine.loadError ?? 'turned off'}',
      fix: native ? null : 'Put the engine library next to warpgate, or set WARPGATE_ENGINE_LIBRARY',
    );
    final location = SshAgentClient.location;
    if (location == null) {
      check(
        'ssh-agent',
        ok: false,
        detail: 'SSH_AUTH_SOCK is not set',
        fix: r'Run eval "$(ssh-agent)" and ssh-add',
      );
    } else {
      final agent = await SshAgentClient.connect(location);
      if (agent == null) {
        check('ssh-agent', ok: false, detail: 'Could not reach $location', fix: 'Start ssh-agent or Pageant');
      } else {
        final keys = await agent.keys();
        await agent.close();
        check('ssh-agent', ok: true, detail: '${keys.length} keys loaded');
      }
    }
    if (args['perf'] == true) {
      if (client == null) {
        check('Performance', ok: false, detail: 'The app is not running, so there is nothing to measure', fix: 'Open Warpgate and run this again');
      } else {
        final report = await client.call('diagnostics.snapshot');
        for (final item in PerfChecks.from(report)) {
          check(item.name, ok: item.ok, detail: item.detail, fix: item.fix);
        }
      }
    }
    final allOk = checks.every((item) => item['ok'] == true);
    final result = {'checks': checks, 'ok': allOk};
    final output = context.output;
    if (output.json) {
      output.emit(action, result);
      throw ExitWith(allOk ? 0 : ExitKind.general.code);
    }
    for (final item in checks) {
      final ok = item['ok'] == true;
      output.line(
        '${ok ? output.green('ok  ') : output.red('fail')}  ${'${item['name']}'.padRight(15)} ${item['detail']}',
      );
      if (!ok && item['fix'] != null) {
        output.line('      ${''.padRight(15)} ${output.dim('Fix: ${item['fix']}')}');
      }
    }
    throw ExitWith(allOk ? 0 : ExitKind.general.code);
  }
}
