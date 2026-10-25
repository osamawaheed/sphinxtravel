import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/driver_tracking_model.dart';
import './api_client.dart';

/// Result of a driver-side tracking call.
enum TrackingCallResult {
  ok,

  /// Backend endpoint not available yet (404 / 405 / 501).
  backendUnavailable,

  /// Backend refused (outside the pickup window, not assigned, ...).
  rejected,

  /// Network / unexpected error.
  failed,
}

/// Tracking API.
///
/// IMPORTANT: Odoo 17 does NOT expose these endpoints yet. The paths below are
/// the PROPOSED contract handed to the Odoo developer (see the backend
/// requirements). Until they exist, every call degrades gracefully to
/// [TrackingCallResult.backendUnavailable] / null so the UI shows
/// "Location Unavailable" and never a fake location.
class DriverTrackingApi {
  final ApiClient _client;

  DriverTrackingApi([ApiClient? client]) : _client = client ?? ApiClient();

  static String customerPath(int segmentId) =>
      '/api/v1/customer/tracking/$segmentId';
  static String driverStartPath(int segmentId) =>
      '/api/v1/driver/tracking/$segmentId/start';
  static String driverStopPath(int segmentId) =>
      '/api/v1/driver/tracking/$segmentId/stop';
  static String driverLocationPath(int segmentId) =>
      '/api/v1/driver/tracking/$segmentId/location';

  static bool _isUnavailable(int? code) =>
      code == 404 || code == 405 || code == 501;

  /// Customer: current tracking snapshot. Returns null when the backend has
  /// no tracking (endpoint missing, not eligible, or no active session).
  Future<DriverTrackingSnapshot?> fetchSnapshot(int segmentId) async {
    try {
      final res = await _client.get(customerPath(segmentId));
      final data = res.data;
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      final inner = map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : map;
      return DriverTrackingSnapshot.fromJson(inner);
    } on DioException catch (e) {
      debugPrint(
        '[TRACKING] snapshot failed (${e.response?.statusCode ?? e.type.name})',
      );
      return null;
    } catch (_) {
      return null;
    }
  }

  TrackingCallResult _mapError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (_isUnavailable(code)) return TrackingCallResult.backendUnavailable;
      if (code == 400 || code == 403 || code == 409 || code == 422) {
        return TrackingCallResult.rejected;
      }
    }
    return TrackingCallResult.failed;
  }

  Future<TrackingCallResult> startSession(int segmentId) async {
    try {
      await _client.post(driverStartPath(segmentId), data: const {});
      return TrackingCallResult.ok;
    } catch (e) {
      return _mapError(e);
    }
  }

  Future<TrackingCallResult> stopSession(int segmentId) async {
    try {
      await _client.post(driverStopPath(segmentId), data: const {});
      return TrackingCallResult.ok;
    } catch (e) {
      return _mapError(e);
    }
  }

  Future<TrackingCallResult> postLocation(int segmentId, Position p) async {
    try {
      await _client.post(
        driverLocationPath(segmentId),
        data: {
          'latitude': p.latitude,
          'longitude': p.longitude,
          'accuracy': p.accuracy,
          'heading': p.heading,
          'speed': p.speed,
          'timestamp': p.timestamp.toUtc().toIso8601String(),
        },
      );
      return TrackingCallResult.ok;
    } catch (e) {
      return _mapError(e);
    }
  }
}

/// Outcome of asking the driver to start sharing.
enum StartSharingResult {
  started,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  backendUnavailable,
  rejected,
  failed,
}

/// Driver-side GPS sharing controller.
///
/// - Sharing only starts when the driver taps Start (never automatic).
/// - Real GPS only (geolocator position stream); no simulated coordinates.
/// - Android runs a foreground service so sharing continues in background;
///   iOS uses background location updates during the active session.
/// - Stops on [stop], on [reset] (logout) or when the backend rejects posts.
class DriverLocationSharingService extends ChangeNotifier {
  DriverLocationSharingService._();

  static final DriverLocationSharingService instance =
      DriverLocationSharingService._();

  DriverTrackingApi api = DriverTrackingApi();

  StreamSubscription<Position>? _sub;
  int? _segmentId;
  DateTime? _lastSentAt;
  DateTime? _lastFixAt;
  bool _starting = false;
  int _generation = 0;

  static const Duration _minSendGap = Duration(seconds: 8);

  bool get isSharing => _sub != null && _segmentId != null;
  int? get activeSegmentId => _segmentId;
  bool get isStarting => _starting;
  DateTime? get lastSentAt => _lastSentAt;
  DateTime? get lastFixAt => _lastFixAt;

  /// Background-capable location settings for an active pickup session.
  LocationSettings _settings({
    required String notificationTitle,
    required String notificationText,
  }) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          enableWakeLock: true,
        ),
      );
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  /// Requests permission (while-in-use first, then tries "always" on mobile).
  Future<StartSharingResult?> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return StartSharingResult.serviceDisabled;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return StartSharingResult.permissionDeniedForever;
    }
    if (perm == LocationPermission.denied) {
      return StartSharingResult.permissionDenied;
    }
    // Best effort upgrade to background ("always") permission on mobile.
    if (!kIsWeb &&
        perm == LocationPermission.whileInUse &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      perm = await Geolocator.requestPermission();
    }
    return null;
  }

  /// Starts sharing for [segmentId]. Must be triggered by the driver.
  Future<StartSharingResult> start({
    required int segmentId,
    required String notificationTitle,
    required String notificationText,
  }) async {
    if (_starting) return StartSharingResult.failed;
    if (isSharing && _segmentId == segmentId) return StartSharingResult.started;
    if (isSharing) await stop();

    _starting = true;
    final gen = _generation;
    notifyListeners();
    try {
      final permIssue = await _ensurePermission();
      if (permIssue != null) return permIssue;

      final res = await api.startSession(segmentId);
      if (gen != _generation) return StartSharingResult.failed;
      switch (res) {
        case TrackingCallResult.ok:
          break;
        case TrackingCallResult.backendUnavailable:
          return StartSharingResult.backendUnavailable;
        case TrackingCallResult.rejected:
          return StartSharingResult.rejected;
        case TrackingCallResult.failed:
          return StartSharingResult.failed;
      }

      _segmentId = segmentId;
      _lastSentAt = null;
      _lastFixAt = null;
      _sub =
          Geolocator.getPositionStream(
            locationSettings: _settings(
              notificationTitle: notificationTitle,
              notificationText: notificationText,
            ),
          ).listen(
            _onPosition,
            onError: (Object e) {
              debugPrint('[TRACKING] GPS stream error: $e');
            },
            cancelOnError: false,
          );
      return StartSharingResult.started;
    } catch (e) {
      debugPrint('[TRACKING] start failed: $e');
      return StartSharingResult.failed;
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> _onPosition(Position p) async {
    final seg = _segmentId;
    if (seg == null) return;
    _lastFixAt = DateTime.now();
    final last = _lastSentAt;
    if (last != null && DateTime.now().difference(last) < _minSendGap) {
      notifyListeners();
      return;
    }
    _lastSentAt = DateTime.now();
    final res = await api.postLocation(seg, p);
    if (res == TrackingCallResult.rejected && _segmentId == seg) {
      // Outside the pickup window / reassigned / completed: stop sharing.
      await stop(notifyBackend: false);
      return;
    }
    notifyListeners();
  }

  /// Stops sharing (driver tapped Stop, pickup completed, etc.).
  Future<void> stop({bool notifyBackend = true}) async {
    final seg = _segmentId;
    await _sub?.cancel();
    _sub = null;
    _segmentId = null;
    _lastSentAt = null;
    _lastFixAt = null;
    notifyListeners();
    if (notifyBackend && seg != null) {
      await api.stopSession(seg);
    }
  }

  /// Opens the OS settings so the driver can grant permission.
  Future<void> openSettings({bool location = false}) async {
    // Browsers have no OS settings screen to open.
    if (kIsWeb) return;
    try {
      if (location) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (e) {
      debugPrint('[TRACKING] openSettings failed: $e');
    }
  }

  /// Clears all account-specific state (logout).
  void reset() {
    _generation++;
    final sub = _sub;
    _sub = null;
    _segmentId = null;
    _lastSentAt = null;
    _lastFixAt = null;
    _starting = false;
    sub?.cancel();
    notifyListeners();
  }
}
