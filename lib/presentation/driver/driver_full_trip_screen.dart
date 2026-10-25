import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/localization_service.dart';
import '../../models/trip_model.dart';
import '../../models/hotel_model.dart';
import '../../models/flight_model.dart';
import '../../models/transportation_segment_model.dart';
import '../../models/extra_service_model.dart';
import '../../models/driver_bootstrap_model.dart';
import '../../services/api_client.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_api_service.dart';
import '../../data/mock_api_data_source.dart';
import './hotel_details_screen.dart';

class DriverFullTripScreen extends StatefulWidget {
  final TripModel trip;
  final DriverBootstrapModel? bootstrap;

  const DriverFullTripScreen({super.key, required this.trip, this.bootstrap});

  @override
  State<DriverFullTripScreen> createState() => _DriverFullTripScreenState();
}

class _DriverFullTripScreenState extends State<DriverFullTripScreen> {
  late TripModel _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    LocalizationService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  Future<void> _refreshTripFromOdoo() async {
    try {
      if (MockApiDataSource.useMock) {
        final bootstrap = await MockApiDataSource.getDriverBootstrap();
        final refreshed = bootstrap.assignedTrips.firstWhere(
          (t) => t.id == _trip.id,
          orElse: () => _trip,
        );
        if (mounted) setState(() => _trip = refreshed);
      } else {
        final bootstrap = await DriverAuthService(ApiClient()).loadBootstrap();
        final refreshed = bootstrap.assignedTrips.firstWhere(
          (t) => t.id == _trip.id,
          orElse: () => _trip,
        );
        if (mounted) setState(() => _trip = refreshed);
      }
    } catch (_) {}
  }

  Future<void> _confirmSimDelivery(ExtraServiceModel extra) async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SimDeliveryBottomSheet(
        trip: _trip,
        extra: extra,
        bootstrap: widget.bootstrap,
        isDark: isDark,
        l10n: l10n,
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'trip_id': _trip.id,
        'trip_reference': _trip.reference,
        'customer_name': _trip.customerName ?? '',
        'driver_id': widget.bootstrap?.driverId,
        'driver_name': widget.bootstrap?.driverName ?? '',
        'sim_quantity': extra.quantity,
        'delivery_status': 'delivered',
        'delivered_at': now,
        'extra_service_id': extra.id,
      };

      if (!MockApiDataSource.useMock) {
        await DriverApiService(
          ApiClient(),
        ).confirmSimDelivery(tripId: _trip.id, payload: payload);
      }

      if (mounted) Navigator.of(context).pop(); // close loading

      await _refreshTripFromOdoo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.simMarkedDelivered,
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiException.messageOf(e) ?? l10n.confirmDeliveryFailed,
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trip = _trip;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : AppTheme.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(l10n, isDark, trip),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trip overview card
                    _buildTripOverviewCard(trip, l10n, isDark),
                    const SizedBox(height: 20),
                    // Arrival / Flight info
                    if (_hasArrivalInfo(trip)) ...[
                      _SectionHeader(title: l10n.arrivalInfo, isDark: isDark),
                      const SizedBox(height: 10),
                      _buildArrivalCard(trip, l10n, isDark),
                      const SizedBox(height: 20),
                    ],
                    // Departure info
                    if (_hasDepartureInfo(trip)) ...[
                      _SectionHeader(title: l10n.departureInfo, isDark: isDark),
                      const SizedBox(height: 10),
                      _buildDepartureCard(trip, l10n, isDark),
                      const SizedBox(height: 20),
                    ],
                    // Flights
                    if (trip.flights.isNotEmpty) ...[
                      _SectionHeader(title: l10n.flightsLabel, isDark: isDark),
                      const SizedBox(height: 10),
                      ...trip.flights.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FlightCard(
                            flight: f,
                            l10n: l10n,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Hotels
                    if (trip.hotels.isNotEmpty) ...[
                      _SectionHeader(title: l10n.hotelsLabel, isDark: isDark),
                      const SizedBox(height: 10),
                      ...trip.hotels.map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FullHotelCard(
                            hotel: h,
                            l10n: l10n,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Transportation segments
                    if (trip.transportationSegments.isNotEmpty) ...[
                      _SectionHeader(
                        title: l10n.transportationLabel,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildTransportationList(
                        trip.transportationSegments,
                        l10n,
                        isDark,
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Extra services (no financial data)
                    if (_hasOperationalExtras(trip.extraServices)) ...[
                      _SectionHeader(title: l10n.extraServices, isDark: isDark),
                      const SizedBox(height: 10),
                      ...trip.extraServices
                          .where((e) => _isOperationalExtra(e))
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ExtraServiceCard(
                                extra: e,
                                l10n: l10n,
                                isDark: isDark,
                                onSimCardTap: e.isSimCard
                                    ? () => _confirmSimDelivery(e)
                                    : null,
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n, bool isDark, TripModel trip) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: textColor,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fullTripDetails,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trip.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Trip state badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _tripStateColor(trip).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _tripStateColor(trip).withAlpha(60)),
            ),
            child: Text(
              _tripStateLabel(trip, l10n),
              style: GoogleFonts.inter(
                color: _tripStateColor(trip),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripOverviewCard(
    TripModel trip,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandNavy, const Color(0xFF1A3D5C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14.95,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.destination,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${trip.totalDays}',
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    l10n.daysLabel,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withAlpha(25)),
          const SizedBox(height: 16),
          // Customer
          if (trip.customerName != null)
            _TripDetailRow(
              icon: Icons.person_outline_rounded,
              label: l10n.customer,
              value: trip.customerName!,
              isLight: true,
            ),
          // Dates
          _TripDetailRow(
            icon: Icons.calendar_today_rounded,
            label: l10n.checkIn,
            value: trip.startDate,
            isLight: true,
          ),
          _TripDetailRow(
            icon: Icons.calendar_today_outlined,
            label: l10n.checkOut,
            value: trip.endDate,
            isLight: true,
          ),
          // Passengers
          if (trip.passengerCount != null)
            _TripDetailRow(
              icon: Icons.group_outlined,
              label: l10n.passengers,
              value: '${trip.passengerCount}',
              isLight: true,
            ),
        ],
      ),
    );
  }

  Widget _buildArrivalCard(TripModel trip, AppLocalizations l10n, bool isDark) {
    return _DetailCard(
      isDark: isDark,
      children: [
        if (trip.arrivalDate != null)
          _DetailRow(
            label: l10n.arrival,
            value: trip.arrivalDate!,
            isDark: isDark,
          ),
        if (trip.arrivalTime != null)
          _DetailRow(
            label: l10n.arrivalTime,
            value: trip.arrivalTime!,
            isDark: isDark,
          ),
        if (trip.arrivalAirline != null)
          _DetailRow(
            label: l10n.airline,
            value: trip.arrivalAirline!,
            isDark: isDark,
          ),
        if (trip.arrivalFlightNumber != null)
          _DetailRow(
            label: l10n.flightLabel,
            value: trip.arrivalFlightNumber!,
            isDark: isDark,
          ),
        if (trip.arrivalAirport != null)
          _DetailRow(
            label: l10n.airport,
            value: trip.arrivalAirport!,
            isDark: isDark,
          ),
        if (trip.firstPickupLocation != null)
          _DetailRow(
            label: l10n.firstPickup,
            value:
                '${trip.firstPickupLocation}${trip.firstPickupTime != null ? '  ${trip.firstPickupTime}' : ''}',
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildDepartureCard(
    TripModel trip,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return _DetailCard(
      isDark: isDark,
      children: [
        if (trip.departureDate != null)
          _DetailRow(
            label: l10n.departure,
            value: trip.departureDate!,
            isDark: isDark,
          ),
        if (trip.departureTime != null)
          _DetailRow(
            label: l10n.departureTime,
            value: trip.departureTime!,
            isDark: isDark,
          ),
        if (trip.departureAirline != null)
          _DetailRow(
            label: l10n.airline,
            value: trip.departureAirline!,
            isDark: isDark,
          ),
        if (trip.departureFlightNumber != null)
          _DetailRow(
            label: l10n.flightLabel,
            value: trip.departureFlightNumber!,
            isDark: isDark,
          ),
        if (trip.departureAirport != null)
          _DetailRow(
            label: l10n.airport,
            value: trip.departureAirport!,
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildTransportationList(
    List<TransportationSegmentModel> segments,
    AppLocalizations l10n,
    bool isDark,
  ) {
    // Group by date
    final Map<String, List<TransportationSegmentModel>> byDate = {};
    for (final seg in segments) {
      byDate.putIfAbsent(seg.date, () => []).add(seg);
    }
    final sortedDates = byDate.keys.toList()..sort();

    return Column(
      children: sortedDates.map((date) {
        final segs = byDate[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                date,
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppTheme.darkSecondaryText
                      : AppTheme.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...segs.map(
              (seg) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SegmentCard(segment: seg, l10n: l10n, isDark: isDark),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  bool _hasArrivalInfo(TripModel trip) =>
      trip.arrivalDate != null ||
      trip.arrivalFlightNumber != null ||
      trip.arrivalAirport != null;

  bool _hasDepartureInfo(TripModel trip) =>
      trip.departureDate != null ||
      trip.departureFlightNumber != null ||
      trip.departureAirport != null;

  bool _hasOperationalExtras(List<ExtraServiceModel> extras) =>
      extras.any((e) => _isOperationalExtra(e));

  bool _isOperationalExtra(ExtraServiceModel e) =>
      e.serviceType == 'sim_card' ||
      e.serviceType == 'insurance' ||
      e.serviceType == 'visa' ||
      e.serviceType == 'transfer' ||
      e.serviceType == 'activity';

  Color _tripStateColor(TripModel trip) {
    if (trip.isInProgress) return AppTheme.successGreen;
    if (trip.isPreTrip) return AppTheme.luxuryAccent;
    if (trip.isCompleted) return AppTheme.secondaryText;
    return AppTheme.brandNavy;
  }

  String _tripStateLabel(TripModel trip, AppLocalizations l10n) {
    if (trip.isInProgress) return l10n.activeTrip;
    if (trip.isPreTrip) return l10n.upcomingLabel;
    if (trip.isCompleted) return l10n.completedLabel;
    return l10n.activeTrip;
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: isDark ? AppTheme.darkSecondaryText : AppTheme.secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ─── Trip Detail Row (dark card) ───────────────────────────────────────────────

class _TripDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLight;

  const _TripDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isLight ? Colors.white38 : AppTheme.secondaryText,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              color: isLight ? Colors.white38 : AppTheme.secondaryText,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: isLight ? Colors.white70 : AppTheme.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Card ───────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;

  const _DetailCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) Divider(color: border, height: 12),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.inter(color: subColor, fontSize: 13),
          ),
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
    );
  }
}

// ─── Flight Card ───────────────────────────────────────────────────────────────

class _FlightCard extends StatelessWidget {
  final FlightModel flight;
  final AppLocalizations l10n;
  final bool isDark;

  const _FlightCard({
    required this.flight,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flight_rounded, size: 16, color: AppTheme.navyText),
              const SizedBox(width: 8),
              Text(
                '${flight.airline}  ${flight.flightNumber}',
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _StatusChip(status: flight.status, isDark: isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flight.origin,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      flight.departureTime,
                      style: GoogleFonts.inter(color: subColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: subColor, size: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      flight.destination,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      flight.arrivalTime,
                      style: GoogleFonts.inter(color: subColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            flight.departureDate,
            style: GoogleFonts.inter(color: subColor, fontSize: 12),
          ),
          if (flight.terminal != null || flight.gate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (flight.terminal != null)
                  Text(
                    '${l10n.terminal}: ${flight.terminal}',
                    style: GoogleFonts.inter(color: subColor, fontSize: 12),
                  ),
                if (flight.terminal != null && flight.gate != null)
                  Text(
                    '  ·  ',
                    style: GoogleFonts.inter(color: subColor, fontSize: 12),
                  ),
                if (flight.gate != null)
                  Text(
                    '${l10n.gate}: ${flight.gate}',
                    style: GoogleFonts.inter(color: subColor, fontSize: 12),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Full Hotel Card ───────────────────────────────────────────────────────────

class _FullHotelCard extends StatelessWidget {
  final HotelModel hotel;
  final AppLocalizations l10n;
  final bool isDark;

  const _FullHotelCard({
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

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hotel_rounded,
                      size: 16,
                      color: AppTheme.luxuryAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => HotelDetailsScreen.show(
                          context,
                          name: hotel.name,
                          phone: hotel.phone ?? '',
                          googleMapUrl: hotel.googleMapUrl ?? '',
                        ),
                        child: Text(
                          hotel.name,
                          style: GoogleFonts.inter(
                            color: AppTheme.luxuryAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    hotel.location,
                    style: GoogleFonts.inter(color: subColor, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _HotelDateChip(
                        label: l10n.checkIn,
                        value: hotel.checkIn,
                        time: hotel.checkInTime,
                        color: AppTheme.successGreen,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HotelDateChip(
                        label: l10n.checkOut,
                        value: hotel.checkOut,
                        time: hotel.checkOutTime,
                        color: AppTheme.luxuryAccent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                if (hotel.roomType != null) ...[
                  const SizedBox(height: 10),
                  _DetailRow(
                    label: l10n.room,
                    value: hotel.roomType!,
                    isDark: isDark,
                  ),
                ],
                if (hotel.guestInfo != null) ...[
                  const SizedBox(height: 4),
                  _DetailRow(
                    label: l10n.guestInfo,
                    value: hotel.guestInfo!,
                    isDark: isDark,
                  ),
                ],
                if (hotel.nights > 0) ...[
                  const SizedBox(height: 4),
                  _DetailRow(
                    label: l10n.nights,
                    value: '${hotel.nights}',
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HotelDateChip extends StatelessWidget {
  final String label;
  final String value;
  final String? time;
  final Color color;
  final bool isDark;

  const _HotelDateChip({
    required this.label,
    required this.value,
    this.time,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkBackground : AppTheme.mainBackground;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (time != null)
            Text(
              time!,
              style: GoogleFonts.inter(color: subColor, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

// ─── Segment Card ──────────────────────────────────────────────────────────────

class _SegmentCard extends StatelessWidget {
  final TransportationSegmentModel segment;
  final AppLocalizations l10n;
  final bool isDark;

  const _SegmentCard({
    required this.segment,
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: segment.isActive
              ? AppTheme.luxuryAccent.withAlpha(80)
              : border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                segment.pickupTime,
                style: GoogleFonts.inter(
                  color: AppTheme.luxuryAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  segment.description ?? segment.dropoffLocation,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: segment.status, isDark: isDark),
            ],
          ),
          const SizedBox(height: 8),
          // Pickup → Dropoff
          Row(
            children: [
              Icon(
                Icons.radio_button_checked_rounded,
                size: 12,
                color: AppTheme.successGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  segment.pickupLocation,
                  style: GoogleFonts.inter(color: subColor, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 12,
                color: AppTheme.luxuryAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  segment.dropoffLocation,
                  style: GoogleFonts.inter(color: subColor, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (segment.customerName != null ||
              segment.vehicleDisplayName != null) ...[
            const SizedBox(height: 8),
            Divider(color: border, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (segment.customerName != null) ...[
                  Icon(Icons.person_outline_rounded, size: 12, color: subColor),
                  const SizedBox(width: 4),
                  Text(
                    segment.customerName!,
                    style: GoogleFonts.inter(color: subColor, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                ],
                if (segment.vehicleDisplayName != null) ...[
                  Icon(Icons.directions_car_rounded, size: 12, color: subColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      segment.vehicleDisplayName!,
                      style: GoogleFonts.inter(color: subColor, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (segment.flightNumber != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.flight_rounded, size: 12, color: subColor),
                const SizedBox(width: 4),
                Text(
                  '${segment.flightAirline != null ? '${segment.flightAirline} · ' : ''}${segment.flightNumber}',
                  style: GoogleFonts.inter(color: subColor, fontSize: 11),
                ),
              ],
            ),
          ],
          if (segment.notes != null && segment.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkBackground
                    : AppTheme.mainBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                segment.notes!,
                style: GoogleFonts.inter(
                  color: subColor,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Extra Service Card ────────────────────────────────────────────────────────

class _ExtraServiceCard extends StatelessWidget {
  final ExtraServiceModel extra;
  final AppLocalizations l10n;
  final bool isDark;
  final VoidCallback? onSimCardTap;

  const _ExtraServiceCard({
    required this.extra,
    required this.l10n,
    required this.isDark,
    this.onSimCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final isSimCard = extra.isSimCard;
    final isDelivered =
        extra.status?.toLowerCase() == 'delivered' ||
        extra.status?.toLowerCase() == 'done' ||
        extra.status?.toLowerCase() == 'completed';

    final canTap = isSimCard && !isDelivered && onSimCardTap != null;

    return GestureDetector(
      onTap: canTap ? onSimCardTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: canTap ? AppTheme.brandNavy.withAlpha(80) : border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSimCard
                    ? AppTheme.brandNavy.withAlpha(20)
                    : AppTheme.luxuryAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  isSimCard
                      ? Icons.sim_card_outlined
                      : Icons.add_circle_outline_rounded,
                  size: 20,
                  color: isSimCard ? AppTheme.brandNavy : AppTheme.luxuryAccent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    extra.name,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (extra.description != null)
                    Text(
                      extra.description!,
                      style: GoogleFonts.inter(color: subColor, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  if (canTap) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.tapToConfirmDelivery,
                      style: GoogleFonts.inter(
                        color: AppTheme.navyText,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'x${extra.quantity}',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (extra.status != null)
                  _StatusChip(status: extra.status!, isDark: isDark),
              ],
            ),
            if (canTap) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.brandNavy.withAlpha(150),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── SIM Delivery Bottom Sheet ─────────────────────────────────────────────────

class _SimDeliveryBottomSheet extends StatelessWidget {
  final TripModel trip;
  final ExtraServiceModel extra;
  final DriverBootstrapModel? bootstrap;
  final bool isDark;
  final AppLocalizations l10n;

  const _SimDeliveryBottomSheet({
    required this.trip,
    required this.extra,
    required this.bootstrap,
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
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.brandNavy.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.sim_card_outlined,
                    size: 20,
                    color: AppTheme.navyText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.confirmSimDeliveredTitle,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : AppTheme.mainBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _SheetDetailRow(
                  label: l10n.tripReference,
                  value: trip.reference,
                  textColor: textColor,
                  subColor: subColor,
                ),
                Divider(color: border, height: 16),
                _SheetDetailRow(
                  label: l10n.customerName,
                  value: trip.customerName ?? '—',
                  textColor: textColor,
                  subColor: subColor,
                ),
                Divider(color: border, height: 16),
                _SheetDetailRow(
                  label: l10n.simQuantity,
                  value: '${extra.quantity} ${l10n.simCardsCount}',
                  textColor: textColor,
                  subColor: subColor,
                ),
                Divider(color: border, height: 16),
                _SheetDetailRow(
                  label: l10n.currentStatus,
                  value: extra.status != null
                      ? l10n.backendStatus(extra.status!)
                      : l10n.pending,
                  textColor: textColor,
                  subColor: subColor,
                  valueColor: AppTheme.luxuryAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.cancelAction,
                    style: GoogleFonts.inter(
                      color: subColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.confirmDelivery,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color subColor;
  final Color? valueColor;

  const _SheetDetailRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.subColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(color: subColor, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Status Chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isDark;

  const _StatusChip({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
      case 'in_progress':
      case 'completed':
      case 'done':
        color = AppTheme.successGreen;
        break;
      case 'scheduled':
      case 'confirmed':
      case 'assigned':
        color = AppTheme.brandNavy;
        break;
      case 'pending':
        color = AppTheme.luxuryAccent;
        break;
      default:
        color = AppTheme.secondaryText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        l10n.backendStatus(status),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
