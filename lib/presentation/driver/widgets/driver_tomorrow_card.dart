import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../models/transportation_segment_model.dart';
import '../../../theme/app_theme.dart';
import '../models/trip_status_display.dart';

/// One assignment shown in the Driver Home Tomorrow card.
class DriverTomorrowEntry {
  final HomePlanItem? planItem;
  final TransportationSegmentModel? segment;
  final bool isNewTrip;
  final String sortKey;

  const DriverTomorrowEntry({
    this.planItem,
    this.segment,
    required this.isNewTrip,
    required this.sortKey,
  });

  bool get isAirportPickup {
    final s = segment;
    if (s == null) return false;
    final hasFlight =
        (s.flightNumber ?? '').isNotEmpty ||
        (s.flightAirline ?? '').isNotEmpty ||
        (s.flightArrivalTime ?? '').isNotEmpty;
    final type = s.segmentType.toLowerCase();
    return hasFlight ||
        type.contains('airport') ||
        type.contains('arrival') ||
        type.contains('pickup');
  }
}

class DriverTomorrowBuilder {
  static String _two(int n) => n.toString().padLeft(2, '0');

  static String isoDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static bool _excluded(String status) {
    final s = status.toLowerCase().trim();
    return s == 'cancelled' ||
        s == 'canceled' ||
        s == 'cancel' ||
        s == 'unassigned' ||
        s == 'draft';
  }

  /// Merges tomorrow's items of the active trip (`active_trip.tomorrow`) with
  /// tomorrow's segments from ALL assigned trips (`assigned_segments`) and
  /// from the details of the driver's other trips (`GET /driver/trips/{id}`).
  static List<DriverTomorrowEntry> build({
    required List<HomePlanItem> activeTripTomorrow,
    required List<TransportationSegmentModel> assignedSegments,
    required String? activeTripReference,
    required DateTime tomorrow,
    List<CustomerHomeTrip> otherTrips = const [],
  }) {
    final tomorrowStr = isoDate(tomorrow);
    final entries = <DriverTomorrowEntry>[];
    final coveredIds = <int>{};

    for (final item in activeTripTomorrow) {
      if (_excluded(item.status)) continue;
      if (item.id > 0) coveredIds.add(item.id);
      entries.add(
        DriverTomorrowEntry(
          planItem: item,
          isNewTrip: false,
          sortKey: item.time.isEmpty ? '99:99' : item.time,
        ),
      );
    }

    for (final seg in assignedSegments) {
      if (seg.date.length < 10 || seg.date.substring(0, 10) != tomorrowStr) {
        continue;
      }
      if (_excluded(seg.status)) continue;
      if (seg.id > 0 && coveredIds.contains(seg.id)) continue;
      final ref = seg.tripReference;
      final isNew =
          ref != null &&
          ref.isNotEmpty &&
          (activeTripReference == null || ref != activeTripReference);
      if (!isNew && activeTripTomorrow.isNotEmpty) {
        // Same trip as the active one: already represented by the active
        // trip's own tomorrow items.
        continue;
      }
      if (seg.id > 0) coveredIds.add(seg.id);
      entries.add(
        DriverTomorrowEntry(
          segment: seg,
          isNewTrip: isNew,
          sortKey: seg.pickupTime.isEmpty ? '99:99' : seg.pickupTime,
        ),
      );
    }

    // Other assigned trips (loaded from the same API that powers My Trips).
    for (final trip in otherTrips) {
      if (activeTripReference != null &&
          trip.reference.isNotEmpty &&
          trip.reference == activeTripReference) {
        continue;
      }
      final flight = trip.arrivalFlight;
      final flightIsTomorrow = _datePart(flight?.date ?? '') == tomorrowStr;
      final arrivalIsTomorrow = _datePart(trip.arrivalDate) == tomorrowStr;

      var addedForTrip = false;
      for (final seg in trip.transportation) {
        if (_datePart(seg.date) != tomorrowStr) continue;
        if (_excluded(seg.status)) continue;
        if (!seg.driverAssigned) continue;
        if (seg.id > 0 && coveredIds.contains(seg.id)) continue;
        if (seg.id > 0) coveredIds.add(seg.id);
        final isAirport = flightIsTomorrow || arrivalIsTomorrow;
        entries.add(
          DriverTomorrowEntry(
            segment: _withTripData(seg, trip, isAirport ? flight : null),
            isNewTrip: true,
            sortKey: seg.pickupTime.isEmpty ? '99:99' : seg.pickupTime,
          ),
        );
        addedForTrip = true;
      }
      // Trip arriving tomorrow whose airport pickup is not listed as a
      // dated segment: still surface the arrival from the Odoo flight data.
      if (!addedForTrip && flight != null && flightIsTomorrow) {
        final hasPickup = trip.transportation.any(
          (s) => !_excluded(s.status) && s.driverAssigned,
        );
        if (hasPickup) {
          entries.add(
            DriverTomorrowEntry(
              segment: _withTripData(
                TransportationSegmentModel(
                  id: 0,
                  segmentType: 'airport_pickup',
                  pickupLocation: flight.airport,
                  dropoffLocation: '',
                  pickupTime: flight.time,
                  date: tomorrowStr,
                  status: 'scheduled',
                  driverAssigned: true,
                ),
                trip,
                flight,
              ),
              isNewTrip: true,
              sortKey: flight.time.isEmpty ? '99:99' : flight.time,
            ),
          );
        }
      }
    }

    entries.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return entries;
  }

  static String _datePart(String raw) =>
      raw.length >= 10 ? raw.substring(0, 10) : raw;

  static TransportationSegmentModel _withTripData(
    TransportationSegmentModel s,
    CustomerHomeTrip trip,
    HomeFlight? flight,
  ) {
    return TransportationSegmentModel(
      id: s.id,
      segmentType: flight != null && s.segmentType == 'transfer'
          ? 'airport_pickup'
          : s.segmentType,
      pickupLocation: s.pickupLocation,
      dropoffLocation: s.dropoffLocation,
      pickupTime: s.pickupTime,
      date: s.date,
      description: s.description,
      status: s.status,
      driverAssignment: s.driverAssignment,
      homeDriver: s.homeDriver,
      notes: s.notes,
      endTime: s.endTime,
      city: s.city,
      title: s.title,
      tripReference: trip.reference.isNotEmpty ? trip.reference : null,
      flightNumber: flight != null && flight.flightNo.isNotEmpty
          ? flight.flightNo
          : null,
      flightAirline: flight != null && flight.airline.isNotEmpty
          ? flight.airline
          : null,
      flightArrivalTime: flight != null && flight.time.isNotEmpty
          ? flight.time
          : null,
      flightAirport: flight != null && flight.airport.isNotEmpty
          ? flight.airport
          : null,
      flightDate: flight != null && flight.date.isNotEmpty ? flight.date : null,
      imageUrl: s.imageUrl,
      driverAssigned: s.driverAssigned,
      driverName: s.driverName,
      tripId: trip.id > 0 ? trip.id : null,
      pickupAddress: s.pickupAddress,
      pickupLat: s.pickupLat,
      pickupLng: s.pickupLng,
      pickupMapUrl: s.pickupMapUrl,
    );
  }
}

class DriverTomorrowCard extends StatelessWidget {
  final List<DriverTomorrowEntry> entries;
  final DateTime tomorrow;
  final AppLocalizations l10n;
  final List<int> mySegmentIds;
  final void Function(int segmentId)? onItemTap;

  const DriverTomorrowCard({
    super.key,
    required this.entries,
    required this.tomorrow,
    required this.l10n,
    this.mySegmentIds = const [],
    this.onItemTap,
  });

  static const _months = {
    'en': [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
    'ar': [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ],
    'ru': [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ],
    'ka': [
      'იანვარი',
      'თებერვალი',
      'მარტი',
      'აპრილი',
      'მაისი',
      'ივნისი',
      'ივლისი',
      'აგვისტო',
      'სექტემბერი',
      'ოქტომბერი',
      'ნოემბერი',
      'დეკემბერი',
    ],
  };

  String _formatDate(DateTime d) {
    final names = _months[l10n.locale] ?? _months['en']!;
    final month = names[d.month - 1];
    return l10n.locale == 'en'
        ? '$month ${d.day}, ${d.year}'
        : '${d.day} $month ${d.year}';
  }

  String _formatIsoDate(String raw, DateTime fallback) {
    if (raw.length >= 10) {
      final p = DateTime.tryParse(raw.substring(0, 10));
      if (p != null) return _formatDate(p);
    }
    return _formatDate(fallback);
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.softGoldBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.luxuryAccent.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.tomorrow} — ${_formatDate(tomorrow)}',
            style: GoogleFonts.inter(
              color: AppTheme.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Divider(
                  height: 1,
                  color: AppTheme.luxuryAccent.withAlpha(60),
                ),
              ),
            _buildEntry(entries[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildEntry(DriverTomorrowEntry e) {
    if (e.segment != null && (e.isNewTrip || e.isAirportPickup)) {
      return _NewTripEntry(
        entry: e,
        l10n: l10n,
        arrivalDateText: _formatIsoDate(
          e.segment!.flightDate ?? e.segment!.date,
          tomorrow,
        ),
      );
    }
    if (e.segment != null) {
      final s = e.segment!;
      return _TourEntry(
        title: (s.title ?? '').isNotEmpty
            ? s.title!
            : '${s.pickupLocation} → ${s.dropoffLocation}',
        subtitle: s.description ?? '',
        time: s.pickupTime,
        status: s.status,
        showStatus: mySegmentIds.contains(s.id),
        onTap: onItemTap == null || !mySegmentIds.contains(s.id)
            ? null
            : () => onItemTap!(s.id),
        l10n: l10n,
      );
    }
    final item = e.planItem!;
    final mine = mySegmentIds.contains(item.id);
    return _TourEntry(
      title: item.title,
      subtitle: item.subtitle,
      time: item.time,
      status: item.status,
      showStatus: mine && item.type == 'transport',
      onTap: onItemTap == null || !mine || item.type != 'transport'
          ? null
          : () => onItemTap!(item.id),
      l10n: l10n,
    );
  }
}

class _NewTripEntry extends StatelessWidget {
  final DriverTomorrowEntry entry;
  final AppLocalizations l10n;
  final String arrivalDateText;

  const _NewTripEntry({
    required this.entry,
    required this.l10n,
    required this.arrivalDateText,
  });

  @override
  Widget build(BuildContext context) {
    final s = entry.segment!;
    final airportPickup = entry.isAirportPickup;
    final label = airportPickup
        ? '${l10n.newTripLabel} · ${l10n.airportPickupLabel}'
        : l10n.newTripLabel;
    final arrivalTime = (s.flightArrivalTime ?? '').isNotEmpty
        ? s.flightArrivalTime!
        : s.pickupTime;

    final rows = <MapEntry<String, String>>[
      if ((s.tripReference ?? '').isNotEmpty)
        MapEntry(l10n.bookingLabel, s.tripReference!),
      if (airportPickup) MapEntry(l10n.arrival, arrivalDateText),
      if (arrivalTime.isNotEmpty) MapEntry(l10n.arrivalTimeLabel, arrivalTime),
      if ((s.flightAirline ?? '').isNotEmpty)
        MapEntry(l10n.airline, s.flightAirline!),
      if ((s.flightNumber ?? '').isNotEmpty)
        MapEntry(l10n.flightLabel, s.flightNumber!),
      if ((s.flightAirport ?? '').isNotEmpty)
        MapEntry(l10n.airport, s.flightAirport!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.luxuryAccent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          airportPickup
              ? l10n.tomorrowAirportPickupMessage
              : l10n.tomorrowNewTripMessage,
          style: GoogleFonts.inter(
            color: AppTheme.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!airportPickup &&
            (s.pickupLocation.isNotEmpty || s.dropoffLocation.isNotEmpty)) ...[
          const SizedBox(height: 6),
          Text(
            '${s.pickupLocation} → ${s.dropoffLocation}',
            style: GoogleFonts.inter(
              color: AppTheme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
        if (rows.isNotEmpty) const SizedBox(height: 10),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${r.key}: ',
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: r.value,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TourEntry extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final String status;
  final bool showStatus;
  final VoidCallback? onTap;
  final AppLocalizations l10n;

  const _TourEntry({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
    required this.showStatus,
    required this.l10n,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsetsDirectional.only(end: 10, top: 7),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.luxuryAccent,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              if (showStatus && status.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  formatTripStatusDisplay(status),
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 8),
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
            ],
          ),
        ),
        if (time.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.inter(
              color: AppTheme.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
