import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../presentation/splash/splash_screen.dart';
import '../presentation/onboarding/user_type_selection_screen.dart';
import '../presentation/onboarding/language_selection_screen.dart';
import '../presentation/auth/customer_login_screen.dart';
import '../presentation/auth/customer_otp_screen.dart';
import '../presentation/auth/driver_login_screen.dart';
import '../presentation/customer/customer_home_screen.dart';
import '../presentation/driver/driver_home_screen.dart';
import '../presentation/driver/driver_location_permission_screen.dart';
import '../presentation/driver/driver_profile_check_screen.dart';
import '../presentation/driver/driver_profile_completion_screen.dart';
import '../presentation/driver/driver_trip_details_screen.dart';
import '../presentation/driver/driver_full_trip_screen.dart';
import '../presentation/driver/driver_trip_overview_screen.dart';
import '../presentation/driver/driver_ratings_screen.dart';
import '../models/trip_model.dart';
import '../models/driver_bootstrap_model.dart';
import '../models/driver_profile_model.dart';
import '../models/transportation_segment_model.dart';

class AppRoutes {
  static const String initial = '/';
  static const String splash1 = '/splash/1';
  static const String splash2 = '/splash/2';
  static const String splash3 = '/splash/3';
  static const String userTypeSelection = '/select-type';
  static const String customerLanguage = '/customer/language';
  static const String driverLanguage = '/driver/language';
  static const String customerLogin = '/customer/login';
  static const String customerOtp = '/customer/otp';
  static const String driverLogin = '/driver/login';
  static const String customerHome = '/customer/home';
  static const String driverHome = '/driver/home';
  static const String driverTripDetails = '/driver/trip-details';
  static const String driverFullTrip = '/driver/full-trip';
  static const String driverTripOverview = '/driver/trip-overview';
  static const String driverRatings = '/driver/ratings';

  // Driver onboarding routes
  static const String driverLocationPermission = '/driver/onboarding/location';
  static const String driverProfileCheck = '/driver/onboarding/profile-check';
  static const String driverProfileCompletion =
      '/driver/onboarding/profile-completion';

  // Cached session state — populated before router is used
  static bool _sessionChecked = false;
  static bool _hasValidSession = false;
  static String? _userRole;

  /// Call this once at app startup (before runApp) to pre-load session state.
  static Future<void> preloadSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('sphinx_access_token');
    _hasValidSession = token != null && token.isNotEmpty;
    _userRole = prefs.getString('sphinx_user_role');
    _sessionChecked = true;
  }

  /// Invalidate cache so next navigation re-reads from prefs.
  static Future<void> refreshSessionState() async {
    await preloadSessionState();
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  redirect: (context, state) {
    // If session state hasn't been preloaded yet, don't redirect
    if (!AppRoutes._sessionChecked) return null;

    final path = state.uri.path;

    if (AppRoutes._hasValidSession &&
        (path == '/' || path == AppRoutes.splash1)) {
      final role = AppRoutes._userRole;
      if (role == 'driver') {
        debugPrint(
          '[DRIVER ROUTE] GoRouter redirect: valid driver session at $path → redirecting to driverProfileCheck',
        );
        return AppRoutes.driverProfileCheck;
      }
      if (role == 'customer') return AppRoutes.customerHome;
    }
    return null;
  },
  routes: [
    // Root → Splash 1
    GoRoute(
      path: AppRoutes.initial,
      builder: (context, state) => const SplashScreen(splashIndex: 1),
    ),
    // Splash screens
    GoRoute(
      path: '/splash/:index',
      builder: (context, state) {
        final index = int.tryParse(state.pathParameters['index'] ?? '1') ?? 1;
        return SplashScreen(splashIndex: index);
      },
    ),
    // User type selection
    GoRoute(
      path: AppRoutes.userTypeSelection,
      builder: (context, state) => const UserTypeSelectionScreen(),
    ),
    // Customer language
    GoRoute(
      path: AppRoutes.customerLanguage,
      builder: (context, state) => const CustomerLanguageScreen(),
    ),
    // Driver language
    GoRoute(
      path: AppRoutes.driverLanguage,
      builder: (context, state) => const DriverLanguageScreen(),
    ),
    // Customer login
    GoRoute(
      path: AppRoutes.customerLogin,
      builder: (context, state) => const CustomerLoginScreen(),
    ),
    // Customer OTP
    GoRoute(
      path: AppRoutes.customerOtp,
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map) {
          return CustomerOtpScreen(
            phoneNumber: extra['phone'] as String? ?? '',
            requestId: extra['request_id'] as String? ?? '',
            expiresIn: (extra['expires_in'] as num?)?.toInt() ?? 120,
            debugOtp: extra['debug_otp'] as String?,
          );
        }
        final phone = extra as String? ?? '';
        return CustomerOtpScreen(phoneNumber: phone);
      },
    ),
    // Driver login
    GoRoute(
      path: AppRoutes.driverLogin,
      builder: (context, state) => const DriverLoginScreen(),
    ),
    // Customer home
    GoRoute(
      path: AppRoutes.customerHome,
      builder: (context, state) => const CustomerHomeScreen(),
    ),
    // Driver home
    GoRoute(
      path: AppRoutes.driverHome,
      builder: (context, state) => const DriverHomeScreen(),
    ),
    // Driver trip details
    GoRoute(
      path: AppRoutes.driverTripDetails,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final segmentId = extra?['segmentId'] as int? ?? 0;
        final segment = extra?['segment'] as TransportationSegmentModel?;
        return DriverTripDetailsScreen(
          segmentId: segmentId,
          initialSegment: segment,
        );
      },
    ),
    // Driver full trip
    GoRoute(
      path: AppRoutes.driverFullTrip,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final trip = extra?['trip'] as TripModel?;
        final bootstrap = extra?['bootstrap'] as DriverBootstrapModel?;
        if (trip == null) {
          return const DriverHomeScreen();
        }
        return DriverFullTripScreen(trip: trip, bootstrap: bootstrap);
      },
    ),
    // Driver trip overview (GET /api/v1/driver/trips/{id})
    GoRoute(
      path: AppRoutes.driverTripOverview,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final tripId = extra?['tripId'] as int? ?? 0;
        return DriverTripOverviewScreen(tripId: tripId);
      },
    ),
    // ─── Driver Onboarding ────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.driverRatings,
      builder: (context, state) => const DriverRatingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.driverLocationPermission,
      builder: (context, state) => const DriverLocationPermissionScreen(),
    ),
    GoRoute(
      path: AppRoutes.driverProfileCheck,
      builder: (context, state) => const DriverProfileCheckScreen(),
    ),
    GoRoute(
      path: AppRoutes.driverProfileCompletion,
      builder: (context, state) {
        final extra = state.extra;
        return DriverProfileCompletionScreen(
          initialDriver: extra is DriverProfile ? extra : null,
        );
      },
    ),
  ],
);
