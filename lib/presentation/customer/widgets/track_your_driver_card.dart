import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../models/driver_tracking_model.dart';
import '../../../services/customer_tracking_controller.dart';
import '../../../theme/app_theme.dart';

/// "Track Your Driver" card shown directly below the Pickup Driver card.
///
/// Live tracking is shown ONLY when the backend returns a real, fresh GPS
/// fix from the current driver. Otherwise the card shows the honest state
/// (not open yet / waiting / "Location Unavailable"). No location is ever
/// simulated.
class TrackYourDriverCard extends StatefulWidget {
  final HomeNextPickup pickup;
  final AppLocalizations l10n;

  const TrackYourDriverCard({
    super.key,
    required this.pickup,
    required this.l10n,
  });

  @override
  State<TrackYourDriverCard> createState() => _TrackYourDriverCardState();
}

class _TrackYourDriverCardState extends State<TrackYourDriverCard> {
  late final CustomerTrackingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = CustomerTrackingController()..update(widget.pickup);
  }

  @override
  void didUpdateWidget(covariant TrackYourDriverCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ctrl.update(widget.pickup);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  AppLocalizations get l10n => widget.l10n;

  Future<void> _openMaps(DriverLiveLocation loc) async {
    final p = widget.pickup;
    final dest = (p.pickupLat != null && p.pickupLng != null)
        ? '${p.pickupLat},${p.pickupLng}'
        : null;
    final uri = dest != null
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&origin=${loc.latitude},${loc.longitude}'
            '&destination=$dest&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1'
            '&query=${loc.latitude},${loc.longitude}',
          );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 10) return l10n.trackingJustNow;
    if (diff.inSeconds < 60) return l10n.trackingSecondsAgo(diff.inSeconds);
    return l10n.trackingMinutesAgo(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        if (!_ctrl.hasDriver) return const SizedBox.shrink();
        final dark = AppTheme.isDarkActive;
        final state = _ctrl.state;
        final loc = _ctrl.location;
        final eta = _ctrl.snapshot?.etaMinutes;

        final primary = dark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
        final secondary = dark
            ? AppTheme.darkSecondaryText
            : AppTheme.secondaryText;

        final (statusText, statusColor, statusIcon) = switch (state) {
          TrackingState.live => (
            l10n.trackingStatusLive,
            AppTheme.successGreen,
            Icons.radio_button_checked_rounded,
          ),
          TrackingState.waitingForDriver => (
            l10n.trackingStatusWaiting,
            AppTheme.luxuryAccent,
            Icons.hourglass_top_rounded,
          ),
          TrackingState.unavailable => (
            l10n.locationUnavailable,
            AppTheme.errorRed,
            Icons.location_off_rounded,
          ),
          TrackingState.ended => (
            l10n.trackingStatusEnded,
            secondary,
            Icons.check_circle_outline_rounded,
          ),
          TrackingState.notEligible => (
            l10n.trackingStatusNotStarted,
            secondary,
            Icons.schedule_rounded,
          ),
        };

        final kind = _ctrl.isAirport
            ? l10n.trackingAirportPickup
            : l10n.trackingHotelPickup;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.luxuryAccent.withAlpha(dark ? 90 : 70),
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
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: AppTheme.luxuryAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trackYourDriver,
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
                          kind,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: secondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(dark ? 36 : 22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusText,
                        style: GoogleFonts.inter(
                          color: dark ? AppTheme.darkPrimaryText : statusColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_ctrl.driverChanged &&
                  state != TrackingState.notEligible) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.trackingDriverChanged,
                  style: GoogleFonts.inter(color: secondary, fontSize: 12),
                ),
              ],
              if (state == TrackingState.live && loc != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        label: l10n.trackingLastUpdate,
                        value: _ago(loc.updatedAt),
                        primary: primary,
                        secondary: secondary,
                      ),
                    ),
                    if (eta != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoTile(
                          label: l10n.trackingEta,
                          value: l10n.trackingEtaMinutes(eta),
                          primary: primary,
                          secondary: secondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openMaps(loc),
                    icon: const Icon(Icons.map_rounded, size: 20),
                    label: Text(
                      l10n.trackingOpenInMaps,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.luxuryAccent,
                      foregroundColor: AppTheme.brandNavy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color primary;
  final Color secondary;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.softGoldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: secondary, fontSize: 11.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
