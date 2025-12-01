import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'package:tuna/di/settings/settings_controller.dart';
import 'package:tuna/di/tabs/tabs_controller.dart';
import 'package:tuna/presentation/console_screen.dart';
import 'package:tuna/presentation/settings_screen.dart';
import 'package:tuna/utils/helpers.dart';

import '../../../di/console/console_controller.dart';
import '../../../di/tunnels/tunnels_controller.dart';
import '../app_colors.dart';

import 'package:tuna/presentation/tunnels_screen.dart';

class AppShell extends StatelessWidget {
  final SettingsController settingsController;
  final TabsController tabsController;
  final TunnelsController tunnelsController;
  final ConsoleController consoleController;

  const AppShell({
    super.key,
    required this.settingsController,
    required this.tabsController,
    required this.tunnelsController,
    required this.consoleController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellBg = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: shellBg,
          ),
          child: Row(
            children: [
              _LeftSideMenu(
                tabsController: tabsController,
                tunnelsController: tunnelsController,
              ),

              // Вертикальный разделитель
              Container(
                width: 1,
                color: theme.dividerColor.withOpacity(0.6),
              ),

              // Правая часть
              Expanded(
                child: Column(
                  children: [
                    const _CustomTitleBar(),
                    Expanded(
                      child: _RightContent(
                        tabsController: tabsController,
                        settingsController: settingsController,
                        tunnelsController: tunnelsController,
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

// ===========================================================================
//                                TITLE BAR
// ===========================================================================

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
          Expanded(
            child: MoveWindow(
              child: const SizedBox.expand(),
            ),
          ),
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
    final hoverBg = cs.surfaceVariant.withOpacity(0.8);
    final pressedBg = cs.surfaceVariant;

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

// ===========================================================================
//                               LEFT SIDE MENU
// ===========================================================================

class _LeftSideMenu extends StatelessWidget {
  final TabsController tabsController;
  final TunnelsController tunnelsController;

  const _LeftSideMenu({
    required this.tabsController,
    required this.tunnelsController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final menuBg = isDark
        ? AppColors.sidebarBackgroundDark
        : AppColors.sidebarBackgroundLight;

    final titleColor = theme.colorScheme.onSurface;

    return Container(
      width: 220,
      color: menuBg,
      child: AnimatedBuilder(
        animation: Listenable.merge([tabsController, tunnelsController]),
        builder: (context, _) {
          final account = tunnelsController.accountInfo;
          final upgrade = tunnelsController.latestUpgrade;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Логотип / заголовок
              SizedBox(
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
                          fontFamily: "JetBrains Mono",
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ),
                ),
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
              // Вкладку настроек убрали отсюда — она теперь внизу в виде иконки

              const Spacer(),

              if (upgrade != null)
                _UpgradeSidebarTile(upgrade: upgrade),

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
                            launchWeb("https://my.tuna.am/profile"),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BottomIconButton(
                          icon: Icons.settings_outlined,
                          tooltip: 'Настройки',
                          tab: AppTab.settings,
                          tabsController: tabsController,
                        ),
                        _BottomIconButton(
                          icon: Icons.terminal_outlined,
                          tooltip: 'Консоль',
                          tab: AppTab.console,
                          tabsController: tabsController,
                        ),
                      ],
                    ),
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

// ----------------------------- TAB BUTTON ----------------------------------

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
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

// ------------------------- UPGRADE SIDEBAR TILE -----------------------------

class _UpgradeSidebarTile extends StatelessWidget {
  final UpgradeInfo upgrade;

  const _UpgradeSidebarTile({required this.upgrade});

  @override
  Widget build(BuildContext context) {
    if (upgrade.newVersion.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark
        ? Colors.orange.withOpacity(0.10)
        : Colors.orange.withOpacity(0.08);
    final border = Colors.orange.withOpacity(0.4);
    final textColor =
    isDark ? Colors.orange.shade200 : Colors.orange.shade800;

    final text = upgrade.currentVersion.isNotEmpty
        ? 'Доступна новая версия: ${upgrade.currentVersion} → ${upgrade.newVersion}'
        : 'Доступна новая версия: ${upgrade.newVersion}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.system_update_alt,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------- ACCOUNT SIDEBAR TILE -----------------------------

class _AccountSidebarTile extends StatelessWidget {
  final AccountInfo account;
  final VoidCallback onTap;

  const _AccountSidebarTile({
    required this.account,
    required this.onTap,
  });

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
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 18,
              color: secondaryText,
            ),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryText,
                    ),
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

// --------------------------- BOTTOM ICON BUTTON -----------------------------

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
            child: Icon(
              widget.icon,
              size: 20,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
//                              RIGHT CONTENT
// ===========================================================================

class _RightContent extends StatelessWidget {
  final TabsController tabsController;
  final SettingsController settingsController;
  final TunnelsController tunnelsController;
  final ConsoleController consoleController;

  const _RightContent({
    required this.tabsController,
    required this.settingsController,
    required this.tunnelsController,
    required this.consoleController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabsController,
      builder: (context, _) {
        switch (tabsController.current) {
          case AppTab.dashboard:
            return const Center(child: Text('Dashboard (заглушка)'));
          case AppTab.tunnels:
            return TunnelsScreen(controller: tunnelsController);
          case AppTab.settings:
            return SettingsScreen(controller: settingsController);
          case AppTab.console:
            return ConsoleScreen(controller: consoleController);
        }
      },
    );
  }
}
