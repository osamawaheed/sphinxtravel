import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/customer_bootstrap_model.dart';
import '../models/driver_tracking_model.dart';
import './driver_tracking_service.dart';
import './flight_visibility.dart';

/// Customer-side tracking controller for one pickup.
///
/// - Eligibility starts 30 minutes before the Odoo pickup time.
/// - Polls the backend only while eligible (never outside the pickup period).
/// - If the assigned driver changes, the previous snapshot is discarded
///   immediately and tracking restarts for the new driver.
/// - Never fabricates a location: [location] is non-null only when the
///   backend returned real coordinates for the CURRENT driver.
class CustomerTrackingController extends ChangeNotifier {
  CustomerTrackingController({DriverTrackingApi? api})
    : _api = api ?? DriverTrackingApi();

  final DriverTrackingApi _api;

  static const Duration _pollEvery = Duration(seconds: 10);
  static const Duration _clockEvery = Duration(seconds: 20);
  static const Duration _staleAfter = Duration(minutes: 2);

  Timer? _poll;
  Timer? _clock;
  bool _disposed = false;
  bool _fetching = false;
  int _gen = 0;

  HomeNextPickup? _pickup;
  int _driverId = 0;
  int _segmentId = 0;
  DriverTrackingSnapshot? _snapshot;
  bool _driverChanged = false;

  DriverTrackingSnapshot? get snapshot => _snapshot;
  bool get driverChanged => _driverChanged;
  int get segmentId => _segmentId;
  HomeNextPickup? get pickup => _pickup;

  bool get isAirport {
    final t = (_pickup?.trackingInfo.segmentType ?? '').toLowerCase();
    return t.contains('airport') || t.contains('arrival');
  }

  /// Scheduled pickup date-time, only when Odoo data makes it resolvable.
  DateTime? get pickupAt {
    final p = _pickup;
    if (p == null) return null;
    final info = p.trackingInfo;
    final full = DateTime.tryParse(info.pickupDatetime);
    if (full != null) return full;
    final date = FlightVisibility.parseDate(info.date);
    final t = _parseTime(p.time);
    if (date == null || t == null) return null;
    return DateTime(date.year, date.month, date.day, t.$1, t.$2);
  }

  static (int, int)? _parseTime(String raw) {
    final m = RegExp(
      r'(\d{1,2})[:.](\d{2})\s*(AM|PM|am|pm)?',
    ).firstMatch(raw.trim());
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3)?.toLowerCase();
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    if (h > 23 || min > 59) return null;
    return (h, min);
  }

  bool get _completed {
    final s = (_pickup?.progressStatus ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-]+'),
      '_',
    );
    return s == 'completed' ||
        s == 'done' ||
        s == 'picked_up' ||
        s == 'passenger_picked_up' ||
        s == 'passenger_on_board' ||
        s == 'in_tour';
  }

  PickupTrackingWindow? get window {
    final p = _pickup;
    if (p == null) return null;
    return PickupTrackingWindow(
      segmentId: _segmentId,
      driverId: _driverId,
      pickupAt: pickupAt,
      completed: _completed,
      backendEligible: p.trackingInfo.trackingEligible,
      windowStart: DateTime.tryParse(p.trackingInfo.trackingWindowStart),
    );
  }

  bool get hasDriver => _driverId > 0;
  bool get locationVisible => _snapshot?.locationVisible ?? false;
  bool get eligible => window?.isEligibleAt(DateTime.now()) ?? false;

  TrackingState get state {
    if (!hasDriver) return TrackingState.notEligible;
    if (_completed) return TrackingState.ended;
    if (!eligible) return TrackingState.notEligible;
    final s = _snapshot;
    if (s == null) return TrackingState.waitingForDriver;
    if (s.isEnded) return TrackingState.ended;
    if (!s.isActive) return TrackingState.waitingForDriver;
    final loc = s.location;
    if (loc == null) return TrackingState.unavailable;
    if (DateTime.now().difference(loc.updatedAt) > _staleAfter) {
      return TrackingState.unavailable;
    }
    return TrackingState.live;
  }

  /// Real location only; null when GPS is inactive or stale.
  DriverLiveLocation? get location =>
      state == TrackingState.live ? _snapshot?.location : null;

  /// Feeds the latest bootstrap pickup. Safe to call on every rebuild.
  void update(HomeNextPickup? pickup) {
    final newDriver = pickup?.driver?.id ?? 0;
    final newSeg = pickup?.transportationId ?? 0;
    final driverSwitched = _driverId != 0 && newDriver != _driverId;
    final segmentSwitched = _segmentId != 0 && newSeg != _segmentId;

    _pickup = pickup;
    if (driverSwitched || segmentSwitched || newDriver == 0) {
      // Stop following the previous driver immediately.
      _gen++;
      _snapshot = null;
      _driverChanged = driverSwitched && newDriver != 0;
    }
    _driverId = newDriver;
    _segmentId = newSeg;
    _sync();
    _notify();
  }

  void _sync() {
    final shouldPoll = hasDriver && _segmentId > 0 && eligible && !_completed;
    if (shouldPoll && _poll == null) {
      _fetch();
      _poll = Timer.periodic(_pollEvery, (_) => _fetch());
    } else if (!shouldPoll && _poll != null) {
      _poll?.cancel();
      _poll = null;
      if (_completed) _snapshot = null;
    }
    // Light clock so "opens in" / "last update" text and the 30-minute
    // window re-evaluate without a network call.
    _clock ??= Timer.periodic(_clockEvery, (_) {
      _sync();
      _notify();
    });
  }

  Future<void> refreshNow() => _fetch();

  Future<void> _fetch() async {
    if (_fetching || _segmentId <= 0 || _driverId <= 0) return;
    _fetching = true;
    final gen = _gen;
    final seg = _segmentId;
    final drv = _driverId;
    try {
      final snap = await _api.fetchSnapshot(seg);
      // Ignore late responses for a previous driver / segment.
      if (_disposed || gen != _gen || seg != _segmentId || drv != _driverId) {
        return;
      }
      if (snap != null && snap.driverId != 0 && snap.driverId != drv) {
        // Backend still reports the old driver: do not show it.
        _snapshot = null;
      } else {
        _snapshot = snap;
      }
      _notify();
    } finally {
      _fetching = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }
}
