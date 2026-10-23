import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class DriverLocationPermissionScreen extends StatefulWidget {
  const DriverLocationPermissionScreen({super.key});

  @override
  State<DriverLocationPermissionScreen> createState() =>
      _DriverLocationPermissionScreenState();
}

class _DriverLocationPermissionScreenState
    extends State<DriverLocationPermissionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  _LocationState _locationState = _LocationState.initial;
  bool _isChecking = false;

  // Track whether we sent the user to Settings so we can re-check on return.
  bool _sentToSettings = false;
  bool _sentToLocationSettings = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[DRIVER ROUTE] DriverLocationPermissionScreen: initState — screen is now visible',
    );
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    // Check initial permission state to update UI only — NO auto-navigation.
    Future.microtask(() {
      if (mounted) _checkInitialPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Called automatically when the app resumes (e.g. user returns from Settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_sentToSettings || _sentToLocationSettings)) {
      debugPrint(
        '[DRIVER ROUTE] DriverLocationPermissionScreen: app resumed from Settings — re-checking permission state (UI update only)',
      );
      _sentToSettings = false;
      _sentToLocationSettings = false;
      // Update UI state only — do NOT auto-navigate.
      _checkInitialPermission();
    }
  }

  // ─── Permission Logic ──────────────────────────────────────────────────────

  /// Checks current permission state and updates UI only. Never navigates.
  Future<void> _checkInitialPermission() async {
    debugPrint(
      '[DRIVER ROUTE] DriverLocationPermissionScreen: _checkInitialPermission called (UI update only)',
    );
    if (kIsWeb) {
      // On web, stay at initial state — user must tap the button.
      return;
    }
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;

    debugPrint(
      '[DRIVER ROUTE] DriverLocationPermissionScreen: permission status=$status',
    );

    if (status.isGranted) {
      final serviceOn =
          await Permission.locationWhenInUse.serviceStatus.isEnabled;
      if (!mounted) return;
      debugPrint(
        '[DRIVER ROUTE] DriverLocationPermissionScreen: permission granted, locationServicesEnabled=$serviceOn',
      );
      if (serviceOn) {
        // Permission already granted and services on — show granted state but
        // do NOT navigate. Driver must still tap the button.
        debugPrint(
          '[DRIVER ROUTE] DriverLocationPermissionScreen: permission+services OK — staying on screen, waiting for user tap',
        );
        setState(() => _locationState = _LocationState.granted);
      } else {
        debugPrint(
          '[DRIVER ROUTE] DriverLocationPermissionScreen: location services OFF — showing servicesDisabled state',
        );
        setState(() => _locationState = _LocationState.servicesDisabled);
      }
    } else if (status.isPermanentlyDenied) {
      debugPrint(
        '[DRIVER ROUTE] DriverLocationPermissionScreen: permission permanently denied — showing permanentlyDenied state',
      );
      setState(() => _locationState = _LocationState.permanentlyDenied);
    } else {
      debugPrint(
        '[DRIVER ROUTE] DriverLocationPermissionScreen: permission not yet granted (status=$status) — waiting for user action',
      );
      // Stay at initial state — user hasn't been asked yet.
    }
    // No navigation here under any circumstance.
  }

  Future<void> _requestPermission() async {
    debugPrint(
      '[DRIVER ROUTE] DriverLocationPermissionScreen: _requestPermission called',
    );
    if (kIsWeb) {
      debugPrint(
        '[DRIVER ROUTE] DriverLocationPermissionScreen: web platform — proceeding to DriverHome',
      );
      _proceedToDriverHome();
      return;
    }
    setState(() => _isChecking = true);
    try {
      // If already granted (state == granted), just verify services and proceed.
      if (_locationState == _LocationState.granted) {
        final serviceOn =
            await Permission.locationWhenInUse.serviceStatus.isEnabled;
        if (!mounted) return;
        if (serviceOn) {
          debugPrint(
            '[DRIVER ROUTE] DriverLocationPermissionScreen: already granted + services on → DriverHome',
          );
          _proceedToDriverHome();
        } else {
          setState(() => _locationState = _LocationState.servicesDisabled);
        }
        return;
      }

      // First check if location services are enabled.
      final serviceOn =
          await Permission.locationWhenInUse.serviceStatus.isEnabled;
      if (!mounted) return;
      debugPrint(
        '[DRIVER ROUTE] DriverLocationPermissionScreen: _requestPermission — locationServicesEnabled=$serviceOn',
      );
      if (!serviceOn) {
        setState(() {
          _locationState = _LocationState.servicesDisabled;
          _isChecking = false;
        });
        return;
      }

      final status = await Permission.locationWhenInUse.request();
      if (!mounted) return;

      debugPrint(
        '[DRIVER ROUTE] DriverLocationPermissionScreen: _requestPermission — result status=$status',
      );

      if (status.isGranted) {
        debugPrint(
          '[DRIVER ROUTE] DriverLocationPermissionScreen: permission granted → proceeding to DriverHome',
        );
        setState(() => _locationState = _LocationState.granted);
        await Future.delayed(const Duration(milliseconds: 500));
        _proceedToDriverHome();
      } else if (status.isPermanentlyDenied) {
        debugPrint(
          '[DRIVER ROUTE] DriverLocationPermissionScreen: permanently denied → showing Open Settings',
        );
        setState(() => _locationState = _LocationState.permanentlyDenied);
      } else {
        debugPrint(
          '[DRIVER ROUTE] DriverLocationPermissionScreen: denied → showing retry state',
        );
        setState(() => _locationState = _LocationState.denied);
      }
    } catch (e) {
      debugPrint(
        '[DRIVER ROUTE] DriverLocationPermissionScreen: _requestPermission error ($e) — proceeding to DriverHome',
      );
      // On simulator / unexpected error, proceed.
      _proceedToDriverHome();
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _openAppSettings() async {
    debugPrint(
      '[DRIVER ROUTE] DriverLocationPermissionScreen: opening app settings',
    );
    if (!kIsWeb) {
      _sentToSettings = true;
      await openAppSettings();
    }
  }

  Future<void> _openLocationSettings() async {
    debugPrint(
      '[DRIVER ROUTE] DriverLocationPermissionScreen: opening device location settings',
    );
    if (kIsWeb) return;
    _sentToLocationSettings = true;
    try {
      const platform = MethodChannel('com.sphinxtravel/location_settings');
      await platform.invokeMethod('openLocationSettings');
    } catch (_) {
      // Fallback: open app settings which also lets user enable location.
      await openAppSettings();
    }
  }

  void _proceedToDriverHome() {
    debugPrint(
      '[DRIVER ROUTE] DriverLocationPermissionScreen: _proceedToDriverHome → navigating to driverHome',
    );
    if (mounted) context.go(AppRoutes.driverHome);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  _buildHeroSection(l10n),
                  const SizedBox(height: 40),
                  _buildFeaturesCard(l10n),
                  const SizedBox(height: 32),
                  if (_locationState != _LocationState.initial &&
                      _locationState != _LocationState.granted)
                    _buildStatusBanner(l10n),
                  if (_locationState != _LocationState.initial &&
                      _locationState != _LocationState.granted)
                    const SizedBox(height: 20),
                  _buildPrimaryButton(l10n),
                  if (_locationState == _LocationState.denied)
                    _buildRetryNote(l10n),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHeroSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppTheme.brandNavy,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandNavy.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.enableLocation,
          style: GoogleFonts.inter(
            color: AppTheme.primaryText,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.locationPermissionBody,
          style: GoogleFonts.inter(
            color: AppTheme.secondaryText,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ─── Features Card ─────────────────────────────────────────────────────────

  Widget _buildFeaturesCard(AppLocalizations l10n) {
    final features = [
      (Icons.directions_car_rounded, l10n.locationFeatureTrips),
      (Icons.navigation_rounded, l10n.locationFeatureNavigation),
      (Icons.place_rounded, l10n.locationFeaturePickup),
      (Icons.person_pin_circle_rounded, l10n.locationFeatureTracking),
      (Icons.route_rounded, l10n.locationFeatureLiveOps),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: features.asMap().entries.map((entry) {
          final i = entry.key;
          final feature = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < features.length - 1 ? 16 : 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.softGoldBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    feature.$1,
                    color: AppTheme.luxuryAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    feature.$2,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Status Banner ─────────────────────────────────────────────────────────

  Widget _buildStatusBanner(AppLocalizations l10n) {
    String message;
    IconData icon;

    switch (_locationState) {
      case _LocationState.denied:
        message = l10n.locationDeniedMessage;
        icon = Icons.warning_amber_rounded;
        break;
      case _LocationState.permanentlyDenied:
        message = l10n.locationPermanentlyDenied;
        icon = Icons.block_rounded;
        break;
      case _LocationState.servicesDisabled:
        message = l10n.locationServicesDisabled;
        icon = Icons.location_disabled_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppTheme.errorRed,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Primary Button ────────────────────────────────────────────────────────

  Widget _buildPrimaryButton(AppLocalizations l10n) {
    final bool goToSettings =
        _locationState == _LocationState.permanentlyDenied;
    final bool openLocationSettings =
        _locationState == _LocationState.servicesDisabled;

    final String label;
    final IconData btnIcon;

    if (goToSettings) {
      label = l10n.openSettings;
      btnIcon = Icons.settings_rounded;
    } else if (openLocationSettings) {
      label = l10n.openLocationSettings;
      btnIcon = Icons.location_searching_rounded;
    } else {
      label = l10n.enableLocation;
      btnIcon = Icons.location_on_rounded;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isChecking
            ? null
            : () {
                if (goToSettings || openLocationSettings) {
                  if (goToSettings) {
                    _openAppSettings();
                  } else {
                    _openLocationSettings();
                  }
                } else {
                  _requestPermission();
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.brandNavy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.brandNavy.withAlpha(100),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isChecking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(btnIcon, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Retry Note ────────────────────────────────────────────────────────────

  Widget _buildRetryNote(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: TextButton(
          onPressed: _isChecking ? null : _requestPermission,
          child: Text(
            l10n.retry,
            style: GoogleFonts.inter(
              color: AppTheme.navyText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

enum _LocationState {
  initial,
  granted,
  denied,
  permanentlyDenied,
  servicesDisabled,
}
