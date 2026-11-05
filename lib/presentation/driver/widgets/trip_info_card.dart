import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/az_case.dart';

class TripSectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const TripSectionTitle({
    super.key,
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      AzCase.upper(title),
      style: GoogleFonts.inter(
        color: isDark ? AppTheme.darkSecondaryText : AppTheme.secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class TripInfoCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> rows;

  const TripInfoCard({super.key, required this.isDark, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    if (rows.isEmpty) return const SizedBox.shrink();
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
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) Divider(color: border, height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class TripDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const TripDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.luxuryAccent),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(color: subColor, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.end,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
