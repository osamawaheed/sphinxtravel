import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/trip_model.dart';
import '../../../l10n/app_localizations.dart';

class TomorrowPreviewCard extends StatelessWidget {
  final List<ItineraryItem> items;
  final String tomorrowDate;
  final AppLocalizations l10n;

  const TomorrowPreviewCard({
    super.key,
    required this.items,
    required this.tomorrowDate,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
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
          // Header row: "Tomorrow" + date
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
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Items list
          ...items.take(3).map((item) => _TomorrowItem(item: item)),
          const SizedBox(height: 14),
          // View Tomorrow CTA
          GestureDetector(
            onTap: () {},
            child: Row(
              children: [
                Text(
                  l10n.viewTomorrow,
                  style: GoogleFonts.inter(
                    color: AppTheme.brandNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppTheme.brandNavy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TomorrowItem extends StatelessWidget {
  final ItineraryItem item;
  const _TomorrowItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.secondaryText,
            ),
          ),
          Expanded(
            child: Text(
              item.time.isNotEmpty
                  ? '${item.title} • ${item.time}'
                  : item.title,
              style: GoogleFonts.inter(
                color: AppTheme.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
