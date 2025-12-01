import 'package:flutter/foundation.dart';

import '../cli/cli_commands.dart';

enum TunnelStatus {
  inactive,
  starting,
  active,
  failed,
}

@immutable
class SavedTunnel {
  final String id;
  final String name;
  final int localPort;
  final String? ip;        // локальный IP (опционально)
  final String? subdomain; // субдомен (опционально, для HTTP)
  final TunnelType type;
  final TunnelStatus status;

  const SavedTunnel({
    required this.id,
    required this.name,
    required this.localPort,
    required this.type,
    required this.status,
    this.ip,
    this.subdomain,
  });

  SavedTunnel copyWith({
    String? id,
    String? name,
    int? localPort,
    String? ip,
    String? subdomain,
    TunnelType? type,
    TunnelStatus? status,
  }) {
    return SavedTunnel(
      id: id ?? this.id,
      name: name ?? this.name,
      localPort: localPort ?? this.localPort,
      ip: ip ?? this.ip,
      subdomain: subdomain ?? this.subdomain,
      type: type ?? this.type,
      status: status ?? this.status,
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
  };

  factory SavedTunnel.fromJson(Map<String, dynamic> json) {
    return SavedTunnel(
      id: json['id'] as String,
      name: json['name'] as String,
      localPort: json['localPort'] as int,
      ip: json['ip'] as String?, // может отсутствовать в старых данных
      subdomain: json['subdomain'] as String?, // тоже
      type: TunnelType.values
          .firstWhere((e) => e.name == json['type'] as String),
      status: TunnelStatus.values
          .firstWhere((e) => e.name == json['status'] as String),
    );
  }
}
