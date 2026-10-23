import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../theme/app_theme.dart';
import './day_itinerary_card.dart';
import './flight_card.dart';
import './sim_delivery_status_block.dart';
import './trip_hero_card.dart';

/// Customer "My Trip" body. Mirrors the Driver Trip Overview layout
/// (image hero card + day-by-day "Trip Details") with view-only content.
class CustomerTripDetailsWidget extends StatelessWidget {
  final CustomerHomeTrip trip;
  final AppLocalizations l10n;

  const CustomerTripDetailsWidget({
    super.key,
    required this.trip,
    required this.l10n,
  });

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  DateTime? _parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final dmyNum = RegExp(
      r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})',
    ).firstMatch(s);
    if (dmyNum != null) {
      return DateTime(
        int.parse(dmyNum.group(3)!),
        int.parse(dmyNum.group(2)!),
        int.parse(dmyNum.group(1)!),
      );
    }
    final dmy = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\.?,?\s+(\d{4})',
    ).firstMatch(s);
    if (dmy != null) {
      final m = _months[dmy.group(2)!.toLowerCase()];
      if (m != null) {
        return DateTime(int.parse(dmy.group(3)!), m, int.parse(dmy.group(1)!));
      }
    }
    final mdy = RegExp(
      r'([A-Za-z]{3})[A-Za-z]*\.?\s+(\d{1,2}),?\s+(\d{4})',
    ).firstMatch(s);
    if (mdy != null) {
      final m = _months[mdy.group(1)!.toLowerCase()];
      if (m != null) {
        return DateTime(int.parse(mdy.group(3)!), m, int.parse(mdy.group(2)!));
      }
    }
    return null;
  }

  int _timeMinutes(String t) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(t);
    if (m == null) return 1 << 20;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3)?.toLowerCase();
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    return h * 60 + min;
  }

  String _fmtDate(DateTime d) => l10n.shortDateWithYear(d);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        TripHeroCard(trip: trip, l10n: l10n, referenceAboveBadge: true),
        const SizedBox(height: 20),
        ..._buildItinerary(context),
        if (trip.extraServices.isNotEmpty) ...[
          _SectionHeader(title: l10n.services),
          const SizedBox(height: 12),
          for (final e in trip.extraServices) ...[
            _ServiceRow(service: e, l10n: l10n),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  List<Widget> _buildItinerary(BuildContext context) {
    final days = <DateTime, _DayBucket>{};
    final undated = _DayBucket();

    _DayBucket bucketFor(DateTime? d) {
      if (d == null) return undated;
      return days.putIfAbsent(d, () => _DayBucket());
    }

    final seenSeg = <int>{};
    for (final s in trip.transportation) {
      if (s.id != 0 && !seenSeg.add(s.id)) continue;
      final title = (s.title ?? s.notes ?? '').trim();
      bucketFor(_parseDate(s.date)).items.add(
        HomePlanItem(
          id: s.id,
          time: s.pickupTime,
          endTime: s.endTime ?? '',
          title: title.isNotEmpty ? title : l10n.transportationLabel,
          subtitle: s.city ?? '',
          imageUrl: s.imageUrl,
          type: 'transport',
          status: s.status,
        ),
      );
    }

    final seenAct = <String>{};
    for (final a in trip.activities) {
      final key = '${a.id}|${a.title}|${a.date}';
      if (!seenAct.add(key)) continue;
      bucketFor(_parseDate(a.date)).items.add(a);
    }

    final seenHotel = <String>{};
    final hotels = <HomeStayHotel>[];
    for (final h in trip.hotels) {
      final key = '${h.id}|${h.name}|${h.checkIn}|${h.checkOut}';
      if (seenHotel.add(key)) hotels.add(h);
    }
    final far = DateTime(9999);
    hotels.sort((a, b) {
      final c = (_parseDate(a.checkIn) ?? far).compareTo(
        _parseDate(b.checkIn) ?? far,
      );
      if (c != 0) return c;
      return (_parseDate(a.checkOut) ?? far).compareTo(
        _parseDate(b.checkOut) ?? far,
      );
    });
    for (final h in hotels) {
      bucketFor(_parseDate(h.checkIn)).hotels.add(h);
    }

    final flightWidgets = <Widget>[
      if (trip.arrivalFlight != null) ...[
        FlightCard(
          title: l10n.arrivalFlight,
          flight: trip.arrivalFlight!,
          isArrival: true,
        ),
        const SizedBox(height: 14),
      ],
      if (trip.departureFlight != null) ...[
        FlightCard(
          title: l10n.departureFlightTitle,
          flight: trip.departureFlight!,
          isArrival: false,
        ),
        const SizedBox(height: 20),
      ],
    ];

    if (days.isEmpty && undated.isEmpty && flightWidgets.isEmpty) {
      return const [];
    }

    final sortedDates = days.keys.toList()..sort();
    final start = _parseDate(trip.arrivalDate);

    final out = <Widget>[
      _SectionHeader(title: l10n.tripDetails),
      const SizedBox(height: 14),
      ...flightWidgets,
    ];

    for (var i = 0; i < sortedDates.length; i++) {
      final d = sortedDates[i];
      final dayNo = start != null ? d.difference(start).inDays + 1 : i + 1;
      final label = dayNo > 0 ? '${l10n.dayLabel} $dayNo' : _fmtDate(d);
      out.add(_dayCard(label, _fmtDate(d), days[d]!));
    }

    if (!undated.isEmpty) {
      out.add(_dayCard('', '', undated));
    }

    return out;
  }

  Widget _dayCard(String label, String dateLabel, _DayBucket b) {
    final items = [...b.items]
      ..sort((a, c) => _timeMinutes(a.time).compareTo(_timeMinutes(c.time)));
    return DayItineraryCard(
      dayLabel: label,
      dateLabel: label.isEmpty || label == dateLabel ? '' : dateLabel,
      hotels: b.hotels,
      items: items,
      l10n: l10n,
    );
  }
}

class _DayBucket {
  final List<HomeStayHotel> hotels = [];
  final List<HomePlanItem> items = [];

  bool get isEmpty => hotels.isEmpty && items.isEmpty;
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: AppTheme.primaryText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final HomeExtraService service;
  final AppLocalizations l10n;

  const _ServiceRow({required this.service, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.softGoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              service.isSimCard
                  ? Icons.sim_card_outlined
                  : Icons.star_outline_rounded,
              color: AppTheme.luxuryAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (service.date.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      service.date,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (service.isSimCard)
                  SimDeliveryStatusBlock(
                    service: service,
                    l10n: l10n,
                    textColor: AppTheme.primaryText,
                    subColor: AppTheme.secondaryText,
                  ),
              ],
            ),
          ),
          if (service.qty > 0)
            Text(
              'x${service.qty}',
              style: GoogleFonts.inter(
                color: AppTheme.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
