import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/auth_network_image.dart';

class TripHeroCard extends StatelessWidget {
  final CustomerHomeTrip trip;
  final AppLocalizations l10n;
  final bool referenceAboveBadge;

  const TripHeroCard({
    super.key,
    required this.trip,
    required this.l10n,
    this.referenceAboveBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!referenceAboveBadge) {
      return _buildSummaryCard();
    }
    final place = [
      trip.city,
      trip.destination,
    ].where((e) => e.trim().isNotEmpty).join(', ');
    final dayText =
        '${l10n.dayLabel} ${trip.dayOfTour} ${l10n.ofLabel} ${trip.totalDays}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 230,
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
            LayoutBuilder(
              builder: (context, c) => AuthNetworkImage(
                photoUrl: trip.imageUrl,
                width: c.maxWidth,
                height: c.maxHeight,
                fit: BoxFit.cover,
                fallback: Container(color: AppTheme.brandNavy),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.brandNavy.withAlpha(150),
                    AppTheme.brandNavy.withAlpha(235),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
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
                          dayText,
                          style: GoogleFonts.inter(
                            color: AppTheme.luxuryAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!referenceAboveBadge && trip.reference.isNotEmpty)
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.confirmation_number_outlined,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  trip.reference,
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    place,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (trip.arrivalDate.isNotEmpty)
                        _Meta(
                          icon: Icons.flight_land_rounded,
                          text: trip.arrivalDate,
                        ),
                      if (trip.departureDate.isNotEmpty)
                        _Meta(
                          icon: Icons.flight_takeoff_rounded,
                          text: trip.departureDate,
                        ),
                      _Meta(
                        icon: Icons.calendar_today_rounded,
                        text: '${trip.totalDays} ${l10n.daysLabel}',
                      ),
                      _Meta(
                        icon: Icons.people_alt_outlined,
                        text: '${trip.passengers} ${l10n.guestsLabel}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (referenceAboveBadge && trip.reference.isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                top: 230 * 0.12,
                child: Text(
                  trip.reference,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Customer Home Trip Summary card: gold booking reference, main destination
  /// only (no city, no arrival/departure rows), trip duration and passengers.
  Widget _buildSummaryCard() {
    final parts = trip.destination
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final mainDestination = parts.isNotEmpty ? parts.last : trip.city.trim();
    final daysText =
        '${trip.totalDays} ${trip.totalDays == 1 ? l10n.day : l10n.days}';
    final guestsText = '${trip.passengers} ${l10n.guestsLabel}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 230,
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
            LayoutBuilder(
              builder: (context, c) => AuthNetworkImage(
                photoUrl: trip.imageUrl,
                width: c.maxWidth,
                height: c.maxHeight,
                fit: BoxFit.cover,
                fallback: Container(color: AppTheme.brandNavy),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.brandNavy.withAlpha(150),
                    AppTheme.brandNavy.withAlpha(235),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trip.reference.isNotEmpty)
                    Text(
                      trip.reference,
                      style: GoogleFonts.inter(
                        color: AppTheme.luxuryAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  const SizedBox(height: 10),
                  if (mainDestination.isNotEmpty)
                    Text(
                      mainDestination,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  const Spacer(),
                  Container(
                    height: 1,
                    color: Colors.white.withAlpha(50),
                    margin: const EdgeInsets.only(bottom: 14),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryMetric(
                          icon: Icons.calendar_today_rounded,
                          value: daysText,
                          label: l10n.duration,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withAlpha(50),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: _SummaryMetric(
                          icon: Icons.people_outline_rounded,
                          value: guestsText,
                          label: l10n.passengers,
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

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.luxuryAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 13),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
