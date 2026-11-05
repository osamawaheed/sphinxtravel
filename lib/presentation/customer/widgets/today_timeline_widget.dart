import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../models/hotel_grouping.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auth_network_image.dart';
import '../../driver/models/trip_status_display.dart';
import './day_itinerary_card.dart';
import 'day_itinerary_card.dart' show TripHotelCard;

class TodayTimelineWidget extends StatelessWidget {
  final List<HomePlanItem> items;
  final String dateText;
  final AppLocalizations l10n;
  final void Function(HomeDriver driver)? onRateDriver;
  final void Function(HomePlanItem item)? onItemTap;
  final bool Function(HomePlanItem item)? isItemTappable;
  final bool driverMode;
  final List<int> mySegmentIds;
  final List<HomeStayHotel> hotels;

  const TodayTimelineWidget({
    super.key,
    required this.items,
    required this.dateText,
    required this.l10n,
    this.onRateDriver,
    this.onItemTap,
    this.isItemTappable,
    this.driverMode = false,
    this.mySegmentIds = const [],
    this.hotels = const [],
  });

  @override
  Widget build(BuildContext context) {
    // One row per hotel stay: duplicate hotel records (extra rooms / images)
    // collapse into the first occurrence; other items are untouched.
    final items = HotelGrouping.dedupeHotelPlanItems(this.items);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                l10n.todaysPlan,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (dateText.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateText,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...items.asMap().entries.map(
          (e) => _TimelineRow(
            item: e.value,
            isLast: e.key == items.length - 1,
            l10n: l10n,
            onRateDriver: onRateDriver,
            driverMode: driverMode,
            isMine: mySegmentIds.contains(e.value.id),
            hotels: hotels,
            onTap:
                (onItemTap != null && (isItemTappable?.call(e.value) ?? true))
                ? () => onItemTap!(e.value)
                : null,
          ),
        ),
      ],
    );
  }
}

/// Public wrapper exposing the exact Today's Plan row design so other
/// screens (e.g. the driver full itinerary) render identical cards.
class TimelineItemCard extends StatelessWidget {
  final HomePlanItem item;
  final bool isLast;
  final AppLocalizations l10n;
  final VoidCallback? onTap;
  final bool driverMode;
  final bool isMine;

  const TimelineItemCard({
    super.key,
    required this.item,
    required this.l10n,
    this.isLast = false,
    this.onTap,
    this.driverMode = false,
    this.isMine = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TimelineRow(
      item: item,
      isLast: isLast,
      l10n: l10n,
      onTap: onTap,
      driverMode: driverMode,
      isMine: isMine,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final HomePlanItem item;
  final bool isLast;
  final AppLocalizations l10n;
  final void Function(HomeDriver driver)? onRateDriver;
  final VoidCallback? onTap;
  final bool driverMode;
  final bool isMine;
  final List<HomeStayHotel> hotels;

  const _TimelineRow({
    required this.item,
    required this.isLast,
    required this.l10n,
    this.onRateDriver,
    this.onTap,
    this.driverMode = false,
    this.isMine = false,
    this.hotels = const [],
  });

  HomeStayHotel _resolveHotel() {
    for (final h in hotels) {
      if (h.id != 0 && h.id == item.id) return h;
    }
    final title = HotelGrouping.normName(item.title);
    for (final h in hotels) {
      final n = HotelGrouping.normName(h.name);
      if (n.isNotEmpty && (title == n || title.contains(n))) return h;
    }
    return HomeStayHotel(id: item.id, name: item.title, city: item.subtitle);
  }

  @override
  Widget build(BuildContext context) {
    final timeText = item.endTime.isNotEmpty
        ? '${item.time} – ${item.endTime}'
        : item.time;
    final isHotelCard = driverMode && item.type == 'hotel';

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        children: [
          if (!isLast)
            PositionedDirectional(
              start: 9,
              top: 18,
              bottom: 0,
              child: Container(width: 1.5, color: AppTheme.borderColor),
            ),
          PositionedDirectional(
            start: 0,
            top: 4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cardWhite,
                border: Border.all(color: AppTheme.luxuryAccent, width: 2.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 34, bottom: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (timeText.trim().isNotEmpty)
                  Text(
                    timeText,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 3),
                if (isHotelCard) ...[
                  const SizedBox(height: 4),
                  TripHotelCard(hotel: _resolveHotel(), l10n: l10n),
                ] else ...[
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      softWrap: true,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (item.imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 150,
                        child: AuthNetworkImage(
                          photoUrl: item.imageUrl,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                          fallback: Container(
                            height: 150,
                            width: double.infinity,
                            color: AppTheme.softGoldBg,
                            child: Icon(
                              Icons.image_outlined,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                if (driverMode) ...[
                  if (item.type == 'transport' && isMine) ...[
                    if (item.status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        formatTripStatusDisplay(item.status),
                        style: GoogleFonts.inter(
                          color: AppTheme.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n.viewUpdateStatus,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else if (item.type == 'transport') ...[
                    const SizedBox(height: 8),
                    Text(
                      item.driverAssigned && item.driverName.isNotEmpty
                          ? '${l10n.driverNoColon}: ${item.driverName}'
                          : l10n.noDriverAssigned,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null || (driverMode && item.type == 'transport')) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
