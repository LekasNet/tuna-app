// lib/core/cli/cli_controller.dart
import 'dart:io';

import 'cli_commands.dart';

class CliController {
  /// Пользовательский путь до tuna (если указали вручную в настройках).
  /// Может быть null.
  final String? customExecutablePath;

  CliController({this.customExecutablePath});

  /// Внутренний геттер, выбирающий реальный исполняемый файл.
  /// Если customExecutablePath задан — используем его.
  /// Иначе — fallback: 'tuna.exe' на Windows, 'tuna' на остальных.
  String get _executable {
    if (customExecutablePath != null && customExecutablePath!.isNotEmpty) {
      return customExecutablePath!;
    }
    if (Platform.isWindows) {
      return 'tuna.exe';
    }
    return 'tuna';
  }

  /// Публичный путь, который можно использовать снаружи (например, в SettingsController).
  /// Всегда НЕ null — возвращает тот же путь, что и _executable.
  String get executablePath => _executable;

  // ---------------------------------------------------------------------------
  // ЗАПУСК ТОННЕЛЕЙ
  // ---------------------------------------------------------------------------

  Future<Process> startSimpleHttpTunnel({
    required int localPort,
    String? localIp,
    String? subdomain,
  }) async {
    final command = CliCommands.simpleHttp(
      localPort: localPort,
      localIp: localIp,
      subdomain: subdomain,
    );
    return _startTunnelProcess(command);
  }

  Future<Process> startSimpleTcpTunnel({
    required int localPort,
  }) async {
    final command = CliCommands.simpleTcp(localPort: localPort);
    return _startTunnelProcess(command);
  }

  Future<Process> _startTunnelProcess(TunnelCommand command) async {
    final process = await Process.start(
      _executable,
      command.args,
      runInShell: false, // важно для корректного kill()
    );
    return process;
  }

  /// Пытаемся завершить туннель «мягко»
  Future<bool> stopTunnel(Process process) async {
    bool ok = false;
    try {
      // SIGINT (аналог Ctrl+C там, где поддерживается)
      ok = process.kill(ProcessSignal.sigint);
    } catch (_) {
      // На Windows может не поддерживаться — пробуем обычный kill
      ok = process.kill();
    }
    return ok;
  }

  // ---------------------------------------------------------------------------
  // УТИЛИТНЫЙ МЕТОД ДЛЯ ПРОСТЫХ КОМАНД (например, config check)
  // ---------------------------------------------------------------------------

  Future<ProcessResult> runSimple(List<String> args) {
    return Process.run(
      _executable,
      args,
      runInShell: false,
    );
  }
}
