import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/mock_api_data_source.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/az_case.dart';
import '../../models/driver_bootstrap_model.dart';
import '../../models/customer_bootstrap_model.dart';
import '../../models/hotel_model.dart';
import '../../models/hotel_grouping.dart';
import '../../models/transportation_segment_model.dart';
import '../../models/trip_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/session_manager.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_api_service.dart';
import '../../services/driver_passkey_service.dart';
import '../../services/localization_service.dart';
import '../../services/flight_visibility.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_notification_source.dart';
import '../../services/customer_language_sync_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_network_image.dart';
import '../customer/widgets/flight_card.dart';
import '../customer/widgets/day_itinerary_card.dart' show TripHotelCard;
import '../customer/widgets/hotel_contact_actions.dart'
    show kItineraryActionButtonHeight;
import '../customer/widgets/language_picker_sheet.dart';
import '../customer/widgets/management_team_section.dart';
import '../customer/widgets/support_contact_actions.dart';
import '../customer/widgets/today_timeline_widget.dart';
import '../chat/chat_inbox_strings.dart';
import '../chat/driver_chats_view.dart';
import '../../services/chat/chat_inbox_service.dart';
import '../../services/chat/chat_unread_service.dart';
import '../../services/chat/chat_presence_service.dart';
import '../../widgets/unread_badge.dart';
import './widgets/driver_tomorrow_card.dart';
import './widgets/driver_customer_card.dart';
import './widgets/driver_corner_ribbon.dart';
import './widgets/driver_trip_hero_card.dart';
import './widgets/driver_location_sharing_card.dart';
import './wallet/driver_wallet_view.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with WidgetsBindingObserver, FlightVisibilityRefresher {
  int _selectedTab = 0;

  /// Support now lives inside Profile. When true, the (unchanged) Support
  /// page is shown in place of the Profile tab content.
  bool _showSupport = false;
  DriverBootstrapModel? _bootstrap;
  bool _isLoading = true;
  String? _errorMessage;

  DriverAuthService? _driverAuthService;

  List<DriverTripListItem> _myTrips = const [];
  bool _tripsLoading = false;
  String? _tripsError;

  /// Details of the driver's other assigned trips (GET /driver/trips/{id}),
  /// used only by the Tomorrow card.
  List<CustomerHomeTrip> _otherTripDetails = const [];

  /// Service ids with a delivery confirmation currently in flight.
  final Set<int> _confirmingServiceIds = <int>{};

  /// Service ids confirmed by Odoo in this session (guards duplicates until
  /// the refreshed bootstrap reports the Delivered status).
  final Set<int> _deliveredServiceIds = <int>{};

  @override
  void initState() {
    super.initState();
    if (!MockApiDataSource.useMock) {
      _driverAuthService = DriverAuthService(ApiClient());
    }
    _loadData();
    // Authenticated drivers read their own notifications (RLS-scoped).
    if (NotificationService.instance.source is! SupabaseNotificationSource) {
      NotificationService.instance.source = SupabaseNotificationSource(
        useLocalizedRpc: true,
      );
    }
    NotificationService.instance.refresh();
    // Sync the saved driver language to Supabase (no-op if already synced).
    DriverLanguageSyncService.instance.sync();
    if (!MockApiDataSource.useMock) _loadTrips();
    LocalizationService.instance.addListener(_onLocaleChanged);
    initFlightVisibility();
  }

  @override
  void dispose() {
    ChatUnreadService.instance.untrack('driver');
    disposeFlightVisibility();
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ChatUnreadService.instance.refresh('driver');
    }
  }

  /// Tracks only currently assigned (non-completed) bookings, so read-only
  /// history from earlier assignments / finished trips is never counted.
  void _trackDriverUnread(List<DriverTripListItem> trips) {
    final active = [
      for (final t in trips)
        if (!ChatInboxService.isTripCompleted(t)) t,
    ];
    ChatUnreadService.instance.track(
      role: 'driver',
      references: [for (final t in active) t.reference],
      bookingIds: {
        for (final t in active)
          if (t.id > 0) t.reference.trim(): t.id,
      },
    );
    _syncPresence(trips);
  }

  /// App-level presence for the signed-in driver. Unique key is
  /// `driver:<driverId>`; carries the currently assigned booking references
  /// so each customer resolves only THEIR assigned driver's status.
  void _syncPresence(List<DriverTripListItem> trips) {
    if (MockApiDataSource.useMock) {
      debugPrint('[presence] driver start skipped: USE_MOCK_API=true');
      return;
    }
    final id = _bootstrap?.driver.id ?? 0;
    if (id <= 0) {
      debugPrint(
        '[presence] driver start deferred: driverId=$id (bootstrap not loaded)',
      );
      return;
    }
    final active = [
      for (final t in trips)
        if (!ChatInboxService.isTripCompleted(t)) t,
    ];
    ChatPresenceService.instance.start(
      role: 'driver',
      userId: id,
      bookings: [for (final t in active) t.reference],
      bookingIds: [
        for (final t in active)
          if (t.id > 0) t.id,
      ],
    );
  }

  void _onLocaleChanged() {
    _loadData();
    if (!MockApiDataSource.useMock) _loadTrips();
    DriverLanguageSyncService.instance.sync();
  }

  String _currentLanguageLabel() {
    final code = LocalizationService.instance.currentLanguage;
    for (final lang in LocalizationService.driverLanguages) {
      if (lang['code'] == code) return '${lang['flag']} ${lang['label']}';
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

    setState(() => _signingOut = true);
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
    await SessionManager.signOut(fallbackRole: 'driver');
    if (navigator.canPop()) navigator.pop();
    router.go(AppRoutes.driverLogin);
  }

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
        // Trips may have finished loading before the bootstrap (driver id was
        // unknown then): start presence now that the id is available. Also
        // covers a driver with no trips yet (still Online, no bookings).
        _syncPresence(_myTrips);
        if (_myTrips.isNotEmpty) _loadOtherTripDetails(_myTrips);
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

  Future<void> _loadTrips() async {
    if (mounted) {
      setState(() {
        _tripsLoading = true;
        _tripsError = null;
      });
    }
    try {
      final trips = await DriverApiService(ApiClient()).loadTrips();
      if (mounted) {
        setState(() {
          _myTrips = trips;
          _tripsLoading = false;
          _tripsError = null;
        });
        _trackDriverUnread(trips);
        _loadOtherTripDetails(trips);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tripsLoading = false;
          _tripsError = ApiException.messageOf(e) ?? e.toString();
        });
      }
    }
  }

  /// Loads the detail (flight + transportation) of every assigned trip that
  /// could contribute to Tomorrow: not the active trip, not already finished.
  /// Uses the same Odoo endpoints as My Trips / Trip Overview.
  Future<void> _loadOtherTripDetails(List<DriverTripListItem> trips) async {
    final activeRef = _bootstrap?.homeTrip?.reference;
    final today = FlightVisibility.destinationToday();
    final candidates = trips.where((t) {
      if (t.id <= 0) return false;
      if (activeRef != null &&
          activeRef.isNotEmpty &&
          t.reference == activeRef) {
        return false;
      }
      final dep = FlightVisibility.parseDate(t.departureDate);
      return dep == null || !dep.isBefore(today);
    }).toList();
    if (candidates.isEmpty) {
      if (mounted && _otherTripDetails.isNotEmpty) {
        setState(() => _otherTripDetails = const []);
      }
      return;
    }
    final api = DriverApiService(ApiClient());
    final loaded = <CustomerHomeTrip>[];
    for (final t in candidates) {
      try {
        loaded.add(await api.loadTripDetail(t.id));
      } catch (_) {
        // Skip a trip whose detail cannot be loaded; Tomorrow stays accurate
        // for the trips that did load.
      }
    }
    if (mounted) setState(() => _otherTripDetails = loaded);
  }

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  Future<void> _onSimServiceTap(
    HomeExtraService service,
    CustomerHomeTrip home,
  ) async {
    if (service.isDelivered ||
        _deliveredServiceIds.contains(service.id) ||
        _confirmingServiceIds.contains(service.id)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              service.isFlowers
                  ? Icons.local_florist_outlined
                  : Icons.sim_card_outlined,
              color: AppTheme.luxuryAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                service.title,
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppTheme.darkPrimaryText
                      : AppTheme.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          service.isFlowers
              ? l10n.flowersDeliveryQuestion
              : l10n.esimDeliveryQuestion,
          style: GoogleFonts.inter(
            color: isDark ? AppTheme.darkSecondaryText : AppTheme.secondaryText,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancelAction,
              style: GoogleFonts.inter(
                color: isDark
                    ? AppTheme.darkSecondaryText
                    : AppTheme.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l10n.confirmDelivery,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (_confirmingServiceIds.contains(service.id)) return;

    setState(() => _confirmingServiceIds.add(service.id));
    try {
      if (!MockApiDataSource.useMock) {
        final payload = <String, dynamic>{
          'booking_id': home.id,
          'trip_reference': home.reference,
          'driver_id': _bootstrap?.driverId,
          'extra_service_id': service.id,
          'delivered_quantity': service.qty,
          'delivery_status': 'delivered',
          'delivered_at': DateTime.now().toUtc().toIso8601String(),
        };
        final result = await DriverApiService(
          ApiClient(),
        ).confirmSimDelivery(tripId: home.id, payload: payload);
        if (result['success'] != true) {
          throw Exception('Delivery not confirmed by Odoo');
        }
      }

      if (!mounted) return;
      setState(() => _deliveredServiceIds.add(service.id));
      // Re-sync with Odoo so the status reflects the backend state.
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.isFlowers
                ? l10n.flowersDeliveredSuccess
                : l10n.esimDeliveredSuccess,
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
            ApiException.messageOf(e) ?? l10n.esimDeliveryFailed,
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingServiceIds.remove(service.id));
    }
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
    final fullName = (_bootstrap?.driverName.trim().isNotEmpty ?? false)
        ? _bootstrap!.driverName.trim()
        : 'Driver';
    final firstNameRaw = (_bootstrap?.firstName ?? '').trim();
    final name = firstNameRaw.isNotEmpty ? firstNameRaw : fullName;
    final isAr = l10n.isRtlLocale;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final greetingText = l10n.helloWithName(name);
    final taglineText = l10n.headerSubtitle(isDriver: true);
    final dateLabel = l10n.formattedHeaderDate(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      color: isDark ? AppTheme.darkBackground : AppTheme.mainBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
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
                      color: textColor,
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
                      color: subColor,
                      fontSize: isAr ? 15.64 : 13.6,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Notification button — white rounded card with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.driverNotifications),
                child: Container(
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
              ),
              Positioned(
                top: -4,
                right: -4,
                child: AnimatedBuilder(
                  animation: NotificationService.instance,
                  builder: (context, _) {
                    final count = NotificationService.instance.unreadCount;
                    if (count <= 0) return const SizedBox.shrink();
                    return IgnorePointer(
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: AppTheme.luxuryAccent,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Center(
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
        return _buildWalletTab(l10n, isDark);
      case 3:
        return DriverChatsView(
          trips: _myTrips,
          tripsLoading: _tripsLoading,
          tripsError: _tripsError,
          onReloadTrips: _loadTrips,
          driverName: _bootstrap?.driverName.trim() ?? '',
          driverOdooId: _bootstrap?.driver.id ?? 0,
          driverPhotoUrl: _bootstrap?.driverPhotoUrl,
          isDark: isDark,
        );
      case 4:
        return _showSupport
            ? _buildSupportPage(l10n, isDark)
            : _buildProfileTab(l10n, isDark);
      default:
        return _buildTodayTab(l10n, isDark);
    }
  }

  // ─── Today Tab ─────────────────────────────────────────────────────────────

  Widget _buildTodayTab(AppLocalizations l10n, bool isDark) {
    if (_errorMessage != null) return _buildErrorState(l10n, isDark);

    final home = _bootstrap?.homeTrip;
    if (home == null) {
      return _buildEmptyState(l10n, isDark);
    }

    final cust = home.customer;
    final hasCustomer =
        cust != null &&
        (cust.name.trim().isNotEmpty ||
            cust.phone.trim().isNotEmpty ||
            cust.whatsapp.trim().isNotEmpty);

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Trip card
            DriverTripHeroCard(trip: home, l10n: l10n),
            const SizedBox(height: 20),
            // 1b. Live location sharing (own pickup segment only)
            if (_bootstrap?.nextToday != null &&
                (_bootstrap?.driver.id ?? 0) > 0) ...[
              DriverLocationSharingCard(
                segment: _bootstrap!.nextToday!,
                driverId: _bootstrap!.driver.id,
                l10n: l10n,
              ),
              const SizedBox(height: 20),
            ],
            // 2. Customer card
            if (hasCustomer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DriverCustomerCard(
                  customer: cust,
                  l10n: l10n,
                  bookingId: home.id,
                  bookingReference: home.reference,
                ),
              ),
              const SizedBox(height: 20),
            ],
            // 3. Flights
            if (FlightVisibility.isArrivalVisible(home.arrivalFlight)) ...[
              FlightCard(
                title: l10n.arrivalFlight,
                flight: home.arrivalFlight!,
                isArrival: true,
              ),
              const SizedBox(height: 14),
            ],
            if (FlightVisibility.isDepartureVisible(home.departureFlight)) ...[
              FlightCard(
                title: l10n.departureFlightTitle,
                flight: home.departureFlight!,
                isArrival: false,
              ),
              const SizedBox(height: 20),
            ],
            // 4. Today's Plan
            TodayTimelineWidget(
              items: home.todayPlan,
              dateText: home.today,
              l10n: l10n,
              driverMode: true,
              mySegmentIds: home.mySegmentIds,
              hotels: home.hotels,
              isItemTappable: (item) => home.mySegmentIds.contains(item.id),
              onItemTap: (item) {
                context.push(
                  AppRoutes.driverTripDetails,
                  extra: {'segmentId': item.id},
                );
              },
            ),
            const SizedBox(height: 28),
            // 5. Tomorrow (all trips assigned to this driver)
            Builder(
              builder: (_) {
                final destToday = FlightVisibility.destinationToday();
                final tomorrowDate = DateTime(
                  destToday.year,
                  destToday.month,
                  destToday.day + 1,
                );
                final entries = DriverTomorrowBuilder.build(
                  activeTripTomorrow: home.tomorrow,
                  assignedSegments: _bootstrap?.assignedSegments ?? const [],
                  activeTripReference: home.reference,
                  tomorrow: tomorrowDate,
                  otherTrips: _otherTripDetails,
                );
                return DriverTomorrowCard(
                  entries: entries,
                  tomorrow: tomorrowDate,
                  l10n: l10n,
                  mySegmentIds: home.mySegmentIds,
                  onItemTap: (segmentId) {
                    context.push(
                      AppRoutes.driverTripDetails,
                      extra: {'segmentId': segmentId},
                    );
                  },
                );
              },
            ),
            // 6. Services (confirmed SIM/eSIM leaves Today; it stays in My Trip)
            if (home.extraServices.any(
              (e) =>
                  !(e.isSimCard &&
                      (e.isSimConfirmed ||
                          _deliveredServiceIds.contains(e.id))),
            )) ...[
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.services,
                  style: GoogleFonts.inter(
                    color: isDark
                        ? AppTheme.darkPrimaryText
                        : AppTheme.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final e in home.extraServices.where(
                (e) =>
                    !(e.isSimCard &&
                        (e.isSimConfirmed ||
                            _deliveredServiceIds.contains(e.id))),
              )) ...[
                _HomeServiceRow(
                  service: e,
                  isDark: isDark,
                  l10n: l10n,
                  isDelivered:
                      e.isDelivered || _deliveredServiceIds.contains(e.id),
                  isConfirming: _confirmingServiceIds.contains(e.id),
                  onTap: e.isSimCard ? () => _onSimServiceTap(e, home) : null,
                ),
                const SizedBox(height: 10),
              ],
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
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showHotelBottomSheet(hotel),
          child: TripHotelCard(
            hotel: HomeStayHotel(
              id: hotel.id,
              name: hotel.name,
              city: hotel.location,
              checkIn: hotel.checkIn,
              checkOut: hotel.checkOut,
              phone: hotel.phone ?? '',
              googleMapUrl: hotel.googleMapUrl ?? '',
              rooms: HotelGrouping.roomsOf(hotel, trip.hotels),
            ),
            l10n: l10n,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showHotelBottomSheet(HotelModel hotel) {
    final l10n = AppLocalizations.of(context);
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
                            l10n.hotelDetailsTitle,
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
                            label: l10n.hotelName,
                            value: hotel.name,
                            textColor: textColor,
                            subColor: subColor,
                            border: border,
                          ),
                          const SizedBox(height: 12),
                          // Full Address
                          _BottomSheetDetailRow(
                            icon: Icons.location_on_rounded,
                            label: l10n.fullAddress,
                            value: hotel.address ?? l10n.addressNotAvailable,
                            textColor: textColor,
                            subColor: subColor,
                            border: border,
                          ),
                          const SizedBox(height: 12),
                          // Phone Number
                          _BottomSheetDetailRow(
                            icon: Icons.phone_rounded,
                            label: l10n.phoneNumber,
                            value:
                                (hotel.phone != null && hotel.phone!.isNotEmpty)
                                ? hotel.phone!
                                : l10n.notAvailable,
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
                          // Call Hotel + Maps buttons (one row)
                          Builder(
                            builder: (context) {
                              const gap = 10.0;
                              final hasHotelPhone =
                                  hotel.phone != null &&
                                  hotel.phone!.isNotEmpty;
                              Widget hotelBtn({
                                required IconData icon,
                                required String label,
                                required VoidCallback onTap,
                              }) {
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    height: kItineraryActionButtonHeight,
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: onTap,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(
                                          0,
                                          kItineraryActionButtonHeight,
                                        ),
                                        maximumSize: const Size(
                                          double.infinity,
                                          kItineraryActionButtonHeight,
                                        ),
                                        fixedSize: const Size.fromHeight(
                                          kItineraryActionButtonHeight,
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        side: const BorderSide(
                                          color: AppTheme.luxuryAccent,
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            icon,
                                            size: 13,
                                            color: AppTheme.luxuryAccent,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              label,
                                              maxLines: 1,
                                              softWrap: false,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: AppTheme.luxuryAccent,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return SizedBox(
                                width: double.infinity,
                                child: Row(
                                  children: [
                                    if (hasHotelPhone) ...[
                                      Expanded(
                                        child: hotelBtn(
                                          icon: Icons.call_rounded,
                                          label: l10n.callHotel,
                                          onTap: () async {
                                            final uri = Uri.parse(
                                              'tel:${hotel.phone}',
                                            );
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: gap),
                                    ],
                                    Expanded(
                                      child: hotelBtn(
                                        icon: Icons.map_outlined,
                                        label: l10n.hotelMapsShort,
                                        onTap: () async {
                                          final address =
                                              hotel.address ?? hotel.name;
                                          final encoded = Uri.encodeComponent(
                                            address,
                                          );
                                          final uri = Uri.parse(
                                            'https://www.google.com/maps/search/?api=1&query=$encoded',
                                          );
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

    final dateLabel = l10n.weekdayDayMonth(now);

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
          foregroundColor: AppTheme.navyText,
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

    Widget body;
    if (_tripsLoading && _myTrips.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.brandNavy,
            strokeWidth: 2,
          ),
        ),
      );
    } else if (_tripsError != null && _myTrips.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          children: [
            Text(
              _tripsError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: subColor, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTrips,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandNavy,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    } else if (_myTrips.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            l10n.noTripsAssigned,
            style: GoogleFonts.inter(color: subColor, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          for (final trip in _myTrips) ...[
            _DriverTripRow(
              trip: trip,
              isDark: isDark,
              onTap: () => context.push(
                AppRoutes.driverTripOverview,
                extra: {'tripId': trip.id},
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _loadTrips,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.myTripsTitle,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
    );
  }

  // ─── Wallet Tab ────────────────────────────────────────────────────────────

  Widget _buildWalletTab(AppLocalizations l10n, bool isDark) {
    return DriverWalletView(isDark: isDark);
  }

  // ignore: unused_element
  Widget _buildLegacyWalletTab(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.wallet,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.brandNavy,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandNavy.withAlpha(51),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AzCase.upper(l10n.walletBalance),
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(179),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '0.00',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.transactions,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: isDark ? null : AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, color: subColor, size: 32),
                const SizedBox(height: 10),
                Text(
                  l10n.noTransactionsYet,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: subColor, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Support Tab ───────────────────────────────────────────────────────────

  /// Existing Support content (unchanged) shown from Driver Profile with a
  /// back control that returns to the Profile tab.
  Widget _buildSupportPage(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showSupport = false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
            child: TextButton.icon(
              onPressed: () => setState(() => _showSupport = false),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: textColor,
              ),
              label: Text(
                l10n.profile,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(child: _buildSupportTab(l10n, isDark)),
        ],
      ),
    );
  }

  Widget _buildPasskeySettingTile(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final service = DriverPasskeyService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: service.enabledNotifier,
      builder: (context, enabled, _) {
        final available = service.isBackendAvailable;
        // Switch is interactive only to turn OFF an enabled Passkey, or to
        // turn ON when the backend can verify registration.
        final canToggle = enabled || available;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: isDark ? null : AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackground
                      : AppTheme.mainBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  color: isDark ? AppTheme.luxuryAccent : AppTheme.brandNavy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.passkeyLogin,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      available || enabled
                          ? l10n.passkeySubtitle
                          : l10n.passkeyComingSoon,
                      style: GoogleFonts.inter(color: subColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: canToggle
                    ? (value) async {
                        final messenger = ScaffoldMessenger.of(context);
                        if (value) {
                          final ok = await service.enable();
                          if (!ok) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(l10n.passkeyUnavailableYet),
                              ),
                            );
                          }
                        } else {
                          await service.disable();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(l10n.passkeyDisabledMessage),
                            ),
                          );
                        }
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSupportItem(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    return GestureDetector(
      onTap: () => setState(() => _showSupport = true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: isDark ? null : AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkBackground
                    : AppTheme.mainBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.headset_mic_outlined,
                color: isDark ? AppTheme.luxuryAccent : AppTheme.brandNavy,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.support,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subColor, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Support Tab (content reused by the Profile → Support page) ───────────

  static const String _supportEmail = 'info@sphinx-travel.com';

  Widget _buildSupportTab(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.supportTitle,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _DriverSupportItem(
            icon: Icons.phone_outlined,
            title: l10n.callUs,
            subtitle: SupportContactActions.callNumber,
            isDark: isDark,
            onTap: () => SupportContactActions.call(context),
          ),
          const SizedBox(height: 12),
          _DriverSupportItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: l10n.whatsapp,
            subtitle: l10n.chatWithTeam,
            isDark: isDark,
            onTap: () => SupportContactActions.whatsapp(context),
          ),
          const SizedBox(height: 12),
          _DriverSupportItem(
            icon: Icons.email_outlined,
            title: l10n.email,
            subtitle: _supportEmail,
            isDark: isDark,
            onTap: () => SupportContactActions.email(context, _supportEmail),
          ),
          const SizedBox(height: 12),
          _DriverSupportItem(
            icon: Icons.help_outline_rounded,
            title: l10n.faq,
            subtitle: l10n.faqSubtitle,
            isDark: isDark,
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.supportComingSoon)));
            },
          ),
          const SizedBox(height: 28),
          ManagementTeamSection(isDark: isDark),
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
          if (driver != null) ...[
            GestureDetector(
              onTap: () => context.push(AppRoutes.driverRatings),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            driver.driver.rating10.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: subColor,
                            size: 18,
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
                          Icon(
                            Icons.directions_car_rounded,
                            color: AppTheme.navyText,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${driver.driver.tripCount}',
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
            ),
          ],
          const SizedBox(height: 24),
          if (driver != null &&
              (driver.driver.phone.isNotEmpty ||
                  driver.driver.email.isNotEmpty)) ...[
            _InfoCard(
              isDark: isDark,
              children: [
                if (driver.driver.phone.isNotEmpty)
                  _InfoRow(
                    label: l10n.phoneLabel,
                    value: driver.driver.phone,
                    isDark: isDark,
                  ),
                if (driver.driver.email.isNotEmpty)
                  _InfoRow(
                    label: l10n.email,
                    value: driver.driver.email,
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (driver != null &&
              (driver.driver.vehicleModel.isNotEmpty ||
                  driver.driver.vehicleYear.isNotEmpty ||
                  driver.driver.vehicleColor.isNotEmpty)) ...[
            _InfoCard(
              isDark: isDark,
              children: [
                if (driver.driver.vehicleModel.isNotEmpty)
                  _InfoRow(
                    label: l10n.vehicleModelLabel,
                    value: driver.driver.vehicleModel,
                    isDark: isDark,
                  ),
                if (driver.driver.vehicleYear.isNotEmpty)
                  _InfoRow(
                    label: l10n.modelYear,
                    value: driver.driver.vehicleYear,
                    isDark: isDark,
                  ),
                if (driver.driver.vehicleColor.isNotEmpty)
                  _InfoRow(
                    label: l10n.color,
                    value: driver.driver.vehicleColor,
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (driver != null &&
              driver.driver.personalPhotos.any((u) => u.isNotEmpty)) ...[
            _PhotoThumbRow(
              title: l10n.personalPhotosLabel,
              urls: driver.driver.personalPhotos,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
          ],
          if (driver != null &&
              driver.driver.vehiclePhotos.any((u) => u.isNotEmpty)) ...[
            _PhotoThumbRow(
              title: l10n.vehiclePhotosLabel,
              urls: driver.driver.vehiclePhotos,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 8),
          GestureDetector(
            onTap: () => LanguagePickerSheet.show(
              context,
              role: 'driver',
              isDark: isDark,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
                boxShadow: isDark ? null : AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkBackground
                          : AppTheme.softSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.language_outlined,
                      color: isDark
                          ? AppTheme.luxuryAccent
                          : AppTheme.brandNavy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.chooseYourLanguage,
                          style: GoogleFonts.inter(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _currentLanguageLabel(),
                          style: GoogleFonts.inter(
                            color: subColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: subColor, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DriverThemeSelector(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
            child: Text(
              l10n.securitySectionTitle,
              style: GoogleFonts.inter(
                color: subColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          _buildPasskeySettingTile(l10n, isDark),
          const SizedBox(height: 16),
          _buildProfileSupportItem(l10n, isDark),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signingOut ? null : () => _confirmSignOut(l10n),
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
        'label': l10n.navToday,
      },
      {
        'icon': Icons.map_outlined,
        'activeIcon': Icons.map_rounded,
        'label': l10n.navMyTrips,
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'activeIcon': Icons.account_balance_wallet_rounded,
        'label': l10n.wallet,
      },
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'activeIcon': Icons.chat_bubble_rounded,
        'label': ChatInboxStrings(l10n.locale).navChat,
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
                  onTap: () => setState(() {
                    _selectedTab = i;
                    if (i != 4) _showSupport = false;
                    // Back on Today (or leaving Chat): re-count unread.
                    if (i == 0 || i == 3) {
                      ChatUnreadService.instance.refresh('driver');
                    }
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      i == 3
                          ? ValueListenableBuilder<int>(
                              valueListenable: ChatUnreadService.instance
                                  .countFor('driver'),
                              builder: (context, unread, child) =>
                                  UnreadBadge(count: unread, child: child!),
                              child: Icon(
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
                            )
                          : Icon(
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

// ─── Driver Support Item (matches Customer Support row) ───────────────────────

class _DriverSupportItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;
  const _DriverSupportItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final iconBg = isDark ? AppTheme.darkBackground : AppTheme.softSurface;
    final iconColor = isDark ? AppTheme.darkPrimaryText : AppTheme.navyText;
    final titleColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
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
          boxShadow: isDark ? null : AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(color: subColor, fontSize: 13),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Driver Trip Row (GET /api/v1/driver/trips item) ──────────────────────────

class _DriverTripRow extends StatelessWidget {
  final DriverTripListItem trip;
  final bool isDark;
  final VoidCallback onTap;

  const _DriverTripRow({
    required this.trip,
    required this.isDark,
    required this.onTap,
  });

  /// True from the calendar day after the departure date, in Georgia
  /// local time (Asia/Tbilisi, UTC+4, no DST).
  bool get _isEnded {
    final raw = trip.departureDate.trim();
    if (raw.isEmpty) return false;
    final m = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw);
    if (m == null) return false;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final nowTbilisi = DateTime.now().toUtc().add(const Duration(hours: 4));
    final today = DateTime.utc(
      nowTbilisi.year,
      nowTbilisi.month,
      nowTbilisi.day,
    );
    final endDay = DateTime.utc(y, mo, d).add(const Duration(days: 1));
    return !today.isBefore(endDay);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final place = [
      trip.city,
      trip.destination,
    ].where((e) => e.trim().isNotEmpty).join(', ');
    final dates = [
      trip.arrivalDate,
      trip.departureDate,
    ].where((e) => e.trim().isNotEmpty).join(' – ');

    final thumbFallback = Container(
      color: AppTheme.softGoldBg,
      child: Icon(Icons.image_outlined, color: AppTheme.secondaryText),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandNavy.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: AuthNetworkImage(
                        photoUrl: trip.imageUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        fallback: thumbFallback,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (trip.reference.isNotEmpty)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
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
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        if (place.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            place,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (dates.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            dates,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (trip.customerName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            trip.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: subColor),
                ],
              ),
            ),
            if (_isEnded)
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(
                  child: DriverCornerRibbon(label: l10n.tripEndedRibbon),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Driver Trip Row (GET /api/v1/driver/trips item) ──────────────────────────

class _HomeServiceRow extends StatelessWidget {
  final HomeExtraService service;
  final bool isDark;
  final AppLocalizations l10n;
  final bool isDelivered;
  final bool isConfirming;
  final VoidCallback? onTap;

  const _HomeServiceRow({
    required this.service,
    required this.isDark,
    required this.l10n,
    this.isDelivered = false,
    this.isConfirming = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final tappable = onTap != null && !isDelivered && !isConfirming;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: tappable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (tappable)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l10n.tapToConfirmDelivery,
                            style: GoogleFonts.inter(
                              color: AppTheme.luxuryAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isConfirming)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isDelivered && service.isSimCard)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.deliveredLabel,
                      style: GoogleFonts.inter(
                        color: AppTheme.successGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (service.qty > 0)
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
    // Main display: country (e.g. "Georgia"), no city row
    final mainCountry = countryPart.isNotEmpty ? countryPart : cityPart;

    final passengerCount = trip.passengerCount ?? 1;
    final guestLabel = l10n.guestCount(passengerCount);
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17.25,
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
                                l10n.tripDuration,
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
                                l10n.passengersLabel,
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

  Future<void> _openPhone(BuildContext context, String? phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final cleaned = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.customerPhoneUnavailable)),
      );
      return;
    }
    var launched = false;
    try {
      launched = await launchUrl(
        Uri(scheme: 'tel', path: cleaned),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.callFailed)));
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
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openPhone(context, customerPhone),
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
                          l10n.call,
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
                          l10n.whatsapp,
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
      return l10n.dayMonthYear(d);
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
                      l10n.arrivalFlightUnavailable,
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
      return l10n.dayMonth(d);
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
                            color: AppTheme.isDarkActive
                                ? AppTheme.darkSecondaryText
                                : const Color(0xFF6B5B3E),
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
                            l10n.checkInLabel,
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
                              l10n.checkOutLabel,
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
                        AppLocalizations.of(context).viewDetails,
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

    final tomorrowDateStr = l10n.shortMonthDay(tomorrow);
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
                                  ? l10n.checkInWithName(hotel!.name)
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
                            color: AppTheme.navyText,
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
                      foregroundColor: AppTheme.navyText,
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
              : [AppTheme.brandNavy, const Color(0xFF4A2A8A)],
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
                    color: AppTheme.navyText,
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
                AppLocalizations.of(context).appearance,
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
                label: AppLocalizations.of(context).themeSystem,
                selected: current == AppThemeMode.system,
                isDark: isDark,
                onTap: () =>
                    ThemeService.instance.setThemeMode(AppThemeMode.system),
              ),
              const SizedBox(width: 8),
              _ThemeOptionBtn(
                icon: Icons.wb_sunny_rounded,
                label: AppLocalizations.of(context).themeLight,
                selected: current == AppThemeMode.light,
                isDark: isDark,
                onTap: () =>
                    ThemeService.instance.setThemeMode(AppThemeMode.light),
              ),
              const SizedBox(width: 8),
              _ThemeOptionBtn(
                icon: Icons.nightlight_round,
                label: AppLocalizations.of(context).themeDark,
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
        : (isDark ? AppTheme.darkBackground : AppTheme.softSurface);
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
        boxShadow: isDark ? null : AppTheme.cardShadow,
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

class _PhotoThumbRow extends StatelessWidget {
  final String title;
  final List<String> urls;
  final bool isDark;

  const _PhotoThumbRow({
    required this.title,
    required this.urls,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final visible = urls.where((u) => u.trim().isNotEmpty).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: visible
                .map(
                  (u) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AuthNetworkImage(
                      photoUrl: u,
                      width: 72,
                      height: 72,
                      fallback: Container(
                        width: 72,
                        height: 72,
                        color: border,
                        child: Icon(
                          Icons.image_outlined,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
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
