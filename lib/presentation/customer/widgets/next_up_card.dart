import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../../../models/transportation_segment_model.dart';
import '../../../models/driver_assignment_model.dart';
import '../../../l10n/app_localizations.dart';

class NextUpCard extends StatelessWidget {
  final TransportationSegmentModel segment;
  final AppLocalizations l10n;

  const NextUpCard({super.key, required this.segment, required this.l10n});

  String? _cleanPhone(String? phone) {
    if (phone == null) return null;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _callDriver(String? phone) async {
    final p = _cleanPhone(phone);
    if (p == null) return;
    try {
      final uri = Uri.parse('tel:$p');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _messageDriver(String? phone) async {
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

  @override
  Widget build(BuildContext context) {
    final driver = segment.driverAssignment;
    final title = (segment.notes != null && segment.notes!.isNotEmpty)
        ? segment.notes!
        : l10n.driverPickup;
    final subtitle =
        (segment.description != null && segment.description!.isNotEmpty)
        ? segment.description!
        : l10n.yourDriverArrives;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.brandNavy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(77),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.luxuryAccent.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.luxuryAccent.withAlpha(102),
                    ),
                  ),
                  child: Text(
                    l10n.nextUp,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (segment.pickupTime.isNotEmpty)
                  Text(
                    segment.pickupTime,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(179),
                fontSize: 14,
              ),
            ),
          ),
          if (driver != null) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.white.withAlpha(26), height: 1),
            // Driver info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.luxuryAccent,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: driver.driverPhotoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: driver.driverPhotoUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _driverInitials(driver),
                            )
                          : _driverInitials(driver),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.displayName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppTheme.luxuryAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${driver.rating?.toStringAsFixed(1) ?? '—'} · ${driver.totalTrips ?? 0} ${l10n.trips}',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withAlpha(179),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (driver.vehicle != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (driver.vehicle!.displayName.isNotEmpty)
                          Text(
                            driver.vehicle!.displayName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (driver.vehicle!.color.isNotEmpty)
                          Text(
                            driver.vehicle!.color,
                            style: GoogleFonts.inter(
                              color: Colors.white.withAlpha(153),
                              fontSize: 12,
                            ),
                          ),
                        if (driver.vehicle!.plateNumber.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(26),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              driver.vehicle!.plateNumber,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            // Route info
            if (segment.pickupLocation.isNotEmpty ||
                segment.dropoffLocation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      if (segment.pickupLocation.isNotEmpty)
                        _RouteRow(
                          icon: Icons.radio_button_checked,
                          iconColor: AppTheme.successGreen,
                          label: l10n.pickup,
                          value: segment.pickupLocation,
                        ),
                      if (segment.pickupLocation.isNotEmpty &&
                          segment.dropoffLocation.isNotEmpty)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 10),
                          child: Container(
                            width: 1,
                            height: 16,
                            color: Colors.white.withAlpha(51),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      if (segment.dropoffLocation.isNotEmpty)
                        _RouteRow(
                          icon: Icons.location_on_rounded,
                          iconColor: AppTheme.luxuryAccent,
                          label: l10n.destination,
                          value: segment.dropoffLocation,
                        ),
                    ],
                  ),
                ),
              ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.phone_outlined,
                      label: l10n.call,
                      onTap: () => _callDriver(driver.driverPhone),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: l10n.message,
                      onTap: () => _messageDriver(driver.driverPhone),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.person_outline_rounded,
                      label: l10n.viewDriver,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _driverInitials(DriverAssignment driver) {
    return Container(
      color: AppTheme.brandNavy,
      child: Center(
        child: Text(
          driver.displayName.isNotEmpty
              ? driver.displayName[0].toUpperCase()
              : 'D',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
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
