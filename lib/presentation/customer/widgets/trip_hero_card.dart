import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../models/trip_model.dart';
import '../../../l10n/app_localizations.dart';

class TripHeroCard extends StatelessWidget {
  final TripModel trip;
  final AppLocalizations l10n;

  const TripHeroCard({super.key, required this.trip, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final progress = trip.currentDay / trip.totalDays;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            trip.heroImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: trip.heroImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppTheme.brandNavy),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppTheme.brandNavy),
                  )
                : Container(color: AppTheme.brandNavy),
            // Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topEnd,
                  end: AlignmentDirectional.bottomStart,
                  colors: [
                    Colors.transparent,
                    AppTheme.brandNavy.withAlpha(179),
                    AppTheme.brandNavy.withAlpha(230),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Day badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.luxuryAccent.withAlpha(64),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.luxuryAccent.withAlpha(128),
                      ),
                    ),
                    child: Text(
                      '${l10n.dayLabel} ${trip.currentDay} ${l10n.ofLabel} ${trip.totalDays}',
                      style: GoogleFonts.inter(
                        color: AppTheme.luxuryAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trip.destination.isNotEmpty ? trip.destination : trip.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (trip.reference.isNotEmpty) ...[
                        const Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trip.reference,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Progress bar
                      SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${((progress) * 100).round()}%',
                              style: GoogleFonts.inter(
                                color: AppTheme.luxuryAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white.withAlpha(51),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppTheme.luxuryAccent,
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
