import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/docker/docker_service.dart';

class DockerController extends ChangeNotifier {
  final DockerService _dockerService;

  DockerController({DockerService? dockerService})
    : _dockerService = dockerService ?? DockerService();

  bool _loadingContainers = false;
  String? _containersError;
  String? _selectedContainerId;
  List<DockerContainerSummary> _containers = const <DockerContainerSummary>[];

  final Map<String, bool> _detailsLoading = <String, bool>{};
  final Map<String, String?> _detailsError = <String, String?>{};
  final Map<String, List<DockerTunnelProcess>> _tunnelsByContainer =
      <String, List<DockerTunnelProcess>>{};
  final Map<String, List<String>> _containerLogsByContainer =
      <String, List<String>>{};
  final Map<String, Map<int, List<String>>> _tunnelLogsByContainer =
      <String, Map<int, List<String>>>{};
  final Map<String, int?> _selectedTunnelPidByContainer = <String, int?>{};
  final Set<String> _stoppingKeys = <String>{};

  bool get loadingContainers => _loadingContainers;
  String? get containersError => _containersError;
  List<DockerContainerSummary> get containers => List.unmodifiable(_containers);
  String? get selectedContainerId => _selectedContainerId;

  DockerContainerSummary? get selectedContainer {
    final id = _selectedContainerId;
    if (id == null) return null;

    for (final container in _containers) {
      if (container.id == id) {
        return container;
      }
    }
    return null;
  }

  bool isDetailsLoading(String containerId) {
    return _detailsLoading[containerId] == true;
  }

  String? detailsError(String containerId) {
    return _detailsError[containerId];
  }

  List<DockerTunnelProcess> tunnelsFor(String containerId) {
    return List.unmodifiable(_tunnelsByContainer[containerId] ?? const []);
  }

  List<String> containerLogsFor(String containerId) {
    return List.unmodifiable(
      _containerLogsByContainer[containerId] ?? const [],
    );
  }

  int? selectedTunnelPidFor(String containerId) {
    return _selectedTunnelPidByContainer[containerId];
  }

  List<String> selectedLogsFor(String containerId) {
    final selectedPid = _selectedTunnelPidByContainer[containerId];
    if (selectedPid == null) {
      return containerLogsFor(containerId);
    }

    final logsMap = _tunnelLogsByContainer[containerId];
    final logs = logsMap?[selectedPid];
    if (logs == null || logs.isEmpty) {
      return containerLogsFor(containerId);
    }
    return List.unmodifiable(logs);
  }

  bool isStoppingTunnel(String containerId, int pid) {
    return _stoppingKeys.contains(_stopKey(containerId, pid));
  }

  Future<void> refreshContainers() async {
    _loadingContainers = true;
    _containersError = null;
    notifyListeners();

    try {
      final items = await _dockerService.listContainers();
      _containers = items;

      if (_containers.isEmpty) {
        _selectedContainerId = null;
      } else {
        final current = _selectedContainerId;
        final exists =
            current != null && _containers.any((c) => c.id == current);
        if (!exists) _selectedContainerId = null;
      }
    } catch (e) {
      _containers = const <DockerContainerSummary>[];
      _selectedContainerId = null;
      _containersError = _asErrorText(e);
    } finally {
      _loadingContainers = false;
      notifyListeners();
    }

    final selectedId = _selectedContainerId;
    if (selectedId != null) {
      await loadContainerDetails(selectedId, force: true);
    }
  }

  void clearSelectedContainer() {
    if (_selectedContainerId == null) return;
    _selectedContainerId = null;
    notifyListeners();
  }

  void selectContainer(String containerId) {
    if (_selectedContainerId == containerId) return;

    _selectedContainerId = containerId;
    notifyListeners();
    unawaited(loadContainerDetails(containerId));
  }

  void selectLogSource(String containerId, {int? tunnelPid}) {
    final previous = _selectedTunnelPidByContainer[containerId];
    if (previous == tunnelPid) return;

    _selectedTunnelPidByContainer[containerId] = tunnelPid;
    notifyListeners();
  }

  Future<void> loadContainerDetails(
    String containerId, {
    bool force = false,
  }) async {
    if (!force && _detailsLoading[containerId] == true) {
      return;
    }

    final hasCached =
        _tunnelsByContainer.containsKey(containerId) &&
        _containerLogsByContainer.containsKey(containerId);
    if (!force && hasCached) {
      return;
    }

    _detailsLoading[containerId] = true;
    _detailsError[containerId] = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _dockerService.listContainerTunnels(containerId),
        _dockerService.readContainerLogs(containerId),
      ]);

      final tunnels = (results[0] as List<DockerTunnelProcess>).toList(
        growable: false,
      );
      final logs = (results[1] as List<String>).toList(growable: false);

      _tunnelsByContainer[containerId] = tunnels;
      _containerLogsByContainer[containerId] = logs;
      _tunnelLogsByContainer[containerId] = _buildTunnelLogsMap(tunnels, logs);
      _detailsError[containerId] = null;

      final selectedPid = _selectedTunnelPidByContainer[containerId];
      final selectedExists =
          selectedPid != null && tunnels.any((item) => item.pid == selectedPid);
      if (!selectedExists) {
        _selectedTunnelPidByContainer[containerId] = null;
      }
    } catch (e) {
      _detailsError[containerId] = _asErrorText(e);
      _tunnelsByContainer[containerId] = const <DockerTunnelProcess>[];
      _containerLogsByContainer.putIfAbsent(
        containerId,
        () => const <String>[],
      );
      _tunnelLogsByContainer[containerId] = const <int, List<String>>{};
      _selectedTunnelPidByContainer[containerId] = null;
    } finally {
      _detailsLoading[containerId] = false;
      notifyListeners();
    }
  }

  Future<bool> stopTunnel(
    String containerId,
    DockerTunnelProcess tunnel,
  ) async {
    final key = _stopKey(containerId, tunnel.pid);
    if (_stoppingKeys.contains(key)) return false;

    _stoppingKeys.add(key);
    notifyListeners();

    try {
      final ok = await _dockerService.stopTunnelProcess(
        containerId: containerId,
        pid: tunnel.pid,
      );
      if (!ok) {
        _detailsError[containerId] =
            'Не удалось остановить туннель в контейнере.';
        notifyListeners();
        return false;
      }

      await loadContainerDetails(containerId, force: true);
      return true;
    } finally {
      _stoppingKeys.remove(key);
      notifyListeners();
    }
  }

  Map<int, List<String>> _buildTunnelLogsMap(
    List<DockerTunnelProcess> tunnels,
    List<String> containerLogs,
  ) {
    final map = <int, List<String>>{};
    for (final tunnel in tunnels) {
      map[tunnel.pid] = _filterLogsForTunnel(containerLogs, tunnel);
    }
    return map;
  }

  List<String> _filterLogsForTunnel(
    List<String> logs,
    DockerTunnelProcess tunnel,
  ) {
    if (logs.isEmpty) return const <String>[];

    final tokens = <String>{
      tunnel.address,
      if (tunnel.localPort != null) ':${tunnel.localPort}',
      if (tunnel.localPort != null) ' ${tunnel.localPort}',
    }..removeWhere((token) => token.trim().isEmpty);

    var filtered = logs
        .where((line) {
          for (final token in tokens) {
            if (line.contains(token)) {
              return true;
            }
          }
          return false;
        })
        .toList(growable: false);

    if (filtered.isEmpty) {
      final command = tunnel.commandLine.trim();
      if (command.isNotEmpty) {
        filtered = logs
            .where((line) => line.contains(command))
            .toList(growable: false);
      }
    }

    if (filtered.isEmpty) {
      return _tail(logs, 200);
    }

    return _tail(filtered, 400);
  }

  List<String> _tail(List<String> lines, int limit) {
    if (lines.length <= limit) return lines;
    return lines.sublist(lines.length - limit);
  }

  String _asErrorText(Object error) {
    if (error is DockerServiceException) {
      return error.message;
    }
    return 'Не удалось выполнить docker-операцию.';
  }

  String _stopKey(String containerId, int pid) {
    return '$containerId:$pid';
  }
}
