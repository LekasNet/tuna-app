import 'dart:convert';
import 'dart:io';

class RemoteTunnelSnapshot {
  final int? id;
  final String uid;
  final bool active;
  final String? protocol;
  final String? forwardsTo;
  final String? forwardsToHost;
  final String? publicUrl;
  final String? clientName;
  final String? location;
  final String? clientAddress;

  const RemoteTunnelSnapshot({
    required this.id,
    required this.uid,
    required this.active,
    this.protocol,
    this.forwardsTo,
    this.forwardsToHost,
    this.publicUrl,
    this.clientName,
    this.location,
    this.clientAddress,
  });
}

enum _DeleteTunnelRequestResult { success, unauthorized, failed }

class TunaApiService {
  static const _tunnelsBaseEndpoint = 'https://my.tuna.am/v1/tunnels';

  Future<List<RemoteTunnelSnapshot>> fetchActiveTunnels({
    String? apiKey,
    String? token,
  }) {
    return fetchTunnels(apiKey: apiKey, token: token, onlyActive: true);
  }

  Future<List<RemoteTunnelSnapshot>> fetchTunnels({
    String? apiKey,
    String? token,
    bool onlyActive = false,
  }) async {
    final authValue = _pickAuthValue(apiKey: apiKey, token: token);

    if (authValue == null) {
      return const <RemoteTunnelSnapshot>[];
    }

    final variants = <String>{
      if (authValue.startsWith('Bearer ')) authValue else 'Bearer $authValue',
      authValue,
    };

    for (final headerValue in variants) {
      final result = await _requestTunnels(headerValue);
      if (result == null) continue;
      if (!onlyActive) return result;
      return result.where((t) => t.active).toList(growable: false);
    }

    return const <RemoteTunnelSnapshot>[];
  }

  Future<bool> deleteTunnel({
    required int tunnelId,
    String? apiKey,
    String? token,
  }) async {
    final authValue = _pickAuthValue(apiKey: apiKey, token: token);
    if (authValue == null) return false;

    final variants = <String>{
      if (authValue.startsWith('Bearer ')) authValue else 'Bearer $authValue',
      authValue,
    };

    for (final headerValue in variants) {
      final result = await _deleteTunnel(
        tunnelId: tunnelId,
        authHeader: headerValue,
      );
      if (result == _DeleteTunnelRequestResult.unauthorized) {
        continue;
      }
      return result == _DeleteTunnelRequestResult.success;
    }

    return false;
  }

  String? _pickAuthValue({required String? apiKey, required String? token}) {
    final key = apiKey?.trim();
    if (key != null && key.isNotEmpty) return key;

    final tok = token?.trim();
    if (tok != null && tok.isNotEmpty) return tok;

    return null;
  }

  Future<List<RemoteTunnelSnapshot>?> _requestTunnels(String authHeader) async {
    final uri = Uri.parse('$_tunnelsBaseEndpoint?page_size=200');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, authHeader);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'tuna-app-desktop');

      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        return null;
      }

      if (response.statusCode != HttpStatus.ok) {
        return const <RemoteTunnelSnapshot>[];
      }

      final raw = await response.transform(utf8.decoder).join();
      final data = jsonDecode(raw);
      if (data is! List) return const <RemoteTunnelSnapshot>[];

      return data
          .whereType<Map<String, dynamic>>()
          .map(_parseTunnel)
          .toList(growable: false);
    } catch (_) {
      return const <RemoteTunnelSnapshot>[];
    } finally {
      client.close(force: true);
    }
  }

  Future<_DeleteTunnelRequestResult> _deleteTunnel({
    required int tunnelId,
    required String authHeader,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse('$_tunnelsBaseEndpoint/$tunnelId'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, authHeader);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'tuna-app-desktop');

      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        return _DeleteTunnelRequestResult.unauthorized;
      }

      if (response.statusCode == HttpStatus.ok ||
          response.statusCode == HttpStatus.noContent) {
        return _DeleteTunnelRequestResult.success;
      }

      return _DeleteTunnelRequestResult.failed;
    } catch (_) {
      return _DeleteTunnelRequestResult.failed;
    } finally {
      client.close(force: true);
    }
  }

  RemoteTunnelSnapshot _parseTunnel(Map<String, dynamic> json) {
    final forwardsTo = _readString(json['forwards_to']);

    return RemoteTunnelSnapshot(
      id: json['id'] as int?,
      uid: (json['uid'] as String?)?.trim() ?? '',
      active: json['active'] == true,
      protocol: _readString(json['protocol']),
      forwardsTo: forwardsTo,
      forwardsToHost: _extractHost(forwardsTo),
      publicUrl: _readString(json['public_url']),
      clientName: _readString(json['client_name']),
      location: _readString(json['location']),
      clientAddress: _pickClientAddress(json),
    );
  }

  String? _pickClientAddress(Map<String, dynamic> json) {
    final candidates = <String?>[
      _readString(json['client_address']),
      _readString(json['remote_address']),
      _readString(json['external_address']),
      _readString(json['address']),
      _readString(json['client_ip']),
    ];

    for (final value in candidates) {
      if (value == null) continue;
      if (_looksLikeIp(value)) return value.toLowerCase();
    }

    final location = _readString(json['location']);
    if (location != null && _looksLikeIp(location)) {
      return location.toLowerCase();
    }

    return null;
  }

  String? _readString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _extractHost(String? rawValue) {
    final raw = rawValue?.trim();
    if (raw == null || raw.isEmpty) return null;

    if (raw.contains('://')) {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host.toLowerCase();
      }
    }

    if (raw.startsWith('[')) {
      final end = raw.indexOf(']');
      if (end > 1) {
        return raw.substring(1, end).toLowerCase();
      }
    }

    final colonCount = ':'.allMatches(raw).length;
    if (colonCount == 1) {
      final parts = raw.split(':');
      if (parts.length == 2 && parts.first.isNotEmpty) {
        return parts.first.toLowerCase();
      }
    }

    if (colonCount > 1) {
      return raw.toLowerCase();
    }

    return raw.toLowerCase();
  }

  bool _looksLikeIp(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return false;

    final v4 = RegExp(
      r'^(25[0-5]|2[0-4]\d|1?\d?\d)\.(25[0-5]|2[0-4]\d|1?\d?\d)\.(25[0-5]|2[0-4]\d|1?\d?\d)\.(25[0-5]|2[0-4]\d|1?\d?\d)$',
    );
    if (v4.hasMatch(raw)) return true;

    final v6 = RegExp(r'^[0-9a-fA-F:]+$');
    return raw.contains(':') && v6.hasMatch(raw);
  }
}
