import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/tunnels/tunnel_models.dart';

class TunnelsService {
  static const _keyTunnels = 'tunnels_list';

  Future<List<SavedTunnel>> loadTunnels() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyTunnels) ?? [];

    return rawList
        .map((e) => SavedTunnel.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTunnels(List<SavedTunnel> tunnels) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList =
    tunnels.map((t) => jsonEncode(t.toJson())).toList(growable: false);
    await prefs.setStringList(_keyTunnels, rawList);
  }
}
