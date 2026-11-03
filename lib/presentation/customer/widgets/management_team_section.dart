import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

class _ManagementContact {
  final String name;
  final String position;
  final String phone;
  const _ManagementContact({
    required this.name,
    required this.position,
    required this.phone,
  });
}

const List<_ManagementContact> _managementContacts = [
  _ManagementContact(
    name: 'Tornike Lashkhi',
    position: 'Head Manager',
    phone: '+995 595 04 00 95',
  ),
  _ManagementContact(
    name: 'Lasha Bunturi',
    position: 'Transportation Manager',
    phone: '+995 558 24 27 52',
  ),
  _ManagementContact(
    name: 'Giorgi Kanchaveli',
    position: 'Financial Manager',
    phone: '+995 574 21 99 69',
  ),
];

/// Management Team section shared by the Customer and Driver Support pages.
class ManagementTeamSection extends StatelessWidget {
  final bool isDark;
  const ManagementTeamSection({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management Team',
          style: GoogleFonts.inter(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _managementContacts.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _ManagementContactCard(
            contact: _managementContacts[i],
            isDark: isDark,
          ),
        ],
      ],
    );
  }
}

class _ManagementContactCard extends StatelessWidget {
  final _ManagementContact contact;
  final bool isDark;
  const _ManagementContactCard({required this.contact, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final iconBg = isDark ? AppTheme.darkBackground : AppTheme.softSurface;
    final nameColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final phoneColor = isDark ? AppTheme.darkPrimaryText : AppTheme.brandNavy;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.luxuryAccent, width: 1),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
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
                  contact.name,
                  style: GoogleFonts.inter(
                    color: nameColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.position,
                  style: GoogleFonts.inter(
                    color: AppTheme.luxuryAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: subColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        contact.phone,
                        style: GoogleFonts.inter(
                          color: phoneColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
