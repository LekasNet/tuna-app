import 'package:flutter/material.dart';

import 'package:tuna/app/l10n/app_localizations.dart';

class TunnelDetailsHeader extends StatelessWidget {
  final String title;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onBack;
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onExportLogs;
  final String? webInterfaceUrl;
  final VoidCallback? onOpenWebInterface;

  const TunnelDetailsHeader({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.onBack,
    required this.isRunning,
    required this.onStart,
    required this.onStop,
    required this.onExportLogs,
    this.webInterfaceUrl,
    this.onOpenWebInterface,
  });

  @override
  Widget build(BuildContext context) {
    final hasWebUI = webInterfaceUrl != null;
    final canOpenWebUI = hasWebUI && isRunning;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.t('tunnels.backToList'),
          onPressed: onBack,
        ),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        Icon(Icons.circle, size: 10, color: statusColor),
        const SizedBox(width: 8),
        Text(statusLabel, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 16),
        if (hasWebUI) ...[
          Opacity(
            opacity: canOpenWebUI ? 1.0 : 0.4,
            child: IconButton(
              tooltip: context.l10n.t('tunnels.webInterface'),
              onPressed: canOpenWebUI ? onOpenWebInterface : null,
              icon: const Icon(Icons.web, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
          tooltip: isRunning
              ? context.l10n.t('common.stop')
              : context.l10n.t('common.start'),
          onPressed: isRunning ? onStop : onStart,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.download_outlined),
          tooltip: context.l10n.t('tunnels.exportLogs'),
          onPressed: onExportLogs,
        ),
      ],
    );
  }
}

class TunnelInfoSectionCard extends StatelessWidget {
  final bool editing;
  final Widget readOnlyChild;
  final Widget editableChild;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const TunnelInfoSectionCard({
    super.key,
    required this.editing,
    required this.readOnlyChild,
    required this.editableChild,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 0, right: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!editing) readOnlyChild else editableChild,
                if (editing) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        child: Text(context.l10n.t('common.cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onSave,
                        child: Text(context.l10n.t('common.save')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!editing)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: context.l10n.t('tunnels.edit'),
                onPressed: onEdit,
              ),
            ),
        ],
      ),
    );
  }
}

class TunnelLogsToolbar extends StatelessWidget {
  final Widget filterField;
  final VoidCallback onClearVisibleLogs;

  const TunnelLogsToolbar({
    super.key,
    required this.filterField,
    required this.onClearVisibleLogs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.l10n.t('tunnels.log'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(width: 16),
        SizedBox(width: 130, child: filterField),
        const Spacer(),
        TextButton.icon(
          onPressed: onClearVisibleLogs,
          icon: const Icon(Icons.clear_all, size: 18),
          label: Text(context.l10n.t('tunnels.clearVisibleLog')),
        ),
      ],
    );
  }
}
