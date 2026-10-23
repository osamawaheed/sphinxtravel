import 'package:flutter/foundation.dart';

import '../models/app_notification_model.dart';

/// Source of notifications for the signed-in account.
///
/// Odoo 17 is the source of truth. No notification endpoint exists in the
/// current Odoo API, so none is invented here. When Odoo exposes one, add an
/// implementation of [NotificationSource] (list + mark-read) and assign it to
/// [NotificationService.source]. The default [LocalDemoNotificationSource]
/// is a clearly labeled local demo state that returns no data.
abstract class NotificationSource {
  /// True when this source is a local placeholder rather than Odoo.
  bool get isLocalDemo;

  Future<List<AppNotification>> fetch();

  /// Persists the read state in the backend (no-op for the local demo).
  Future<void> markRead(List<String> ids);
}

/// LOCAL DEMO STATE — used until Odoo notification APIs are available.
/// Returns an empty list on purpose: no notification data is invented.
class LocalDemoNotificationSource implements NotificationSource {
  const LocalDemoNotificationSource();

  @override
  bool get isLocalDemo => true;

  @override
  Future<List<AppNotification>> fetch() async => const [];

  @override
  Future<void> markRead(List<String> ids) async {}
}

/// Receives push messages in the future.
///
/// Future Firebase FCM integration: in the FCM layer call
/// [NotificationService.ingest] with the message data map from `onMessage` /
/// `onMessageOpenedApp`. FCM is intentionally NOT implemented yet.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  NotificationSource source = const LocalDemoNotificationSource();

  List<AppNotification> _items = const [];
  bool _loading = false;
  bool _failed = false;

  /// Bumped on every reset so late responses from a previous account are
  /// ignored.
  int _generation = 0;

  List<AppNotification> get items => _items;
  bool get isLoading => _loading;
  bool get hasError => _failed;
  bool get isLocalDemo => source.isLocalDemo;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  List<AppNotification> _sorted(Iterable<AppNotification> list) {
    final copy = list.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  /// Loads the signed-in account's notifications (newest first).
  Future<void> refresh() async {
    if (_loading) return;
    final gen = _generation;
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      final fetched = await source.fetch();
      if (gen != _generation) return;
      _items = _sorted(fetched);
    } catch (_) {
      if (gen != _generation) return;
      _failed = true;
      debugPrint('[NOTIFICATIONS] Failed to load notifications.');
    } finally {
      if (gen == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Adds a notification delivered by Odoo / a future FCM data message.
  /// Duplicates (same id) are ignored.
  AppNotification? ingest(dynamic payload) {
    final n = AppNotification.fromMap(payload);
    if (n == null) return null;
    if (_items.any((e) => e.id == n.id)) return n;
    _items = _sorted([..._items, n]);
    notifyListeners();
    return n;
  }

  Future<void> markAsRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0 || _items[idx].isRead) return;
    final updated = List<AppNotification>.of(_items);
    updated[idx] = updated[idx].copyWith(isRead: true);
    _items = updated;
    notifyListeners();
    try {
      await source.markRead([id]);
    } catch (_) {
      debugPrint('[NOTIFICATIONS] Failed to sync read state.');
    }
  }

  Future<void> markAllAsRead() async {
    final unread = _items.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unread.isEmpty) return;
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    try {
      await source.markRead(unread);
    } catch (_) {
      debugPrint('[NOTIFICATIONS] Failed to sync read state.');
    }
  }

  /// Clears all account-specific notification state (used on sign-out).
  void reset() {
    _generation++;
    _items = const [];
    _loading = false;
    _failed = false;
    notifyListeners();
  }

  /// Returns the route to open for [n], or null when there is no valid
  /// navigation target for the current role.
  static String? validRouteFor(AppNotification n, {required bool isDriver}) {
    final route = n.targetRoute;
    if (route == null) return null;
    const driverRoutes = {'/driver/ratings', '/driver/home'};
    const customerRoutes = {'/customer/home'};
    final allowed = isDriver ? driverRoutes : customerRoutes;
    if (route == 'driver_profile_reviews') {
      return isDriver ? '/driver/ratings' : null;
    }
    return allowed.contains(route) ? route : null;
  }
}
