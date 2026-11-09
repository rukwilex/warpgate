import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:warpgate/app/app.dart';
import 'package:warpgate/app/router.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/features/cli/presentation/cli_bridge.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/core/data/app_data_migration.dart';
import 'package:warpgate_core/core/diagnostics/app_log.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/features/sftp/data/endpoints.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (PlatformInfo.isDesktop) {
    await windowManager.ensureInitialized();
    final custom = WindowChrome.forPlatform.custom;
    unawaited(
      windowManager.waitUntilReadyToShow(
        WindowOptions(
          title: 'Warpgate',
          size: const Size(1360, 860),
          minimumSize: const Size(720, 480),
          center: true,
          titleBarStyle: custom ? TitleBarStyle.hidden : null,
          windowButtonVisibility: custom ? true : null,
        ),
        () async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
    );
  }
  if (!PlatformInfo.isWeb) {
    try {
      final support = await getApplicationSupportDirectory();
      if (AppPaths.resolve(platformRoot: support.path).root == support.path) {
        await AppDataMigration.run(support.path);
      }
    } on Object catch (error) {
      debugPrint('Could not copy data from the previous app folder: $error');
    }
  }
  LocalEndpoint.mobileHome = () async =>
      (await getApplicationDocumentsDirectory()).path;
  AppPaths? paths;
  if (!PlatformInfo.isWeb) {
    paths = AppPaths.resolve(
      platformRoot: (await getApplicationSupportDirectory()).path,
    );
  }
  final root = paths?.root;
  AppLog.instance = AppLog(directory: root == null ? null : '$root/logs');
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.instance.error('ui', details.exception, details.stack);
    presentError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.instance.error('uncaught', error, stack);
    return true;
  };
  final database = AppDatabase(
    driftDatabase(
      name: AppIdentity.databaseName,
      native: DriftNativeOptions(
        databaseDirectory: root == null
            ? getApplicationSupportDirectory
            : () async => Directory(root)..createSync(recursive: true),
      ),
    ),
  );
  final store = DriftDocumentStore(database);
  final settings = await SettingsController.load(store);
  NativeEngine.preferred = settings.sshEngine == 'dart'
      ? SshEngineKind.dart
      : SshEngineKind.native;
  if (!PlatformInfo.isWeb && !await NativeEngine.ensureLoaded()) {
    AppLog.instance.warning(
      'engine',
      'The native SSH engine is not available, using dartssh2: ${NativeEngine.loadError}',
    );
  }
  final workbench = await WorkbenchController.load(store);
  final transfers = await TransferQueue.load(store);
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        appPathsProvider.overrideWithValue(
          PlatformInfo.isDesktop ? paths : null,
        ),
        initialSettingsProvider.overrideWithValue(settings),
        initialWorkbenchProvider.overrideWithValue(workbench),
        initialTransfersProvider.overrideWithValue(transfers),
        routerProvider.overrideWithValue(buildRouter()),
      ],
      child: const WarpgateApp(),
    ),
  );
}
