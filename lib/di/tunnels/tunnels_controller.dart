import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/tuna_api_service.dart';
import '../../core/cli/cli_commands.dart';
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
  final String localTarget;

  const ForwardingInfo({required this.publicUrl, required this.localTarget});
}

class AccountInfo {
  final String name;
  final DateTime? paidTill;

  const AccountInfo({required this.name, this.paidTill});
}

class RunningTunnelProbeResult {
  final int localMatchedCount;
  final int remoteMatchedCount;
  final int remoteActiveCount;
  final int remoteOnlyCount;

  const RunningTunnelProbeResult({
    required this.localMatchedCount,
    required this.remoteMatchedCount,
    required this.remoteActiveCount,
    required this.remoteOnlyCount,
  });
}

class _LocalProcessTunnel {
  final int pid;
  final TunnelType type;
  final int localPort;

  const _LocalProcessTunnel({
    required this.pid,
    required this.type,
    required this.localPort,
  });
}

class TunnelsController extends ChangeNotifier {
  static const int _maxVisibleLogLines = 750;

  final TunnelsService _service;
  final CliController _cli;
  final TunaApiService _tunaApiService;

  TunnelsController({
    required TunnelsService service,
    required CliController cli,
    TunaApiService? tunaApiService,
  }) : _service = service,
       _cli = cli,
       _tunaApiService = tunaApiService ?? TunaApiService();

  static const _accountNameKey = 'account_name';
  static const _accountPaidTillKey = 'account_paid_till';

  List<SavedTunnel> _tunnels = <SavedTunnel>[];
  bool _initialized = false;

  final Map<String, Process> _runningProcesses = <String, Process>{};
  final Map<String, int> _externalLocalPids = <String, int>{};
  final Set<String> _stoppingIds = <String>{};

  final Map<String, List<String>> _allLogs = <String, List<String>>{};
  final Map<String, int> _visibleOffset = <String, int>{};
  final Map<String, UpgradeInfo> _upgrades = <String, UpgradeInfo>{};
  final Map<String, String> _webInterfaces = <String, String>{};
  final Map<String, ForwardingInfo> _forwardings = <String, ForwardingInfo>{};

  AccountInfo? _accountInfo;
  SavedTunnel? _selectedTunnel;
  int _remoteActiveCount = 0;

  bool get initialized => _initialized;
  int get remoteActiveCount => _remoteActiveCount;
  List<SavedTunnel> get tunnels => List.unmodifiable(_tunnels);
  AccountInfo? get accountInfo => _accountInfo;
  SavedTunnel? get selectedTunnel => _selectedTunnel;
  UpgradeInfo? get latestUpgrade =>
      _upgrades.isEmpty ? null : _upgrades.values.first;

  bool isRunning(String id) {
    return _runningProcesses.containsKey(id) ||
        _externalLocalPids.containsKey(id);
  }

  UpgradeInfo? upgradeFor(String id) => _upgrades[id];
  String? webInterfaceFor(String id) => _webInterfaces[id];
  ForwardingInfo? forwardingFor(String id) => _forwardings[id];
  bool hasKnownPublicUrl(String? publicUrl) {
    final expected = _normalizePublicUrl(publicUrl);
    if (expected == null) return false;

    for (final forwarding in _forwardings.values) {
      final current = _normalizePublicUrl(forwarding.publicUrl);
      if (current == expected) {
        return true;
      }
    }

    return false;
  }

  List<String> logsFor(String id) {
    final all = _allLogs[id] ?? const <String>[];
    final offset = _visibleOffset[id] ?? 0;
    if (offset >= all.length) return const <String>[];

    final visible = <String>[];
    for (var i = all.length - 1; i >= offset; i--) {
      final line = all[i];
      if (_shouldHideFromVisibleLog(line)) continue;

      visible.add(line);
      if (visible.length >= _maxVisibleLogLines) break;
    }

    return visible.reversed.toList(growable: false);
  }

  void clearVisibleLogs(String id) {
    final all = _allLogs[id];
    if (all == null) return;
    _visibleOffset[id] = all.length;
    notifyListeners();
  }

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

  Future<RunningTunnelProbeResult> reconcileRunningTunnels({
    String? apiKey,
    String? token,
  }) async {
    final localProcesses = await _detectLocalRunningTunnels();
    final localMatchedIds = _matchLocalRunningTunnels(localProcesses);

    final remoteActiveTunnels = await _tunaApiService.fetchActiveTunnels(
      apiKey: apiKey,
      token: token,
    );
    final remoteMatchedIds = _matchRemoteTunnels(remoteActiveTunnels);

    final activeIds = <String>{..._runningProcesses.keys, ...localMatchedIds};

    final statusChanged = _applyStatusesByActiveIds(activeIds);
    if (statusChanged) {
      await _service.saveTunnels(_tunnels);
    }

    final remoteOnlyCount =
        remoteActiveTunnels.length - remoteMatchedIds.length;
    final prevRemoteCount = _remoteActiveCount;
    _remoteActiveCount = remoteActiveTunnels.length;

    if (statusChanged || prevRemoteCount != _remoteActiveCount) {
      notifyListeners();
    }

    return RunningTunnelProbeResult(
      localMatchedCount: localMatchedIds.length,
      remoteMatchedCount: remoteMatchedIds.length,
      remoteActiveCount: remoteActiveTunnels.length,
      remoteOnlyCount: remoteOnlyCount < 0 ? 0 : remoteOnlyCount,
    );
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

    _tunnels = <SavedTunnel>[..._tunnels, tunnel];
    notifyListeners();
    await _service.saveTunnels(_tunnels);
  }

  Future<void> updateTunnel(SavedTunnel updated) async {
    _tunnels = _tunnels
        .map((t) => t.id == updated.id ? updated : t)
        .toList(growable: false);

    if (_selectedTunnel?.id == updated.id) {
      _selectedTunnel = updated;
    }

    notifyListeners();
    await _service.saveTunnels(_tunnels);
  }

  Future<void> updateStatus(String id, TunnelStatus status) async {
    _tunnels = _tunnels
        .map((t) => t.id == id ? t.copyWith(status: status) : t)
        .toList(growable: false);

    if (_selectedTunnel?.id == id) {
      _selectedTunnel = _selectedTunnel!.copyWith(status: status);
    }

    notifyListeners();
    await _service.saveTunnels(_tunnels);
  }

  Future<void> removeTunnel(String id) async {
    if (isRunning(id)) {
      final tunnel = _tunnels.firstWhere(
        (t) => t.id == id,
        orElse: () => throw Exception('Tunnel not found'),
      );
      await stopTunnel(tunnel);
    }

    _tunnels = _tunnels.where((t) => t.id != id).toList(growable: false);
    _externalLocalPids.remove(id);
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

  void _appendLog(String id, String line) {
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

  void processProbeLogLine(String line) {
    final cleaned = line.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    _tryParseAccount(cleaned);
  }

  void _tryParseUpgrade(String id, String line) {
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

    final urlMatch = RegExp(r'Update instructions:\s*(\S+)').firstMatch(line);
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
      } catch (_) {}
    }

    _accountInfo = AccountInfo(name: name, paidTill: paidTill);
    unawaited(_saveAccountToPrefs());
    notifyListeners();
  }

  void _tryParseWebInterface(String id, String line) {
    final match = RegExp(r'Web Interface:\s*(\S+)').firstMatch(line);
    if (match == null) return;

    final url = match.group(1)!.trim();
    _webInterfaces[id] = url;
  }

  void _checkForwarding(String id, String line) {
    final match = RegExp(r'Forwarding\s+(\S+)\s*->\s*(\S+)').firstMatch(line);

    if (match != null) {
      final publicUrl = match.group(1)!.trim();
      final local = match.group(2)!.trim();
      _forwardings[id] = ForwardingInfo(
        publicUrl: publicUrl,
        localTarget: local,
      );

      Future<void>.delayed(const Duration(seconds: 1), () {
        if (!_runningProcesses.containsKey(id) &&
            !_externalLocalPids.containsKey(id)) {
          return;
        }

        final index = _tunnels.indexWhere((t) => t.id == id);
        if (index == -1) return;

        final current = _tunnels[index].status;
        if (current == TunnelStatus.failed) return;

        updateStatus(id, TunnelStatus.active);
      });
    }
  }

  Future<String?> exportLogsToTempFile(SavedTunnel tunnel) async {
    final logs = _allLogs[tunnel.id] ?? const <String>[];
    if (logs.isEmpty) return null;

    final dir = Directory.systemTemp;
    final safeName = tunnel.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final file = File('${dir.path}/tuna_${safeName}_${tunnel.id}.log');

    await file.writeAsString(logs.join('\n'));
    return file.path;
  }

  Future<void> startTunnel(SavedTunnel tunnel) async {
    if (isRunning(tunnel.id)) {
      return;
    }

    try {
      late Process process;
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
      _externalLocalPids.remove(id);
      _stoppingIds.remove(id);
      _appendLog(id, '--- START ${tunnel.type.name.toUpperCase()} ---');

      await updateStatus(id, TunnelStatus.starting);

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _appendLog(id, line);
          });

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _appendLog(id, line);
          });

      process.exitCode.then((code) {
        final wasStopping = _stoppingIds.remove(id);
        _runningProcesses.remove(id);

        final nextStatus = wasStopping
            ? TunnelStatus.inactive
            : (code == 0 ? TunnelStatus.inactive : TunnelStatus.failed);

        _appendLog(id, '--- EXIT code=$code ---');
        updateStatus(id, nextStatus);
      });
    } catch (e) {
      await updateStatus(tunnel.id, TunnelStatus.failed);
      _appendLog(tunnel.id, '[ERRO] Failed to start: $e');
      rethrow;
    }
  }

  Future<void> stopTunnel(SavedTunnel tunnel) async {
    final process = _runningProcesses[tunnel.id];
    if (process != null) {
      _stoppingIds.add(tunnel.id);
      var killed = false;
      try {
        killed = process.kill(ProcessSignal.sigint);
      } catch (_) {
        killed = process.kill();
      }

      if (!killed) {
        _stoppingIds.remove(tunnel.id);
        _appendLog(tunnel.id, '[ERRO] Failed to send stop signal');
      }
      return;
    }

    final externalPid = _externalLocalPids[tunnel.id];
    if (externalPid == null) {
      return;
    }

    final killed = Process.killPid(externalPid);
    if (killed) {
      _externalLocalPids.remove(tunnel.id);
      await updateStatus(tunnel.id, TunnelStatus.inactive);
      _appendLog(
        tunnel.id,
        '[INFO] Stopped external tuna process pid=$externalPid',
      );
    } else {
      _appendLog(
        tunnel.id,
        '[ERRO] Failed to stop external tuna process pid=$externalPid',
      );
    }
  }

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

  bool _applyStatusesByActiveIds(Set<String> activeIds) {
    var changed = false;
    _tunnels = _tunnels
        .map((tunnel) {
          final expected = activeIds.contains(tunnel.id)
              ? TunnelStatus.active
              : TunnelStatus.inactive;

          if (tunnel.status == expected) return tunnel;
          changed = true;
          return tunnel.copyWith(status: expected);
        })
        .toList(growable: false);

    if (_selectedTunnel != null) {
      final updated = _tunnels
          .where((t) => t.id == _selectedTunnel!.id)
          .toList();
      if (updated.isNotEmpty) {
        _selectedTunnel = updated.first;
      }
    }

    return changed;
  }

  bool _shouldHideFromVisibleLog(String line) {
    if (line.contains('New version available')) return true;
    if (line.contains('Update instructions:')) return true;
    if (line.contains('Account:')) return true;
    if (line.contains('Web Interface:')) return true;
    if (line.contains('Forwarding ')) return true;
    return false;
  }

  Set<String> _matchLocalRunningTunnels(List<_LocalProcessTunnel> processes) {
    final matchedIds = <String>{};
    final pool = List<_LocalProcessTunnel>.from(processes);

    for (final tunnel in _tunnels) {
      final index = pool.indexWhere((p) {
        return p.type == tunnel.type && p.localPort == tunnel.localPort;
      });

      if (index == -1) {
        _externalLocalPids.remove(tunnel.id);
        continue;
      }

      final process = pool.removeAt(index);
      _externalLocalPids[tunnel.id] = process.pid;
      matchedIds.add(tunnel.id);
    }

    return matchedIds;
  }

  Set<String> _matchRemoteTunnels(List<RemoteTunnelSnapshot> remote) {
    final matched = <String>{};

    for (final item in remote) {
      final protocol = item.protocol?.toLowerCase().trim() ?? '';
      final type = protocol.contains('tcp') ? TunnelType.tcp : TunnelType.http;
      final port = _extractLocalPort(item.forwardsTo);
      if (port == null) continue;

      final tunnel = _tunnels.where((t) {
        return t.type == type && t.localPort == port;
      }).toList();
      if (tunnel.isNotEmpty) {
        matched.add(tunnel.first.id);
      }
    }

    return matched;
  }

  int? _extractLocalPort(String? forwardsTo) {
    final raw = forwardsTo?.trim();
    if (raw == null || raw.isEmpty) return null;

    final match = RegExp(r':(\d+)$').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String? _normalizePublicUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return raw.toLowerCase();
    }

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final port = uri.hasPort ? ':${uri.port}' : '';
    final path = uri.path == '/' ? '' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';

    return '$scheme://$host$port$path$query';
  }

  Future<List<_LocalProcessTunnel>> _detectLocalRunningTunnels() async {
    if (Platform.isWindows) {
      return _detectWindowsRunningTunnels();
    }
    return _detectPosixRunningTunnels();
  }

  Future<List<_LocalProcessTunnel>> _detectWindowsRunningTunnels() async {
    const script = r'''
$items = Get-CimInstance Win32_Process |
  Where-Object {
    ($_.Name -match '^tuna(\.exe)?$') -or
    ($_.CommandLine -match '(^|\s)tuna(\.exe)?(\s|$)')
  } |
  Select-Object ProcessId, CommandLine
$items | ConvertTo-Json -Compress
''';

    try {
      final result = await Process.run('powershell.exe', <String>[
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ]);

      if (result.exitCode != 0) return const <_LocalProcessTunnel>[];

      final out = (result.stdout as String?)?.trim() ?? '';
      if (out.isEmpty) return const <_LocalProcessTunnel>[];

      final parsed = jsonDecode(out);
      final list = parsed is List ? parsed : <dynamic>[parsed];

      final matches = <_LocalProcessTunnel>[];
      for (final item in list.whereType<Map<String, dynamic>>()) {
        final pid = item['ProcessId'];
        final cmd = (item['CommandLine'] as String?)?.trim() ?? '';
        final detected = _parseProcessCommandLine(
          pid: pid is int ? pid : int.tryParse('$pid') ?? -1,
          commandLine: cmd,
        );
        if (detected != null) {
          matches.add(detected);
        }
      }
      return matches;
    } catch (_) {
      return const <_LocalProcessTunnel>[];
    }
  }

  Future<List<_LocalProcessTunnel>> _detectPosixRunningTunnels() async {
    try {
      final result = await Process.run('ps', <String>['-eo', 'pid=,args=']);
      if (result.exitCode != 0) return const <_LocalProcessTunnel>[];

      final raw = (result.stdout as String?) ?? '';
      final lines = const LineSplitter().convert(raw);

      final matches = <_LocalProcessTunnel>[];
      for (final line in lines) {
        final firstSpace = line.trimLeft().indexOf(' ');
        if (firstSpace <= 0) continue;

        final leftTrimmed = line.trimLeft();
        final pidRaw = leftTrimmed.substring(0, firstSpace).trim();
        final cmd = leftTrimmed.substring(firstSpace + 1).trim();

        final pid = int.tryParse(pidRaw);
        if (pid == null) continue;

        final detected = _parseProcessCommandLine(pid: pid, commandLine: cmd);
        if (detected != null) {
          matches.add(detected);
        }
      }

      return matches;
    } catch (_) {
      return const <_LocalProcessTunnel>[];
    }
  }

  _LocalProcessTunnel? _parseProcessCommandLine({
    required int pid,
    required String commandLine,
  }) {
    if (pid <= 0 || commandLine.isEmpty) return null;

    final match = RegExp(
      r'(?:^|\s)tuna(?:\.exe)?\s+(http|tcp)\s+([^\s]+)',
      caseSensitive: false,
    ).firstMatch(commandLine);
    if (match == null) return null;

    final rawType = (match.group(1) ?? '').toLowerCase();
    final rawAddress = (match.group(2) ?? '').trim();
    if (rawAddress.isEmpty) return null;

    final type = rawType == 'tcp' ? TunnelType.tcp : TunnelType.http;

    int? port;
    if (rawAddress.contains(':')) {
      port = int.tryParse(rawAddress.split(':').last);
    } else {
      port = int.tryParse(rawAddress);
    }

    if (port == null) return null;

    return _LocalProcessTunnel(pid: pid, type: type, localPort: port);
  }
}
