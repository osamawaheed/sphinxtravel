import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/auth_network_image.dart';

class DriverTripHeroCard extends StatelessWidget {
  final CustomerHomeTrip trip;
  final AppLocalizations l10n;

  const DriverTripHeroCard({super.key, required this.trip, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final title = trip.destination.trim().isNotEmpty
        ? trip.destination.trim()
        : trip.city.trim();
    final location =
        trip.destination.trim().isNotEmpty && trip.city.trim().isNotEmpty
        ? trip.city.trim()
        : '';
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.brandNavy.withAlpha(230),
                    AppTheme.brandNavy.withAlpha(160),
                    AppTheme.brandNavy.withAlpha(90),
                  ],
                  stops: const [0.0, 0.55, 1.0],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.luxuryAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white70,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (trip.arrivalDate.isNotEmpty ||
                      trip.departureDate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        if (trip.arrivalDate.isNotEmpty)
                          _DateChip(
                            icon: Icons.flight_land_rounded,
                            text: trip.arrivalDate,
                          ),
                        if (trip.departureDate.isNotEmpty)
                          _DateChip(
                            icon: Icons.flight_takeoff_rounded,
                            text: trip.departureDate,
                          ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Container(
                    height: 1,
                    color: Colors.white.withAlpha(50),
                    margin: const EdgeInsets.only(bottom: 14),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: _Metric(
                          icon: Icons.calendar_today_rounded,
                          value: daysText,
                          label: l10n.duration,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withAlpha(50),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Flexible(
                        child: _Metric(
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

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Metric({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.luxuryAccent, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DateChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.luxuryAccent, size: 13),
        const SizedBox(width: 5),
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
