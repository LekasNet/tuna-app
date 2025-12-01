import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'di/console/console_controller.dart';
import 'di/settings/settings_controller.dart';
import 'di/settings/settings_service.dart';
import 'di/tabs/tabs_controller.dart';
import 'di/tunnels/tunnels_controller.dart';
import 'di/tunnels/tunnels_service.dart';
import 'core/cli/cli_controller.dart';
import 'presentation/tuna_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------- 1. SettingsService ----------
  final settingsService = SettingsService();

  // ---------- 2. Загружаем путь ----------
  String? tunaPath = await settingsService.loadTunaPath();

  // ---------- 3. Если пути нет — автоопределяем ----------
  if (tunaPath == null || tunaPath.isEmpty) {
    await settingsService.detectTunaPathIfNeeded();
    tunaPath = await settingsService.loadTunaPath(); // забираем найденный путь
  }

  // ---------- 4. Создаём CLI-контроллер с уже готовым путем ----------
  final cliController = CliController(
    customExecutablePath: tunaPath, // может быть null → тогда CliController сам пробует PATH
  );

  // ---------- 5. Создаём TunnelsController ----------
  final tunnelsService = TunnelsService();
  final tunnelsController = TunnelsController(
    service: tunnelsService,
    cli: cliController,
  );
  await tunnelsController.load();

  // ---------- 6. Создаём SettingsController ----------
  // Теперь можно передавать cliController — замкнутости нет,
  // потому что путь уже известен ДО создания контроллера.
  final settingsController = SettingsController(settingsService, cliController);
  await settingsController.load();

  // ---------- 7. Остальные ----------
  final tabsController = TabsController();
  final consoleController = ConsoleController();

  // ---------- 8. Запускаем приложение ----------
  runApp(
    TunaApp(
      settingsController: settingsController,
      tabsController: tabsController,
      tunnelsController: tunnelsController,
      consoleController: consoleController,
    ),
  );

  // ---------- 9. Окно ----------
  doWhenWindowReady(() {
    const initialSize = Size(800, 600);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'Tuna';
    appWindow.show();
  });
}
