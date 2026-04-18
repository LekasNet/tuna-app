import 'package:flutter/material.dart';
import 'package:tuna/utils/helpers.dart';

import '../../app/uikit/widgets/simple_select_field.dart';
import '../../core/cli/cli_commands.dart';
import '../../core/tunnels/tunnel_models.dart';
import '../../di/tunnels/tunnels_controller.dart';
import 'widgets/log_console_panel.dart';
import 'widgets/tunnel_card.dart';
import 'widgets/tunnel_details_sections.dart';
import 'widgets/tunnel_form.dart';
import 'widgets/tunnel_presenters.dart';

import 'package:flutter/services.dart';

class TunnelsScreen extends StatelessWidget {
  final TunnelsController controller;

  const TunnelsScreen({super.key, required this.controller});

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
                            final isRunning = controller.isRunning(tunnel.id);

                            final item = _SharedTunnelListItem(
                              tunnel: tunnel,
                              isRunning: isRunning,
                              onTap: () => controller.selectTunnel(tunnel.id),
                              onDelete: () =>
                                  controller.removeTunnel(tunnel.id),
                              onStart: () => controller.startTunnel(tunnel),
                              onStop: () => controller.stopTunnel(tunnel),
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
              child: SlideTransition(position: slideAnimation, child: child),
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
                    TunnelFormFields(
                      nameController: nameController,
                      portController: portController,
                      ipController: ipController,
                      subdomainController: subController,
                      type: selectedType,
                      layout: TunnelFormLayout.dialog,
                      onTypeChanged: (value) {
                        setState(() {
                          selectedType = value;
                          errorMessage = null;
                        });
                      },
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
                    final validation = TunnelFormValidator.validate(
                      name: nameController.text,
                      portText: portController.text,
                      ip: ipController.text,
                      subdomain: subController.text,
                      type: selectedType,
                    );

                    if (!validation.isValid) {
                      setState(() => errorMessage = validation.errorMessage);
                      return;
                    }

                    final name = nameController.text.trim();
                    final ip = ipController.text.trim();
                    final sub = subController.text.trim();
                    final navigator = Navigator.of(dialogContext);
                    await controller.addTunnel(
                      name: name,
                      localPort: validation.port!,
                      type: selectedType,
                      ip: ip.isEmpty ? null : ip,
                      subdomain: sub.isEmpty ? null : sub,
                    );

                    if (!navigator.mounted) return;
                    navigator.pop();
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

// ---------------------------------------------------------------------------
//              СТРАНИЦА ДЕТАЛЕЙ ТУННЕЛЯ
// ---------------------------------------------------------------------------

class _SharedTunnelListItem extends StatelessWidget {
  final SavedTunnel tunnel;
  final bool isRunning;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _SharedTunnelListItem({
    required this.tunnel,
    required this.isRunning,
    required this.onTap,
    required this.onDelete,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final address = tunnel.ip != null && tunnel.ip!.isNotEmpty
        ? '${tunnel.ip}:${tunnel.localPort}'
        : 'порт ${tunnel.localPort}';
    final statusText = tunnelStatusLabel(tunnel.status);
    final subdomainText =
        tunnel.subdomain != null && tunnel.subdomain!.isNotEmpty
        ? ' • subdomain: ${tunnel.subdomain}'
        : '';

    return TunnelCard(
      onTap: onTap,
      title: tunnel.name,
      subtitle:
          '${tunnelTypeLabel(tunnel.type)} • $address • $statusText$subdomainText',
      activityColor: tunnelStatusColor(context, tunnel.status),
      activityHint: 'Статус: $statusText',
      rowCrossAxisAlignment: CrossAxisAlignment.center,
      actions: [
        IconButton(
          icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
          tooltip: isRunning ? 'Остановить' : 'Запустить',
          onPressed: isRunning ? onStop : onStart,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Удалить',
          onPressed: onDelete,
        ),
      ],
    );
  }
}

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
  late final TextEditingController _nameController;
  late final TextEditingController _portController;
  late final TextEditingController _ipController;
  late final TextEditingController _subController;
  late TunnelType _type;

  final ScrollController _logScrollController = ScrollController();

  bool _editing = false;
  _LogFilter _logFilter = _LogFilter.all;

  TunnelsController get controller => widget.controller;
  SavedTunnel get tunnel => widget.tunnel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _portController = TextEditingController();
    _ipController = TextEditingController();
    _subController = TextEditingController();
    _applyTunnelToForm(tunnel);
  }

  @override
  void didUpdateWidget(covariant _TunnelDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tunnel.id != widget.tunnel.id) {
      _applyTunnelToForm(widget.tunnel);
    }
  }

  void _applyTunnelToForm(SavedTunnel t) {
    _nameController.text = t.name;
    _portController.text = t.localPort.toString();
    _ipController.text = t.ip ?? '';
    _subController.text = t.subdomain ?? '';
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
    final validation = TunnelFormValidator.validate(
      name: _nameController.text,
      portText: _portController.text,
      ip: _ipController.text,
      subdomain: _subController.text,
      type: _type,
    );

    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.errorMessage ?? 'Проверь данные формы'),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();
    final sub = _subController.text.trim();

    final updated = tunnel.copyWith(
      name: name,
      localPort: validation.port!,
      ip: ip.isEmpty ? null : ip,
      subdomain: sub.isEmpty ? null : sub,
      type: _type,
    );

    await controller.updateTunnel(updated);
    if (!mounted) return;

    setState(() {
      _editing = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Туннель сохранён')));
  }

  void _cancelEdit() {
    _applyTunnelToForm(tunnel);
    setState(() {
      _editing = false;
    });
  }

  Future<void> _exportLogs() async {
    final path = await controller.exportLogsToTempFile(tunnel);
    if (!mounted) return;

    if (path == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Логи отсутствуют')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Логи сохранены в файл:\n$path')));
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
    final canOpenWebUI = webInterfaceUrl != null && isRunning;

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
          TunnelDetailsHeader(
            title: 'Туннель: ${tunnel.name}',
            statusLabel: statusLabel,
            statusColor: statusColor,
            onBack: controller.clearSelection,
            isRunning: isRunning,
            onStart: () => controller.startTunnel(tunnel),
            onStop: () => controller.stopTunnel(tunnel),
            onExportLogs: _exportLogs,
            webInterfaceUrl: webInterfaceUrl,
            onOpenWebInterface: canOpenWebUI
                ? () => launchWeb(webInterfaceUrl)
                : null,
          ),
          const SizedBox(height: 16),

          // ---------- ПАНЕЛЬ ИНФО / РЕДАКТИРОВАНИЯ ----------
          TunnelInfoSectionCard(
            editing: _editing,
            readOnlyChild: _buildReadOnlyInfo(context),
            editableChild: _buildEditableInfo(),
            onEdit: () {
              setState(() {
                _editing = true;
              });
            },
            onCancel: _cancelEdit,
            onSave: _saveChanges,
          ),
          const SizedBox(height: 16),

          // ---------- ПАНЕЛЬ ФИЛЬТРА + ОЧИСТКА ВИДИМОГО ЛОГА ----------
          TunnelLogsToolbar(
            filterField: SimpleSelectField<_LogFilter>(
              value: _logFilter,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              options: const [
                SimpleSelectOption(value: _LogFilter.all, label: 'Все'),
                SimpleSelectOption(value: _LogFilter.info, label: 'INFO'),
                SimpleSelectOption(value: _LogFilter.warn, label: 'WARN'),
                SimpleSelectOption(value: _LogFilter.error, label: 'ERROR'),
              ],
              onChanged: (v) => setState(() => _logFilter = v),
            ),
            onClearVisibleLogs: () => controller.clearVisibleLogs(tunnel.id),
          ),
          const SizedBox(height: 8),

          // ---------- КОНСОЛЬ ----------
          Expanded(
            child: LogConsolePanel(
              controller: _logScrollController,
              itemCount: logs.length,
              emptyContent: const SizedBox.shrink(),
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
                    style: TextStyle(color: Colors.grey.shade500),
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
                    style: TextStyle(color: Colors.grey.shade500),
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
                    Clipboard.setData(ClipboardData(text: webInterfaceUrl));
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
            child: Text(label, style: TextStyle(color: Colors.grey.shade500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildEditableInfo() {
    return TunnelFormFields(
      nameController: _nameController,
      portController: _portController,
      ipController: _ipController,
      subdomainController: _subController,
      type: _type,
      layout: TunnelFormLayout.panel,
      onTypeChanged: (value) => setState(() => _type = value),
    );
  }

  Color _statusColor(BuildContext context, TunnelStatus status) {
    return tunnelStatusColor(context, status);
  }

  String _statusLabel(TunnelStatus status) {
    return tunnelStatusLabel(status);
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
    final isCritical =
        upper.contains('CRITICAL') ||
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
            style: TextStyle(color: Colors.grey.shade400),
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
          style: TextStyle(color: numberColor),
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

  const _HoverCopyIcon({required this.onTap, required this.tooltip});

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
                child: Icon(Icons.copy, size: 16, color: Colors.grey.shade700),
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

  const _StaggeredListItem({required this.index, required this.child});

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
