/// Notification-ready SIM delivery events.
///
/// Odoo is the source of truth: events are only built from payloads returned
/// by Odoo after the action was saved (or from a future FCM data message that
/// carries the same fields). Nothing is generated locally and no push is
/// simulated. Firebase push is intentionally NOT implemented yet.
class SimEventType {
  static const String customerReceived = 'sim.customer_received';
  static const String customerNotReceived = 'sim.customer_not_received';
}

class SimDeliveryEvent {
  final String eventType;
  final int tripId;
  final int customerId;
  final int? driverId;
  final String timestamp;

  const SimDeliveryEvent({
    required this.eventType,
    required this.tripId,
    required this.customerId,
    this.driverId,
    required this.timestamp,
  });

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Parses an Odoo event payload. Returns null for any other event type.
  static SimDeliveryEvent? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final type = (m['event_type'] ?? m['event'] ?? m['type'])?.toString();
    if (type != SimEventType.customerReceived &&
        type != SimEventType.customerNotReceived) {
      return null;
    }
    final driver = _i(m['driver_id']);
    return SimDeliveryEvent(
      eventType: type!,
      tripId: _i(m['trip_id']),
      customerId: _i(m['customer_id']),
      driverId: driver > 0 ? driver : null,
      timestamp: (m['timestamp'] ?? m['created_at'] ?? '').toString(),
    );
  }
}

/// Implement in the future FCM layer and register with [SimNotifications].
abstract class SimNotificationHandler {
  void onSimEvent(SimDeliveryEvent event);
}

class SimNotifications {
  SimNotifications._();

  static final List<SimNotificationHandler> _handlers = [];

  static void register(SimNotificationHandler handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  static void unregister(SimNotificationHandler handler) {
    _handlers.remove(handler);
  }

  /// Dispatches an Odoo-provided event payload to registered handlers.
  static SimDeliveryEvent? dispatch(dynamic payload) {
    final event = SimDeliveryEvent.fromMap(payload);
    if (event == null) return null;
    for (final h in List.of(_handlers)) {
      h.onSimEvent(event);
    }
    return event;
  }
}
