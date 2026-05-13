import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/cli/cli_controller.dart';
import 'core/storage/shared_preferences_migration.dart';
import 'core/updates/app_update_service.dart';
import 'di/console/console_controller.dart';
import 'di/docker/docker_controller.dart';
import 'di/notifications/notifications_controller.dart';
import 'di/settings/settings_controller.dart';
import 'di/settings/settings_service.dart';
import 'di/tabs/tabs_controller.dart';
import 'di/tunnels/remote_tunnels_controller.dart';
import 'di/tunnels/tunnels_controller.dart';
import 'di/tunnels/tunnels_service.dart';
import 'presentation/tuna_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await migrateLegacySharedPreferences();

  final settingsService = SettingsService();

  String? tunaPath = await settingsService.loadTunaPath();
  if (tunaPath == null || tunaPath.isEmpty) {
    await settingsService.detectTunaPathIfNeeded();
    tunaPath = await settingsService.loadTunaPath();
  }

  final cliController = CliController(customExecutablePath: tunaPath);

  final tunnelsController = TunnelsController(
    service: TunnelsService(),
    cli: cliController,
  );
  await tunnelsController.load();

  final notificationsController = NotificationsController();

  void syncUpgradeNotification() {
    final upgrade = tunnelsController.latestUpgrade;
    notificationsController.syncUpgradeNotification(
      currentVersion: upgrade?.currentVersion,
      newVersion: upgrade?.newVersion,
      updateUrl: upgrade?.url,
    );
  }

  tunnelsController.addListener(syncUpgradeNotification);
  syncUpgradeNotification();

  final settingsController = SettingsController(settingsService, cliController);
  await settingsController.load();

  final tabsController = TabsController();
  final consoleController = ConsoleController();
  final dockerController = DockerController();
  final remoteTunnelsController = RemoteTunnelsController();

  runApp(
    TunaApp(
      settingsController: settingsController,
      tabsController: tabsController,
      tunnelsController: tunnelsController,
      dockerController: dockerController,
      remoteTunnelsController: remoteTunnelsController,
      consoleController: consoleController,
      notificationsController: notificationsController,
    ),
  );

  unawaited(() async {
    final tunnelProbe = await tunnelsController.reconcileRunningTunnels(
      apiKey: settingsController.apiKey,
      token: settingsController.token,
    );
    notificationsController.syncRemoteTunnelsNotification(
      tunnelProbe.remoteActiveCount,
    );

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final appUpdateService = AppUpdateService();
    final update = await appUpdateService.checkForUpdate(
      currentVersion: currentVersion,
    );

    notificationsController.syncDesktopAppUpdateNotification(
      currentVersion: currentVersion,
      newVersion: update?.latestVersion,
      releaseUrl: update?.releaseUrl,
    );
  }());

  doWhenWindowReady(() {
    const initialSize = Size(800, 600);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'tuna_unofficial_client';
    appWindow.show();
  });
}
