// lib/core/cli/cli_controller.dart
import 'dart:io';

import 'cli_commands.dart';

class CliController {
  /// Пользовательский путь до tuna (если указали вручную в настройках).
  /// Может быть null.
  final String? customExecutablePath;
  String? _authToken;

  CliController({this.customExecutablePath, String? authToken})
    : _authToken = authToken;

  void updateAuthToken(String? token) {
    final clean = token?.trim() ?? '';
    _authToken = clean.isEmpty ? null : clean;
  }

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
    bool useAuthToken = false,
  }) async {
    final command = CliCommands.simpleHttp(
      localPort: localPort,
      localIp: localIp,
      subdomain: subdomain,
    );
    return _startTunnelProcess(command, useAuthToken: useAuthToken);
  }

  Future<Process> startSimpleTcpTunnel({
    required int localPort,
    bool useAuthToken = false,
  }) async {
    final command = CliCommands.simpleTcp(localPort: localPort);
    return _startTunnelProcess(command, useAuthToken: useAuthToken);
  }

  Future<Process> startSimplePostgresTunnel({
    required int localPort,
    String? localIp,
    bool useAuthToken = false,
  }) async {
    final command = CliCommands.simplePostgres(
      localPort: localPort,
      localIp: localIp,
    );
    return _startTunnelProcess(command, useAuthToken: useAuthToken);
  }

  Future<Process> startSimpleRedisTunnel({
    required int localPort,
    String? localIp,
    bool useAuthToken = false,
  }) async {
    final command = CliCommands.simpleRedis(
      localPort: localPort,
      localIp: localIp,
    );
    return _startTunnelProcess(command, useAuthToken: useAuthToken);
  }

  Future<Process> startSimpleSshTunnel({bool useAuthToken = false}) async {
    return _startTunnelProcess(
      CliCommands.simpleSsh,
      useAuthToken: useAuthToken,
    );
  }

  Future<Process> _startTunnelProcess(
    TunnelCommand command, {
    required bool useAuthToken,
  }) async {
    final process = await Process.start(
      _executable,
      useAuthToken ? _argsWithAuthToken(command.args) : command.args,
      runInShell: false, // важно для корректного kill()
    );
    return process;
  }

  List<String> _argsWithAuthToken(List<String> args) {
    final token = _authToken?.trim();
    if (token == null || token.isEmpty) {
      return args;
    }
    return <String>[...args, '--token=$token'];
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
    return Process.run(_executable, args, runInShell: false);
  }
}
