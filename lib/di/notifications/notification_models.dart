import 'notification_actions.dart';

enum NotificationSeverity { info, warning, error }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationSeverity severity;
  final NotificationAction? action;
  final String? actionPayload;
  final String? actionLabel;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    this.action,
    this.actionPayload,
    this.actionLabel,
    required this.createdAt,
  });

  bool get hasAction => action != null;
}
