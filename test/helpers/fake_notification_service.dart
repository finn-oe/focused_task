import 'package:focused_task/core/services/notification_service.dart';

/// Records notification calls instead of talking to the platform.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.grantPermission = true});

  /// What [requestPermission] answers.
  bool grantPermission;
  int permissionRequests = 0;
  final List<AppNotification> shown = [];
  final Map<int, (AppNotification, DateTime)> scheduled = {};
  final List<int> cancelled = [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<void> show(AppNotification notification) async => shown.add(notification);

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async => scheduled[notification.id] = (notification, at);

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}
