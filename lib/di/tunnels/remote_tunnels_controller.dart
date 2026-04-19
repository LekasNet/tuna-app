import 'package:flutter/foundation.dart';

import '../../core/api/tuna_api_service.dart';

class RemoteTunnelsController extends ChangeNotifier {
  final TunaApiService _tunaApiService;

  RemoteTunnelsController({TunaApiService? tunaApiService})
    : _tunaApiService = tunaApiService ?? TunaApiService();

  bool _loading = false;
  String? _error;
  final Set<int> _stoppingTunnelIds = <int>{};
  List<RemoteTunnelSnapshot> _tunnels = const <RemoteTunnelSnapshot>[];

  bool get loading => _loading;
  String? get error => _error;
  List<RemoteTunnelSnapshot> get tunnels => List.unmodifiable(_tunnels);

  bool isStopping(RemoteTunnelSnapshot tunnel) {
    final id = tunnel.id;
    return id != null && _stoppingTunnelIds.contains(id);
  }

  Future<void> refresh({String? apiKey, String? token}) async {
    final hasApiKey = (apiKey?.trim().isNotEmpty ?? false);
    final hasToken = (token?.trim().isNotEmpty ?? false);
    if (!hasApiKey && !hasToken) {
      _tunnels = const <RemoteTunnelSnapshot>[];
      _error = 'Для загрузки удалённых туннелей нужен API key или token.';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await _tunaApiService.fetchActiveTunnels(
        apiKey: apiKey,
        token: token,
      );

      _tunnels = List<RemoteTunnelSnapshot>.from(list)
        ..sort((a, b) {
          final aKey = a.publicUrl ?? a.uid;
          final bKey = b.publicUrl ?? b.uid;
          return aKey.compareTo(bKey);
        });
    } catch (_) {
      _error = 'Не удалось загрузить удалённые туннели.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> stopTunnel(
    RemoteTunnelSnapshot tunnel, {
    String? apiKey,
    String? token,
  }) async {
    final id = tunnel.id;
    if (id == null) {
      _error = 'Нельзя остановить туннель без ID.';
      notifyListeners();
      return false;
    }
    if (_stoppingTunnelIds.contains(id)) return false;

    _stoppingTunnelIds.add(id);
    notifyListeners();

    try {
      final ok = await _tunaApiService.deleteTunnel(
        tunnelId: id,
        apiKey: apiKey,
        token: token,
      );

      if (!ok) {
        _error = 'Не удалось остановить удалённый туннель.';
        return false;
      }

      _error = null;
      _tunnels = _tunnels
          .where((item) => item.id != id)
          .toList(growable: false);
      return true;
    } finally {
      _stoppingTunnelIds.remove(id);
      notifyListeners();
    }
  }
}
