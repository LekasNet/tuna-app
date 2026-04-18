import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

import 'package:tuna/di/settings/settings_controller.dart';
import 'package:tuna/di/tabs/tabs_controller.dart';
import 'package:tuna/di/docker/docker_controller.dart';
import 'package:tuna/di/tunnels/remote_tunnels_controller.dart';
import 'package:tuna/presentation/console_screen.dart';
import 'package:tuna/presentation/dashboard_screen.dart';
import 'package:tuna/presentation/docker_screen.dart';
import 'package:tuna/presentation/remote_tunnels_screen.dart';
import 'package:tuna/presentation/settings_screen.dart';
import 'package:tuna/presentation/tunnels_screen.dart';
import 'package:tuna/utils/helpers.dart';

import '../../../di/console/console_controller.dart';
import '../../../di/notifications/notification_actions.dart';
import '../../../di/notifications/notification_models.dart';
import '../../../di/notifications/notifications_controller.dart';
import '../../../di/tunnels/tunnels_controller.dart';
import '../app_colors.dart';

class AppShell extends StatelessWidget {
  final SettingsController settingsController;
  final TabsController tabsController;
  final TunnelsController tunnelsController;
  final DockerController dockerController;
  final RemoteTunnelsController remoteTunnelsController;
  final ConsoleController consoleController;
  final NotificationsController notificationsController;

  const AppShell({
    super.key,
    required this.settingsController,
    required this.tabsController,
    required this.tunnelsController,
    required this.dockerController,
    required this.remoteTunnelsController,
    required this.consoleController,
    required this.notificationsController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellBg = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(color: shellBg),
          child: Row(
            children: [
              _LeftSideMenu(
                tabsController: tabsController,
                tunnelsController: tunnelsController,
                notificationsController: notificationsController,
              ),
              Container(width: 1, color: theme.dividerColor.withOpacity(0.6)),
              Expanded(
                child: Column(
                  children: [
                    const _CustomTitleBar(),
                    Expanded(
                      child: _RightContent(
                        tabsController: tabsController,
                        settingsController: settingsController,
                        tunnelsController: tunnelsController,
                        dockerController: dockerController,
                        remoteTunnelsController: remoteTunnelsController,
                        consoleController: consoleController,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomTitleBar extends StatelessWidget {
  const _CustomTitleBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.surface;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: barColor,
      child: Row(
        children: [
          Expanded(child: MoveWindow(child: const SizedBox.expand())),
          const _WindowButtons(),
        ],
      ),
    );
  }
}

class _WindowButtons extends StatefulWidget {
  const _WindowButtons();

  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> {
  void _maximizeOrRestore() {
    setState(() {
      appWindow.maximizeOrRestore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final iconColor = cs.onSurface;
    final hoverBg = cs.surfaceContainerHighest.withOpacity(0.8);
    final pressedBg = cs.surfaceContainerHighest;

    final buttonColors = WindowButtonColors(
      iconNormal: iconColor,
      iconMouseOver: iconColor,
      iconMouseDown: iconColor,
      mouseOver: hoverBg,
      mouseDown: pressedBg,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: iconColor,
      iconMouseOver: cs.onError,
      iconMouseDown: cs.onError,
      mouseOver: cs.error.withOpacity(0.9),
      mouseDown: cs.error,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        appWindow.isMaximized
            ? RestoreWindowButton(
                colors: buttonColors,
                onPressed: _maximizeOrRestore,
              )
            : MaximizeWindowButton(
                colors: buttonColors,
                onPressed: _maximizeOrRestore,
              ),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}

class _LeftSideMenu extends StatelessWidget {
  final TabsController tabsController;
  final TunnelsController tunnelsController;
  final NotificationsController notificationsController;

  const _LeftSideMenu({
    required this.tabsController,
    required this.tunnelsController,
    required this.notificationsController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final menuBg = isDark
        ? AppColors.sidebarBackgroundDark
        : AppColors.sidebarBackgroundLight;
    final titleColor = theme.colorScheme.onSurface;

    return SizedBox(
      width: 220,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          tabsController,
          tunnelsController,
          notificationsController,
        ]),
        builder: (context, _) {
          final account = tunnelsController.accountInfo;
          final panelOpen = notificationsController.isPanelOpen;

          return Stack(
            children: [
              Container(
                color: menuBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: MoveWindow(child: const SizedBox.expand()),
                    ),
                    const SizedBox(height: 12),
                    _TabButton(
                      label: 'Обзор',
                      icon: Icons.dashboard_outlined,
                      selected: tabsController.current == AppTab.dashboard,
                      onTap: () => tabsController.selectTab(AppTab.dashboard),
                    ),
                    _TabButton(
                      label: 'Туннели',
                      icon: Icons.device_hub_outlined,
                      selected: tabsController.current == AppTab.tunnels,
                      onTap: () => tabsController.selectTab(AppTab.tunnels),
                    ),
                    _TabButton(
                      label: 'Docker',
                      icon: Icons.dns_outlined,
                      selected: tabsController.current == AppTab.docker,
                      onTap: () => tabsController.selectTab(AppTab.docker),
                    ),
                    _TabButton(
                      label: 'Удалённые',
                      icon: Icons.cloud_outlined,
                      selected: tabsController.current == AppTab.remoteTunnels,
                      onTap: () =>
                          tabsController.selectTab(AppTab.remoteTunnels),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 12,
                        top: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (account != null)
                            _AccountSidebarTile(
                              account: account,
                              onTap: () =>
                                  launchWeb('https://my.tuna.am/profile'),
                            ),
                          const SizedBox(height: 12),
                          _BottomActionRow(
                            tabsController: tabsController,
                            notificationsController: notificationsController,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: _SidebarBlurOverlay(isDark: isDark, visible: panelOpen),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 48,
                child: MoveWindow(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'tuna',
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (panelOpen)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 62, 10, 70),
                    child: _NotificationsPanel(
                      notificationsController: notificationsController,
                    ),
                  ),
                ),
              if (panelOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 44, height: 36),
                      _NotificationToggleButton(
                        notificationsController: notificationsController,
                      ),
                      const SizedBox(width: 44, height: 36),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SidebarBlurOverlay extends StatelessWidget {
  final bool isDark;
  final bool visible;

  const _SidebarBlurOverlay({required this.isDark, required this.visible});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(end: visible ? 1.0 : 0.0),
      builder: (context, t, _) {
        if (t <= 0.001) {
          return const SizedBox.shrink();
        }

        return AbsorbPointer(
          absorbing: visible,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 11 * t, sigmaY: 11 * t),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  final NotificationsController notificationsController;

  const _NotificationsPanel({required this.notificationsController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifications = notificationsController.notifications;
    final mutedColor = theme.colorScheme.onSurface.withOpacity(0.68);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Text(
            'Уведомления',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: notifications.isEmpty
              ? Center(
                  child: Text(
                    'Нет уведомлений',
                    style: TextStyle(color: mutedColor),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationTile(
                      key: ValueKey(notification.id),
                      notification: notification,
                      notificationsController: notificationsController,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatefulWidget {
  final AppNotification notification;
  final NotificationsController notificationsController;

  const _NotificationTile({
    super.key,
    required this.notification,
    required this.notificationsController,
  });

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  static const _actionsAnimationDuration = Duration(milliseconds: 220);
  bool _showUpgradeActions = false;

  bool get _isUpgradeChoiceTile =>
      widget.notification.action == NotificationAction.openUpgradeInstructions;

  @override
  void didUpdateWidget(covariant _NotificationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isUpgradeChoiceTile) {
      _showUpgradeActions = false;
    }
  }

  Color _accentFor(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        return Colors.blue;
      case NotificationSeverity.warning:
        return Colors.orange;
      case NotificationSeverity.error:
        return Colors.red;
    }
  }

  IconData _iconFor(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        return Icons.info_outline_rounded;
      case NotificationSeverity.warning:
        return Icons.warning_amber_rounded;
      case NotificationSeverity.error:
        return Icons.error_outline_rounded;
    }
  }

  Future<bool> _runNotificationAction({
    NotificationAction? action,
    String? payload,
  }) async {
    final success = action != null
        ? await widget.notificationsController.executeAction(
            action,
            payload: payload,
          )
        : await widget.notificationsController.handleNotificationTap(
            widget.notification,
          );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось выполнить действие уведомления'),
        ),
      );
    }
    return success;
  }

  Future<void> _runUpgradeCommand() async {
    widget.notificationsController.markCliUpgradeStarted();
    if (mounted) {
      setState(() => _showUpgradeActions = false);
    }
    final success = await _runNotificationAction(
      action: NotificationAction.runTunaCliUpgrade,
    );
    widget.notificationsController.markCliUpgradeFinished(success: success);
  }

  Future<void> _runSiteAction() async {
    await _runNotificationAction();
    if (!mounted) return;
    setState(() => _showUpgradeActions = false);
  }

  void _handleTileTap() {
    if (!widget.notification.hasAction) return;
    if (_isUpgradeChoiceTile) {
      setState(() => _showUpgradeActions = !_showUpgradeActions);
      return;
    }
    _runNotificationAction();
  }

  Widget _buildMainContent({
    required BuildContext context,
    required Color accent,
    required Color baseText,
    required Color secondaryText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              _iconFor(widget.notification.severity),
              size: 16,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.notification.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: baseText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.notification.message,
                  style: TextStyle(fontSize: 11, color: secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeActionsOverlay() {
    final visible = _showUpgradeActions;

    Widget actionButton({
      required String text,
      required VoidCallback onPressed,
    }) {
      return TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(0, 28),
          visualDensity: VisualDensity.compact,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(text),
      );
    }

    return IgnorePointer(
      ignoring: !visible,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            AnimatedSlide(
              duration: _actionsAnimationDuration,
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : const Offset(-0.25, 0),
              child: AnimatedOpacity(
                duration: _actionsAnimationDuration,
                curve: Curves.easeOutCubic,
                opacity: visible ? 1 : 0,
                child: actionButton(text: 'На сайт', onPressed: _runSiteAction),
              ),
            ),
            const Spacer(),
            AnimatedSlide(
              duration: _actionsAnimationDuration,
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : const Offset(0.25, 0),
              child: AnimatedOpacity(
                duration: _actionsAnimationDuration,
                curve: Curves.easeOutCubic,
                opacity: visible ? 1 : 0,
                child: actionButton(
                  text: 'Обновить',
                  onPressed: _runUpgradeCommand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(widget.notification.severity);
    final baseText = theme.colorScheme.onSurface;
    final secondaryText = baseText.withOpacity(0.74);

    return Material(
      color: accent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.notification.hasAction ? _handleTileTap : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: _actionsAnimationDuration,
              curve: Curves.easeOutCubic,
              tween: Tween<double>(end: _showUpgradeActions ? 1.0 : 0.0),
              builder: (context, t, _) {
                final content = _buildMainContent(
                  context: context,
                  accent: accent,
                  baseText: baseText,
                  secondaryText: secondaryText,
                );
                if (!_isUpgradeChoiceTile || t <= 0.001) {
                  return content;
                }

                return ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 4.8 * t,
                    sigmaY: 4.8 * t,
                  ),
                  child: content,
                );
              },
            ),
            if (_isUpgradeChoiceTile) _buildUpgradeActionsOverlay(),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;

    if (widget.selected) {
      bg = cs.primary.withOpacity(0.10);
      fg = cs.primary;
    } else if (_hovered) {
      bg = cs.primary.withOpacity(0.06);
      fg = cs.primary;
    } else {
      bg = Colors.transparent;
      fg = cs.onSurface.withOpacity(0.7);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSidebarTile extends StatelessWidget {
  final AccountInfo account;
  final VoidCallback onTap;

  const _AccountSidebarTile({required this.account, required this.onTap});

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Дата не указана';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final primaryText = cs.onSurface;
    final secondaryText = cs.onSurface.withOpacity(0.6);
    final subtitle = 'Подписка до ${_formatDate(account.paidTill)}';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 18, color: secondaryText),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionRow extends StatelessWidget {
  final TabsController tabsController;
  final NotificationsController notificationsController;

  const _BottomActionRow({
    required this.tabsController,
    required this.notificationsController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _BottomIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Настройки',
          tab: AppTab.settings,
          tabsController: tabsController,
        ),
        _NotificationToggleButton(
          notificationsController: notificationsController,
        ),
        _BottomIconButton(
          icon: Icons.terminal_outlined,
          tooltip: 'Консоль',
          tab: AppTab.console,
          tabsController: tabsController,
        ),
      ],
    );
  }
}

class _BottomIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final AppTab tab;
  final TabsController tabsController;

  const _BottomIconButton({
    required this.icon,
    required this.tooltip,
    required this.tab,
    required this.tabsController,
  });

  @override
  State<_BottomIconButton> createState() => _BottomIconButtonState();
}

class _BottomIconButtonState extends State<_BottomIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = widget.tabsController.current == widget.tab;

    final bg = selected
        ? cs.primary.withOpacity(0.18)
        : (_hovered ? cs.primary.withOpacity(0.08) : Colors.transparent);

    final fg = selected
        ? cs.primary
        : cs.onSurface.withOpacity(_hovered ? 0.9 : 0.7);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => widget.tabsController.selectTab(widget.tab),
          child: Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}

class _NotificationToggleButton extends StatefulWidget {
  final NotificationsController notificationsController;

  const _NotificationToggleButton({required this.notificationsController});

  @override
  State<_NotificationToggleButton> createState() =>
      _NotificationToggleButtonState();
}

class _NotificationToggleButtonState extends State<_NotificationToggleButton> {
  static const _panelAnimationDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selected = widget.notificationsController.isPanelOpen;
    final hasNotifications = widget.notificationsController.hasNotifications;

    final fg = selected ? cs.primary : cs.onSurface.withOpacity(0.74);
    final bellScale = selected ? 1.08 : 1.0;
    final bellOffset = selected ? const Offset(0, -0.12) : Offset.zero;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Уведомления',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.notificationsController.togglePanel,
          child: SizedBox(
            width: 44,
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: AnimatedOpacity(
                    duration: _panelAnimationDuration,
                    curve: Curves.easeOutCubic,
                    opacity: selected ? 1 : 0,
                    child: IgnorePointer(
                      child: Transform.translate(
                        offset: const Offset(0, 2),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 1.8,
                            sigmaY: 1.8,
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.black.withOpacity(0.46)
                                : Colors.black.withOpacity(0.22),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedSlide(
                    duration: _panelAnimationDuration,
                    curve: Curves.easeOutCubic,
                    offset: bellOffset,
                    child: AnimatedScale(
                      duration: _panelAnimationDuration,
                      curve: Curves.easeOutCubic,
                      scale: bellScale,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 20,
                            color: fg,
                          ),
                          if (hasNotifications)
                            Positioned(
                              right: -2,
                              top: -1,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RightContent extends StatelessWidget {
  final TabsController tabsController;
  final SettingsController settingsController;
  final TunnelsController tunnelsController;
  final DockerController dockerController;
  final RemoteTunnelsController remoteTunnelsController;
  final ConsoleController consoleController;

  const _RightContent({
    required this.tabsController,
    required this.settingsController,
    required this.tunnelsController,
    required this.dockerController,
    required this.remoteTunnelsController,
    required this.consoleController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabsController,
      builder: (context, _) {
        switch (tabsController.current) {
          case AppTab.dashboard:
            return DashboardScreen(
              tabsController: tabsController,
              tunnelsController: tunnelsController,
            );
          case AppTab.tunnels:
            return TunnelsScreen(controller: tunnelsController);
          case AppTab.docker:
            return DockerScreen(controller: dockerController);
          case AppTab.remoteTunnels:
            return RemoteTunnelsScreen(
              controller: remoteTunnelsController,
              settingsController: settingsController,
              tunnelsController: tunnelsController,
            );
          case AppTab.settings:
            return SettingsScreen(controller: settingsController);
          case AppTab.console:
            return ConsoleScreen(controller: consoleController);
        }
      },
    );
  }
}
