import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/auth_network_image.dart';

class HomeDriverBlock extends StatelessWidget {
  final HomeDriver driver;
  final AppLocalizations l10n;
  final bool dark;
  final VoidCallback? onRate;

  const HomeDriverBlock({
    super.key,
    required this.driver,
    required this.l10n,
    this.dark = false,
    this.onRate,
  });

  static String? _cleanPhone(String? phone) {
    if (phone == null) return null;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  static Future<void> _call(String? phone) async {
    final p = _cleanPhone(phone);
    if (p == null) return;
    try {
      final uri = Uri.parse('tel:$p');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  static Future<void> _message(String? phone) async {
    final p = _cleanPhone(phone);
    if (p == null) return;
    try {
      final digits = p.startsWith('+') ? p.substring(1) : p;
      final uri = Uri.parse('https://wa.me/$digits');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _initials() {
    final name = driver.name;
    return Container(
      color: AppTheme.brandNavy,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'D',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _statsText() {
    final parts = <String>[];
    final rating = driver.rating;
    if (rating != null) {
      final count = driver.ratingCount;
      parts.add(
        count != null
            ? '${rating.toStringAsFixed(1)} ($count)'
            : rating.toStringAsFixed(1),
      );
    }
    final trips = driver.tripCount;
    if (trips != null) parts.add('$trips ${l10n.trips}');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : AppTheme.primaryText;
    final secondary = dark
        ? Colors.white.withAlpha(179)
        : AppTheme.secondaryText;
    final tertiary = dark
        ? Colors.white.withAlpha(153)
        : AppTheme.secondaryText;
    final full = driver.hasAppAccount;
    final stats = full ? _statsText() : '';
    final showRating = full && driver.rating != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onRate,
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.luxuryAccent, width: 2),
                ),
                child: ClipOval(
                  child: full
                      ? AuthNetworkImage(
                          photoUrl: driver.photoUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          fallback: _initials(),
                        )
                      : SizedBox(width: 48, height: 48, child: _initials()),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: GoogleFonts.inter(
                        color: primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (showRating) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: AppTheme.luxuryAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              stats,
                              style: GoogleFonts.inter(
                                color: secondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (driver.vehicleModel.isNotEmpty)
                      Text(
                        driver.vehicleModel,
                        style: GoogleFonts.inter(
                          color: primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (full && driver.vehicleYear.isNotEmpty)
                      Text(
                        driver.vehicleYear,
                        style: GoogleFonts.inter(color: tertiary, fontSize: 12),
                      ),
                    if (full && driver.vehicleColor.isNotEmpty)
                      Text(
                        driver.vehicleColor,
                        style: GoogleFonts.inter(color: tertiary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (driver.phone.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DriverActionButton(
                  icon: Icons.phone_outlined,
                  label: l10n.call,
                  dark: dark,
                  onTap: () => _call(driver.phone),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DriverActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: l10n.message,
                  dark: dark,
                  onTap: () => _message(driver.phone),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DriverActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback onTap;

  const _DriverActionButton({
    required this.icon,
    required this.label,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppTheme.primaryText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withAlpha(26) : AppTheme.softGoldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
