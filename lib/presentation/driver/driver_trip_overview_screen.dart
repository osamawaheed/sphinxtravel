import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../models/customer_bootstrap_model.dart';
import '../../models/hotel_grouping.dart';
import '../../models/transportation_segment_model.dart';
import '../../routes/app_routes.dart';
import 'models/trip_status_display.dart';
import '../../services/api_client.dart';
import '../../services/driver_api_service.dart';
import '../../services/driver_auth_service.dart';
import '../../services/chat/chat_inbox_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../customer/widgets/day_itinerary_card.dart';
import '../customer/widgets/flight_card.dart';
import '../customer/widgets/hotel_contact_actions.dart'
    show kItineraryActionButtonHeight;
import '../customer/widgets/sim_delivery_status_block.dart';
import '../customer/widgets/trip_hero_card.dart';
import './widgets/driver_customer_card.dart';
import './hotel_details_screen.dart';
import '../customer/widgets/driver_navigate_button.dart';

class DriverTripOverviewScreen extends StatefulWidget {
  final int tripId;

  const DriverTripOverviewScreen({super.key, required this.tripId});

  @override
  State<DriverTripOverviewScreen> createState() =>
      _DriverTripOverviewScreenState();
}

class _DriverTripOverviewScreenState extends State<DriverTripOverviewScreen> {
  CustomerHomeTrip? _trip;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    LocalizationService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final trip = await DriverApiService(
        ApiClient(),
      ).loadTripDetail(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ApiException.messageOf(e) ?? e.toString();
        });
      }
    }
  }

  void _openSegment(int id) {
    context.push(AppRoutes.driverTripDetails, extra: {'segmentId': id});
  }

  /// Opens the shared Smart Chat. The driver's own name / id / photo come from
  /// the same driver bootstrap the Driver home header uses; if it cannot be
  /// loaded the chat still opens (initial fallback only for that avatar).
  Future<void> _openChat(CustomerHomeTrip trip, HomeCustomer cust) async {
    String? myName;
    int? myId;
    String? myPhoto;
    try {
      final b = await DriverAuthService(ApiClient()).loadBootstrap();
      myName = b.driverName.trim().isEmpty ? null : b.driverName.trim();
      myId = b.driver.id > 0 ? b.driver.id : null;
      myPhoto = b.driverPhotoUrl;
    } catch (_) {}
    if (!mounted) return;
    final closed = ChatInboxService.isChatClosed(
      odooStatus: trip.tripStatus,
      departureDate: trip.departureDate,
    );
    context.push(
      AppRoutes.smartChat,
      extra: {
        'role': 'driver',
        'bookingReference': trip.reference,
        'tripTitle': trip.destination,
        'currentUserName': myName,
        'currentUserPhoto': myPhoto,
        'currentUserOdooId': myId,
        'counterpartName': cust.name,
        'counterpartPhoto': cust.photoUrl.isNotEmpty ? cust.photoUrl : null,
        'counterpartOdooId': cust.id > 0 ? cust.id : null,
        'counterpartPhone': cust.phone,
        'odooBookingId': trip.id > 0 ? trip.id : null,
        'readOnly': closed,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.mainBackground;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          l10n.tripDetails,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.brandNavy,
                  strokeWidth: 2,
                ),
              )
            : (_errorMessage != null || _trip == null)
            ? _buildError(l10n, isDark)
            : _buildContent(_trip!, l10n, isDark),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n, bool isDark) {
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? l10n.error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: subColor, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandNavy,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    CustomerHomeTrip trip,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final cust = trip.customer;
    final hasCustomer =
        cust != null &&
        (cust.name.trim().isNotEmpty ||
            cust.phone.trim().isNotEmpty ||
            cust.whatsapp.trim().isNotEmpty);

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TripHeroCard(trip: trip, l10n: l10n, referenceAboveBadge: true),
            const SizedBox(height: 20),
            if (hasCustomer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DriverCustomerCard(
                  customer: cust,
                  l10n: l10n,
                  bookingId: widget.tripId,
                  bookingReference: trip.reference,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _openChat(trip, cust),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppTheme.luxuryAccent,
                      size: 20,
                    ),
                    label: Text(
                      l10n.message,
                      style: GoogleFonts.inter(
                        color: AppTheme.luxuryAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.luxuryAccent.withAlpha(120),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
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
            ..._buildItinerary(trip, l10n, isDark),
            if (trip.extraServices.isNotEmpty) ...[
              _SectionHeader(title: l10n.services, isDark: isDark),
              const SizedBox(height: 12),
              for (final e in trip.extraServices) ...[
                _ServiceRow(service: e, isDark: isDark, l10n: l10n),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ─── Full itinerary (chronological, by day) ───────────────────────────────

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

  /// Tolerant date parser (ISO, dd/MM/yyyy, dd.MM.yyyy, "Oct 21, 2026",
  /// "21 Oct 2026"). Returns null when the value cannot be understood.
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

  List<Widget> _buildItinerary(
    CustomerHomeTrip trip,
    AppLocalizations l10n,
    bool isDark,
  ) {
    // Build day buckets keyed by date (null-date entries go to an "other" list).
    final Map<DateTime, _DayBucket> days = {};
    final undated = _DayBucket();

    _DayBucket bucketFor(DateTime? d) {
      if (d == null) return undated;
      return days.putIfAbsent(d, () => _DayBucket());
    }

    // Transportation (de-duplicated by segment id).
    final seenSeg = <int>{};
    for (final s in trip.transportation) {
      if (s.id != 0 && !seenSeg.add(s.id)) continue;
      final title = (s.title ?? s.notes ?? '').trim();
      final item = HomePlanItem(
        id: s.id,
        time: s.pickupTime,
        endTime: s.endTime ?? '',
        title: title.isNotEmpty ? title : l10n.transportationLabel,
        subtitle: s.city ?? '',
        imageUrl: s.imageUrl,
        type: 'transport',
        status: s.status,
        driverAssigned: s.driverAssigned,
        driverName: s.driverName,
        driver: s.homeDriver,
        pickupAddress: s.pickupAddress ?? '',
        pickupLat: s.pickupLat,
        pickupLng: s.pickupLng,
        pickupMapUrl: s.pickupMapUrl ?? '',
      );
      bucketFor(_parseDate(s.date)).transport.add(item);
    }

    // Activities (de-duplicated by id+title+date).
    final seenAct = <String>{};
    for (final a in trip.activities) {
      final key = '${a.id}|${a.title}|${a.date}';
      if (!seenAct.add(key)) continue;
      // Hotels are rendered once by the grouped hotel card below.
      if (HotelGrouping.isHotelItem(a)) continue;
      bucketFor(_parseDate(a.date)).activities.add(a);
    }

    // Hotels: de-duplicate, sort by check-in then check-out, attach to check-in day.
    final hotels = HotelGrouping.groupStays(trip.hotels);
    final far = DateTime(9999);
    hotels.sort((a, b) {
      final ai = _parseDate(a.checkIn) ?? far;
      final bi = _parseDate(b.checkIn) ?? far;
      final c = ai.compareTo(bi);
      if (c != 0) return c;
      final ao = _parseDate(a.checkOut) ?? far;
      final bo = _parseDate(b.checkOut) ?? far;
      return ao.compareTo(bo);
    });
    for (final h in hotels) {
      bucketFor(_parseDate(h.checkIn)).hotels.add(h);
    }

    if (days.isEmpty && undated.isEmpty) return const [];

    final sortedDates = days.keys.toList()..sort();
    final start = _parseDate(trip.arrivalDate);

    final out = <Widget>[
      _SectionHeader(title: l10n.tripDetails, isDark: isDark),
      const SizedBox(height: 14),
    ];

    Widget dayCard(String label, String dateLabel, _DayBucket b) {
      final items = <HomePlanItem>[...b.transport, ...b.activities]
        ..sort((a, c) => _timeMinutes(a.time).compareTo(_timeMinutes(c.time)));
      return DayItineraryCard(
        dayLabel: label,
        dateLabel: label.isEmpty || label == dateLabel ? '' : dateLabel,
        hotels: b.hotels,
        items: items,
        l10n: l10n,
        driverMode: true,
        mySegmentIds: trip.mySegmentIds.toSet(),
        onItemTap: (it) => _openSegment(it.id),
      );
    }

    for (var i = 0; i < sortedDates.length; i++) {
      final d = sortedDates[i];
      final dayNo = start != null ? d.difference(start).inDays + 1 : i + 1;
      final label = dayNo > 0 ? '${l10n.dayLabel} $dayNo' : _fmtDate(d);
      out.add(dayCard(label, _fmtDate(d), days[d]!));
    }

    if (!undated.isEmpty) {
      out.add(dayCard('', '', undated));
    }

    return out;
  }

  String _fmtDate(DateTime d) =>
      AppLocalizations.of(context).shortDateWithYear(d);
}

class _DayBucket {
  final List<HomeStayHotel> hotels = [];
  final List<HomePlanItem> transport = [];
  final List<HomePlanItem> activities = [];

  bool get isEmpty => hotels.isEmpty && transport.isEmpty && activities.isEmpty;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HotelRow extends StatelessWidget {
  final HomeStayHotel hotel;
  final AppLocalizations l10n;
  final bool isDark;

  const _HotelRow({
    required this.hotel,
    required this.l10n,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final hasIn = hotel.checkIn.isNotEmpty;
    final hasOut = hotel.checkOut.isNotEmpty;

    Widget dateLine(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(color: subColor, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
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
                      style: GoogleFonts.inter(color: subColor, fontSize: 12),
                    ),
                  ),
                if (hasIn) dateLine(l10n.checkIn, hotel.checkIn),
                if (hasOut) dateLine(l10n.checkOut, hotel.checkOut),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  final TransportationSegmentModel segment;
  final AppLocalizations l10n;
  final bool isDark;
  final bool isMine;
  final VoidCallback onTap;

  const _TransportRow({
    required this.segment,
    required this.l10n,
    required this.isDark,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final s = segment;
    final title = (s.title ?? s.notes ?? '').trim();
    final timeRange = [
      if (s.pickupTime.isNotEmpty) s.pickupTime,
      if ((s.endTime ?? '').isNotEmpty) s.endTime!,
    ].join(' – ');
    final meta = [
      if (s.date.isNotEmpty) s.date,
      if (timeRange.isNotEmpty) timeRange,
    ].join('  ·  ');
    final driver = s.homeDriver;

    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMine ? AppTheme.luxuryAccent : border,
          width: isMine ? 1.5 : 1,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: GoogleFonts.inter(
                          color: AppTheme.luxuryAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if ((s.city ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        s.city!,
                        style: GoogleFonts.inter(color: subColor, fontSize: 13),
                      ),
                    ],
                    DriverPickupPointInfo(
                      address: s.pickupAddress,
                      navigateUrl: s.pickupNavigateUrl,
                      buttonLabel: l10n.pickupNavigate,
                      addressColor: subColor,
                    ),
                    if (s.status.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        formatTripStatusDisplay(
                          s.status,
                          localize: AppLocalizations.of(context).locale == 'az'
                              ? AppLocalizations.of(context).backendStatus
                              : null,
                        ),
                        style: GoogleFonts.inter(color: subColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (isMine) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: kItineraryActionButtonHeight,
              child: ElevatedButton(
                onPressed: onTap,
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
          ] else ...[
            const SizedBox(height: 8),
            Text(
              driver != null && driver.name.trim().isNotEmpty
                  ? '${l10n.driverNoColon}: ${driver.name}'
                  : l10n.noDriverAssigned,
              style: GoogleFonts.inter(color: subColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );

    return card;
  }
}

class _ServiceRow extends StatelessWidget {
  final HomeExtraService service;
  final bool isDark;
  final AppLocalizations l10n;

  const _ServiceRow({
    required this.service,
    required this.isDark,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark ? null : AppTheme.cardShadow,
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
              service.isFlowers
                  ? Icons.local_florist_outlined
                  : service.isSimCard
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
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (service.date.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      service.date,
                      style: GoogleFonts.inter(color: subColor, fontSize: 12),
                    ),
                  ),
                if (service.isSimCard)
                  SimDeliveryStatusBlock(
                    service: service,
                    l10n: l10n,
                    textColor: textColor,
                    subColor: subColor,
                  ),
              ],
            ),
          ),
          if (service.qty > 0)
            Text(
              'x${service.qty}',
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
