import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/auth_network_image.dart';

class CurrentHotelCard extends StatelessWidget {
  final HomeHotel hotel;
  final AppLocalizations l10n;
  final VoidCallback? onRate;
  final VoidCallback? onOpenDetails;

  const CurrentHotelCard({
    super.key,
    required this.hotel,
    required this.l10n,
    this.onRate,
    this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final place = [
      hotel.city,
      hotel.country,
    ].where((e) => e.trim().isNotEmpty).join(', ');
    final nightText =
        '${l10n.night} ${hotel.night} ${l10n.ofLabel} ${hotel.totalNights}';

    return GestureDetector(
      onTap: onRate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) => AuthNetworkImage(
                        photoUrl: hotel.imageUrl,
                        width: c.maxWidth,
                        height: c.maxHeight,
                        fit: BoxFit.cover,
                        fallback: Container(
                          color: AppTheme.brandNavy,
                          child: const Center(
                            child: Icon(
                              Icons.hotel_rounded,
                              color: Colors.white54,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 12,
                      start: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandNavy.withAlpha(204),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          nightText,
                          style: GoogleFonts.inter(
                            color: AppTheme.luxuryAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentHotel,
                      style: GoogleFonts.inter(
                        color: AppTheme.luxuryAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpenDetails,
                      child: Text(
                        hotel.name,
                        style: GoogleFonts.inter(
                          color: onOpenDetails != null
                              ? AppTheme.luxuryAccent
                              : AppTheme.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (place.isNotEmpty) ...[
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
                              place,
                              style: GoogleFonts.inter(
                                color: AppTheme.secondaryText,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hotel.checkOut.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 14,
                            color: AppTheme.primaryText,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${l10n.checkOut} ${hotel.checkOut}',
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
        ),
      ),
    );
  }
}
