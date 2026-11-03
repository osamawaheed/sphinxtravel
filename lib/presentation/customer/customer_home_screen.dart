import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_api_data_source.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer_bootstrap_model.dart';
import '../../models/extra_service_model.dart';
import '../../models/flight_model.dart';
import '../../models/hotel_model.dart';
import '../../models/transportation_segment_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/chat/chat_presence_service.dart';
import '../../services/customer_auth_service.dart';
import '../../services/flight_visibility.dart';
import '../../services/localization_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_notification_source.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../driver/hotel_details_screen.dart';
import './widgets/current_hotel_card.dart';
import './widgets/customer_sim_card.dart';
import './widgets/customer_my_trips_list.dart';
import './widgets/driver_review_dialog.dart';
import './widgets/flight_card.dart';
import './widgets/language_picker_sheet.dart';
import './widgets/management_team_section.dart';
import './widgets/next_up_card.dart';
import './widgets/support_contact_actions.dart';
import './widgets/rating_sheet.dart';
import './widgets/todays_plan_card.dart';
import './widgets/tomorrow_preview_card.dart';
import './widgets/track_your_driver_card.dart';
import './widgets/trip_hero_card.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver, FlightVisibilityRefresher {
  int _selectedTab = 0;
  final Set<int> _simBusyIds = <int>{};
  CustomerBootstrapModel? _bootstrap;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Authenticated customers read real notifications (read-only).
    if (NotificationService.instance.source is! SupabaseNotificationSource) {
      NotificationService.instance.source = SupabaseNotificationSource();
    }
    NotificationService.instance.refresh();
    LocalizationService.instance.addListener(_onLocaleChanged);
    initFlightVisibility();
  }

  @override
  void dispose() {
    disposeFlightVisibility();
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    _loadData();
  }

  /// App-level presence for the signed-in customer. Unique key is
  /// `customer:<customerId>`; the booking reference lets the driver of the
  /// same booking resolve this customer's status.
  void _startPresence(CustomerBootstrapModel data) {
    if (MockApiDataSource.useMock) {
      debugPrint('[presence] customer start skipped: USE_MOCK_API=true');
      return;
    }
    if (data.customerId <= 0) {
      debugPrint(
        '[presence] customer start skipped: customerId=${data.customerId}',
      );
      return;
    }
    final trip = data.homeTrip;
    final ref = (trip?.reference ?? '').trim();
    ChatPresenceService.instance.start(
      role: 'customer',
      userId: data.customerId,
      bookings: ref.isEmpty ? const [] : [ref],
      bookingIds: (trip?.id ?? 0) > 0 ? [trip!.id] : const [],
    );
  }

  String _currentLanguageLabel() {
    final code = LocalizationService.instance.currentLanguage;
    for (final lang in LocalizationService.customerLanguages) {
      if (lang['code'] == code) return lang['label']!;
    }
    return '';
  }

  bool _signingOut = false;

  Future<void> _confirmSignOut(AppLocalizations l10n) async {
    if (_signingOut || SessionManager.isSigningOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.signOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.signOut,
              style: const TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _signingOut) return;

    _signingOut = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.luxuryAccent),
        ),
      ),
    );
    await SessionManager.signOut(fallbackRole: 'customer');
    if (navigator.canPop()) navigator.pop();
    router.go(AppRoutes.customerLogin);
  }

  Future<void> _loadData() async {
    try {
      final CustomerBootstrapModel data = MockApiDataSource.useMock
          ? await MockApiDataSource.getCustomerBootstrap()
          : await CustomerAuthService(ApiClient()).loadBootstrap();
      if (mounted) {
        setState(() {
          _bootstrap = data;
          _isLoading = false;
        });
        _startPresence(data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              ApiException.messageOf(e) ??
              AppLocalizations.of(context).failedToLoad;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _afterRated(AppLocalizations l10n) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.thanksForRating),
        duration: const Duration(seconds: 2),
      ),
    );
    await _loadData();
  }

  /// Runs a customer SIM action against Odoo. Success is only shown when the
  /// API call succeeds; errors are surfaced and nothing is faked.
  Future<void> _runSimAction(
    HomeExtraService service,
    AppLocalizations l10n, {
    required bool received,
  }) async {
    if (_simBusyIds.contains(service.id)) return;
    final trip = _bootstrap?.homeTrip;
    final tripId = trip?.id ?? 0;
    final customerId = _bootstrap?.customerId ?? 0;
    if (tripId <= 0 || customerId <= 0 || service.id <= 0) return;
    // Duplicate guards (Odoo remains the source of truth on reload).
    if (service.isCustomerReceived) return;
    if (!received && service.isNotReceivedReported) return;

    setState(() => _simBusyIds.add(service.id));
    try {
      final api = CustomerAuthService(ApiClient());
      if (received) {
        await api.confirmSimReceived(
          tripId: tripId,
          customerId: customerId,
          extraServiceId: service.id,
        );
      } else {
        await api.reportSimNotReceived(
          tripId: tripId,
          customerId: customerId,
          extraServiceId: service.id,
        );
      }
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            received
                ? (service.isFlowers
                      ? l10n.flowersReceiptSaved
                      : l10n.simReceiptSaved)
                : l10n.simReportSaved,
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiException.messageOf(e) ??
                (service.isFlowers
                    ? l10n.flowersActionFailed
                    : l10n.simActionFailed),
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _simBusyIds.remove(service.id));
    }
  }

  Widget _buildSimSection(CustomerHomeTrip trip, AppLocalizations l10n) {
    final sims = trip.extraServices.where((e) => e.isSimCard).toList();
    if (sims.isEmpty) return const SizedBox.shrink();
    // Once the customer or driver has confirmed delivery in Odoo, the eSIM
    // card leaves Today (it stays visible in My Trip).
    if (sims.every((e) => e.isSimConfirmed)) return const SizedBox.shrink();
    final service = sims.firstWhere(
      (e) => !e.isSimConfirmed,
      orElse: () => sims.first,
    );
    final totalQty = sims.fold<int>(0, (sum, e) => sum + e.qty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: CustomerSimCard(
        service: service,
        totalQty: totalQty,
        l10n: l10n,
        busy: _simBusyIds.contains(service.id),
        onConfirmReceived: () => _runSimAction(service, l10n, received: true),
        onReportNotReceived: () =>
            _runSimAction(service, l10n, received: false),
      ),
    );
  }

  Future<void> _rateDriver(HomeDriver driver, AppLocalizations l10n) async {
    final tripId = _bootstrap?.homeTrip?.id ?? 0;
    if (tripId <= 0 || driver.id <= 0) return;
    final transportationId =
        _bootstrap?.homeTrip?.nextPickup?.transportationId ?? 0;
    final ok = await DriverReviewDialog.show(
      context,
      driverName: driver.name,
      initial: driver.myRating,
      l10n: l10n,
      onSubmit: (rating, comment) =>
          CustomerAuthService(ApiClient()).rateDriver(
            tripId: tripId,
            driverId: driver.id,
            rating10: rating,
            comment: comment,
            transportationId: transportationId,
          ),
    );
    if (ok == true) await _afterRated(l10n);
  }

  Future<void> _rateHotel(HomeHotel hotel, AppLocalizations l10n) async {
    final tripId = _bootstrap?.homeTrip?.id ?? 0;
    if (tripId <= 0 || hotel.id <= 0) return;
    final ok = await RatingSheet.show(
      context,
      title: l10n.rateHotelTitle,
      subjectName: hotel.name,
      initial: hotel.myRating,
      l10n: l10n,
      onSubmit: (rating, comment) => CustomerAuthService(ApiClient()).rateHotel(
        tripId: tripId,
        hotelId: hotel.id,
        rating: rating,
        comment: comment,
      ),
    );
    if (ok == true) await _afterRated(l10n);
  }

  void _openHotelDetails({
    required String name,
    String phone = '',
    String googleMapUrl = '',
  }) {
    HotelDetailsScreen.show(
      context,
      name: name,
      phone: phone,
      googleMapUrl: googleMapUrl,
    );
  }

  String _formattedDate(AppLocalizations l10n) {
    final now = DateTime.now();
    final isAr = LocalizationService.instance.isArabic;
    if (isAr) {
      const arMonths = [
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
      ];
      const arDays = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      return '${arDays[now.weekday - 1]}، ${now.day} ${arMonths[now.month - 1]}';
    }
    const months = [
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
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRTL = LocalizationService.instance.isRTL;

    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(l10n),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.brandNavy,
                        strokeWidth: 2,
                      ),
                    )
                  : _error != null
                  ? _buildError(l10n)
                  : _buildTabContent(l10n),
            ),
            _buildBottomNav(l10n, isRTL),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final fullName = (_bootstrap?.customerName ?? '').trim();
    final name = fullName.isNotEmpty ? fullName : l10n.traveler;
    final avatarUrl = (_bootstrap?.avatarUrl?.isNotEmpty ?? false)
        ? _bootstrap?.avatarUrl
        : null;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
    final isAr = l10n.isRtlLocale;
    final firstName = (_bootstrap?.firstName ?? '').trim();
    final displayName = firstName.isNotEmpty ? firstName : name;
    final greetingText = l10n.helloWithName(displayName);
    final taglineText = l10n.headerSubtitle(isDriver: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      color: AppTheme.mainBackground,
      child: Row(
        children: [
          Expanded(
            child: Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.formattedHeaderDate(DateTime.now()),
                    textAlign: TextAlign.start,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    greetingText,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    taglineText,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: isAr ? 15.64 : 13.6,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                    maxLines: isAr ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Notification button
          GestureDetector(
            onTap: () => context.push('/customer/notifications'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      color: AppTheme.primaryText,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: AnimatedBuilder(
                      animation: NotificationService.instance,
                      builder: (context, _) {
                        final count = NotificationService.instance.unreadCount;
                        if (count <= 0) return const SizedBox.shrink();
                        return Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: AppTheme.luxuryAccent,
                            borderRadius: BorderRadius.all(Radius.circular(9)),
                          ),
                          child: Center(
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Profile avatar
          GestureDetector(
            onTap: () => setState(() => _selectedTab = 4),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.luxuryAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandNavy.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _avatarFallback(initial),
                      )
                    : _avatarFallback(initial),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Container(
      color: AppTheme.brandNavy,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(AppLocalizations l10n) {
    switch (_selectedTab) {
      case 0:
        return _buildTodayTab(l10n);
      case 1:
        return _buildMyTripTab(l10n);
      case 2:
        return _buildServicesTab(l10n);
      case 3:
        return _buildSupportTab(l10n);
      case 4:
        return _buildProfileTab(l10n);
      default:
        return _buildTodayTab(l10n);
    }
  }

  Widget _buildTodayTab(AppLocalizations l10n) {
    final trip = _bootstrap?.homeTrip;

    if (trip == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flight_takeoff_rounded,
                color: AppTheme.secondaryText,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noActiveTrips,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.upcomingTripsHere,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Trip hero card
            TripHeroCard(trip: trip, l10n: l10n),
            const SizedBox(height: 20),
            // Next up card
            if (trip.nextPickup != null) ...[
              NextUpCard(
                pickup: trip.nextPickup!,
                l10n: l10n,
                onRateDriver: (d) => _rateDriver(d, l10n),
                bookingReference: trip.reference,
                tripTitle: trip.destination,
                customerName: _bootstrap?.customerName,
                customerPhoto: _bootstrap?.avatarUrl,
                customerId: _bootstrap?.customerId,
                tripId: trip.id,
              ),
              if (trip.nextPickup!.driver != null) ...[
                const SizedBox(height: 14),
                TrackYourDriverCard(pickup: trip.nextPickup!, l10n: l10n),
              ],
              const SizedBox(height: 20),
            ],
            // Arrival flight
            if (FlightVisibility.isArrivalVisible(trip.arrivalFlight)) ...[
              FlightCard(
                title: l10n.arrivalFlight,
                flight: trip.arrivalFlight!,
                isArrival: true,
              ),
              const SizedBox(height: 14),
            ],
            // Departure flight
            if (FlightVisibility.isDepartureVisible(trip.departureFlight)) ...[
              FlightCard(
                title: l10n.departureFlightTitle,
                flight: trip.departureFlight!,
                isArrival: false,
              ),
              const SizedBox(height: 20),
            ],
            // Current hotel
            if (trip.currentHotel != null) ...[
              CurrentHotelCard(
                hotel: trip.currentHotel!,
                l10n: l10n,
                onRate: () => _rateHotel(trip.currentHotel!, l10n),
                onOpenDetails: () => _openHotelDetails(
                  name: trip.currentHotel!.name,
                  phone: trip.currentHotel!.phone,
                  googleMapUrl: trip.currentHotel!.googleMapUrl,
                ),
              ),
              const SizedBox(height: 28),
            ],
            // Today's Plan section
            TodaysPlanCard(
              trip: trip,
              dateText: trip.today.isNotEmpty
                  ? trip.today
                  : _formattedDate(l10n),
              l10n: l10n,
              onHotelTap: trip.currentHotel == null
                  ? null
                  : () => _openHotelDetails(
                      name: trip.currentHotel!.name,
                      phone: trip.currentHotel!.phone,
                      googleMapUrl: trip.currentHotel!.googleMapUrl,
                    ),
            ),
            const SizedBox(height: 20),
            // Customer SIM delivery (only when booking has SIM/eSIM)
            _buildSimSection(trip, l10n),
            // Tomorrow card
            if (trip.tomorrow.isNotEmpty) ...[
              TomorrowPreviewCard(
                items: trip.tomorrow,
                tomorrowDate: trip.tomorrowDate,
                l10n: l10n,
              ),
            ],
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTripTab(AppLocalizations l10n) {
    // One list with every booking (past, current, future). Today/Home keep
    // using the active trip only.
    return CustomerMyTripsList(
      key: ValueKey('my-trips-${_bootstrap?.homeTrip?.id ?? 0}'),
      fallbackTrip: _bootstrap?.homeTrip,
      l10n: l10n,
    );
  }

  Widget _buildTripFlightCard(FlightModel f, AppLocalizations l10n) {
    final isArrival = f.direction == 'arrival';
    final isDeparture = f.direction == 'departure';
    final dirLabel = isArrival
        ? l10n.arrivalLabel
        : (isDeparture ? l10n.departureLabel : l10n.flightLabel);
    final dateTime = [
      if ((f.date ?? '').isNotEmpty) f.date!,
      if ((f.time ?? '').isNotEmpty) f.time!,
    ].join(' ');
    return _InfoCard(
      children: [
        _InfoRow(label: l10n.flightLabel, value: dirLabel),
        if (f.airline.isNotEmpty)
          _InfoRow(label: l10n.airline, value: f.airline),
        if (f.flightNumber.isNotEmpty)
          _InfoRow(label: l10n.flightLabel, value: f.flightNumber),
        if (dateTime.isNotEmpty)
          _InfoRow(
            label: isArrival ? l10n.arrival : l10n.departure,
            value: dateTime,
          ),
        if ((f.airport ?? '').isNotEmpty)
          _InfoRow(label: l10n.airport, value: f.airport!),
      ],
    );
  }

  Widget _buildTripHotelCard(HotelModel h, AppLocalizations l10n) {
    return _InfoCard(
      children: [
        _InfoRow(
          label: l10n.hotel,
          value: h.name,
          onTap: () => _openHotelDetails(
            name: h.name,
            phone: h.phone ?? '',
            googleMapUrl: h.googleMapUrl ?? '',
          ),
        ),
        if (h.location.isNotEmpty)
          _InfoRow(label: l10n.location, value: h.location),
        if (h.checkIn.isNotEmpty)
          _InfoRow(label: l10n.checkIn, value: h.checkIn),
        if (h.checkOut.isNotEmpty)
          _InfoRow(label: l10n.checkOut, value: h.checkOut),
        if (h.nights > 0) _InfoRow(label: l10n.nights, value: '${h.nights}'),
        if (h.roomType != null) _InfoRow(label: l10n.room, value: h.roomType!),
      ],
    );
  }

  Widget _buildTripTransportCard(
    TransportationSegmentModel s,
    AppLocalizations l10n,
  ) {
    final timeRange = [
      if (s.pickupTime.isNotEmpty) s.pickupTime,
      if ((s.endTime ?? '').isNotEmpty) s.endTime!,
    ].join(' – ');
    final title = (s.title ?? s.notes ?? '');
    return _InfoCard(
      children: [
        if (title.isNotEmpty)
          _InfoRow(label: l10n.transportationLabel, value: title),
        if (s.date.isNotEmpty)
          _InfoRow(label: l10n.transportDateLabel, value: s.date),
        if (timeRange.isNotEmpty)
          _InfoRow(label: l10n.transportTimeLabel, value: timeRange),
        if ((s.city ?? '').isNotEmpty)
          _InfoRow(label: l10n.transportCityLabel, value: s.city!),
        if (s.pickupLocation.isNotEmpty)
          _InfoRow(label: l10n.pickup, value: s.pickupLocation),
        if (s.dropoffLocation.isNotEmpty)
          _InfoRow(label: l10n.destination, value: s.dropoffLocation),
        if (s.status.isNotEmpty)
          _InfoRow(label: l10n.transportStatusLabel, value: s.status),
      ],
    );
  }

  String _serviceQtyText(ExtraServiceModel s) {
    final qty = s.quantity;
    if (qty <= 0) return '';
    if (qty == 1 && !s.isSimCard) return '';
    return 'x$qty';
  }

  Widget _buildServicesTab(AppLocalizations l10n) {
    final trip = _bootstrap?.activeTrip;
    final services = trip?.extraServices ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: l10n.extraServices),
          const SizedBox(height: 12),
          if (services.isEmpty)
            _buildEmptyState(l10n.noExtraServices)
          else
            ...services.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.softGoldBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          s.isFlowers
                              ? Icons.local_florist_outlined
                              : s.isSimCard
                              ? Icons.sim_card_outlined
                              : Icons.star_outline_rounded,
                          color: AppTheme.luxuryAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (s.deliveryDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  s.deliveryDate!,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (s.description != null)
                              Text(
                                s.description!,
                                style: GoogleFonts.inter(
                                  color: AppTheme.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_serviceQtyText(s).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.softGoldBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _serviceQtyText(s),
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
              ),
            ),
        ],
      ),
    );
  }

  static const String _supportEmail = 'support@tour-operations.net';

  Widget _buildSupportTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: l10n.supportTitle),
          const SizedBox(height: 16),
          _SupportItem(
            icon: Icons.phone_outlined,
            title: l10n.callUs,
            subtitle: SupportContactActions.callNumber,
            onTap: () => SupportContactActions.call(context),
          ),
          const SizedBox(height: 12),
          _SupportItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: l10n.whatsapp,
            subtitle: l10n.chatWithTeam,
            onTap: () => SupportContactActions.whatsapp(context),
          ),
          const SizedBox(height: 12),
          _SupportItem(
            icon: Icons.email_outlined,
            title: l10n.email,
            subtitle: _supportEmail,
            onTap: () => SupportContactActions.email(context, _supportEmail),
          ),
          const SizedBox(height: 12),
          _SupportItem(
            icon: Icons.help_outline_rounded,
            title: l10n.faq,
            subtitle: l10n.faqSubtitle,
            onTap: () {},
          ),
          const SizedBox(height: 28),
          const ManagementTeamSection(),
        ],
      ),
    );
  }

  Widget _buildProfileTab(AppLocalizations l10n) {
    final customer = _bootstrap;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.brandNavy,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.luxuryAccent, width: 2),
            ),
            child: Center(
              child: Text(
                customer?.firstName.isNotEmpty == true
                    ? customer!.firstName[0].toUpperCase()
                    : 'T',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            (customer?.customerName.isNotEmpty ?? false)
                ? customer!.customerName
                : l10n.traveler,
            style: GoogleFonts.inter(
              color: AppTheme.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (customer?.customerPhone?.isNotEmpty ?? false)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                customer!.customerPhone!,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 14,
                ),
              ),
            ),
          if (customer?.customerEmail?.isNotEmpty ?? false)
            Text(
              customer!.customerEmail!,
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 32),
          _SupportItem(
            icon: Icons.language_outlined,
            title: l10n.chooseYourLanguage,
            subtitle: _currentLanguageLabel(),
            onTap: () => LanguagePickerSheet.show(context, role: 'customer'),
          ),
          const SizedBox(height: 12),
          _SupportItem(
            icon: Icons.logout_rounded,
            title: l10n.signOut,
            subtitle: '',
            onTap: () => _confirmSignOut(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
          const SizedBox(height: 16),
          Text(
            _error ?? l10n.failedToLoad,
            style: GoogleFonts.inter(color: AppTheme.primaryText, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadData, child: Text(l10n.retry)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: GoogleFonts.inter(color: AppTheme.secondaryText, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n, bool isRTL) {
    final items = [
      _NavItem(
        icon: Icons.today_outlined,
        activeIcon: Icons.today_rounded,
        label: l10n.today,
      ),
      _NavItem(
        icon: Icons.luggage_outlined,
        activeIcon: Icons.luggage_rounded,
        label: l10n.myTrip,
      ),
      _NavItem(
        icon: Icons.room_service_outlined,
        activeIcon: Icons.room_service_rounded,
        label: l10n.services,
      ),
      _NavItem(
        icon: Icons.headset_mic_outlined,
        activeIcon: Icons.headset_mic_rounded,
        label: l10n.support,
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: l10n.profile,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        border: Border(top: BorderSide(color: AppTheme.borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isActive = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 24,
                        color: isActive
                            ? AppTheme.luxuryAccent
                            : AppTheme.secondaryText,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? AppTheme.luxuryAccent
                              : AppTheme.secondaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 20 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.luxuryAccent,
                          borderRadius: BorderRadius.circular(2),
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

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ─── Shared helper widgets ────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: AppTheme.primaryText,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _InfoRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  color: onTap != null
                      ? AppTheme.luxuryAccent
                      : AppTheme.primaryText,
                  fontSize: 13,
                  fontWeight: onTap != null ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SupportItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.softSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.navyText, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.secondaryText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
