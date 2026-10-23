import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../models/trip_status.dart';

String tripStatusLabel(TripStatus status, AppLocalizations l10n) {
  switch (status) {
    case TripStatus.assigned:
      return l10n.statusAssigned;
    case TripStatus.onTheWay:
      return l10n.statusOnTheWay;
    case TripStatus.arrived:
      return l10n.statusArrived;
    case TripStatus.passengerPickedUp:
      return l10n.statusPassengerPickedUp;
    case TripStatus.inProgress:
      return l10n.statusInTour;
    case TripStatus.completed:
      return l10n.statusCompleted;
  }
}

class TripStatusBadge extends StatelessWidget {
  final TripStatus status;

  const TripStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;
    switch (status) {
      case TripStatus.assigned:
        badgeColor = AppTheme.brandNavy.withAlpha(26);
        textColor = AppTheme.navyText;
        break;
      case TripStatus.onTheWay:
        badgeColor = const Color(0xFF1565C0).withAlpha(26);
        textColor = AppTheme.isDarkActive
            ? const Color(0xFF64B5F6)
            : const Color(0xFF1565C0);
        break;
      case TripStatus.arrived:
        badgeColor = AppTheme.luxuryAccent.withAlpha(38);
        textColor = AppTheme.luxuryAccent;
        break;
      case TripStatus.passengerPickedUp:
        badgeColor = const Color(0xFF7B1FA2).withAlpha(26);
        textColor = AppTheme.isDarkActive
            ? const Color(0xFFCE93D8)
            : const Color(0xFF7B1FA2);
        break;
      case TripStatus.inProgress:
        badgeColor = AppTheme.successGreen.withAlpha(38);
        textColor = AppTheme.successGreen;
        break;
      case TripStatus.completed:
        badgeColor = AppTheme.secondaryText.withAlpha(38);
        textColor = AppTheme.secondaryText;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tripStatusLabel(status, AppLocalizations.of(context)),
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
