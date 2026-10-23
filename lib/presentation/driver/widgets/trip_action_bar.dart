import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../models/trip_status.dart';

class TripActionBar extends StatelessWidget {
  final TripStatus status;
  final bool isDark;
  final bool isUpdating;
  final String? statusError;
  final AppLocalizations l10n;
  final ValueChanged<TripStatus> onAdvance;

  const TripActionBar({
    super.key,
    required this.status,
    required this.isDark,
    required this.isUpdating,
    required this.statusError,
    required this.l10n,
    required this.onAdvance,
  });

  String _actionButtonLabel(TripStatus status) {
    switch (status) {
      case TripStatus.assigned:
        return l10n.startDriving;
      case TripStatus.onTheWay:
        return l10n.arrivedAction;
      case TripStatus.arrived:
        return l10n.arrivedAction;
      case TripStatus.passengerPickedUp:
        return l10n.startTrip;
      case TripStatus.inProgress:
        return l10n.completeTrip;
      case TripStatus.completed:
        return l10n.statusCompleted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextStatus = status.next;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorRed.withAlpha(77)),
              ),
              child: Text(
                statusError!,
                style: GoogleFonts.inter(
                  color: AppTheme.errorRed,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (status.isCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withAlpha(26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.successGreen.withAlpha(77)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tripCompleted,
                    style: GoogleFonts.inter(
                      color: AppTheme.successGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else if (nextStatus != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUpdating ? null : () => onAdvance(nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.brandNavy.withAlpha(128),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _actionButtonLabel(status),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
