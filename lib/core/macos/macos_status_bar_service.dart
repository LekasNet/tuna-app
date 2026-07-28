import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../cli/cli_commands.dart';
import '../tunnels/tunnel_models.dart';
import '../../di/tabs/tabs_controller.dart';
import '../../di/tunnels/tunnels_controller.dart';

class MacosStatusBarService {
  static const MethodChannel _channel = MethodChannel(
    'ru.lek4s.tuna/status_bar',
  );

  final TunnelsController _tunnelsController;
  final TabsController _tabsController;

  MacosStatusBarService({
    required TunnelsController tunnelsController,
    required TabsController tabsController,
  }) : _tunnelsController = tunnelsController,
       _tabsController = tabsController;

  static bool get _isSupportedPlatform => Platform.isMacOS || Platform.isWindows;

  Future<void> initialize() async {
    if (!_isSupportedPlatform) return;

    _channel.setMethodCallHandler(_handleNativeCall);
    _tunnelsController.addListener(_syncMenu);
    try {
      await _channel.invokeMethod<void>('initialize');
      await _syncMenu();
    } on MissingPluginException catch (error, stackTrace) {
      _tunnelsController.removeListener(_syncMenu);
      debugPrint('desktop status bar channel is not available: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void dispose() {
    if (!_isSupportedPlatform) return;
    _tunnelsController.removeListener(_syncMenu);
    _channel.setMethodCallHandler(null);
  }

  static Future<void> hideWindow() async {
    if (!_isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('hideWindow');
    } on MissingPluginException catch (error) {
      debugPrint('desktop status bar hideWindow is not available: $error');
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
      case 'statusBarOpenTunnel':
        final id = call.arguments as String?;
        if (id == null) return;
        await _openTunnel(id);
        break;
      case 'statusBarStopAll':
        await _tunnelsController.stopAllTunnels();
        break;
    }

    await _syncMenu();
  }

  Future<void> _openTunnel(String id) async {
    _tunnelsController.selectTunnel(id);
    _tabsController.selectTab(AppTab.tunnels);

    if (Platform.isMacOS || Platform.isWindows) {
      await windowManager.show();
      await windowManager.focus();
    }
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
    if (!_isSupportedPlatform) return;

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
    final forwarding = _tunnelsController.forwardingFor(tunnel.id);
    return <String, Object?>{
      'id': tunnel.id,
      'name': tunnel.name,
      'type': tunnel.type.name,
      'localPort': tunnel.localPort,
      'status': tunnel.status.name,
      'running': running,
      'localAddress': _localAddressFor(tunnel),
      'publicUrl': forwarding?.publicUrl,
    };
  }

  String _localAddressFor(SavedTunnel tunnel) {
    if (tunnel.type == TunnelType.ssh) {
      return 'SSH';
    }

    final host = tunnel.ip == null || tunnel.ip!.trim().isEmpty
        ? '127.0.0.1'
        : tunnel.ip!.trim();
    return '$host:${tunnel.localPort}';
  }
}
