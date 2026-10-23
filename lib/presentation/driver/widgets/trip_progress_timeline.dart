import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../models/trip_status.dart';

class TripProgressTimeline extends StatelessWidget {
  final TripStatus currentStatus;
  final bool isDark;

  const TripProgressTimeline({
    super.key,
    required this.currentStatus,
    required this.isDark,
  });

  static String _shortStatusLabel(TripStatus s, AppLocalizations l10n) {
    switch (s) {
      case TripStatus.assigned:
        return l10n.statusAssigned;
      case TripStatus.onTheWay:
        return l10n.statusOnTheWay;
      case TripStatus.arrived:
        return l10n.statusArrived;
      case TripStatus.passengerPickedUp:
        return l10n.statusPickedUpShort;
      case TripStatus.inProgress:
        return l10n.statusInTour;
      case TripStatus.completed:
        return l10n.statusCompleted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statuses = [
      TripStatus.assigned,
      TripStatus.onTheWay,
      TripStatus.passengerPickedUp,
      TripStatus.inProgress,
      TripStatus.completed,
    ];
    final current = currentStatus == TripStatus.arrived
        ? TripStatus.onTheWay
        : currentStatus;
    final currentIndex = statuses.indexOf(current);
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tripProgress,
            style: GoogleFonts.inter(
              color: isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = statuses.length;
              final colWidth = constraints.maxWidth / count;
              final lineLeft = colWidth / 2;
              final lineWidth = constraints.maxWidth - colWidth;
              final progressFraction = count > 1
                  ? (currentIndex.clamp(0, count - 1)) / (count - 1)
                  : 0.0;
              return Stack(
                children: [
                  Positioned(
                    left: lineLeft,
                    top: 13,
                    width: lineWidth,
                    height: 2,
                    child: Container(color: border),
                  ),
                  Positioned(
                    left: lineLeft,
                    top: 13,
                    width: lineWidth * progressFraction,
                    height: 2,
                    child: Container(color: AppTheme.successGreen),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: statuses.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final isDone = i < currentIndex;
                      final isCurrent = i == currentIndex;

                      return SizedBox(
                        width: colWidth,
                        child: Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDone || isCurrent
                                    ? (isCurrent
                                          ? AppTheme.luxuryAccent
                                          : AppTheme.successGreen)
                                    : (isDark
                                          ? AppTheme.darkBackground
                                          : AppTheme.mainBackground),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDone || isCurrent
                                      ? (isCurrent
                                            ? AppTheme.luxuryAccent
                                            : AppTheme.successGreen)
                                      : border,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: isDone
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : isCurrent
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _shortStatusLabel(s, l10n),
                                  style: GoogleFonts.inter(
                                    color: isCurrent
                                        ? AppTheme.luxuryAccent
                                        : isDone
                                        ? AppTheme.successGreen
                                        : (isDark
                                              ? AppTheme.darkSecondaryText
                                              : AppTheme.secondaryText),
                                    fontSize: 8.5,
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
