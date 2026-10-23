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

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.targetRoute,
    this.targetExtra,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    message: message,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    targetRoute: targetRoute,
    targetExtra: targetExtra,
  );

  static bool _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return false;
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
