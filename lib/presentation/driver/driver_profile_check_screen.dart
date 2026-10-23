import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/mock_api_data_source.dart';
import '../../models/driver_bootstrap_model.dart';
import '../../services/api_client.dart';
import '../../services/driver_auth_service.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

/// Calls GET /api/v1/driver/bootstrap (Odoo is source of truth).
/// profile_completed == true  → proceed to Location Permission
/// profile_completed == false → proceed to Profile Completion
///
/// This screen is also the entry point after session restore so that
/// a driver who reinstalls or logs in on another device always gets
/// the correct state from Odoo — never from a local flag.
class DriverProfileCheckScreen extends StatefulWidget {
  const DriverProfileCheckScreen({super.key});

  @override
  State<DriverProfileCheckScreen> createState() =>
      _DriverProfileCheckScreenState();
}

class _DriverProfileCheckScreenState extends State<DriverProfileCheckScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint(
      '[DRIVER ROUTE] DriverProfileCheckScreen: initState — calling bootstrap',
    );
    _checkProfileFromOdoo();
  }

  Future<void> _checkProfileFromOdoo() async {
    debugPrint(
      '[DRIVER ROUTE] DriverProfileCheckScreen: fetching bootstrap from Odoo...',
    );
    try {
      // Always fetch fresh from Odoo — never rely on a local flag.
      final DriverBootstrapModel bootstrap = MockApiDataSource.useMock
          ? await MockApiDataSource.getDriverBootstrap()
          : await DriverAuthService(ApiClient()).loadBootstrap();
      if (!mounted) return;

      debugPrint(
        '[DRIVER ROUTE] DriverProfileCheckScreen: bootstrap received — profile_completed=${bootstrap.profileCompleted}',
      );

      if (bootstrap.profileCompleted) {
        // Profile already complete in Odoo → go to location permission (NEVER directly to home).
        debugPrint(
          '[DRIVER ROUTE] DriverProfileCheckScreen: profile_completed=true → navigating to driverLocationPermission',
        );
        context.go(AppRoutes.driverLocationPermission);
      } else {
        // Profile not complete → driver must fill it in.
        debugPrint(
          '[DRIVER ROUTE] DriverProfileCheckScreen: profile_completed=false → navigating to driverProfileCompletion',
        );
        context.go(AppRoutes.driverProfileCompletion);
      }
    } catch (e) {
      debugPrint(
        '[DRIVER ROUTE] DriverProfileCheckScreen: bootstrap error ($e) → falling back to driverLocationPermission',
      );
      // On network error fall back to location permission so the driver
      // is not permanently blocked; the profile check will run again on
      // the next bootstrap call.
      if (mounted) context.go(AppRoutes.driverLocationPermission);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.brandNavy,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
