import 'dart:io';

enum TunnelType {
  http,
  tcp,
}

class TunnelCommand {
  final TunnelType type;
  final List<String> args;

  const TunnelCommand({
    required this.type,
    required this.args,
  });
}

/// Шаблоны простых туннелей для tuna CLI
class CliCommands {
  /// Простой HTTP-туннель:
  /// tuna http <port>          // если IP не задан
  /// tuna http <ip:port>       // если IP задан
  /// + опциональный --subdomain
  static TunnelCommand simpleHttp({
    required int localPort,
    String? localIp,
    String? subdomain,
  }) {
    final address = (localIp != null && localIp.isNotEmpty)
        ? '$localIp:$localPort'
        : localPort.toString();

    final args = <String>[
      'http',
      address,
    ];

    if (subdomain != null && subdomain.isNotEmpty) {
      args.add('--subdomain=$subdomain');
    }

    return TunnelCommand(
      type: TunnelType.http,
      args: args,
    );
  }

  /// Простой TCP-туннель:
  /// tuna tcp <localPort>
  static TunnelCommand simpleTcp({
    required int localPort,
  }) {
    final args = <String>[
      'tcp',
      localPort.toString(),
    ];

    return TunnelCommand(
      type: TunnelType.tcp,
      args: args,
    );
  }
}

/// Дефолтное имя исполняемого файла для tuna в зависимости от платформы
String defaultTunaExecutableName() {
  if (Platform.isWindows) {
    return 'tuna.exe';
  }
  return 'tuna';
}
