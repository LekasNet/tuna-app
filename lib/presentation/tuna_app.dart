import 'package:flutter/material.dart';

import '../app/uikit/app_colors.dart';
import '../di/console/console_controller.dart';
import '../di/docker/docker_controller.dart';
import '../di/notifications/notifications_controller.dart';
import '../di/settings/settings_controller.dart';
import '../di/settings/settings_service.dart';
import '../di/tabs/tabs_controller.dart';
import '../di/tunnels/remote_tunnels_controller.dart';
import 'package:tuna/app/uikit/widgets/app_shell.dart';

import '../di/tunnels/tunnels_controller.dart';

class TunaApp extends StatelessWidget {
  final SettingsController settingsController;
  final TabsController tabsController;
  final TunnelsController tunnelsController;
  final DockerController dockerController;
  final RemoteTunnelsController remoteTunnelsController;
  final ConsoleController consoleController;
  final NotificationsController notificationsController;

  const TunaApp({
    super.key,
    required this.settingsController,
    required this.tabsController,
    required this.tunnelsController,
    required this.dockerController,
    required this.remoteTunnelsController,
    required this.consoleController,
    required this.notificationsController,
  });

  ThemeMode _convertThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (_, __) {
        return MaterialApp(
          title: 'Tuna',
          debugShowCheckedModeBanner: false,
          theme: AppColors.lightTheme,
          darkTheme: AppColors.darkTheme,
          themeMode: _convertThemeMode(settingsController.themeMode),
          home: AppShell(
            tabsController: tabsController,
            settingsController: settingsController,
            tunnelsController: tunnelsController,
            dockerController: dockerController,
            remoteTunnelsController: remoteTunnelsController,
            consoleController: consoleController,
            notificationsController: notificationsController,
          ),
        );
      },
    );
  }
}
