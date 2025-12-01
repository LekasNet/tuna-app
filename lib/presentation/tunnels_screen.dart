import 'package:flutter/material.dart';
import 'package:tuna/utils/helpers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/uikit/app_colors.dart';
import '../../core/cli/cli_commands.dart';
import '../../core/tunnels/tunnel_models.dart';
import '../../di/tunnels/tunnels_controller.dart';

import 'package:flutter/services.dart';

class TunnelsScreen extends StatelessWidget {
  final TunnelsController controller;

  const TunnelsScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.initialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final selected = controller.selectedTunnel;
        final tunnels = controller.tunnels;

        // ---------- ВЫБИРАЕМ, ЧТО РИСОВАТЬ ----------
        Widget body;
        if (selected != null) {
          body = _TunnelDetailsView(
            key: const ValueKey('details_view'),
            controller: controller,
            tunnel: selected,
          );
        } else {
          body = Padding(
            key: const ValueKey('list_view'),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Туннели',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Добавить туннель',
                      onPressed: () => _showAddTunnelDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: tunnels.isEmpty
                      ? Center(
                    child: Text(
                      'Туннелей пока нет.\nНажми "+" чтобы добавить.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                      : ListView.separated(
                    itemCount: tunnels.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tunnel = tunnels[index];
                      final isRunning =
                      controller.isRunning(tunnel.id);

                      final item = InkWell(
                        onTap: () => controller.selectTunnel(tunnel.id),
                        borderRadius: BorderRadius.circular(8),
                        child: _TunnelListItem(
                          tunnel: tunnel,
                          isRunning: isRunning,
                          onDelete: () =>
                              controller.removeTunnel(tunnel.id),
                          onStart: () =>
                              controller.startTunnel(tunnel),
                          onStop: () =>
                              controller.stopTunnel(tunnel),
                        ),
                      );

                      // Обёртка для "появления по порядку"
                      return _StaggeredListItem(
                        index: index,
                        child: item,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        // ---------- АНИМАЦИЯ ПЕРЕКЛЮЧЕНИЯ МЕЖДУ СПИСКОМ И ДЕТАЛЯМИ ----------
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            // лёгкий слайд + фейд
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            );
          },
          child: body,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  //              DIALOG: создание нового туннеля
  // ---------------------------------------------------------------------------

  void _showAddTunnelDialog(BuildContext context) {
    final nameController = TextEditingController();
    final portController = TextEditingController();
    final ipController = TextEditingController();
    final subController = TextEditingController();

    TunnelType selectedType = TunnelType.http;

    String? errorMessage;

    bool isValidIPv4(String ip) {
      final regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
      if (!regex.hasMatch(ip)) return false;
      final parts = ip.split('.');
      for (final part in parts) {
        final n = int.tryParse(part);
        if (n == null || n < 0 || n > 255) return false;
      }
      return true;
    }

    bool isValidPort(int port) => port > 0 && port <= 65535;

    bool isValidSubdomain(String s) {
      final regex = RegExp(r'^[a-zA-Z0-9-]{1,63}$');
      return regex.hasMatch(s);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Новый туннель'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Например, Local API',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: portController,
                      decoration: const InputDecoration(
                        labelText: 'Локальный порт',
                        hintText: 'Например, 8080',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ipController,
                      decoration: const InputDecoration(
                        labelText: 'Локальный IP (опционально)',
                        hintText: 'Например, 127.0.0.1',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TunnelType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Тип туннеля',
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: TunnelType.http, child: Text('HTTP')),
                        DropdownMenuItem(
                            value: TunnelType.tcp, child: Text('TCP')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedType = value;
                            errorMessage = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subController,
                      enabled: selectedType == TunnelType.http,
                      decoration: const InputDecoration(
                        labelText: 'Subdomain (опционально)',
                        hintText: 'Например, myapp',
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final ip = ipController.text.trim();
                    final portText = portController.text.trim();
                    final sub = subController.text.trim();
                    final port = int.tryParse(portText);

                    String? localError;

                    if (name.isEmpty) {
                      localError = 'Укажи название туннеля';
                    } else if (port == null || !isValidPort(port)) {
                      localError = 'Некорректный порт (1–65535)';
                    } else if (ip.isNotEmpty && !isValidIPv4(ip)) {
                      localError = 'Некорректный IPv4 адрес';
                    } else if (selectedType == TunnelType.http &&
                        sub.isNotEmpty &&
                        !isValidSubdomain(sub)) {
                      localError =
                      'Некорректный subdomain (a-z, A-Z, 0-9, тире, длина ≤ 63)';
                    }

                    if (localError != null) {
                      setState(() => errorMessage = localError);
                      return;
                    }

                    await controller.addTunnel(
                      name: name,
                      localPort: port!,
                      type: selectedType,
                      ip: ip.isEmpty ? null : ip,
                      subdomain: sub.isEmpty ? null : sub,
                    );

                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//              ЭЛЕМЕНТ СПИСКА ТУННЕЛЕЙ
// ---------------------------------------------------------------------------

class _TunnelListItem extends StatelessWidget {
  final SavedTunnel tunnel;
  final bool isRunning;
  final VoidCallback onDelete;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _TunnelListItem({
    required this.tunnel,
    required this.isRunning,
    required this.onDelete,
    required this.onStart,
    required this.onStop,
  });

  Color _statusColor(BuildContext context) {
    switch (tunnel.status) {
      case TunnelStatus.active:
        return AppColors.success;
      case TunnelStatus.starting:
        return AppColors.info; // синий
      case TunnelStatus.failed:
        return AppColors.error;
      case TunnelStatus.inactive:
      default:
        return Theme.of(context).dividerColor.withOpacity(0.7);
    }
  }

  String _typeLabel() {
    switch (tunnel.type) {
      case TunnelType.http:
        return 'HTTP';
      case TunnelType.tcp:
        return 'TCP';
    }
  }

  String _statusLabel() {
    switch (tunnel.status) {
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);

    final address = tunnel.ip != null && tunnel.ip!.isNotEmpty
        ? '${tunnel.ip}:${tunnel.localPort}'
        : 'порт ${tunnel.localPort}';

    final subdomainText =
    tunnel.subdomain != null && tunnel.subdomain!.isNotEmpty
        ? ' • subdomain: ${tunnel.subdomain}'
        : '';

    final isActive = tunnel.status == TunnelStatus.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tunnel.name,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_typeLabel()} • $address • ${_statusLabel()}$subdomainText',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
            tooltip: isActive ? 'Остановить' : 'Запустить',
            onPressed: isActive ? onStop : onStart,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//              СТРАНИЦА ДЕТАЛЕЙ ТУННЕЛЯ
// ---------------------------------------------------------------------------

class _TunnelDetailsView extends StatefulWidget {
  final TunnelsController controller;
  final SavedTunnel tunnel;

  const _TunnelDetailsView({
    super.key,
    required this.controller,
    required this.tunnel,
  });

  @override
  State<_TunnelDetailsView> createState() => _TunnelDetailsViewState();
}

enum _LogFilter { all, info, warn, error }

class _TunnelDetailsViewState extends State<_TunnelDetailsView> {
  late TextEditingController _nameController;
  late TextEditingController _portController;
  late TextEditingController _ipController;
  late TextEditingController _subController;
  late TunnelType _type;

  final ScrollController _logScrollController = ScrollController();

  bool _editing = false;
  _LogFilter _logFilter = _LogFilter.all;

  TunnelsController get controller => widget.controller;
  SavedTunnel get tunnel => widget.tunnel;

  @override
  void initState() {
    super.initState();
    _initFromTunnel(tunnel);
  }

  @override
  void didUpdateWidget(covariant _TunnelDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tunnel.id != widget.tunnel.id) {
      _initFromTunnel(widget.tunnel);
    }
  }

  void _initFromTunnel(SavedTunnel t) {
    _nameController = TextEditingController(text: t.name);
    _portController = TextEditingController(text: t.localPort.toString());
    _ipController = TextEditingController(text: t.ip ?? '');
    _subController = TextEditingController(text: t.subdomain ?? '');
    _type = t.type;
    _editing = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portController.dispose();
    _ipController.dispose();
    _subController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final portText = _portController.text.trim();
    final ip = _ipController.text.trim();
    final sub = _subController.text.trim();
    final port = int.tryParse(portText);

    if (name.isEmpty || port == null || port <= 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Проверь название и порт (1–65535)'),
        ),
      );
      return;
    }

    final updated = tunnel.copyWith(
      name: name,
      localPort: port,
      ip: ip.isEmpty ? null : ip,
      subdomain: sub.isEmpty ? null : sub,
      type: _type,
    );

    await controller.updateTunnel(updated);

    setState(() {
      _editing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Туннель сохранён')),
    );
  }

  void _cancelEdit() {
    _initFromTunnel(tunnel);
    setState(() {
      _editing = false;
    });
  }

  Future<void> _exportLogs() async {
    final path = await controller.exportLogsToTempFile(tunnel);
    if (!mounted) return;

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Логи отсутствуют')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Логи сохранены в файл:\n$path')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawLogs = controller.logsFor(tunnel.id);
    final logs = rawLogs.where((l) => _matchesFilter(l)).toList();

    final isRunning = controller.isRunning(tunnel.id);
    final statusColor = _statusColor(context, tunnel.status);
    final statusLabel = _statusLabel(tunnel.status);

    final webInterfaceUrl = controller.webInterfaceFor(tunnel.id);
    final hasWebUI = webInterfaceUrl != null;
    final canOpenWebUI = hasWebUI && isRunning;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(
          _logScrollController.position.maxScrollExtent,
        );
      }
    });

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // ---------- ШАПКА ----------
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'К списку',
                onPressed: controller.clearSelection,
              ),
              const SizedBox(width: 8),
              Text(
                'Туннель: ${tunnel.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              Icon(
                Icons.circle,
                size: 10,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              if (hasWebUI) ...[
                Opacity(
                  opacity: canOpenWebUI ? 1.0 : 0.4,
                  child: IconButton(
                    tooltip: 'Web интерфейс',
                    onPressed: canOpenWebUI
                        ? () {
                      launchWeb(webInterfaceUrl);
                    }
                        : null,
                    icon: const Icon(Icons.web, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                tooltip: isRunning ? 'Остановить' : 'Запустить',
                onPressed: isRunning
                    ? () => controller.stopTunnel(tunnel)
                    : () => controller.startTunnel(tunnel),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Экспорт логов',
                onPressed: _exportLogs,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---------- ПАНЕЛЬ ИНФО / РЕДАКТИРОВАНИЯ ----------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 0, right: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_editing)
                        _buildReadOnlyInfo(context)
                      else
                        _buildEditableInfo(context),
                      if (_editing) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _cancelEdit,
                              child: const Text('Отмена'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _saveChanges,
                              child: const Text('Сохранить'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_editing)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Редактировать',
                      onPressed: () {
                        setState(() {
                          _editing = true;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- ПАНЕЛЬ ФИЛЬТРА + ОЧИСТКА ВИДИМОГО ЛОГА ----------
          Row(
            children: [
              Text(
                'Лог',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 16),
              DropdownButton<_LogFilter>(
                value: _logFilter,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _logFilter = v);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: _LogFilter.all,
                    child: Text('Все'),
                  ),
                  DropdownMenuItem(
                    value: _LogFilter.info,
                    child: Text('INFO'),
                  ),
                  DropdownMenuItem(
                    value: _LogFilter.warn,
                    child: Text('WARN'),
                  ),
                  DropdownMenuItem(
                    value: _LogFilter.error,
                    child: Text('ERROR'),
                  ),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  controller.clearVisibleLogs(tunnel.id);
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Очистить видимый лог'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ---------- КОНСОЛЬ ----------
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                controller: _logScrollController,
                child: ListView.builder(
                  controller: _logScrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final line = logs[index];
                    return SelectableText.rich(
                      _buildLogLineSpan(index, line),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFFE0E0E0),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------ ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ INFO-ПАНЕЛИ И СТАТУСОВ ------------

  Widget _buildReadOnlyInfo(BuildContext context) {
    final address = tunnel.ip != null && tunnel.ip!.isNotEmpty
        ? '${tunnel.ip}:${tunnel.localPort}'
        : 'порт ${tunnel.localPort}';

    final typeLabel = tunnel.type == TunnelType.http ? 'HTTP' : 'TCP';

    final forwarding = controller.forwardingFor(tunnel.id);
    final webInterfaceUrl = controller.webInterfaceFor(tunnel.id);

    String stripProto(String url) {
      return url.replaceFirst(RegExp(r'^https?://'), '');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow('Название', tunnel.name),
        _infoRow('Тип', typeLabel),
        _infoRow('Адрес', address),
        if (tunnel.subdomain != null && tunnel.subdomain!.isNotEmpty)
          _infoRow('Subdomain', tunnel.subdomain!),

        // URL:
        if (forwarding != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'URL',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      launchWeb(forwarding.publicUrl);
                    },
                    child: Text(
                      stripProto(forwarding.publicUrl),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF3498DB),
                      ),
                    ),
                  ),
                ),
                _HoverCopyIcon(
                  tooltip: 'Скопировать URL',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: forwarding.publicUrl),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Адрес скопирован'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],

        // Web UI + иконка копирования
        if (webInterfaceUrl != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'Web UI',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      launchWeb(webInterfaceUrl);
                    },
                    child: Text(
                      stripProto(webInterfaceUrl),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF3498DB),
                      ),
                    ),
                  ),
                ),
                _HoverCopyIcon(
                  tooltip: 'Скопировать Web UI',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: webInterfaceUrl),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Адрес скопирован'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfo(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Порт',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP (опционально)',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<TunnelType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Тип',
                ),
                items: const [
                  DropdownMenuItem(
                      value: TunnelType.http, child: Text('HTTP')),
                  DropdownMenuItem(
                      value: TunnelType.tcp, child: Text('TCP')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subController,
          enabled: _type == TunnelType.http,
          decoration: const InputDecoration(
            labelText: 'Subdomain (опционально)',
          ),
        ),
      ],
    );
  }

  Color _statusColor(BuildContext context, TunnelStatus status) {
    switch (status) {
      case TunnelStatus.active:
        return AppColors.success;
      case TunnelStatus.starting:
        return AppColors.info; // синий
      case TunnelStatus.failed:
        return AppColors.error;
      case TunnelStatus.inactive:
      default:
        return Theme.of(context).dividerColor.withOpacity(0.7);
    }
  }

  String _statusLabel(TunnelStatus status) {
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

  // ------------ ЛОГИ: ФИЛЬТР И ПОДСВЕТКА ------------

  bool _matchesFilter(String line) {
    final level = _detectLevel(line);
    switch (_logFilter) {
      case _LogFilter.all:
        return true;
      case _LogFilter.info:
        return level == 'INFO';
      case _LogFilter.warn:
        return level == 'WARN';
      case _LogFilter.error:
        return level == 'ERRO';
    }
  }

  String _detectLevel(String line) {
    final m = RegExp(r'^\s*(INFO|WARN|ERRO)\[').firstMatch(line);
    return m?.group(1) ?? '';
  }

  TextSpan _buildLogLineSpan(int index, String line) {
    final lineNumber = (index + 1).toString().padLeft(4);

    const baseTextColor = Color(0xFFE0E0E0);
    final numberColor = Colors.grey.shade500;

    const infoTagColor = Color(0xFF3498DB);
    const warnTagColor = Color(0xFFF1C40F);
    const errorTagColor = Color(0xFFE74C3C);

    final upper = line.toUpperCase();
    final isCritical = upper.contains('CRITICAL') ||
        upper.contains('FATAL') ||
        upper.contains('[CRIT');

    final levelRegex = RegExp(r'^\s*(INFO|WARN|ERRO)\[([^\]]*)\](.*)$');
    final levelMatch = levelRegex.firstMatch(line);

    TextSpan contentSpan;

    if (isCritical) {
      contentSpan = TextSpan(
        text: ' $line',
        style: const TextStyle(color: errorTagColor),
      );
    } else if (levelMatch != null) {
      final level = levelMatch.group(1)!;
      final time = levelMatch.group(2) ?? '';
      final rest = (levelMatch.group(3) ?? '').trimLeft();

      String tagText;
      Color tagColor;

      switch (level) {
        case 'INFO':
          tagText = '[INFO]';
          tagColor = infoTagColor;
          break;
        case 'WARN':
          tagText = '[WARN]';
          tagColor = warnTagColor;
          break;
        case 'ERRO':
          tagText = '[ERROR]';
          tagColor = errorTagColor;
          break;
        default:
          tagText = '[$level]';
          tagColor = infoTagColor;
      }

      final children = <InlineSpan>[
        TextSpan(
          text: ' $tagText',
          style: TextStyle(color: tagColor),
        ),
      ];

      if (time.isNotEmpty) {
        children.add(
          TextSpan(
            text: ' [$time]',
            style: TextStyle(
              color: Colors.grey.shade400,
            ),
          ),
        );
      }

      if (rest.isNotEmpty) {
        children.add(
          TextSpan(
            text: ' $rest',
            style: const TextStyle(color: baseTextColor),
          ),
        );
      }

      contentSpan = TextSpan(children: children);
    } else {
      contentSpan = TextSpan(
        text: ' $line',
        style: const TextStyle(color: baseTextColor),
      );
    }

    return TextSpan(
      children: [
        TextSpan(
          text: '$lineNumber ',
          style: TextStyle(
            color: numberColor,
          ),
        ),
        contentSpan,
      ],
    );
  }
}

// Небольшой виджет-иконка копирования с hover-эффектом
class _HoverCopyIcon extends StatefulWidget {
  final VoidCallback onTap;
  final String tooltip;

  const _HoverCopyIcon({
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_HoverCopyIcon> createState() => _HoverCopyIconState();
}

class _HoverCopyIconState extends State<_HoverCopyIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Opacity(
        opacity: _hovered ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Tooltip(
            message: widget.tooltip,
            child: SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Icon(
                  Icons.copy,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//            ОБЁРТКА ДЛЯ ПОЯВЛЕНИЯ ЭЛЕМЕНТОВ СПИСКА ПО ПОРЯДКУ
// ---------------------------------------------------------------------------

class _StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredListItem({
    required this.index,
    required this.child,
  });

  @override
  State<_StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<_StaggeredListItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Небольшая задержка в зависимости от индекса — даёт "поочерёдное" появление
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      opacity: _visible ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.03),
        child: widget.child,
      ),
    );
  }
}
