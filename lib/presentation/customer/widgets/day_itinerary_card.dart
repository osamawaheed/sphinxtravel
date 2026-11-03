import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auth_network_image.dart';
import '../../driver/hotel_details_screen.dart';
import '../../driver/models/trip_status_display.dart';
import './driver_navigate_button.dart';
import './hotel_contact_actions.dart';
import './pickup_point_info.dart';

/// One trip day rendered as an independent rounded card:
/// Day header -> hotel card -> tour description -> tour image -> driver.
/// No timeline lines, dots or connectors.
class DayItineraryCard extends StatelessWidget {
  final String dayLabel;
  final String dateLabel;
  final List<HomeStayHotel> hotels;
  final List<HomePlanItem> items;
  final AppLocalizations l10n;
  final bool driverMode;
  final Set<int> mySegmentIds;
  final void Function(HomePlanItem item)? onItemTap;

  const DayItineraryCard({
    super.key,
    required this.dayLabel,
    required this.dateLabel,
    required this.hotels,
    required this.items,
    required this.l10n,
    this.driverMode = false,
    this.mySegmentIds = const {},
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkActive;
    final cardBg = AppTheme.cardWhite;
    final border = AppTheme.borderColor;

    final children = <Widget>[];
    if (dayLabel.isNotEmpty || dateLabel.isNotEmpty) {
      children.add(_header());
    }
    for (final h in hotels) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 14));
      children.add(_HotelCard(hotel: h, l10n: l10n));
    }
    for (final it in items) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 14));
      children.add(
        _ItemBlock(
          item: it,
          l10n: l10n,
          driverMode: driverMode,
          isMine: it.type == 'transport' && mySegmentIds.contains(it.id),
          onTap: onItemTap,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        if (dayLabel.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.brandNavy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              dayLabel,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (dayLabel.isNotEmpty && dateLabel.isNotEmpty)
          const SizedBox(width: 10),
        if (dateLabel.isNotEmpty)
          Expanded(
            child: Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

/// Public entry point to the exact hotel card used in My Trips → Trip Details,
/// so other screens (e.g. Driver Home → Today's Plan) can reuse it as-is.
class TripHotelCard extends StatelessWidget {
  final HomeStayHotel hotel;
  final AppLocalizations l10n;

  const TripHotelCard({super.key, required this.hotel, required this.l10n});

  @override
  Widget build(BuildContext context) => _HotelCard(hotel: hotel, l10n: l10n);
}

class _HotelCard extends StatelessWidget {
  final HomeStayHotel hotel;
  final AppLocalizations l10n;

  const _HotelCard({required this.hotel, required this.l10n});

  @override
  Widget build(BuildContext context) {
    Widget dateLine(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              color: AppTheme.secondaryText,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: AppTheme.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.softGoldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.hotel_rounded,
                  color: AppTheme.luxuryAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => HotelDetailsScreen.show(
                        context,
                        name: hotel.name,
                        phone: hotel.phone,
                        googleMapUrl: hotel.googleMapUrl,
                      ),
                      child: Text(
                        hotel.name,
                        style: GoogleFonts.inter(
                          color: AppTheme.luxuryAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hotel.city.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          hotel.city,
                          style: GoogleFonts.inter(
                            color: AppTheme.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (hotel.checkIn.isNotEmpty)
                      dateLine(l10n.checkIn, hotel.checkIn),
                    if (hotel.checkOut.isNotEmpty)
                      dateLine(l10n.checkOut, hotel.checkOut),
                  ],
                ),
              ),
            ],
          ),
          HotelContactActions(
            phone: hotel.phone,
            mapUrl: hotel.googleMapUrl,
            l10n: l10n,
          ),
        ],
      ),
    );
  }
}

class _ItemBlock extends StatelessWidget {
  final HomePlanItem item;
  final AppLocalizations l10n;
  final bool driverMode;
  final bool isMine;
  final void Function(HomePlanItem item)? onTap;

  const _ItemBlock({
    required this.item,
    required this.l10n,
    required this.driverMode,
    required this.isMine,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = item.endTime.isNotEmpty
        ? '${item.time} – ${item.endTime}'
        : item.time;
    final secondary = AppTheme.secondaryText;

    final showDriverName =
        item.type == 'transport' &&
        item.driverAssigned &&
        item.driverName.isNotEmpty;
    final showNoDriver =
        driverMode && item.type == 'transport' && !isMine && !showDriverName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timeText.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              timeText,
              style: GoogleFonts.inter(
                color: AppTheme.luxuryAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (item.title.trim().isNotEmpty)
          Text(
            item.title,
            style: GoogleFonts.inter(
              color: AppTheme.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        if (item.subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            softWrap: true,
            style: GoogleFonts.inter(
              color: secondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
        if (item.type == 'transport')
          driverMode
              ? DriverPickupPointInfo(
                  address: item.pickupAddress,
                  navigateUrl: item.pickupLat == null || item.pickupLng == null
                      ? null
                      : 'https://www.google.com/maps/dir/?api=1&destination=${item.pickupLat},${item.pickupLng}',
                  buttonLabel: l10n.pickupNavigate,
                  addressColor: secondary,
                )
              : PickupPointInfo(
                  address: item.pickupAddress,
                  mapUrl: item.pickupMapUrl,
                  buttonLabel: l10n.pickupOpenInMaps,
                  addressColor: secondary,
                ),
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
                  child: Icon(Icons.image_outlined, color: secondary),
                ),
              ),
            ),
          ),
        ],
        if (item.type == 'transport') ...[
          if (driverMode && isMine) ...[
            if (item.status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                formatTripStatusDisplay(item.status),
                style: GoogleFonts.inter(
                  color: secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: kItineraryActionButtonHeight,
                child: ElevatedButton(
                  onPressed: () => onTap!(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, kItineraryActionButtonHeight),
                    fixedSize: const Size.fromHeight(
                      kItineraryActionButtonHeight,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
          ] else if (showDriverName || showNoDriver) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 16, color: secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    showDriverName
                        ? '${l10n.driverNoColon}: ${item.driverName}'
                        : l10n.noDriverAssigned,
                    style: GoogleFonts.inter(color: secondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
