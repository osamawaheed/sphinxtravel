import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/hotel_model.dart';
import '../../theme/app_theme.dart';

class HotelDetailsScreen extends StatelessWidget {
  final HotelModel hotel;

  const HotelDetailsScreen({super.key, required this.hotel});

  Future<void> _openInGoogleMaps() async {
    final address = hotel.address ?? hotel.name;
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone() async {
    final phone = hotel.phone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.mainBackground;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
              color: bgColor,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textColor,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Hotel Details',
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hotel photo
                    if (hotel.photoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 200,
                          child: Image.network(
                            hotel.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.brandNavy.withAlpha(30),
                              child: Icon(
                                Icons.hotel_rounded,
                                color: AppTheme.brandNavy.withAlpha(80),
                                size: 56,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          height: 160,
                          color: AppTheme.brandNavy.withAlpha(20),
                          child: Icon(
                            Icons.hotel_rounded,
                            color: AppTheme.brandNavy.withAlpha(80),
                            size: 56,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Details card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.shadowColor,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hotel Name
                          _DetailRow(
                            icon: Icons.hotel_rounded,
                            label: 'Hotel Name',
                            value: hotel.name,
                            textColor: textColor,
                            subColor: subColor,
                            isDark: isDark,
                            isFirst: true,
                          ),
                          Divider(
                            color: border,
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          // Full Address
                          _DetailRow(
                            icon: Icons.location_on_rounded,
                            label: 'Full Address',
                            value: hotel.address?.isNotEmpty == true
                                ? hotel.address!
                                : hotel.location,
                            textColor: textColor,
                            subColor: subColor,
                            isDark: isDark,
                          ),
                          Divider(
                            color: border,
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          // Phone Number
                          _DetailRow(
                            icon: Icons.phone_rounded,
                            label: 'Phone Number',
                            value: hotel.phone?.isNotEmpty == true
                                ? hotel.phone!
                                : 'Not available',
                            textColor: textColor,
                            subColor: subColor,
                            isDark: isDark,
                            onTap: hotel.phone?.isNotEmpty == true
                                ? _callPhone
                                : null,
                            isActionable: hotel.phone?.isNotEmpty == true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Google Maps button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openInGoogleMaps,
                        icon: const Icon(Icons.map_rounded, size: 20),
                        label: Text(
                          'Open in Google Maps',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.luxuryAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color subColor;
  final bool isDark;
  final bool isFirst;
  final bool isActionable;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.subColor,
    required this.isDark,
    this.isFirst = false,
    this.isActionable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isFirst
          ? const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.luxuryAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppTheme.luxuryAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: subColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      color: isActionable ? AppTheme.luxuryAccent : textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isActionable)
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.luxuryAccent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
