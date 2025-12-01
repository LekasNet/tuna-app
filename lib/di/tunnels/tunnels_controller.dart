// lib/di/tunnels/tunnels_controller.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/cli/cli_commands.dart';
import '../../core/cli/cli_controller.dart';
import '../../core/tunnels/tunnel_models.dart';
import 'tunnels_service.dart';

// lib/di/tunnels/tunnels_controller.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cli/cli_controller.dart';
import '../../core/tunnels/tunnel_models.dart';
import 'tunnels_service.dart';

class UpgradeInfo {
  final String currentVersion;
  final String newVersion;
  final String? url;

  const UpgradeInfo({
    required this.currentVersion,
    required this.newVersion,
    this.url,
  });
}

class ForwardingInfo {
  final String publicUrl;
  final String localTarget; // например, localhost:5173

  const ForwardingInfo({
    required this.publicUrl,
    required this.localTarget,
  });
}

class AccountInfo {
  final String name;
  final DateTime? paidTill;

  const AccountInfo({
    required this.name,
    this.paidTill,
  });
}

class TunnelsController extends ChangeNotifier {
  final TunnelsService _service;
  final CliController _cli;

  TunnelsController({
    required TunnelsService service,
    required CliController cli,
  })  : _service = service,
        _cli = cli;

  // prefs keys
  static const _accountNameKey = 'account_name';
  static const _accountPaidTillKey = 'account_paid_till';

  List<SavedTunnel> _tunnels = [];
  bool _initialized = false;

  /// id туннеля -> процесс
  final Map<String, Process> _runningProcesses = {};

  /// id туннеля -> мы сами инициировали остановку
  final Set<String> _stoppingIds = {};

  /// id -> полный лог (для экспорта)
  final Map<String, List<String>> _allLogs = {};

  /// id -> смещение для видимого лога (после очистки)
  final Map<String, int> _visibleOffset = {};

  /// id -> информация об обновлении
  final Map<String, UpgradeInfo> _upgrades = {};

  /// id -> Web Interface URL
  final Map<String, String> _webInterfaces = {};

  /// id -> Forwarding info
  final Map<String, ForwardingInfo> _forwardings = {};

  /// аккаунт тюны (один на всё приложение)
  AccountInfo? _accountInfo;

  /// выбранный тоннель для страницы деталей
  SavedTunnel? _selectedTunnel;

  // ---------------------------------------------------------------------------
  //                                GETTERS
  // ---------------------------------------------------------------------------

  bool get initialized => _initialized;
  List<SavedTunnel> get tunnels => List.unmodifiable(_tunnels);

  bool isRunning(String id) => _runningProcesses.containsKey(id);

  /// Видимый лог (после offset + без строк обновления / аккаунта / web iface / forwarding)
  List<String> logsFor(String id) {
    final all = _allLogs[id] ?? const [];
    final offset = _visibleOffset[id] ?? 0;
    if (offset >= all.length) return const [];

    return all.sublist(offset).where((line) {
      if (line.contains('New version available')) return false;
      if (line.contains('Update instructions:')) return false;
      if (line.contains('Account:')) return false;
      if (line.contains('Web Interface:')) return false;
      if (line.contains('Forwarding ')) return false;
      return true;
    }).toList();
  }

  /// Очистить ТОЛЬКО видимый лог (полный остаётся для экспорта)
  void clearVisibleLogs(String id) {
    final all = _allLogs[id];
    if (all == null) return;
    _visibleOffset[id] = all.length;
    notifyListeners();
  }

  UpgradeInfo? upgradeFor(String id) => _upgrades[id];

  /// Любое первое найденное обновление — для вывода в боковом меню
  UpgradeInfo? get latestUpgrade =>
      _upgrades.isEmpty ? null : _upgrades.values.first;

  String? webInterfaceFor(String id) => _webInterfaces[id];

  ForwardingInfo? forwardingFor(String id) => _forwardings[id];

  AccountInfo? get accountInfo => _accountInfo;

  SavedTunnel? get selectedTunnel => _selectedTunnel;

  // ---------------------------------------------------------------------------
  //                          SELECTION / LOAD / CRUD
  // ---------------------------------------------------------------------------

  void selectTunnel(String id) {
    try {
      _selectedTunnel = _tunnels.firstWhere((t) => t.id == id);
    } catch (_) {
      _selectedTunnel = null;
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedTunnel = null;
    notifyListeners();
  }

  Future<void> load() async {
    _tunnels = await _service.loadTunnels();
    await _loadAccountFromPrefs();
    _initialized = true;
    notifyListeners();
  }

  Future<void> addTunnel({
    required String name,
    required int localPort,
    required TunnelType type,
    String? ip,
    String? subdomain,
  }) async {
    final tunnel = SavedTunnel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      localPort: localPort,
      ip: ip?.isEmpty == true ? null : ip,
      subdomain: subdomain?.isEmpty == true ? null : subdomain,
      type: type,
      status: TunnelStatus.inactive,
    );

    _tunnels = [..._tunnels, tunnel];
    notifyListeners();
    await _service.saveTunnels(_tunnels);
  }

  Future<void> updateTunnel(SavedTunnel updated) async {
    _tunnels = _tunnels
        .map((t) => t.id == updated.id ? updated : t)
        .toList();

    if (_selectedTunnel?.id == updated.id) {
      _selectedTunnel = updated;
    }

    notifyListeners();
    await _service.saveTunnels(_tunnels);
  }

  Future<void> updateStatus(String id, TunnelStatus status) async {
    _tunnels = _tunnels
        .map((t) => t.id == id ? t.copyWith(status: status) : t)
        .toList();

    if (_selectedTunnel?.id == id) {
      _selectedTunnel = _selectedTunnel!.copyWith(status: status);
    }

    notifyListeners();
    await _service.saveTunnels(_tunnels);
  }

  Future<void> removeTunnel(String id) async {
    // если тоннель запущен — корректно остановим
    if (_runningProcesses.containsKey(id)) {
      final tunnel = _tunnels.firstWhere(
            (t) => t.id == id,
        orElse: () => throw Exception('Tunnel not found'),
      );
      await stopTunnel(tunnel);
    }

    _tunnels = _tunnels.where((t) => t.id != id).toList();
    _allLogs.remove(id);
    _visibleOffset.remove(id);
    _upgrades.remove(id);
    _webInterfaces.remove(id);
    _forwardings.remove(id);

    if (_selectedTunnel?.id == id) {
      _selectedTunnel = null;
    }

    notifyListeners();
    await _service.saveTunnels(_tunnels);
  }

  // ---------------------------------------------------------------------------
  //                                   LOGS
  // ---------------------------------------------------------------------------

  void _appendLog(String id, String line) {
    // убираем ANSI-коды цвета
    final cleaned = line.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

    _tryParseUpgrade(id, cleaned);
    _tryParseAccount(cleaned);
    _tryParseWebInterface(id, cleaned);
    _checkForwarding(id, cleaned);

    final list = _allLogs[id] ?? <String>[];
    list.add(cleaned);
    _allLogs[id] = list;

    notifyListeners();
  }

  // Можно вызывать извне (например, из SettingsController),
  // чтобы "скормить" строку лога и вытащить Account: ...
  void processProbeLogLine(String line) {
    final cleaned = line.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    _tryParseAccount(cleaned); // приватный метод уже есть
  }

  void _tryParseUpgrade(String id, String line) {
    // New version available: 0.27.0 -> 0.27.4
    final verMatch = RegExp(
      r'New version available:\s*([\w\.\-]+)\s*->\s*([\w\.\-]+)',
    ).firstMatch(line);

    if (verMatch != null) {
      final current = verMatch.group(1)!;
      final next = verMatch.group(2)!;
      final existing = _upgrades[id];
      _upgrades[id] = UpgradeInfo(
        currentVersion: current,
        newVersion: next,
        url: existing?.url,
      );
      return;
    }

    // Update instructions: https://...
    final urlMatch =
    RegExp(r'Update instructions:\s*(\S+)').firstMatch(line);
    if (urlMatch != null) {
      final url = urlMatch.group(1)!.trim();
      final existing = _upgrades[id];
      if (existing != null) {
        _upgrades[id] = UpgradeInfo(
          currentVersion: existing.currentVersion,
          newVersion: existing.newVersion,
          url: url,
        );
      } else {
        _upgrades[id] = UpgradeInfo(
          currentVersion: '',
          newVersion: '',
          url: url,
        );
      }
    }
  }

  void _tryParseAccount(String line) {
    // Account: Имя (Paid till 18.12.2025)
    final match = RegExp(
      r'^.*Account:\s*(.+?)(?:\s*\(Paid till\s+([0-9.]+)\))?\s*$',
    ).firstMatch(line);
    if (match == null) return;

    final name = match.group(1)!.trim();
    DateTime? paidTill;

    final dateStr = match.group(2);
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          paidTill = DateTime(year, month, day);
        }
      } catch (_) {
        // игнорируем, если не распарсилось
      }
    }

    _accountInfo = AccountInfo(name: name, paidTill: paidTill);
    _saveAccountToPrefs();
    notifyListeners();
  }

  void _tryParseWebInterface(String id, String line) {
    // Web Interface: http://127.0.0.1:4040
    final match =
    RegExp(r'Web Interface:\s*(\S+)').firstMatch(line);
    if (match == null) return;

    final url = match.group(1)!.trim();
    _webInterfaces[id] = url;
  }

  void _checkForwarding(String id, String line) {
    // INFO[...] Forwarding https://... -> localhost:5173
    final match = RegExp(
      r'Forwarding\s+(\S+)\s*->\s*(\S+)',
    ).firstMatch(line);

    if (match != null) {
      final publicUrl = match.group(1)!.trim();
      final local = match.group(2)!.trim();
      _forwardings[id] = ForwardingInfo(
        publicUrl: publicUrl,
        localTarget: local,
      );

      // через секунду переводим starting -> active, если всё ещё живёт
      Future.delayed(const Duration(seconds: 1), () {
        if (!_runningProcesses.containsKey(id)) return;

        final tIndex = _tunnels.indexWhere((t) => t.id == id);
        if (tIndex == -1) return;

        final current = _tunnels[tIndex].status;
        if (current == TunnelStatus.failed) return;

        updateStatus(id, TunnelStatus.active);
      });
    }
  }

  /// Экспорт полных логов в временный файл. Возвращает путь к файлу или null.
  Future<String?> exportLogsToTempFile(SavedTunnel tunnel) async {
    final logs = _allLogs[tunnel.id] ?? const [];
    if (logs.isEmpty) return null;

    final dir = Directory.systemTemp;
    final safeName =
    tunnel.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final file =
    File('${dir.path}/tuna_${safeName}_${tunnel.id}.log');

    await file.writeAsString(logs.join('\n'));
    return file.path;
  }

  // ---------------------------------------------------------------------------
  //                             START / STOP
  // ---------------------------------------------------------------------------

  /// Старт туннеля через CLI
  Future<void> startTunnel(SavedTunnel tunnel) async {
    if (_runningProcesses.containsKey(tunnel.id)) {
      // уже запущен
      return;
    }

    try {
      Process process;
      switch (tunnel.type) {
        case TunnelType.http:
          process = await _cli.startSimpleHttpTunnel(
            localPort: tunnel.localPort,
            localIp: tunnel.ip,
            subdomain: tunnel.subdomain,
          );
          break;
        case TunnelType.tcp:
          process = await _cli.startSimpleTcpTunnel(
            localPort: tunnel.localPort,
          );
          break;
      }

      final id = tunnel.id;
      _runningProcesses[id] = process;
      _stoppingIds.remove(id);
      _appendLog(id, '--- START ${tunnel.type.name.toUpperCase()} ---');

      // при старте ставим "запускается"
      await updateStatus(id, TunnelStatus.starting);

      // stdout
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLog(id, line);
      });

      // stderr
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLog(id, line);
      });

      // exit
      process.exitCode.then((code) {
        final wasStopping = _stoppingIds.remove(id);
        _runningProcesses.remove(id);

        TunnelStatus nextStatus;
        if (wasStopping) {
          nextStatus = TunnelStatus.inactive;
        } else {
          nextStatus =
          (code == 0) ? TunnelStatus.inactive : TunnelStatus.failed;
        }

        _appendLog(id, '--- EXIT code=$code ---');
        updateStatus(id, nextStatus);
      });
    } catch (e) {
      await updateStatus(tunnel.id, TunnelStatus.failed);
      _appendLog(tunnel.id, '[ERRO] Failed to start: $e');
      rethrow;
    }
  }

  /// Остановить туннель
  Future<void> stopTunnel(SavedTunnel tunnel) async {
    final process = _runningProcesses[tunnel.id];
    if (process == null) {
      return;
    }

    _stoppingIds.add(tunnel.id);
    bool killed = false;
    try {
      // пробуем SIGINT (Ctrl+C аналог)
      killed = process.kill(ProcessSignal.sigint);
    } catch (_) {
      killed = process.kill();
    }

    if (!killed) {
      _stoppingIds.remove(tunnel.id);
      _appendLog(tunnel.id, '[ERRO] Failed to send stop signal');
    }
    // exitCode обработается в then(...) в startTunnel
  }

  // ---------------------------------------------------------------------------
  //                             PREFS: ACCOUNT
  // ---------------------------------------------------------------------------

  Future<void> _loadAccountFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_accountNameKey);
    final paidTillStr = prefs.getString(_accountPaidTillKey);

    if (name == null) return;

    DateTime? paidTill;
    if (paidTillStr != null) {
      paidTill = DateTime.tryParse(paidTillStr);
    }

    _accountInfo = AccountInfo(name: name, paidTill: paidTill);
  }

  Future<void> _saveAccountToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final acc = _accountInfo;
    if (acc == null) {
      await prefs.remove(_accountNameKey);
      await prefs.remove(_accountPaidTillKey);
      return;
    }

    await prefs.setString(_accountNameKey, acc.name);
    if (acc.paidTill != null) {
      await prefs.setString(
        _accountPaidTillKey,
        acc.paidTill!.toIso8601String(),
      );
    } else {
      await prefs.remove(_accountPaidTillKey);
    }
  }

  Future<void> resetAccountInfo() async {
    _accountInfo = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountNameKey);
    await prefs.remove(_accountPaidTillKey);
    notifyListeners();
  }

}
