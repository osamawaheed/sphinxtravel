import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/extra_service_model.dart';
import '../../../theme/app_theme.dart';

class TripExtraServicesCard extends StatelessWidget {
  final List<ExtraServiceModel> services;
  final bool isDark;

  const TripExtraServicesCard({
    super.key,
    required this.services,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    return Container(
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
        children: services.asMap().entries.map((entry) {
          final i = entry.key;
          final svc = entry.value;
          final isLast = i == services.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.softGoldBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.star_outline_rounded,
                        size: 18,
                        color: AppTheme.luxuryAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            svc.name,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (svc.description != null &&
                              svc.description!.isNotEmpty)
                            Text(
                              svc.description!,
                              style: GoogleFonts.inter(
                                color: subColor,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.softGoldBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'x${svc.quantity}',
                        style: GoogleFonts.inter(
                          color: AppTheme.luxuryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(color: border, height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }
}
