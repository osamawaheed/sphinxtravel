/// Navigation targets a notification can open.
class NotificationTarget {
  static const String driverProfileReviews = 'driver_profile_reviews';
}

/// `driver.review.received` event.
///
/// Odoo is the source of truth: an event is only built from data returned by
/// Odoo after the review was saved. Nothing here is generated locally.
class DriverReviewEvent {
  static const String name = 'driver.review.received';

  final String eventId;
  final int driverId;
  final int customerId;
  final int tripId;
  final double rating;
  final String timestamp;
  final String navigationTarget;

  const DriverReviewEvent({
    required this.eventId,
    required this.driverId,
    required this.customerId,
    required this.tripId,
    required this.rating,
    required this.timestamp,
    this.navigationTarget = NotificationTarget.driverProfileReviews,
  });

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Parses an event payload sent by Odoo (or by an FCM data message that
  /// carries the same fields). Returns null when it is not a
  /// `driver.review.received` event or lacks an event id.
  static DriverReviewEvent? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final type = (m['event'] ?? m['event_type'] ?? m['type'])?.toString();
    if (type != null && type.isNotEmpty && type != name) return null;
    final id = (m['event_id'] ?? m['id'])?.toString() ?? '';
    if (id.isEmpty) return null;
    final rating = m['rating'];
    return DriverReviewEvent(
      eventId: id,
      driverId: _i(m['driver_id']),
      customerId: _i(m['customer_id']),
      tripId: _i(m['trip_id']),
      rating: rating is num
          ? rating.toDouble()
          : double.tryParse(rating?.toString() ?? '') ?? 0,
      timestamp: (m['timestamp'] ?? m['created_at'] ?? '').toString(),
      navigationTarget:
          (m['navigation_target'] ?? NotificationTarget.driverProfileReviews)
              .toString(),
    );
  }
}

/// Receives review events once a notification backend exists.
///
/// Future Firebase FCM integration: implement [DriverReviewNotificationHandler]
/// in the FCM layer and call [DriverReviewNotifications.dispatch] with the
/// message data map from `onMessage` / `onMessageOpenedApp`. No push is
/// simulated here.
abstract class DriverReviewNotificationHandler {
  void onDriverReviewReceived(DriverReviewEvent event);
}

class DriverReviewNotifications {
  DriverReviewNotifications._();

  static final List<DriverReviewNotificationHandler> _handlers = [];
  static final Set<String> _seen = <String>{};

  static void register(DriverReviewNotificationHandler handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  static void unregister(DriverReviewNotificationHandler handler) {
    _handlers.remove(handler);
  }

  /// Clears per-user dispatch state (used on sign-out).
  static void reset() {
    _seen.clear();
  }

  /// Dispatches an Odoo-provided event payload to registered handlers.
  /// Duplicate event ids are ignored. Returns the parsed event, or null.
  static DriverReviewEvent? dispatch(dynamic payload) {
    final event = DriverReviewEvent.fromMap(payload);
    if (event == null) return null;
    if (!_seen.add(event.eventId)) return event;
    for (final h in List.of(_handlers)) {
      h.onDriverReviewReceived(event);
    }
    return event;
  }
}
