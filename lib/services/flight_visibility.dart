import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/customer_bootstrap_model.dart';

/// Date-based visibility rules for the Arrival / Departure flight cards on the
/// Home screens (Customer & Driver).
///
/// Rules (calendar days, destination-local time):
///  * Arrival   : visible until the end of the day AFTER the arrival date.
///  * Departure : visible from 00:00 the day BEFORE departure until the end of
///                the day AFTER the departure date.
///
/// These rules only affect the Home screens. Flight records are never removed
/// and remain available in My Trip / Trip Details.
class FlightVisibility {
  FlightVisibility._();

  /// Georgia and Azerbaijan both use a fixed UTC+4 offset (no DST).
  static const Duration destinationOffset = Duration(hours: 4);

  static const Map<String, int> _months = {
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

  /// Current calendar date (time stripped) in the destination timezone.
  static DateTime destinationToday([DateTime? nowUtc]) {
    final shifted = (nowUtc ?? DateTime.now().toUtc()).add(destinationOffset);
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  /// Parses the date strings returned by Odoo into a date-only value.
  static DateTime? parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
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

  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Arrival card: shown through the end of (arrival date + 1 day).
  /// An unparseable date keeps the card visible (never hide on bad data).
  static bool isArrivalVisible(HomeFlight? flight, {DateTime? today}) {
    if (flight == null) return false;
    final date = parseDate(flight.date);
    if (date == null) return true;
    final now = today ?? destinationToday();
    // Hidden starting (arrival date + 2 days) at 00:00.
    return now.isBefore(_addDays(date, 2));
  }

  /// Departure card: shown from 00:00 of (departure date - 1 day) through the
  /// end of (departure date + 1 day).
  static bool isDepartureVisible(HomeFlight? flight, {DateTime? today}) {
    if (flight == null) return false;
    final date = parseDate(flight.date);
    if (date == null) return true;
    final now = today ?? destinationToday();
    final start = _addDays(date, -1);
    final hiddenFrom = _addDays(date, 2);
    return !now.isBefore(start) && now.isBefore(hiddenFrom);
  }
}

/// Mixin for Home screen states. Re-evaluates flight card visibility when the
/// app resumes from background and when the destination-local date changes.
/// Odoo data refreshes already call setState, which re-evaluates as well.
mixin FlightVisibilityRefresher<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  Timer? _flightDayTimer;
  DateTime _flightDay = FlightVisibility.destinationToday();

  void initFlightVisibility() {
    WidgetsBinding.instance.addObserver(this);
    _scheduleFlightDayTick();
  }

  void disposeFlightVisibility() {
    WidgetsBinding.instance.removeObserver(this);
    _flightDayTimer?.cancel();
  }

  void _recheckFlightDay() {
    final today = FlightVisibility.destinationToday();
    if (today != _flightDay) {
      _flightDay = today;
      if (mounted) setState(() {});
    }
  }

  void _scheduleFlightDayTick() {
    _flightDayTimer?.cancel();
    final local = DateTime.now().toUtc().add(
      FlightVisibility.destinationOffset,
    );
    final nextMidnight = DateTime(local.year, local.month, local.day + 1);
    var wait = nextMidnight.difference(local) + const Duration(seconds: 1);
    if (wait.isNegative) wait = const Duration(minutes: 1);
    _flightDayTimer = Timer(wait, () {
      _recheckFlightDay();
      _scheduleFlightDayTick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckFlightDay();
      _scheduleFlightDayTick();
      if (mounted) setState(() {});
    }
  }
}
