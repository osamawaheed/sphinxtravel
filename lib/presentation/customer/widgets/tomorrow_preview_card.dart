import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../driver/models/trip_status_display.dart';

class TomorrowPreviewCard extends StatelessWidget {
  final List<HomePlanItem> items;
  final String tomorrowDate;
  final AppLocalizations l10n;
  final bool driverMode;
  final List<int> mySegmentIds;
  final void Function(HomePlanItem item)? onItemTap;

  const TomorrowPreviewCard({
    super.key,
    required this.items,
    required this.tomorrowDate,
    required this.l10n,
    this.driverMode = false,
    this.mySegmentIds = const [],
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.softGoldBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.luxuryAccent.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.tomorrow,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tomorrowDate,
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => _TomorrowItem(
              item: item,
              l10n: l10n,
              driverMode: driverMode,
              isMine: mySegmentIds.contains(item.id),
              onTap: onItemTap == null ? null : () => onItemTap!(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _TomorrowItem extends StatelessWidget {
  final HomePlanItem item;
  final AppLocalizations l10n;
  final bool driverMode;
  final bool isMine;
  final VoidCallback? onTap;
  const _TomorrowItem({
    required this.item,
    required this.l10n,
    this.driverMode = false,
    this.isMine = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsetsDirectional.only(end: 10, top: 7),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.luxuryAccent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle.isNotEmpty)
                  Text(
                    item.subtitle,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                if (driverMode && item.type == 'transport') ...[
                  if (isMine) ...[
                    if (item.status.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatTripStatusDisplay(item.status),
                        style: GoogleFonts.inter(
                          color: AppTheme.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n.viewUpdateStatus,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      item.driverAssigned && item.driverName.isNotEmpty
                          ? '${l10n.driverNoColon}: ${item.driverName}'
                          : l10n.noDriverAssigned,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (item.time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              item.time,
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
