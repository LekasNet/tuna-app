import 'package:flutter/foundation.dart';

import 'notification_actions.dart';
import 'notification_models.dart';

class NotificationsController extends ChangeNotifier {
  static const String _upgradeNotificationId = 'tuna-upgrade-available';
  static const String _upgradeResultNotificationId = 'tuna-upgrade-result';
  static const String _appUpdateNotificationId = 'desktop-app-update-available';
  static const String _remoteTunnelsNotificationId = 'remote-tunnels-running';

  bool _isPanelOpen = false;
  bool _cliUpgradeInProgress = false;
  String? _knownCliCurrentVersion;
  String? _knownCliTargetVersion;
  String? _knownCliUpdateUrl;
  String? _lastCompletedTargetVersion;

  final List<AppNotification> _notifications = <AppNotification>[];

  bool get isPanelOpen => _isPanelOpen;
  bool get hasNotifications => _notifications.isNotEmpty;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  void togglePanel() {
    _isPanelOpen = !_isPanelOpen;
    notifyListeners();
  }

  void closePanel() {
    if (!_isPanelOpen) return;
    _isPanelOpen = false;
    notifyListeners();
  }

  Future<bool> handleNotificationTap(AppNotification notification) async {
    final action = notification.action;
    if (action == null) return true;
    return executeAction(action, payload: notification.actionPayload);
  }

  Future<bool> executeAction(
    NotificationAction action, {
    String? payload,
  }) async {
    try {
      await executeNotificationAction(action, payload: payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  void syncUpgradeNotification({
    required String? currentVersion,
    required String? newVersion,
    String? updateUrl,
  }) {
    final nextVersion = newVersion?.trim() ?? '';
    if (nextVersion.isEmpty) {
      _knownCliCurrentVersion = null;
      _knownCliTargetVersion = null;
      _knownCliUpdateUrl = null;
      _cliUpgradeInProgress = false;
      _removeById(_upgradeNotificationId);
      return;
    }

    _knownCliCurrentVersion = currentVersion?.trim();
    _knownCliTargetVersion = nextVersion;
    _knownCliUpdateUrl = updateUrl?.trim();

    if (_lastCompletedTargetVersion == nextVersion && !_cliUpgradeInProgress) {
      _removeById(_upgradeNotificationId);
      return;
    }

    if (_cliUpgradeInProgress) {
      _upsert(_buildCliUpgradeProgressNotification());
      return;
    }

    final message = (_knownCliCurrentVersion?.isNotEmpty ?? false)
        ? 'Доступна новая версия tuna CLI: ${_knownCliCurrentVersion!} -> $nextVersion'
        : 'Доступна новая версия tuna CLI: $nextVersion';

    _upsert(
      AppNotification(
        id: _upgradeNotificationId,
        title: 'Обновление tuna CLI',
        message: message,
        severity: NotificationSeverity.warning,
        action: NotificationAction.openUpgradeInstructions,
        actionPayload: _knownCliUpdateUrl,
        actionLabel: NotificationAction.openUpgradeInstructions.label,
        createdAt: DateTime.now(),
      ),
    );
  }

  void markCliUpgradeStarted() {
    if (_knownCliTargetVersion == null || _knownCliTargetVersion!.isEmpty) {
      return;
    }
    _cliUpgradeInProgress = true;
    _upsert(_buildCliUpgradeProgressNotification());
  }

  void markCliUpgradeFinished({required bool success}) {
    final target = _knownCliTargetVersion;
    _cliUpgradeInProgress = false;

    if (!success) {
      if (target != null && target.isNotEmpty) {
        syncUpgradeNotification(
          currentVersion: _knownCliCurrentVersion,
          newVersion: target,
          updateUrl: _knownCliUpdateUrl,
        );
      }
      _upsert(
        AppNotification(
          id: _upgradeResultNotificationId,
          title: 'Обновление tuna CLI',
          message: 'Обновление не завершилось успешно. Попробуйте ещё раз.',
          severity: NotificationSeverity.error,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }

    _removeById(_upgradeNotificationId);
    _lastCompletedTargetVersion = target;

    final text = (target?.isNotEmpty ?? false)
        ? 'tuna CLI успешно обновлён до версии $target.'
        : 'tuna CLI успешно обновлён.';

    _upsert(
      AppNotification(
        id: _upgradeResultNotificationId,
        title: 'Обновление tuna CLI',
        message: text,
        severity: NotificationSeverity.info,
        createdAt: DateTime.now(),
      ),
    );
  }

  void syncDesktopAppUpdateNotification({
    required String? currentVersion,
    required String? newVersion,
    String? releaseUrl,
  }) {
    final latest = newVersion?.trim() ?? '';
    if (latest.isEmpty) {
      _removeById(_appUpdateNotificationId);
      return;
    }

    final current = currentVersion?.trim() ?? '';
    final message = current.isNotEmpty
        ? 'Доступна новая версия tuna-app: $current -> $latest'
        : 'Доступна новая версия tuna-app: $latest';

    _upsert(
      AppNotification(
        id: _appUpdateNotificationId,
        title: 'Обновление приложения',
        message: message,
        severity: NotificationSeverity.info,
        action: NotificationAction.openDesktopAppRelease,
        actionPayload: releaseUrl?.trim(),
        actionLabel: NotificationAction.openDesktopAppRelease.label,
        createdAt: DateTime.now(),
      ),
    );
  }

  void syncRemoteTunnelsNotification(int activeRemoteCount) {
    if (activeRemoteCount <= 0) {
      _removeById(_remoteTunnelsNotificationId);
      return;
    }

    final noun = activeRemoteCount == 1 ? 'туннель' : 'туннелей';
    final message = 'На сервере сейчас активны $activeRemoteCount $noun.';

    _upsert(
      AppNotification(
        id: _remoteTunnelsNotificationId,
        title: 'Активные удалённые туннели',
        message: message,
        severity: NotificationSeverity.info,
        action: NotificationAction.openTunnelsDashboard,
        actionPayload: 'https://my.tuna.am/tunnels',
        actionLabel: NotificationAction.openTunnelsDashboard.label,
        createdAt: DateTime.now(),
      ),
    );
  }

  AppNotification _buildCliUpgradeProgressNotification() {
    final target = _knownCliTargetVersion ?? '';
    final message = target.isNotEmpty
        ? 'Идёт обновление tuna CLI до версии $target...'
        : 'Идёт обновление tuna CLI...';

    return AppNotification(
      id: _upgradeNotificationId,
      title: 'Обновление tuna CLI',
      message: message,
      severity: NotificationSeverity.info,
      createdAt: DateTime.now(),
    );
  }

  void _upsert(AppNotification nextItem) {
    final existingIndex = _notifications.indexWhere(
      (item) => item.id == nextItem.id,
    );

    if (existingIndex == -1) {
      _notifications.insert(0, nextItem);
      notifyListeners();
      return;
    }

    final previous = _notifications[existingIndex];
    final changed =
        previous.title != nextItem.title ||
        previous.message != nextItem.message ||
        previous.severity != nextItem.severity ||
        previous.action != nextItem.action ||
        previous.actionPayload != nextItem.actionPayload ||
        previous.actionLabel != nextItem.actionLabel;

    if (!changed) return;

    _notifications[existingIndex] = nextItem;
    notifyListeners();
  }

  void _removeById(String id) {
    final before = _notifications.length;
    _notifications.removeWhere((item) => item.id == id);
    if (_notifications.length != before) {
      notifyListeners();
    }
  }
}
