import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/mock_api_data_source.dart';
import '../../l10n/app_localizations.dart';
import '../../models/driver_bootstrap_model.dart';
import '../../models/hotel_model.dart';
import '../../models/transportation_segment_model.dart';
import '../../models/trip_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/driver_auth_service.dart';
import '../../services/localization_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_network_image.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedTab = 0;
  DriverBootstrapModel? _bootstrap;
  bool _isLoading = true;
  String? _errorMessage;

  DriverAuthService? _driverAuthService;

  @override
  void initState() {
    super.initState();
    if (!MockApiDataSource.useMock) {
      _driverAuthService = DriverAuthService(ApiClient());
    }
    _loadData();
    LocalizationService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => _loadData();

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final DriverBootstrapModel data;
      if (MockApiDataSource.useMock) {
        data = await MockApiDataSource.getDriverBootstrap();
      } else {
        data = await _driverAuthService!.loadBootstrap();
      }
      if (mounted) {
        setState(() {
          _bootstrap = data;
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

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.mainBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(l10n, isDark),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.brandNavy,
                        strokeWidth: 2,
                      ),
                    )
                  : _buildTabContent(l10n, isDark),
            ),
            _buildBottomNav(l10n, isDark),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n, bool isDark) {
    final name = (_bootstrap?.driverName.trim().isNotEmpty ?? false)
        ? _bootstrap!.driverName.trim()
        : 'Driver';
    final vehicleLine = _bootstrap?.vehicleLine ?? '';
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final now = DateTime.now();
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final monthNames = [
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
    ];
    final dayName = dayNames[now.weekday - 1];
    final monthName = monthNames[now.month - 1];
    final dateLabel = '$dayName, ${now.day} $monthName';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      color: isDark ? AppTheme.darkBackground : AppTheme.mainBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting(l10n)}, $name',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  vehicleLine.isNotEmpty ? vehicleLine : dateLabel,
                  style: GoogleFonts.inter(
                    color: subColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Notification button — white rounded card with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: isDark
                      ? AppTheme.darkPrimaryText
                      : AppTheme.primaryText,
                  size: 24,
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppTheme.luxuryAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '2',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Profile avatar — circular
          GestureDetector(
            onTap: () => setState(() => _selectedTab = 4),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.luxuryAccent.withAlpha(180),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: AuthNetworkImage(
                  photoUrl: _bootstrap?.driverPhotoUrl,
                  width: 48,
                  height: 48,
                  fallback: _avatarInitialCircle(name),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarInitialCircle(String name) {
    return Container(
      color: AppTheme.brandNavy,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'D',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ─── Tab Content ───────────────────────────────────────────────────────────

  Widget _buildTabContent(AppLocalizations l10n, bool isDark) {
    switch (_selectedTab) {
      case 0:
        return _buildTodayTab(l10n, isDark);
      case 1:
        return _buildMyTripsTab(l10n, isDark);
      case 2:
        return _buildServicesTab(l10n, isDark);
      case 3:
        return _buildSupportTab(l10n, isDark);
      case 4:
        return _buildProfileTab(l10n, isDark);
      default:
        return _buildTodayTab(l10n, isDark);
    }
  }

  // ─── Today Tab ─────────────────────────────────────────────────────────────

  Widget _buildTodayTab(AppLocalizations l10n, bool isDark) {
    if (_errorMessage != null) return _buildErrorState(l10n, isDark);

    final trips = _bootstrap?.assignedTrips ?? [];
    final nextToday = _bootstrap?.nextToday;
    if (trips.isEmpty && nextToday == null) {
      return _buildEmptyState(l10n, isDark);
    }

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nextToday != null) ...[
              _NextTodayCard(
                segment: nextToday,
                l10n: l10n,
                isDark: isDark,
                onViewDetails: () {
                  context.push(
                    AppRoutes.driverTripDetails,
                    extra: {'segmentId': nextToday.id, 'segment': nextToday},
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            for (final trip in trips) ...[
              _buildTripSection(trip, l10n, isDark),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTripSection(TripModel trip, AppLocalizations l10n, bool isDark) {
    final now = DateTime.now();

    if (trip.isPreTrip) {
      return _DriverCountdownCard(trip: trip, l10n: l10n, isDark: isDark);
    }

    if (trip.isCompleted) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Trip Summary Card (large image card)
        _TripSummaryCard(trip: trip, l10n: l10n, isDark: isDark),
        const SizedBox(height: 16),
        // 2. Customer Profile Card
        _CustomerProfileCard(trip: trip, l10n: l10n, isDark: isDark),
        const SizedBox(height: 16),
        // 3. Arrival Flight Card (full-width)
        _ArrivalFlightCard(trip: trip, l10n: l10n, isDark: isDark),
        const SizedBox(height: 16),
        // 4. Hotel Card
        _buildTodayHotel(trip, now, l10n, isDark),
        // 5. Today's Plan
        _buildTodayTimeline(trip, now, l10n, isDark),
        const SizedBox(height: 16),
        // 6. Tomorrow Preview
        _buildTomorrowPreview(trip, now, l10n, isDark),
        const SizedBox(height: 16),
        // 7. View Full Trip
        _buildViewFullTripButton(trip, l10n, isDark),
      ],
    );
  }

  Widget _buildTodayHotel(
    TripModel trip,
    DateTime now,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final hotel = trip.hotelForDate(now);
    if (hotel == null) return const SizedBox.shrink();
    final nightNum = hotel.nightNumberForDate(now);
    final isCheckIn = hotel.isCheckInDate(now);
    final isCheckOut = hotel.isCheckOutDate(now);
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showHotelBottomSheet(hotel),
          child: _HotelCard(
            hotel: hotel,
            nightNumber: nightNum,
            isCheckIn: isCheckIn,
            isCheckOut: isCheckOut,
            l10n: l10n,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showHotelBottomSheet(HotelModel hotel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(100),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          snap: true,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadowColor,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.luxuryAccent.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.hotel_rounded,
                            color: AppTheme.luxuryAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Hotel Details',
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: border.withAlpha(80),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: subColor,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: border, height: 1),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hotel Name
                          _BottomSheetDetailRow(
                            icon: Icons.hotel_rounded,
                            label: 'Hotel Name',
                            value: hotel.name,
                            textColor: textColor,
                            subColor: subColor,
                            border: border,
                          ),
                          const SizedBox(height: 12),
                          // Full Address
                          _BottomSheetDetailRow(
                            icon: Icons.location_on_rounded,
                            label: 'Full Address',
                            value: hotel.address ?? 'Address not available',
                            textColor: textColor,
                            subColor: subColor,
                            border: border,
                          ),
                          const SizedBox(height: 12),
                          // Phone Number
                          _BottomSheetDetailRow(
                            icon: Icons.phone_rounded,
                            label: 'Phone Number',
                            value:
                                (hotel.phone != null && hotel.phone!.isNotEmpty)
                                ? hotel.phone!
                                : 'Not available',
                            textColor: textColor,
                            subColor: subColor,
                            border: border,
                            onTap:
                                (hotel.phone != null && hotel.phone!.isNotEmpty)
                                ? () async {
                                    final uri = Uri.parse('tel:${hotel.phone}');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(height: 20),
                          // Open in Google Maps button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final address = hotel.address ?? hotel.name;
                                final encoded = Uri.encodeComponent(address);
                                final uri = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=$encoded',
                                );
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: const Icon(Icons.map_rounded, size: 18),
                              label: Text(
                                'Open in Google Maps',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.luxuryAccent,
                                foregroundColor: AppTheme.brandNavy,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTodayTimeline(
    TripModel trip,
    DateTime now,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final todaySegments = trip.segmentsForDate(now);
    if (todaySegments.isEmpty) return const SizedBox.shrink();

    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final monthNames = [
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
    ];
    final dateLabel =
        '${dayNames[now.weekday - 1]}, ${now.day} ${monthNames[now.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row: "Today's Plan" + date
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.todaysPlan,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              dateLabel,
              style: GoogleFonts.inter(
                color: subColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TodayTimeline(
          segments: todaySegments,
          l10n: l10n,
          isDark: isDark,
          bootstrap: _bootstrap,
          tripId: trip.id,
        ),
      ],
    );
  }

  Widget _buildTomorrowPreview(
    TripModel trip,
    DateTime now,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowSegments = trip.segmentsForDate(tomorrow);
    final tomorrowHotel = trip.hotelForDate(tomorrow);
    if (tomorrowSegments.isEmpty && tomorrowHotel == null) {
      return const SizedBox.shrink();
    }
    return _TomorrowPreviewCard(
      trip: trip,
      segments: tomorrowSegments,
      hotel: tomorrowHotel,
      tomorrow: tomorrow,
      l10n: l10n,
      isDark: isDark,
    );
  }

  Widget _buildViewFullTripButton(
    TripModel trip,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          context.push(
            AppRoutes.driverFullTrip,
            extra: {'trip': trip, 'bootstrap': _bootstrap},
          );
        },
        icon: const Icon(Icons.article_outlined, size: 18),
        label: Text(
          l10n.viewFullTrip,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.brandNavy,
          side: BorderSide(
            color: isDark ? AppTheme.darkBorderColor : AppTheme.borderColor,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ─── My Trips Tab ──────────────────────────────────────────────────────────

  Widget _buildMyTripsTab(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final trips = _bootstrap?.assignedTrips ?? [];

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Trips',
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            if (trips.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Text(
                    l10n.noTripsAssigned,
                    style: GoogleFonts.inter(color: subColor, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final trip in trips) ...[
                _TripListCard(
                  trip: trip,
                  isDark: isDark,
                  onTap: () {
                    context.push(
                      AppRoutes.driverFullTrip,
                      extra: {'trip': trip, 'bootstrap': _bootstrap},
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  // ─── Services Tab ──────────────────────────────────────────────────────────

  Widget _buildServicesTab(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services',
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'Services coming soon',
                style: GoogleFonts.inter(color: subColor, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Support Tab ───────────────────────────────────────────────────────────

  Widget _buildSupportTab(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Support',
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'Support coming soon',
                style: GoogleFonts.inter(color: subColor, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty / Error States ──────────────────────────────────────────────────

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.shadowColor,
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.directions_car_outlined,
                        color: AppTheme.luxuryAccent,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.noTripsAssigned,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.assignedTripsHere,
                    style: GoogleFonts.inter(
                      color: subColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, color: subColor, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.somethingWentWrong,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.retry,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Profile Tab ───────────────────────────────────────────────────────────

  Widget _buildProfileTab(AppLocalizations l10n, bool isDark) {
    final driver = _bootstrap;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.luxuryAccent, AppTheme.brandNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.luxuryAccent.withAlpha(60),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                ),
                child: ClipOval(
                  child: AuthNetworkImage(
                    photoUrl: driver?.driverPhotoUrl,
                    width: 91,
                    height: 91,
                    fallback: _buildAvatarInitial(
                      driver?.firstName ?? 'D',
                      isDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            driver?.driverName.isNotEmpty == true
                ? driver!.driverName
                : 'Driver',
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (driver?.rating != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppTheme.luxuryAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          driver!.rating!.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Rating',
                          style: GoogleFonts.inter(
                            color: subColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: VerticalDivider(
                        color: border,
                        thickness: 1,
                        width: 1,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_car_rounded,
                          color: AppTheme.brandNavy,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${driver.totalTrips ?? 0}',
                          style: GoogleFonts.inter(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.trips,
                          style: GoogleFonts.inter(
                            color: subColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (driver?.driverPhone != null ||
              driver?.driverUsername != null) ...[
            _InfoCard(
              isDark: isDark,
              children: [
                if (driver?.driverPhone != null)
                  _InfoRow(
                    label: 'Phone',
                    value: driver!.driverPhone!,
                    isDark: isDark,
                  ),
                if (driver?.driverUsername != null)
                  _InfoRow(
                    label: 'Username',
                    value: driver!.driverUsername!,
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (driver?.vehicle != null &&
              (driver!.vehicle!.make.isNotEmpty ||
                  driver.vehicle!.model.isNotEmpty)) ...[
            _InfoCard(
              isDark: isDark,
              children: [
                if (driver.vehicle!.make.isNotEmpty)
                  _InfoRow(
                    label: 'Vehicle Type',
                    value: driver.vehicle!.make,
                    isDark: isDark,
                  ),
                if (driver.vehicle!.model.isNotEmpty)
                  _InfoRow(
                    label: 'Vehicle Model',
                    value: driver.vehicle!.model,
                    isDark: isDark,
                  ),
                if (driver.vehicle!.manufacturingYear.isNotEmpty)
                  _InfoRow(
                    label: 'Manufacturing Year',
                    value: driver.vehicle!.manufacturingYear,
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 8),
          _DriverThemeSelector(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.userTypeSelection),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                l10n.logout,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: BorderSide(color: AppTheme.errorRed.withAlpha(102)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarInitial(String name, bool isDark) {
    return Container(
      width: 91,
      height: 91,
      color: AppTheme.brandNavy,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'D',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ─── Bottom Navigation ─────────────────────────────────────────────────────

  Widget _buildBottomNav(AppLocalizations l10n, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    final tabs = [
      {
        'icon': Icons.today_outlined,
        'activeIcon': Icons.today_rounded,
        'label': 'Today',
      },
      {
        'icon': Icons.map_outlined,
        'activeIcon': Icons.map_rounded,
        'label': 'My Trips',
      },
      {
        'icon': Icons.room_service_outlined,
        'activeIcon': Icons.room_service_rounded,
        'label': 'Services',
      },
      {
        'icon': Icons.headset_mic_outlined,
        'activeIcon': Icons.headset_mic_rounded,
        'label': 'Support',
      },
      {
        'icon': Icons.person_outline_rounded,
        'activeIcon': Icons.person_rounded,
        'label': l10n.profile,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final tab = entry.value;
              final isSelected = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      Icon(
                        isSelected
                            ? tab['activeIcon'] as IconData
                            : tab['icon'] as IconData,
                        size: 24,
                        color: isSelected
                            ? AppTheme.luxuryAccent
                            : (isDark
                                  ? AppTheme.darkSecondaryText
                                  : AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab['label'] as String,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? AppTheme.luxuryAccent
                              : (isDark
                                    ? AppTheme.darkSecondaryText
                                    : AppTheme.secondaryText),
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 18 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.luxuryAccent,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Trip Summary Card (Large Image Card — Reference Style) ───────────────────

class _TripSummaryCard extends StatelessWidget {
  final TripModel trip;
  final AppLocalizations l10n;
  final bool isDark;

  const _TripSummaryCard({
    required this.trip,
    required this.l10n,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        trip.heroImageUrl ??
        'https://images.pexels.com/photos/3889843/pexels-photo-3889843.jpeg?auto=compress&cs=tinysrgb&w=800';

    // Parse destination parts — show country as main, city below
    final parts = trip.destination.split(',');
    final cityPart = parts.isNotEmpty ? parts[0].trim() : trip.destination;
    final countryPart = parts.length > 1 ? parts[1].trim() : '';
    // Main display: country (e.g. "Georgia"), city below (e.g. "Tbilisi")
    final mainCountry = countryPart.isNotEmpty ? countryPart : cityPart;
    final cityLabel = countryPart.isNotEmpty ? cityPart : '';

    final passengerCount = trip.passengerCount ?? 1;
    final guestLabel =
        '$passengerCount ${passengerCount == 1 ? 'Guest' : 'Guests'}';
    final daysLabel =
        '${trip.totalDays} ${trip.totalDays == 1 ? l10n.day : l10n.days}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full background image
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.brandNavy,
                child: const Icon(
                  Icons.landscape_rounded,
                  color: Colors.white30,
                  size: 48,
                ),
              ),
            ),
            // Dark gradient overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.brandNavy.withAlpha(230),
                    AppTheme.brandNavy.withAlpha(160),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            // Text content overlaid on top
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reference badge — no border, just gold text (slightly larger)
                  Text(
                    trip.reference,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Country name — main big text
                  Text(
                    mainCountry,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (cityLabel.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    // City row below country
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cityLabel,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Arrival & Departure dates
                  if (trip.arrivalDate != null ||
                      trip.startDate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppTheme.luxuryAccent,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Arrival: ${trip.arrivalDate ?? trip.startDate}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppTheme.luxuryAccent,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Departure: ${trip.departureDate ?? trip.endDate}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withAlpha(50),
                    margin: const EdgeInsets.only(bottom: 14),
                  ),
                  // Metrics row
                  Row(
                    children: [
                      // Days metric
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: AppTheme.luxuryAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                daysLabel,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Trip Duration',
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Vertical divider
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withAlpha(50),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      // Guests metric
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            color: AppTheme.luxuryAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guestLabel,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Passengers',
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Customer Profile Card ─────────────────────────────────────────────────────

class _CustomerProfileCard extends StatelessWidget {
  final TripModel trip;
  final AppLocalizations l10n;
  final bool isDark;

  const _CustomerProfileCard({
    required this.trip,
    required this.l10n,
    required this.isDark,
  });

  Future<void> _openWhatsApp(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final digits = normalized.startsWith('+')
        ? normalized.substring(1)
        : normalized;
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final customerName = trip.customerName;
    final customerPhone = trip.customerPhone;

    if (customerName == null && customerPhone == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer name and phone
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customerName != null)
                Text(
                  customerName,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              if (customerPhone != null) ...[
                const SizedBox(height: 2),
                Text(
                  customerPhone,
                  style: GoogleFonts.inter(
                    color: subColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Action buttons: Call + WhatsApp
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: customerPhone != null
                      ? () => _openPhone(customerPhone)
                      : null,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.brandNavy,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Call',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: customerPhone != null
                      ? () => _openWhatsApp(customerPhone)
                      : null,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFF25D366),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_rounded,
                          color: Color(0xFF25D366),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'WhatsApp',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF25D366),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildCustomerInitial(String? name, bool isDark) {
    return Container(
      color: AppTheme.brandNavy,
      child: Center(
        child: Text(
          name?.isNotEmpty == true ? name![0].toUpperCase() : 'C',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Arrival Flight Card (Full-Width Dedicated Card) ──────────────────────────

class _ArrivalFlightCard extends StatelessWidget {
  final TripModel trip;
  final AppLocalizations l10n;
  final bool isDark;

  const _ArrivalFlightCard({
    required this.trip,
    required this.l10n,
    required this.isDark,
  });

  String _formatArrivalDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final d = DateTime.parse(dateStr);
      final months = [
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
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final hasFlightData =
        trip.arrivalFlightNumber != null ||
        trip.arrivalAirline != null ||
        trip.arrivalDate != null ||
        trip.arrivalAirport != null;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.flight_takeoff_rounded,
                  size: 16,
                  color: AppTheme.luxuryAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.arrivalFlight,
                  style: GoogleFonts.inter(
                    color: subColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!hasFlightData)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: subColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arrival flight details not available',
                      style: GoogleFonts.inter(color: subColor, fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Airline + Flight Number (prominent top row)
            if (trip.arrivalAirline != null || trip.arrivalFlightNumber != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (trip.arrivalAirline != null)
                      Text(
                        trip.arrivalAirline!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0099CC),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (trip.arrivalAirline != null &&
                        trip.arrivalFlightNumber != null)
                      const SizedBox(width: 10),
                    if (trip.arrivalFlightNumber != null)
                      Text(
                        trip.arrivalFlightNumber!,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: border,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            const SizedBox(height: 14),
            // Date, Time, Airport rows
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (trip.arrivalDate != null)
                    _FlightDetailRow(
                      icon: Icons.calendar_today_rounded,
                      value: _formatArrivalDate(trip.arrivalDate),
                      textColor: textColor,
                      subColor: subColor,
                    ),
                  if (trip.arrivalTime != null) ...[
                    const SizedBox(height: 10),
                    _FlightDetailRow(
                      icon: Icons.access_time_rounded,
                      value: trip.arrivalTime!,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                  ],
                  if (trip.arrivalAirport != null) ...[
                    const SizedBox(height: 10),
                    _FlightDetailRow(
                      icon: Icons.location_on_rounded,
                      value: trip.arrivalAirport!,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FlightDetailRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color textColor;
  final Color subColor;

  const _FlightDetailRow({
    required this.icon,
    required this.value,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

// ─── Hotel Card (Reference Style: thumbnail left, info right) ─────────────────

class _HotelCard extends StatelessWidget {
  final HotelModel hotel;
  final int? nightNumber;
  final bool isCheckIn;
  final bool isCheckOut;
  final AppLocalizations l10n;
  final bool isDark;

  const _HotelCard({
    required this.hotel,
    required this.nightNumber,
    required this.isCheckIn,
    required this.isCheckOut,
    required this.l10n,
    required this.isDark,
  });

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final months = [
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
      ];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    // Determine section title
    String sectionTitle;
    if (isCheckIn) {
      sectionTitle = l10n.hotelCheckIn;
    } else if (isCheckOut) {
      sectionTitle = l10n.hotelCheckOut;
    } else {
      sectionTitle = l10n.currentHotel;
    }

    // Night badge label
    String? nightBadge;
    if (!isCheckIn && !isCheckOut && nightNumber != null) {
      nightBadge = '${l10n.night} $nightNumber ${l10n.ofLabel} ${hotel.nights}';
    }

    final checkOutFormatted = _formatDate(hotel.checkOut);
    final checkInFormatted = _formatDate(hotel.checkIn);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  sectionTitle,
                  style: GoogleFonts.inter(
                    color: subColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                if (nightBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0E8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE8DFC8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.nightlight_round,
                          size: 12,
                          color: Color(0xFF8B7355),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          nightBadge,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6B5B3E),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Large hotel photo
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(0),
              topRight: Radius.circular(0),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 200,
              child: hotel.photoUrl != null
                  ? Image.network(
                      hotel.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.brandNavy.withAlpha(30),
                        child: Icon(
                          Icons.hotel_rounded,
                          color: AppTheme.brandNavy.withAlpha(80),
                          size: 56,
                        ),
                      ),
                    )
                  : Container(
                      color: AppTheme.brandNavy.withAlpha(20),
                      child: Icon(
                        Icons.hotel_rounded,
                        color: AppTheme.brandNavy.withAlpha(80),
                        size: 56,
                      ),
                    ),
            ),
          ),
          // Hotel info section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hotel Name
                Text(
                  hotel.name,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // City
                Row(
                  children: [
                    Icon(
                      Icons.location_city_rounded,
                      size: 15,
                      color: AppTheme.luxuryAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hotel.location,
                        style: GoogleFonts.inter(
                          color: AppTheme.luxuryAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Divider
                Divider(color: border, height: 1),
                const SizedBox(height: 14),
                // Check-in / Check-out dates
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check-in',
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: AppTheme.luxuryAccent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                checkInFormatted,
                                style: GoogleFonts.inter(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: border),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Check-out',
                              style: GoogleFonts.inter(
                                color: subColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 13,
                                  color: AppTheme.luxuryAccent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  checkOutFormatted,
                                  style: GoogleFonts.inter(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Number of nights
                Row(
                  children: [
                    Icon(
                      Icons.nightlight_round,
                      size: 15,
                      color: AppTheme.luxuryAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${hotel.nights} ${hotel.nights == 1 ? 'Night' : 'Nights'}',
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 14,
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
    );
  }
}

class _HotelTimeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _HotelTimeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Today Timeline ────────────────────────────────────────────────────────────

class _TodayTimeline extends StatelessWidget {
  final List<TransportationSegmentModel> segments;
  final AppLocalizations l10n;
  final bool isDark;
  final DriverBootstrapModel? bootstrap;
  final int tripId;

  const _TodayTimeline({
    required this.segments,
    required this.l10n,
    required this.isDark,
    required this.bootstrap,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: segments.asMap().entries.map((entry) {
        final i = entry.key;
        final seg = entry.value;
        final isLast = i == segments.length - 1;
        return _TimelineItem(
          segment: seg,
          isLast: isLast,
          l10n: l10n,
          isDark: isDark,
          bootstrap: bootstrap,
          tripId: tripId,
        );
      }).toList(),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TransportationSegmentModel segment;
  final bool isLast;
  final AppLocalizations l10n;
  final bool isDark;
  final DriverBootstrapModel? bootstrap;
  final int tripId;

  const _TimelineItem({
    required this.segment,
    required this.isLast,
    required this.l10n,
    required this.isDark,
    required this.bootstrap,
    required this.tripId,
  });

  bool get _isMainTour {
    final desc = (segment.description ?? '').toLowerCase();
    final type = segment.segmentType.toLowerCase();
    return type == 'tour' ||
        desc.contains('tour') ||
        desc.contains('full-day') ||
        desc.contains('full day') ||
        desc.contains('excursion') ||
        desc.contains('kazbegi') ||
        desc.contains('gudauri') ||
        desc.contains('tbilisi') ||
        desc.contains('kakheti') ||
        desc.contains('batumi');
  }

  List<String> get _locationChips {
    final desc = segment.description ?? '';
    final stops = <String>[];
    // Extract known Georgian destinations as chips
    final knownPlaces = [
      'Ananuri',
      'Gudauri',
      'Kazbegi',
      'Tbilisi',
      'Mtskheta',
      'Gori',
      'Uplistsikhe',
      'Batumi',
      'Kutaisi',
      'Sighnaghi',
      'Telavi',
      'Kakheti',
      'Svaneti',
      'Mestia',
      'Borjomi',
    ];
    for (final place in knownPlaces) {
      if (desc.contains(place)) stops.add(place);
    }
    // Also add dropoff location as a chip if it's short enough
    if (stops.isEmpty &&
        segment.dropoffLocation.isNotEmpty &&
        segment.dropoffLocation.length < 20) {
      stops.add(segment.dropoffLocation);
    }
    return stops.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    final isActive = segment.isActive;
    final isCompleted = segment.isCompleted;
    final isMainTour = _isMainTour;

    // Dot style
    Widget dotWidget;
    if (isCompleted) {
      // Dark filled circle with checkmark
      dotWidget = Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF1C2B3A),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
      );
    } else if (isActive) {
      // Gold filled circle
      dotWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.luxuryAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.luxuryAccent.withAlpha(100),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      );
    } else {
      // Empty circle (upcoming)
      dotWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : const Color(0xFFD0CCC4),
            width: 2,
          ),
        ),
      );
    }

    // Time label — for main tour show range
    String timeLabel = segment.pickupTime;
    if (isMainTour && segment.dropoffLocation.isNotEmpty) {
      // Try to show end time if available in description or notes
      final endTimeMatch = RegExp(
        r'(\d{1,2}:\d{2})\s*(?:PM|AM|pm|am)?',
      ).allMatches(segment.notes ?? '').toList();
      if (endTimeMatch.length >= 2) {
        timeLabel = '${segment.pickupTime}\n– ${endTimeMatch.last.group(0)}';
      }
    }

    Color timeColor;
    if (isCompleted) {
      timeColor = subColor;
    } else if (isActive) {
      timeColor = AppTheme.luxuryAccent;
    } else {
      timeColor = subColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: time + dot + line
            SizedBox(
              width: 80,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: GoogleFonts.inter(
                      color: timeColor,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  dotWidget,
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : const Color(0xFFDDD8CE),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: content card
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: isMainTour
                    ? _buildMainTourCard(
                        context,
                        textColor,
                        subColor,
                        cardBg,
                        border,
                      )
                    : _buildSimpleCard(
                        context,
                        textColor,
                        subColor,
                        cardBg,
                        border,
                        isActive,
                        isCompleted,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard(
    BuildContext context,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color border,
    bool isActive,
    bool isCompleted,
  ) {
    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.driverTripDetails,
          extra: {'segmentId': segment.id, 'segment': segment},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // Car icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkBackground
                    : const Color(0xFFF5F2EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.directions_car_rounded,
                size: 18,
                color: isCompleted ? subColor : AppTheme.brandNavy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.description ?? segment.dropoffLocation,
                    style: GoogleFonts.inter(
                      color: isCompleted ? subColor : textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: isCompleted ? TextDecoration.none : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    segment.pickupLocation,
                    style: GoogleFonts.inter(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTourCard(
    BuildContext context,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color border,
  ) {
    final chips = _locationChips;
    final tourImageUrl =
        'https://images.pexels.com/photos/1624438/pexels-photo-1624438.jpeg?auto=compress&cs=tinysrgb&w=800';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tour image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Stack(
              children: [
                Image.network(
                  tourImageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: AppTheme.brandNavy.withAlpha(30),
                    child: Icon(
                      Icons.landscape_rounded,
                      color: AppTheme.brandNavy.withAlpha(60),
                      size: 40,
                    ),
                  ),
                ),
                // Image icon overlay (bottom right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.image_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tour info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.description ?? segment.dropoffLocation,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 3),
                Text(
                  segment.segmentType == 'tour'
                      ? 'Private Full-Day Tour'
                      : segment.pickupLocation,
                  style: GoogleFonts.inter(
                    color: subColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips
                        .map(
                          (chip) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkBackground
                                  : const Color(0xFFF5F2EC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.darkBorderColor
                                    : const Color(0xFFE8E0D0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 11,
                                  color: subColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  chip,
                                  style: GoogleFonts.inter(
                                    color: subColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    context.push(
                      AppRoutes.driverTripDetails,
                      extra: {'segmentId': segment.id, 'segment': segment},
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'View Details',
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: textColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Next Today Card ───────────────────────────────────────────────────────────

class _NextTodayCard extends StatelessWidget {
  final TransportationSegmentModel segment;
  final AppLocalizations l10n;
  final bool isDark;
  final VoidCallback onViewDetails;

  const _NextTodayCard({
    required this.segment,
    required this.l10n,
    required this.isDark,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    final title = (segment.description ?? '').isNotEmpty
        ? segment.description!
        : segment.dropoffLocation;
    final meta = <String>[
      if (segment.tripReference != null) segment.tripReference!,
      if (segment.date.isNotEmpty) segment.date,
      if (segment.pickupTime.isNotEmpty) segment.pickupTime,
    ].join(' · ');
    final route = <String>[
      if (segment.pickupLocation.isNotEmpty) segment.pickupLocation,
      if (segment.dropoffLocation.isNotEmpty) segment.dropoffLocation,
    ].join(' → ');
    final vehicle = <String>[
      if (segment.vehicleDisplayName != null) segment.vehicleDisplayName!,
      if (segment.vehicleColor != null) segment.vehicleColor!,
      if (segment.vehiclePlate != null) segment.vehiclePlate!,
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.nextToday,
            style: GoogleFonts.inter(
              color: AppTheme.luxuryAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              style: GoogleFonts.inter(color: subColor, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (route.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: subColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    route,
                    style: GoogleFonts.inter(color: subColor, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (vehicle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.directions_car_rounded, size: 14, color: subColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    vehicle,
                    style: GoogleFonts.inter(color: subColor, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onViewDetails,
            child: Row(
              children: [
                Text(
                  l10n.viewDetails,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 16, color: textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tomorrow Preview Card ─────────────────────────────────────────────────────

class _TomorrowPreviewCard extends StatelessWidget {
  final TripModel trip;
  final List<TransportationSegmentModel> segments;
  final HotelModel? hotel;
  final DateTime tomorrow;
  final AppLocalizations l10n;
  final bool isDark;

  const _TomorrowPreviewCard({
    required this.trip,
    required this.segments,
    required this.hotel,
    required this.tomorrow,
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

    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final tomorrowDateStr = '${monthNames[tomorrow.month - 1]} ${tomorrow.day}';
    final firstSegment = segments.isNotEmpty ? segments.first : null;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : AppTheme.mainBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Text(
                  l10n.tomorrow,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.luxuryAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.luxuryAccent.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    tomorrowDateStr,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hotel != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.luxuryAccent.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.hotel_rounded,
                          size: 14,
                          color: AppTheme.luxuryAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hotel!.isCheckInDate(tomorrow)
                                  ? 'Check-in: ${hotel!.name}'
                                  : hotel!.name,
                              style: GoogleFonts.inter(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              hotel!.location,
                              style: GoogleFonts.inter(
                                color: subColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (segments.isNotEmpty) const SizedBox(height: 12),
                ],
                if (firstSegment != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandNavy.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          firstSegment.pickupTime,
                          style: GoogleFonts.inter(
                            color: AppTheme.brandNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstSegment.description ??
                                  firstSegment.dropoffLocation,
                              style: GoogleFonts.inter(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              firstSegment.pickupLocation,
                              style: GoogleFonts.inter(
                                color: subColor,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (segments.length > 1) ...[
                    const SizedBox(height: 6),
                    Text(
                      '+${segments.length - 1} ${l10n.moreSegments}',
                      style: GoogleFonts.inter(color: subColor, fontSize: 12),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      l10n.viewTomorrow,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.brandNavy,
                      side: BorderSide(
                        color: isDark
                            ? AppTheme.darkBorderColor
                            : AppTheme.borderColor,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Countdown Card (Pre-Trip) ─────────────────────────────────────────────────

class _DriverCountdownCard extends StatefulWidget {
  final TripModel trip;
  final AppLocalizations l10n;
  final bool isDark;

  const _DriverCountdownCard({
    required this.trip,
    required this.l10n,
    required this.isDark,
  });

  @override
  State<_DriverCountdownCard> createState() => _DriverCountdownCardState();
}

class _DriverCountdownCardState extends State<_DriverCountdownCard> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.trip.timeUntilStart;
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _remaining = widget.trip.timeUntilStart;
        });
        _startTimer();
      }
    });
  }

  String _formatCountdown() {
    final l10n = widget.l10n;
    if (_remaining.inDays >= 1) {
      final days = _remaining.inDays;
      return '$days ${days == 1 ? l10n.day : l10n.days}';
    }
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    if (hours > 0) return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    return '${_remaining.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final l10n = widget.l10n;
    final isDark = widget.isDark;
    final isUrgent = _remaining.inHours < 6;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUrgent
              ? [const Color(0xFF1A0A00), const Color(0xFF3D1A00)]
              : [AppTheme.brandNavy, const Color(0xFF1A3D5C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? AppTheme.luxuryAccent : AppTheme.brandNavy)
                .withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(13),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.luxuryAccent.withAlpha(51),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.luxuryAccent.withAlpha(102),
                    ),
                  ),
                  child: Text(
                    l10n.upcomingTrip,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.schedule_rounded, color: Colors.white54, size: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tripStartsIn,
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCountdown(),
                  style: GoogleFonts.inter(
                    color: AppTheme.luxuryAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withAlpha(25)),
                const SizedBox(height: 16),
                if (trip.reference.isNotEmpty)
                  _CountdownRow(
                    icon: Icons.tag_rounded,
                    label: l10n.reference,
                    value: trip.reference,
                  ),
                if (trip.customerName != null)
                  _CountdownRow(
                    icon: Icons.person_outline_rounded,
                    label: l10n.customer,
                    value: trip.customerName!,
                  ),
                if (trip.arrivalDate != null)
                  _CountdownRow(
                    icon: Icons.calendar_today_rounded,
                    label: l10n.arrival,
                    value:
                        '${trip.arrivalDate}${trip.arrivalTime != null ? '  ${trip.arrivalTime}' : ''}',
                  ),
                if (trip.arrivalFlightNumber != null)
                  _CountdownRow(
                    icon: Icons.flight_land_rounded,
                    label: l10n.flightLabel,
                    value:
                        '${trip.arrivalAirline != null ? '${trip.arrivalAirline} · ' : ''}${trip.arrivalFlightNumber}',
                  ),
                if (trip.arrivalAirport != null)
                  _CountdownRow(
                    icon: Icons.location_on_rounded,
                    label: l10n.airport,
                    value: trip.arrivalAirport!,
                  ),
                if (trip.destination.isNotEmpty)
                  _CountdownRow(
                    icon: Icons.explore_outlined,
                    label: l10n.destinationLabel,
                    value: trip.destination,
                  ),
                if (trip.firstPickupLocation != null)
                  _CountdownRow(
                    icon: Icons.radio_button_checked_rounded,
                    label: l10n.pickup,
                    value:
                        '${trip.firstPickupLocation}${trip.firstPickupTime != null ? '  ${trip.firstPickupTime}' : ''}',
                  ),
                if (trip.hotels.isNotEmpty)
                  _CountdownRow(
                    icon: Icons.hotel_rounded,
                    label: l10n.hotel,
                    value: trip.hotels.first.name,
                  ),
                if (trip.vehicleDisplayName != null)
                  _CountdownRow(
                    icon: Icons.directions_car_rounded,
                    label: l10n.vehicle,
                    value: trip.vehicleDisplayName!,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.luxuryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.viewTrip,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CountdownRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white70,
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

// ─── Trip List Card (My Trips tab) ─────────────────────────────────────────────

class _TripListCard extends StatelessWidget {
  final TripModel trip;
  final bool isDark;
  final VoidCallback onTap;

  const _TripListCard({
    required this.trip,
    required this.isDark,
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.reference,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trip.destination,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (trip.customerName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      trip.customerName!,
                      style: GoogleFonts.inter(color: subColor, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${trip.totalDays}d',
                  style: GoogleFonts.inter(
                    color: AppTheme.brandNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: subColor, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Theme Selector ────────────────────────────────────────────────────────────

class _DriverThemeSelector extends StatefulWidget {
  @override
  State<_DriverThemeSelector> createState() => _DriverThemeSelectorState();
}

class _DriverThemeSelectorState extends State<_DriverThemeSelector> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final current = ThemeService.instance.themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 18,
                color: AppTheme.luxuryAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'Appearance',
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ThemeOptionBtn(
                icon: Icons.brightness_auto_rounded,
                label: 'System',
                selected: current == AppThemeMode.system,
                isDark: isDark,
                onTap: () =>
                    ThemeService.instance.setThemeMode(AppThemeMode.system),
              ),
              const SizedBox(width: 8),
              _ThemeOptionBtn(
                icon: Icons.wb_sunny_rounded,
                label: 'Light',
                selected: current == AppThemeMode.light,
                isDark: isDark,
                onTap: () =>
                    ThemeService.instance.setThemeMode(AppThemeMode.light),
              ),
              const SizedBox(width: 8),
              _ThemeOptionBtn(
                icon: Icons.nightlight_round,
                label: 'Dark',
                selected: current == AppThemeMode.dark,
                isDark: isDark,
                onTap: () =>
                    ThemeService.instance.setThemeMode(AppThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeOptionBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppTheme.brandNavy
        : (isDark ? AppTheme.darkBackground : AppTheme.mainBackground);
    final fg = selected
        ? Colors.white
        : (isDark ? AppTheme.darkSecondaryText : AppTheme.secondaryText);
    final borderC = selected
        ? AppTheme.brandNavy
        : (isDark ? AppTheme.darkBorderColor : AppTheme.borderColor);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderC),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppTheme.luxuryAccent : fg,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: fg,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info Card / Row ───────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _InfoCard({required this.children, required this.isDark});

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
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) Divider(color: border, height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _InfoRow({
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
      children: [
        Text(label, style: GoogleFonts.inter(color: subColor, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Bottom Sheet Detail Row ───────────────────────────────────────────────────

class _BottomSheetDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color subColor;
  final Color border;
  final VoidCallback? onTap;

  const _BottomSheetDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.subColor,
    required this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: onTap != null
              ? AppTheme.luxuryAccent.withAlpha(10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.luxuryAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.luxuryAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: subColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      color: onTap != null ? AppTheme.luxuryAccent : textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: subColor, size: 18),
          ],
        ),
      ),
    );
  }
}
