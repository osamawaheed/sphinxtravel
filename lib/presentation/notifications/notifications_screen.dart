import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../models/app_notification_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/driver_api_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

/// Notifications list shared by the Customer and Driver apps.
/// Data comes only from NotificationService.
class NotificationsScreen extends StatefulWidget {
  final bool isDriver;

  const NotificationsScreen({super.key, required this.isDriver});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService.instance;

  @override
  void initState() {
    super.initState();

    // Refresh only after the first frame has completed.
    // This prevents notifyListeners() during widget mounting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _service.refresh();
    });
  }

  void _showReadOnlyNotice() {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.notificationsReadOnlyMessage)),
      );
  }

  void _showMarkFailedNotice() {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.notificationsMarkReadFailed)));
  }

  Future<void> _markRead(String id) async {
    if (!_service.canMarkRead) {
      _showReadOnlyNotice();
      return;
    }

    if (_service.isMarking) return;

    await _service.markAsRead(id);

    if (!mounted) return;

    if (_service.markFailed) {
      _showMarkFailedNotice();
    }
  }

  Future<void> _markAllRead() async {
    if (!_service.canMarkRead) {
      _showReadOnlyNotice();
      return;
    }

    if (_service.isMarking) return;

    await _service.markAllAsRead();

    if (!mounted) return;

    if (_service.markFailed) {
      _showMarkFailedNotice();
    }
  }

  void _open(AppNotification n) {
    if (widget.isDriver &&
        (n.notificationType == 'TRIP_ASSIGNED' ||
            n.notificationType == 'TRIP_UNASSIGNED')) {
      _openDriverTripNotification(n);
      return;
    }

    if (_service.canMarkRead && !n.isRead && !_service.isMarking) {
      _markRead(n.id);
    }

    final route = NotificationService.validRouteFor(
      n,
      isDriver: widget.isDriver,
    );

    if (route == null) return;

    context.push(route, extra: n.targetExtra);
  }

  Future<void> _openDriverTripNotification(AppNotification n) async {
    if (_service.canMarkRead && !n.isRead && !_service.isMarking) {
      await _markRead(n.id);
    }

    // An unassigned trip must never be opened.
    if (n.notificationType != 'TRIP_ASSIGNED') return;

    final tripId = int.tryParse(n.tripId ?? '');

    if (tripId == null || tripId <= 0) return;

    try {
      // Backend verifies that the trip belongs to this driver.
      await DriverApiService(ApiClient()).loadTripDetail(tripId);
    } catch (_) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.notificationTripUnavailable)),
        );

      return;
    }

    if (!mounted) return;

    context.push(AppRoutes.driverTripOverview, extra: {'tripId': tripId});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppTheme.darkBackground : AppTheme.mainBackground;

    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;

    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final isAr = l10n.locale == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: Text(
            l10n.notificationsTitle,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            AnimatedBuilder(
              animation: _service,
              builder: (context, _) {
                if (_service.unreadCount == 0) {
                  return const SizedBox.shrink();
                }

                return TextButton(
                  onPressed: _service.isMarking ? null : _markAllRead,
                  child: Text(
                    l10n.markAllAsRead,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _service,
            builder: (context, _) {
              final items = _service.items;

              return Column(
                children: [
                  if (_service.isLocalDemo)
                    _banner(l10n.notificationsDemoLabel, isDark, subColor),
                  Expanded(
                    child: _service.isLoading && items.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.luxuryAccent,
                            ),
                          )
                        : items.isEmpty
                        ? _empty(l10n, textColor, subColor)
                        : RefreshIndicator(
                            color: AppTheme.luxuryAccent,
                            onRefresh: _service.refresh,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                return _NotificationTile(
                                  notification: items[i],
                                  l10n: l10n,
                                  isDark: isDark,
                                  isDriver: widget.isDriver,
                                  onTap: () => _open(items[i]),
                                  onMarkRead: () => _markRead(items[i].id),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, bool isDark, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSoftGoldBg : AppTheme.softGoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.luxuryAccent.withAlpha(90)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(color: color, fontSize: 12, height: 1.3),
      ),
    );
  }

  Widget _empty(AppLocalizations l10n, Color textColor, Color subColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          color: AppTheme.luxuryAccent,
          onRefresh: _service.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _service.hasError
                          ? Icons.error_outline
                          : Icons.notifications_none_rounded,
                      size: 56,
                      color: AppTheme.luxuryAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _service.hasError
                          ? l10n.notificationsLoadError
                          : l10n.notificationsEmptyTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.notificationsEmptyMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: subColor,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final AppLocalizations l10n;
  final bool isDark;
  final bool isDriver;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  const _NotificationTile({
    required this.notification,
    required this.l10n,
    required this.isDark,
    required this.isDriver,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;

    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;

    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;

    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final String titleText;
    final String messageText;

    if (n.notificationType == null) {
      titleText = n.title;
      messageText = n.message;
    } else if (n.hasServerText) {
      titleText = n.serverTitle!.trim();
      messageText = n.serverBody!.trim();
    } else if (n.notificationType == 'BOOKING_UPDATED') {
      titleText = l10n.notificationBookingUpdatedTitle;
      messageText = l10n.notificationBookingUpdatedMessage(n.bookingReference);
    } else if (n.notificationType == 'TRIP_ASSIGNED') {
      titleText = l10n.notificationTripAssignedTitle;
      messageText = l10n.notificationTripAssignedMessage(n.bookingReference);
    } else if (n.notificationType == 'TRIP_UNASSIGNED') {
      titleText = l10n.notificationTripUnassignedTitle;
      messageText = l10n.notificationTripUnassignedMessage(n.bookingReference);
    } else {
      titleText = l10n.notificationGenericTitle;
      messageText = l10n.notificationGenericMessage(n.bookingReference);
    }

    return Material(
      color: cardBg,
      elevation: isDark ? 0 : 3,
      shadowColor: const Color(0x29091444),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: n.isRead ? border : AppTheme.luxuryAccent.withAlpha(150),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6, left: 2, right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: n.isRead ? Colors.transparent : AppTheme.luxuryAccent,
                  border: n.isRead ? Border.all(color: border) : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: n.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                      ),
                    ),
                    if (messageText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        messageText,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: subColor,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.notificationDateTime(n.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        n.isRead
                            ? Text(
                                l10n.readLabel,
                                style: GoogleFonts.inter(
                                  color: subColor,
                                  fontSize: 12,
                                ),
                              )
                            : GestureDetector(
                                onTap: onMarkRead,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    l10n.markAsRead,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.luxuryAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                      ],
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
