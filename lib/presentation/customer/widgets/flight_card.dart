import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/customer_bootstrap_model.dart';

class FlightCard extends StatelessWidget {
  final String title;
  final HomeFlight flight;
  final bool isArrival;

  const FlightCard({
    super.key,
    required this.title,
    required this.flight,
    required this.isArrival,
  });

  @override
  Widget build(BuildContext context) {
    final dateTime = [
      flight.date,
      flight.time,
    ].where((e) => e.trim().isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.softGoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isArrival
                  ? Icons.flight_land_rounded
                  : Icons.flight_takeoff_rounded,
              color: AppTheme.luxuryAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppTheme.luxuryAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    flight.airline,
                    flight.flightNo,
                  ].where((e) => e.trim().isNotEmpty).join(' · '),
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dateTime.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateTime,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (flight.airport.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          flight.airport,
                          style: GoogleFonts.inter(
                            color: AppTheme.secondaryText,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
