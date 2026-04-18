import 'package:flutter/foundation.dart';

import '../cli/cli_commands.dart';

enum TunnelStatus { inactive, starting, active, failed }

@immutable
class SavedTunnel {
  final String id;
  final String name;
  final int localPort;
  final String? ip;
  final String? subdomain;
  final TunnelType type;
  final TunnelStatus status;
  final DateTime? lastStartedAt;

  const SavedTunnel({
    required this.id,
    required this.name,
    required this.localPort,
    required this.type,
    required this.status,
    this.ip,
    this.subdomain,
    this.lastStartedAt,
  });

  SavedTunnel copyWith({
    String? id,
    String? name,
    int? localPort,
    String? ip,
    String? subdomain,
    TunnelType? type,
    TunnelStatus? status,
    DateTime? lastStartedAt,
  }) {
    return SavedTunnel(
      id: id ?? this.id,
      name: name ?? this.name,
      localPort: localPort ?? this.localPort,
      ip: ip ?? this.ip,
      subdomain: subdomain ?? this.subdomain,
      type: type ?? this.type,
      status: status ?? this.status,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'localPort': localPort,
    'ip': ip,
    'subdomain': subdomain,
    'type': type.name,
    'status': status.name,
    'lastStartedAt': lastStartedAt?.toIso8601String(),
  };

  factory SavedTunnel.fromJson(Map<String, dynamic> json) {
    final rawLastStartedAt = json['lastStartedAt'] as String?;

    return SavedTunnel(
      id: json['id'] as String,
      name: json['name'] as String,
      localPort: json['localPort'] as int,
      ip: json['ip'] as String?,
      subdomain: json['subdomain'] as String?,
      type: TunnelType.values.firstWhere(
        (e) => e.name == json['type'] as String,
      ),
      status: TunnelStatus.values.firstWhere(
        (e) => e.name == json['status'] as String,
      ),
      lastStartedAt: rawLastStartedAt == null
          ? null
          : DateTime.tryParse(rawLastStartedAt),
    );
  }
}
