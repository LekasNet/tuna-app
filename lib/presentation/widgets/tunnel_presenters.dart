import 'package:flutter/material.dart';

import '../../app/uikit/app_colors.dart';
import '../../core/cli/cli_commands.dart';
import '../../core/tunnels/tunnel_models.dart';

String tunnelTypeLabel(TunnelType type) {
  switch (type) {
    case TunnelType.http:
      return 'HTTP';
    case TunnelType.tcp:
      return 'TCP';
  }
}

String tunnelStatusLabel(TunnelStatus status) {
  switch (status) {
    case TunnelStatus.active:
      return 'Активен';
    case TunnelStatus.starting:
      return 'Запускается';
    case TunnelStatus.inactive:
      return 'Не активен';
    case TunnelStatus.failed:
      return 'Упал';
  }
}

Color tunnelStatusColor(BuildContext context, TunnelStatus status) {
  switch (status) {
    case TunnelStatus.active:
      return AppColors.success;
    case TunnelStatus.starting:
      return AppColors.info;
    case TunnelStatus.failed:
      return AppColors.error;
    case TunnelStatus.inactive:
      return Theme.of(context).dividerColor.withValues(alpha: 0.7);
  }
}

class RemoteOwnershipPresentation {
  final String label;
  final String hint;
  final Color accentColor;
  final Color textColor;

  const RemoteOwnershipPresentation({
    required this.label,
    required this.hint,
    required this.accentColor,
    required this.textColor,
  });
}

RemoteOwnershipPresentation remoteOwnershipPresentation({
  required bool isLocalMachine,
}) {
  if (isLocalMachine) {
    return const RemoteOwnershipPresentation(
      label: 'С этого компьютера',
      hint: 'URL найден среди локальных туннелей на этом компьютере.',
      accentColor: Colors.green,
      textColor: Color(0xFF2E7D32),
    );
  }

  return const RemoteOwnershipPresentation(
    label: 'Не с этого компьютера',
    hint: 'URL не найден среди локальных туннелей на этом компьютере.',
    accentColor: Colors.orange,
    textColor: Color(0xFFEF6C00),
  );
}
