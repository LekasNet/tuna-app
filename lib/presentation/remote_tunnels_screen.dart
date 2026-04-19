import 'package:flutter/material.dart';

import '../core/api/tuna_api_service.dart';
import '../di/settings/settings_controller.dart';
import '../di/tunnels/remote_tunnels_controller.dart';
import '../di/tunnels/tunnels_controller.dart';
import '../utils/helpers.dart';
import 'widgets/tunnel_card.dart';
import 'widgets/tunnel_presenters.dart';

class RemoteTunnelsScreen extends StatefulWidget {
  final RemoteTunnelsController controller;
  final SettingsController settingsController;
  final TunnelsController tunnelsController;

  const RemoteTunnelsScreen({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.tunnelsController,
  });

  @override
  State<RemoteTunnelsScreen> createState() => _RemoteTunnelsScreenState();
}

class _RemoteTunnelsScreenState extends State<RemoteTunnelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() {
    return widget.controller.refresh(
      apiKey: widget.settingsController.apiKey,
      token: widget.settingsController.token,
    );
  }

  Future<void> _stopTunnel(RemoteTunnelSnapshot tunnel) async {
    final id = tunnel.id;
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя остановить туннель без ID.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Остановить удалённый туннель'),
          content: Text(
            'Остановить туннель ${tunnel.publicUrl ?? tunnel.uid}? '
            'Это завершит удалённое соединение.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Остановить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final ok = await widget.controller.stopTunnel(
      tunnel,
      apiKey: widget.settingsController.apiKey,
      token: widget.settingsController.token,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Удалённый туннель остановлен.'
              : 'Не удалось остановить удалённый туннель.',
        ),
      ),
    );

    if (ok) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.settingsController,
        widget.tunnelsController,
      ]),
      builder: (context, _) {
        final controller = widget.controller;
        final tunnels = controller.tunnels;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Удалённые туннели',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Обновить',
                    onPressed: controller.loading ? null : _refresh,
                    icon: controller.loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: controller.loading && tunnels.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : tunnels.isEmpty
                    ? const Center(
                        child: Text('Активных удалённых туннелей не найдено.'),
                      )
                    : ListView.separated(
                        itemCount: tunnels.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tunnel = tunnels[index];
                          final isMine = widget.tunnelsController
                              .hasKnownPublicUrl(tunnel.publicUrl);

                          return _SharedRemoteTunnelTile(
                            tunnel: tunnel,
                            isMine: isMine,
                            stopping: controller.isStopping(tunnel),
                            onOpen: tunnel.publicUrl == null
                                ? null
                                : () => launchWeb(tunnel.publicUrl!),
                            onStop: tunnel.id == null
                                ? null
                                : () => _stopTunnel(tunnel),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SharedRemoteTunnelTile extends StatelessWidget {
  final RemoteTunnelSnapshot tunnel;
  final bool isMine;
  final bool stopping;
  final VoidCallback? onOpen;
  final VoidCallback? onStop;

  const _SharedRemoteTunnelTile({
    required this.tunnel,
    required this.isMine,
    required this.stopping,
    required this.onOpen,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final title = tunnel.publicUrl ?? 'UID: ${tunnel.uid}';
    final subtitleParts = <String>[
      if ((tunnel.protocol ?? '').isNotEmpty) tunnel.protocol!,
      if ((tunnel.forwardsTo ?? '').isNotEmpty) '-> ${tunnel.forwardsTo}',
      if ((tunnel.clientName ?? '').isNotEmpty) 'client: ${tunnel.clientName}',
    ];
    final ownership = remoteOwnershipPresentation(isLocalMachine: isMine);

    return TunnelCard(
      title: title,
      subtitle: subtitleParts.join(' • '),
      activityColor: ownership.accentColor,
      activityHint: ownership.hint,
      rowCrossAxisAlignment: CrossAxisAlignment.start,
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ownership.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          ownership.label,
          style: TextStyle(fontSize: 11, color: ownership.textColor),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Открыть URL',
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new),
        ),
        IconButton(
          tooltip: 'Принудительно остановить',
          onPressed: stopping ? null : onStop,
          icon: stopping
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.stop_circle_outlined),
        ),
      ],
    );
  }
}
