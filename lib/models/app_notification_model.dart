/// A single in-app notification.
///
/// Odoo 17 is the source of truth. Instances are only built from payloads
/// returned by Odoo (or from a future FCM data message carrying the same
/// fields). Nothing is generated locally.
class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  /// Optional app route (e.g. "/driver/ratings") opened when tapped.
  final String? targetRoute;

  /// Optional extra payload passed to the target route.
  final Map<String, dynamic>? targetExtra;

  /// Structured fields (set for rows read from public.app_notifications).
  /// When [notificationType] is set, the UI resolves a localized title and
  /// message from it instead of using [title]/[message].
  final String? notificationType;
  final String? category;
  final Map<String, dynamic> params;
  final String? bookingReference;
  final String? bookingId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.targetRoute,
    this.targetExtra,
    this.notificationType,
    this.category,
    this.params = const {},
    this.bookingReference,
    this.bookingId,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    message: message,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    targetRoute: targetRoute,
    targetExtra: targetExtra,
    notificationType: notificationType,
    category: category,
    params: params,
    bookingReference: bookingReference,
    bookingId: bookingId,
  );

  static bool _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return false;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// Parses a row of public.app_notifications. Returns null when the row has
  /// no id or no notification_type.
  static AppNotification? fromSupabaseRow(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = _str(m['id']);
    final type = _str(m['notification_type']);
    if (id == null || type == null) return null;

    var params = <String, dynamic>{};
    final p = m['params'];
    if (p is Map) {
      params = Map<String, dynamic>.from(p);
    }

    final occurred = _str(m['occurred_at']);
    final parsed = occurred == null ? null : DateTime.tryParse(occurred);

    return AppNotification(
      id: id,
      title: '',
      message: '',
      createdAt: (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal(),
      isRead: _bool(m['is_read']),
      notificationType: type,
      category: _str(m['category']),
      params: params,
      bookingReference: _str(m['booking_reference']),
      bookingId: _str(m['booking_id']),
    );
  }

  /// Parses an Odoo notification record. Returns null when the payload has no
  /// id or no displayable content.
  static AppNotification? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = (m['id'] ?? m['notification_id'] ?? m['event_id'])?.toString();
    if (id == null || id.isEmpty) return null;
    final title = (m['title'] ?? '').toString();
    final message = (m['message'] ?? m['body'] ?? '').toString();
    if (title.isEmpty && message.isEmpty) return null;

    final created = (m['created_at'] ?? m['timestamp'] ?? m['date'])
        ?.toString();
    final parsed = created == null ? null : DateTime.tryParse(created);

    final route = (m['navigation_target'] ?? m['target_route'])?.toString();
    final extra = m['navigation_extra'] ?? m['target_extra'];

    return AppNotification(
      id: id,
      title: title,
      message: message,
      createdAt: (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal(),
      isRead: _bool(m['is_read'] ?? m['read']),
      targetRoute: (route == null || route.isEmpty) ? null : route,
      targetExtra: extra is Map ? Map<String, dynamic>.from(extra) : null,
    );
  }
}
