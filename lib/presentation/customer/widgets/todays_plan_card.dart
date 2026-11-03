import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auth_network_image.dart';
import '../../driver/models/trip_status_display.dart';

/// Premium, expandable "Today's Plan" for the Customer Home.
///
/// Shows today's hotel first, then every transportation / tour activity of
/// the current day in chronological order. All data comes from Odoo
/// (`current_hotel`, `hotels`, `today_plan`). Expands in place.
class TodaysPlanCard extends StatefulWidget {
  final CustomerHomeTrip trip;
  final AppLocalizations l10n;
  final String dateText;
  final VoidCallback? onHotelTap;

  const TodaysPlanCard({
    super.key,
    required this.trip,
    required this.l10n,
    required this.dateText,
    this.onHotelTap,
  });

  @override
  State<TodaysPlanCard> createState() => _TodaysPlanCardState();
}

class _PlanHotel {
  final String name;
  final String city;
  final String checkIn;
  final String checkOut;
  final String imageUrl;

  const _PlanHotel({
    required this.name,
    required this.city,
    required this.checkIn,
    required this.checkOut,
    required this.imageUrl,
  });
}

class _TodaysPlanCardState extends State<TodaysPlanCard> {
  bool _expanded = false;

  /// Sort key from an Odoo time string such as "09:00" or "9:00 AM".
  static int _minutes(String raw) {
    final s = raw.trim().toUpperCase();
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?').firstMatch(s);
    if (m == null) return 24 * 60 + 1;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3);
    if (ap == 'PM' && h < 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    return h * 60 + min;
  }

  List<HomePlanItem> get _items {
    final list = List<HomePlanItem>.of(widget.trip.todayPlan);
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final c = _minutes(a.value.time).compareTo(_minutes(b.value.time));
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  _PlanHotel? get _hotel {
    final trip = widget.trip;
    final cur = trip.currentHotel;
    if (cur == null || cur.name.trim().isEmpty) return null;
    var checkIn = cur.checkIn;
    var checkOut = cur.checkOut;
    for (final h in trip.hotels) {
      if (h.name.trim().toLowerCase() == cur.name.trim().toLowerCase()) {
        if (checkIn.isEmpty) checkIn = h.checkIn;
        if (checkOut.isEmpty) checkOut = h.checkOut;
        break;
      }
    }
    return _PlanHotel(
      name: cur.name,
      city: cur.city,
      checkIn: checkIn,
      checkOut: checkOut,
      imageUrl: cur.imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final items = _items;
    final hotel = _hotel;
    final hasContent = items.isNotEmpty || hotel != null;
    final canExpand = items.length > 1 || (hotel != null && items.isNotEmpty);
    final visibleItems = _expanded
        ? items
        : (items.isEmpty ? <HomePlanItem>[] : [items.first]);
    final hiddenCount = items.length - visibleItems.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(l10n),
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.luxuryAccent,
                  AppTheme.luxuryAccent.withAlpha(0),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: hasContent
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hotel != null) _hotelTile(hotel, l10n),
                        ...visibleItems.map((i) => _activityTile(i, l10n)),
                        if (!_expanded && hiddenCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '+$hiddenCount ${l10n.planMoreActivities}',
                              style: GoogleFonts.inter(
                                color: AppTheme.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        l10n.planNoActivities,
                        style: GoogleFonts.inter(
                          color: AppTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
          ),
          if (canExpand) _toggleButton(l10n) else const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _header(AppLocalizations l10n) {
    final day = widget.trip.dayOfTour;
    final total = widget.trip.totalDays;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.todaysPlan,
                  style: GoogleFonts.inter(
                    color: AppTheme.navyText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.dateText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.softGoldBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.luxuryAccent.withAlpha(110)),
            ),
            child: Text(
              total > 1
                  ? '${l10n.dayLabel} $day ${l10n.ofLabel} $total'
                  : '${l10n.dayLabel} $day',
              style: GoogleFonts.inter(
                color: AppTheme.navyText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hotelTile(_PlanHotel h, AppLocalizations l10n) {
    final dates = <String>[
      if (h.checkIn.isNotEmpty) '${l10n.checkIn}: ${h.checkIn}',
      if (h.checkOut.isNotEmpty) '${l10n.checkOut}: ${h.checkOut}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onHotelTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.brandNavy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hotel_rounded,
                    color: AppTheme.luxuryAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.hotel.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: AppTheme.luxuryAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        h.name,
                        style: GoogleFonts.inter(
                          color: AppTheme.navyText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (h.city.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppTheme.secondaryText,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                h.city,
                                style: GoogleFonts.inter(
                                  color: AppTheme.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      ...dates.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            d,
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityTile(HomePlanItem item, AppLocalizations l10n) {
    final timeText = item.endTime.isNotEmpty
        ? '${item.time} – ${item.endTime}'
        : item.time;
    final isTransport = item.type == 'transport';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl.isNotEmpty)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: AuthNetworkImage(
                  photoUrl: item.imageUrl,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: AppTheme.softGoldBg,
                    child: Icon(
                      Icons.image_outlined,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isTransport
                            ? Icons.directions_car_filled_outlined
                            : Icons.explore_outlined,
                        size: 16,
                        color: AppTheme.luxuryAccent,
                      ),
                      const SizedBox(width: 6),
                      if (timeText.trim().isNotEmpty)
                        Expanded(
                          child: Text(
                            timeText,
                            style: GoogleFonts.inter(
                              color: AppTheme.luxuryAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (item.status.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.brandNavy.withAlpha(16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              formatTripStatusDisplay(item.status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppTheme.navyText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      color: AppTheme.navyText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.secondaryText,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.subtitle,
                            style: GoogleFonts.inter(
                              color: AppTheme.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.navyText,
            side: const BorderSide(color: AppTheme.luxuryAccent, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _expanded ? l10n.planViewLess : l10n.planViewMore,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.luxuryAccent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
