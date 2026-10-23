import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/driver_tracking_model.dart';
import '../../../models/transportation_segment_model.dart';
import '../../../services/driver_tracking_service.dart';
import '../../../services/flight_visibility.dart';
import '../../../theme/app_theme.dart';

/// Start/Stop Location Sharing controls for the driver.
///
/// Sharing is available only for the driver's own pickup segment, from
/// 30 minutes before the Odoo pickup time until the pickup is completed.
/// The driver must start sharing manually. Sharing is stopped automatically
/// when the segment completes, changes, or the window is no longer valid.
class DriverLocationSharingCard extends StatefulWidget {
  final TransportationSegmentModel segment;
  final int driverId;
  final AppLocalizations l10n;

  const DriverLocationSharingCard({
    super.key,
    required this.segment,
    required this.driverId,
    required this.l10n,
  });

  @override
  State<DriverLocationSharingCard> createState() =>
      _DriverLocationSharingCardState();
}

class _DriverLocationSharingCardState extends State<DriverLocationSharingCard> {
  final DriverLocationSharingService _svc =
      DriverLocationSharingService.instance;

  AppLocalizations get l10n => widget.l10n;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceWindow());
  }

  @override
  void didUpdateWidget(covariant DriverLocationSharingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceWindow());
  }

  @override
  void dispose() {
    _svc.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  DateTime? get _pickupAt {
    final s = widget.segment;
    final date = FlightVisibility.parseDate(s.date);
    final m = RegExp(
      r'(\d{1,2})[:.](\d{2})\s*(AM|PM|am|pm)?',
    ).firstMatch(s.pickupTime.trim());
    if (date == null || m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ap = m.group(3)?.toLowerCase();
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    if (h > 23 || min > 59) return null;
    return DateTime(date.year, date.month, date.day, h, min);
  }

  bool get _eligible {
    final w = PickupTrackingWindow(
      segmentId: widget.segment.id,
      driverId: widget.driverId,
      pickupAt: _pickupAt,
      completed: widget.segment.isCompleted,
    );
    return w.isEligibleAt(DateTime.now());
  }

  bool get _isThisSegmentSharing =>
      _svc.isSharing && _svc.activeSegmentId == widget.segment.id;

  /// Never keep tracking outside the pickup period / for another segment.
  void _enforceWindow() {
    if (!mounted) return;
    if (_svc.isSharing &&
        (_svc.activeSegmentId != widget.segment.id || !_eligible)) {
      _svc.stop();
    }
  }

  void _toast(String msg) {
    Fluttertoast.showToast(msg: msg, toastLength: Toast.LENGTH_LONG);
  }

  Future<void> _start() async {
    final res = await _svc.start(
      segmentId: widget.segment.id,
      notificationTitle: l10n.sharingBackgroundTitle,
      notificationText: l10n.sharingBackgroundText,
    );
    if (!mounted) return;
    switch (res) {
      case StartSharingResult.started:
        break;
      case StartSharingResult.permissionDenied:
        _toast(l10n.sharingPermissionDenied);
        break;
      case StartSharingResult.permissionDeniedForever:
        _toast(l10n.sharingPermissionDenied);
        await _svc.openSettings();
        break;
      case StartSharingResult.serviceDisabled:
        _toast(l10n.sharingServiceDisabled);
        await _svc.openSettings(location: true);
        break;
      case StartSharingResult.backendUnavailable:
        _toast(l10n.sharingBackendUnavailable);
        break;
      case StartSharingResult.rejected:
        _toast(l10n.sharingRejected);
        break;
      case StartSharingResult.failed:
        _toast(l10n.sharingFailed);
        break;
    }
  }

  Future<void> _stop() => _svc.stop();

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDarkActive;
    final primary = dark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final secondary = dark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    final sharing = _isThisSegmentSharing;
    final eligible = _eligible;
    final busy = _svc.isStarting;
    final canStart = eligible && !sharing && !busy;

    // Nothing to show once the pickup is completed and we are not sharing.
    if (widget.segment.isCompleted && !sharing) {
      return const SizedBox.shrink();
    }

    final statusColor = sharing ? AppTheme.successGreen : secondary;
    final statusText = sharing
        ? l10n.sharingActive
        : (eligible ? l10n.sharingStopped : l10n.sharingNotYetAvailable);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: sharing
              ? AppTheme.successGreen.withAlpha(140)
              : AppTheme.luxuryAccent.withAlpha(dark ? 90 : 70),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.softGoldBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  sharing
                      ? Icons.location_on_rounded
                      : Icons.location_searching_rounded,
                  color: sharing
                      ? AppTheme.successGreen
                      : AppTheme.luxuryAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.shareLocationTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.shareLocationSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: secondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                sharing
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    color: sharing ? primary : secondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: sharing
                ? OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_circle_outlined, size: 20),
                    label: Text(
                      l10n.stopLocationSharing,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: canStart ? _start : null,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_outline, size: 20),
                    label: Text(
                      l10n.startLocationSharing,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.luxuryAccent,
                      foregroundColor: AppTheme.brandNavy,
                      disabledBackgroundColor: AppTheme.luxuryAccent.withAlpha(
                        70,
                      ),
                      disabledForegroundColor: dark
                          ? AppTheme.darkSecondaryText
                          : AppTheme.secondaryText,
                      elevation: 0,
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
}
