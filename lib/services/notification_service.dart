import 'package:flutter/foundation.dart';

import '../models/app_notification_model.dart';

/// Source of notifications for the signed-in account.
///
/// Odoo 17 is the source of truth. Implementations of [NotificationSource]
/// (list + optional mark-read) are assigned to [NotificationService.source].
/// The default [LocalDemoNotificationSource] is a clearly labeled local demo
/// state that returns no data.
abstract class NotificationSource {
  /// True when this source is a local placeholder rather than Odoo.
  bool get isLocalDemo;

  /// False when the source is read-only. The service then never changes read
  /// state locally and the UI does not pretend an update succeeded.
  bool get supportsMarkRead => true;

  Future<List<AppNotification>> fetch();

  /// Persists the read state in the backend (no-op for the local demo).
  Future<void> markRead(List<String> ids);

  /// Releases resources (cached tokens, clients). Optional.
  Future<void> dispose() async {}
}

/// LOCAL DEMO STATE — used until Odoo notification APIs are available.
/// Returns an empty list on purpose: no notification data is invented.
class LocalDemoNotificationSource implements NotificationSource {
  const LocalDemoNotificationSource();

  @override
  bool get isLocalDemo => true;

  @override
  bool get supportsMarkRead => true;

  @override
  Future<List<AppNotification>> fetch() async => const [];

  @override
  Future<void> markRead(List<String> ids) async {}

  @override
  Future<void> dispose() async {}
}

/// Receives push messages in the future.
///
/// Future Firebase FCM integration: in the FCM layer call
/// [NotificationService.ingest] with the message data map from `onMessage` /
/// `onMessageOpenedApp`. FCM is intentionally NOT implemented yet.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  NotificationSource _source = const LocalDemoNotificationSource();

  NotificationSource get source => _source;

  set source(NotificationSource value) {
    if (identical(value, _source)) return;
    final old = _source;
    _source = value;
    // Data from the previous source must not leak into the new one.
    _generation++;
    _items = const [];
    _loading = false;
    _failed = false;
    _marking = false;
    _markFailed = false;
    old.dispose();
    notifyListeners();
  }

  List<AppNotification> _items = const [];
  bool _loading = false;
  bool _failed = false;
  bool _marking = false;
  bool _markFailed = false;

  /// Bumped on every reset so late responses from a previous account are
  /// ignored.
  int _generation = 0;

  List<AppNotification> get items => _items;
  bool get isLoading => _loading;
  bool get hasError => _failed;

  /// True while a mark-read request is running (blocks duplicate requests).
  bool get isMarking => _marking;

  /// True when the last mark-read request failed (nothing was changed).
  bool get markFailed => _markFailed;
  bool get isLocalDemo => _source.isLocalDemo;

  /// False while the active source is read-only (mark-read is disabled).
  bool get canMarkRead => _source.supportsMarkRead;
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
      final fetched = await _source.fetch();
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

  /// Marks one notification as read. The backend is called first; the list
  /// and unread count are then reloaded from the source. Nothing is changed
  /// locally if the call fails. Returns true on success.
  Future<bool> markAsRead(String id) async {
    if (!canMarkRead || _marking) return false;
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0 || _items[idx].isRead) return false;
    return _markIds([id]);
  }

  /// Marks all currently loaded unread notifications as read. Returns true
  /// on success; nothing is changed locally if the call fails.
  Future<bool> markAllAsRead() async {
    if (!canMarkRead || _marking) return false;
    final unread = _items.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unread.isEmpty) return false;
    return _markIds(unread);
  }

  Future<bool> _markIds(List<String> ids) async {
    final gen = _generation;
    _marking = true;
    _markFailed = false;
    notifyListeners();
    var ok = false;
    try {
      await _source.markRead(ids);
      ok = true;
    } catch (_) {
      debugPrint('[NOTIFICATIONS] Failed to mark notifications as read.');
      if (gen == _generation) _markFailed = true;
    }
    if (gen != _generation) return false;
    _marking = false;
    notifyListeners();
    if (ok) {
      // Reload list and unread counter from the backend.
      await _reload(gen);
    }
    return ok;
  }

  /// Reloads items without flipping the list into the loading state.
  Future<void> _reload(int gen) async {
    try {
      final fetched = await _source.fetch();
      if (gen != _generation) return;
      _items = _sorted(fetched);
      _failed = false;
    } catch (_) {
      debugPrint('[NOTIFICATIONS] Failed to reload notifications.');
    }
    if (gen == _generation) notifyListeners();
  }

  /// Clears all account-specific notification state (used on sign-out) and
  /// reverts to the local demo source.
  void reset() {
    _generation++;
    _items = const [];
    _loading = false;
    _failed = false;
    _marking = false;
    _markFailed = false;
    final old = _source;
    _source = const LocalDemoNotificationSource();
    old.dispose();
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
