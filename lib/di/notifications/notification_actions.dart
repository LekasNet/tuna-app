import 'dart:io';

import '../../utils/helpers.dart';

enum NotificationAction {
  openUpgradeInstructions,
  runTunaCliUpgrade,
  openDesktopAppRelease,
  openTunnelsDashboard,
}

extension NotificationActionPresentation on NotificationAction {
  String get label {
    switch (this) {
      case NotificationAction.openUpgradeInstructions:
        return 'На сайт';
      case NotificationAction.runTunaCliUpgrade:
        return 'Обновить';
      case NotificationAction.openDesktopAppRelease:
        return 'Релиз';
      case NotificationAction.openTunnelsDashboard:
        return 'Тоннели';
    }
  }
}

Future<void> executeNotificationAction(
  NotificationAction action, {
  String? payload,
}) async {
  switch (action) {
    case NotificationAction.openUpgradeInstructions:
      final url = payload?.trim();
      if (url == null || url.isEmpty) {
        await launchWeb('https://releases.tuna.am/tuna/');
        return;
      }
      await launchWeb(url);

    case NotificationAction.runTunaCliUpgrade:
      await _runTunaUpgradeCommand();

    case NotificationAction.openDesktopAppRelease:
      final url = payload?.trim();
      if (url == null || url.isEmpty) {
        await launchWeb('https://github.com/LekasNet/tuna-app/releases');
        return;
      }
      await launchWeb(url);

    case NotificationAction.openTunnelsDashboard:
      final url = payload?.trim();
      if (url == null || url.isEmpty) {
        await launchWeb('https://my.tuna.am/tunnels');
        return;
      }
      await launchWeb(url);
  }
}

Future<void> _runTunaUpgradeCommand() async {
  if (Platform.isWindows) {
    await _runCheckedProcess('powershell.exe', <String>[
      '-NoLogo',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      'winget upgrade --id yuccastream.tuna',
    ]);
    return;
  }

  if (Platform.isMacOS) {
    await _runCheckedProcess('brew', const <String>['upgrade', 'tuna']);
    return;
  }

  if (Platform.isLinux) {
    await _runCheckedProcess('sh', const <String>[
      '-c',
      r'$(curl -sSLf https://releases.tuna.am/tuna/get.sh)',
    ]);
    return;
  }

  throw UnsupportedError('Unsupported platform for tuna CLI upgrade');
}

Future<void> _runCheckedProcess(
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(executable, arguments, runInShell: true);

  if (result.exitCode == 0) {
    return;
  }

  final stderrText = result.stderr.toString().trim();
  final stdoutText = result.stdout.toString().trim();
  final details = stderrText.isNotEmpty ? stderrText : stdoutText;

  throw ProcessException(
    executable,
    arguments,
    details.isNotEmpty
        ? details
        : 'Command exited with code ${result.exitCode}',
    result.exitCode,
  );
}
