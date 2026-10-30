import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/customer_bootstrap_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/chat/chat_inbox_service.dart';
import '../../services/driver_api_service.dart';
import '../../theme/app_theme.dart';
import './chat_inbox_strings.dart';

enum _InboxFilter { all, active, completed }

/// Driver "Messages" inbox: one conversation card per booking.
/// Rendered inside the Driver home tab area (no own Scaffold / nav bar).
class DriverChatsView extends StatefulWidget {
  /// Driver's assigned trips from Odoo (source of truth for assignments).
  final List<DriverTripListItem> trips;
  final bool tripsLoading;
  final String? tripsError;
  final VoidCallback? onReloadTrips;
  final String driverName;
  final int driverOdooId;
  final String? driverPhotoUrl;
  final bool isDark;

  const DriverChatsView({
    super.key,
    required this.trips,
    required this.tripsLoading,
    required this.tripsError,
    required this.driverName,
    required this.driverOdooId,
    required this.isDark,
    this.driverPhotoUrl,
    this.onReloadTrips,
  });

  @override
  State<DriverChatsView> createState() => _DriverChatsViewState();
}

class _DriverChatsViewState extends State<DriverChatsView> {
  final ChatInboxService _service = ChatInboxService();
  final TextEditingController _search = TextEditingController();

  List<ChatInboxItem> _items = const [];
  bool _loading = true;
  String? _backendError;
  _InboxFilter _filter = _InboxFilter.all;
  String _query = '';
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _refresh();
    _channel = _service.subscribe(_onRealtime);
  }

  @override
  void didUpdateWidget(covariant DriverChatsView old) {
    super.didUpdateWidget(old);
    if (!identical(old.trips, widget.trips)) _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _channel?.unsubscribe();
    _search.dispose();
    super.dispose();
  }

  void _onRealtime() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _refresh);
  }

  Future<void> _refresh() async {
    final result = await _service.load(
      trips: widget.trips,
      viewerOdooId: widget.driverOdooId > 0 ? widget.driverOdooId : null,
    );
    if (!mounted) return;
    setState(() {
      _items = result.items;
      _backendError = result.backendError;
      _loading = false;
    });
  }

  List<ChatInboxItem> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((i) {
      if (_filter == _InboxFilter.active && i.isCompleted) return false;
      if (_filter == _InboxFilter.completed && !i.isCompleted) return false;
      if (q.isEmpty) return true;
      return i.bookingReference.toLowerCase().contains(q) ||
          i.customerName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _open(ChatInboxItem item) async {
    final cid = item.conversationId;
    if (cid != null) await _service.markSeen(cid);
    var phone = item.customerPhone.trim();
    if (phone.isEmpty && item.tripId > 0) {
      // Same source as the working customer details screen:
      // GET /driver/trips/{id} -> customer.phone.
      try {
        final detail = await DriverApiService(
          ApiClient(),
        ).loadTripDetail(item.tripId);
        phone = (detail.customer?.phone ?? '').trim();
      } catch (_) {}
    }
    if (!mounted) return;
    await context.push(
      AppRoutes.smartChat,
      extra: {
        'role': 'driver',
        'bookingReference': item.bookingReference,
        'tripTitle': item.tripTitle,
        'counterpartName': item.customerName,
        'counterpartPhone': phone.isEmpty ? null : phone,
        'counterpartPhoto': item.customerPhotoUrl.isNotEmpty
            ? item.customerPhotoUrl
            : null,
        'counterpartOdooId': item.customerId > 0 ? item.customerId : null,
        'currentUserName': widget.driverName,
        'currentUserPhoto': (widget.driverPhotoUrl ?? '').isNotEmpty
            ? widget.driverPhotoUrl
            : null,
        'currentUserOdooId': widget.driverOdooId > 0
            ? widget.driverOdooId
            : null,
        'odooBookingId': item.tripId > 0 ? item.tripId : null,
        'readOnly': item.isCompleted,
      },
    );
    if (mounted) _refresh();
  }

  String _formatTime(DateTime? d, ChatInboxStrings s) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
    }
    if (diff == 1) return s.yesterday;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ChatInboxStrings(l10n.locale);
    final isDark = widget.isDark;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final list = _visible;
    final busy = _loading || (widget.tripsLoading && widget.trips.isEmpty);

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: () async {
        widget.onReloadTrips?.call();
        await _refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          _buildSearch(s, isDark, textColor, subColor),
          const SizedBox(height: 14),
          _buildFilters(s, isDark),
          const SizedBox(height: 16),
          if (_backendError != null) _buildBlocked(s, isDark),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.brandNavy,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (widget.tripsError != null && widget.trips.isEmpty)
            _buildMessage(
              s.emptyTitle,
              widget.tripsError!,
              textColor,
              subColor,
              retry: widget.onReloadTrips,
              retryLabel: s.retry,
            )
          else if (list.isEmpty)
            _buildMessage(s.emptyTitle, s.emptyBody, textColor, subColor)
          else
            ...list.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ConversationCard(
                  item: i,
                  isDark: isDark,
                  strings: s,
                  timeLabel: _formatTime(i.lastMessageAt, s),
                  onTap: () => _open(i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch(
    ChatInboxStrings s,
    bool isDark,
    Color textColor,
    Color subColor,
  ) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        style: GoogleFonts.inter(color: textColor, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: s.searchHint,
          hintStyle: GoogleFonts.inter(color: subColor, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: subColor, size: 22),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, color: subColor, size: 18),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilters(ChatInboxStrings s, bool isDark) {
    final labels = {
      _InboxFilter.all: s.filterAll,
      _InboxFilter.active: s.filterActive,
      _InboxFilter.completed: s.filterCompleted,
    };
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _InboxFilter.values.map((f) {
          final selected = _filter == f;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark ? AppTheme.luxuryAccent : AppTheme.brandNavy)
                      : (isDark ? AppTheme.darkCard : AppTheme.cardWhite),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : (isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.borderColor),
                  ),
                ),
                child: Text(
                  labels[f]!,
                  style: GoogleFonts.inter(
                    color: selected
                        ? (isDark ? AppTheme.brandNavy : Colors.white)
                        : (isDark
                              ? AppTheme.darkPrimaryText
                              : AppTheme.primaryText),
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlocked(ChatInboxStrings s, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSoftGoldBg : AppTheme.softGoldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppTheme.luxuryAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${s.accessBlocked}: $_backendError',
              style: GoogleFonts.inter(
                color: isDark ? AppTheme.darkPrimaryText : AppTheme.navyText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    String title,
    String body,
    Color textColor,
    Color subColor, {
    VoidCallback? retry,
    String? retryLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 44,
            color: AppTheme.luxuryAccent.withAlpha(180),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: subColor, fontSize: 13.5),
          ),
          if (retry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: retry, child: Text(retryLabel ?? '')),
          ],
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ChatInboxItem item;
  final bool isDark;
  final ChatInboxStrings strings;
  final String timeLabel;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.item,
    required this.isDark,
    required this.strings,
    required this.timeLabel,
    required this.onTap,
  });

  String get _initials {
    final parts = item.customerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final unread = item.unreadCount > 0;

    final preview = item.lastMessageIsVoice
        ? strings.voiceMessage
        : (item.lastMessagePreview.isNotEmpty
              ? item.lastMessagePreview
              : strings.noMessagesYet);

    final statusColor = item.isCompleted ? subColor : AppTheme.successGreen;
    final statusLabel = item.isCompleted
        ? strings.statusCompleted
        : strings.statusActive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unread
                ? (isDark ? AppTheme.darkSoftGoldBg : const Color(0xFFFFFBF2))
                : cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unread ? AppTheme.luxuryAccent.withAlpha(150) : border,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.brandNavy,
                  border: Border.all(
                    color: AppTheme.luxuryAccent.withAlpha(160),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _initials,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.customerName.isEmpty
                                ? item.bookingReference
                                : item.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: GoogleFonts.inter(
                            color: unread ? AppTheme.luxuryAccent : subColor,
                            fontSize: 12,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSoftGoldBg
                            : AppTheme.softGoldBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.bookingReference,
                        style: GoogleFonts.inter(
                          color: isDark
                              ? AppTheme.luxuryAccent
                              : const Color(0xFF7A5A1E),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (item.lastMessageIsVoice) ...[
                          Icon(Icons.mic_rounded, size: 15, color: subColor),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: unread ? textColor : subColor,
                              fontSize: 13.5,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.luxuryAccent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              item.unreadCount > 99
                                  ? '99+'
                                  : '${item.unreadCount}',
                              style: GoogleFonts.inter(
                                color: AppTheme.brandNavy,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
