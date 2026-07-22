import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../tunnels/tunnel_models.dart';
import '../../di/tunnels/tunnels_controller.dart';

class MacosStatusBarService {
  static const MethodChannel _channel = MethodChannel(
    'ru.lek4s.tuna/status_bar',
  );

  final TunnelsController _tunnelsController;

  MacosStatusBarService({required TunnelsController tunnelsController})
    : _tunnelsController = tunnelsController;

  Future<void> initialize() async {
    if (!Platform.isMacOS) return;

    _channel.setMethodCallHandler(_handleNativeCall);
    _tunnelsController.addListener(_syncMenu);
    try {
      await _channel.invokeMethod<void>('initialize');
      await _syncMenu();
    } on MissingPluginException catch (error, stackTrace) {
      _tunnelsController.removeListener(_syncMenu);
      debugPrint('macOS status bar channel is not available: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void dispose() {
    if (!Platform.isMacOS) return;
    _tunnelsController.removeListener(_syncMenu);
    _channel.setMethodCallHandler(null);
  }

  static Future<void> hideWindow() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('hideWindow');
    } on MissingPluginException catch (error) {
      debugPrint('macOS status bar hideWindow is not available: $error');
      await windowManager.hide();
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'statusBarToggleTunnel':
        final id = call.arguments as String?;
        if (id == null) return;
        await _toggleTunnel(id);
        break;
      case 'statusBarStopAll':
        await _tunnelsController.stopAllTunnels();
        break;
    }

    await _syncMenu();
  }

  Future<void> _toggleTunnel(String id) async {
    SavedTunnel? tunnel;
    for (final item in _tunnelsController.tunnels) {
      if (item.id == id) {
        tunnel = item;
        break;
      }
    }
    if (tunnel == null) return;

    if (_tunnelsController.isRunning(tunnel.id)) {
      await _tunnelsController.stopTunnel(tunnel);
    } else {
      await _tunnelsController.startTunnel(tunnel);
    }
  }

  Future<void> _syncMenu() async {
    if (!Platform.isMacOS) return;

    final items = _recentTunnels()
        .map(_serializeTunnel)
        .toList(growable: false);

    await _channel.invokeMethod<void>('updateMenu', <String, Object?>{
      'tunnels': items,
      'hasRunningTunnels': _tunnelsController.tunnels.any(
        (item) => _tunnelsController.isRunning(item.id),
      ),
    });
  }

  List<SavedTunnel> _recentTunnels() {
    final tunnels = _tunnelsController.tunnels.toList(growable: false);
    tunnels.sort((a, b) {
      final aTime = a.lastStartedAt;
      final bTime = b.lastStartedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return tunnels.take(3).toList(growable: false);
  }

  Map<String, Object?> _serializeTunnel(SavedTunnel tunnel) {
    final running = _tunnelsController.isRunning(tunnel.id);
    return <String, Object?>{
      'id': tunnel.id,
      'name': tunnel.name,
      'type': tunnel.type.name,
      'localPort': tunnel.localPort,
      'running': running,
    };
  }
}
