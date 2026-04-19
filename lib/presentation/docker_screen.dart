import 'package:flutter/material.dart';

import '../core/docker/docker_service.dart';
import '../di/docker/docker_controller.dart';
import 'widgets/log_console_panel.dart';

class DockerScreen extends StatefulWidget {
  final DockerController controller;

  const DockerScreen({super.key, required this.controller});

  @override
  State<DockerScreen> createState() => _DockerScreenState();
}

class _DockerScreenState extends State<DockerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.refreshContainers();
    });
  }

  Future<void> _stopTunnel(
    String containerId,
    DockerTunnelProcess tunnel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Остановить туннель в контейнере'),
          content: Text(
            'PID ${tunnel.pid} (${tunnel.type.toUpperCase()} ${tunnel.address}) '
            'будет остановлен внутри контейнера.',
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

    final ok = await widget.controller.stopTunnel(containerId, tunnel);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Туннель остановлен.'
              : 'Не удалось остановить туннель в контейнере.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final selected = controller.selectedContainer;

        if (selected == null) {
          return _ContainersListView(controller: controller);
        }

        return _ContainerDetailsView(
          controller: controller,
          container: selected,
          onBack: controller.clearSelectedContainer,
          onStopTunnel: (tunnel) => _stopTunnel(selected.id, tunnel),
        );
      },
    );
  }
}

class _ContainersListView extends StatelessWidget {
  final DockerController controller;

  const _ContainersListView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final containers = controller.containers;
    final errorText = controller.containersError;
    final engineNotRunning = errorText == 'Docker Engine не запущен.';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Docker контейнеры',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Обновить список',
                onPressed: controller.loadingContainers
                    ? null
                    : controller.refreshContainers,
                icon: controller.loadingContainers
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          if (errorText != null && !engineNotRunning)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Text(
                errorText,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: controller.loadingContainers && containers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : engineNotRunning
                ? const Center(child: Text('Docker Engine не запущен.'))
                : containers.isEmpty
                ? const Center(child: Text('Контейнеры не найдены'))
                : ListView.separated(
                    itemCount: containers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = containers[index];
                      return _ContainerTile(
                        item: item,
                        onTap: () => controller.selectContainer(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContainerTile extends StatelessWidget {
  final DockerContainerSummary item;
  final VoidCallback onTap;

  const _ContainerTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isRunning ? Colors.green : Colors.orange;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                item.image,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              Text(
                item.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.ports.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  item.ports,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContainerDetailsView extends StatelessWidget {
  final DockerController controller;
  final DockerContainerSummary container;
  final VoidCallback onBack;
  final Future<void> Function(DockerTunnelProcess tunnel) onStopTunnel;

  const _ContainerDetailsView({
    required this.controller,
    required this.container,
    required this.onBack,
    required this.onStopTunnel,
  });

  @override
  Widget build(BuildContext context) {
    final containerId = container.id;
    final loading = controller.isDetailsLoading(containerId);
    final detailsError = controller.detailsError(containerId);
    final tunnels = controller.tunnelsFor(containerId);
    final selectedPid = controller.selectedTunnelPidFor(containerId);
    final logs = controller.selectedLogsFor(containerId);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Назад к контейнерам',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  container.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Обновить контейнер',
                onPressed: loading
                    ? null
                    : () => controller.loadContainerDetails(
                        containerId,
                        force: true,
                      ),
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          Text(
            'Image: ${container.image} • State: ${container.state}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (container.ports.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Ports: ${container.ports}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (detailsError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                detailsError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Туннели в контейнере',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
              ),
            ),
            child: tunnels.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        loading
                            ? 'Загрузка...'
                            : 'Туннели tuna внутри контейнера не найдены',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: tunnels.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final tunnel = tunnels[index];
                      final selected = selectedPid == tunnel.pid;
                      return _TunnelProcessTile(
                        tunnel: tunnel,
                        selected: selected,
                        stopping: controller.isStoppingTunnel(
                          containerId,
                          tunnel.pid,
                        ),
                        onSelect: () => controller.selectLogSource(
                          containerId,
                          tunnelPid: tunnel.pid,
                        ),
                        onStop: () => onStopTunnel(tunnel),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Лог контейнера'),
                selected: selectedPid == null,
                onSelected: (_) =>
                    controller.selectLogSource(containerId, tunnelPid: null),
              ),
              ...tunnels.map((tunnel) {
                return ChoiceChip(
                  label: Text('PID ${tunnel.pid}'),
                  selected: selectedPid == tunnel.pid,
                  onSelected: (_) => controller.selectLogSource(
                    containerId,
                    tunnelPid: tunnel.pid,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedPid == null
                ? 'Общий docker logs контейнера'
                : 'Лог туннеля (фильтр из общего docker logs)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LogConsolePanel(
              itemCount: logs.length,
              borderRadius: BorderRadius.circular(8),
              borderAlpha: 0.35,
              itemBuilder: (context, index) {
                return SelectableText(
                  logs[index],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFE0E0E0),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TunnelProcessTile extends StatelessWidget {
  final DockerTunnelProcess tunnel;
  final bool selected;
  final bool stopping;
  final VoidCallback onSelect;
  final VoidCallback onStop;

  const _TunnelProcessTile({
    required this.tunnel,
    required this.selected,
    required this.stopping,
    required this.onSelect,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PID ${tunnel.pid} • ${tunnel.type.toUpperCase()} ${tunnel.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tunnel.commandLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Остановить туннель',
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
          ),
        ),
      ),
    );
  }
}
