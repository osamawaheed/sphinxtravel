import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';

/// Driver-side exact pickup point: address under the pickup city and a
/// "Navigate" button opening Google Maps directions. The button is hidden
/// when [navigateUrl] is null (no pickup_lat).
class DriverPickupPointInfo extends StatelessWidget {
  final String? address;
  final String? navigateUrl;
  final String buttonLabel;
  final Color addressColor;

  const DriverPickupPointInfo({
    super.key,
    required this.address,
    required this.navigateUrl,
    required this.buttonLabel,
    required this.addressColor,
  });

  Future<void> _open() async {
    final uri = Uri.tryParse(navigateUrl ?? '');
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final addr = (address ?? '').trim();
    final hasNav = (navigateUrl ?? '').isNotEmpty;
    if (addr.isEmpty && !hasNav) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (addr.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            addr,
            softWrap: true,
            style: GoogleFonts.inter(
              color: addressColor,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
        if (hasNav) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _open,
            icon: const Icon(
              Icons.navigation_rounded,
              size: 16,
              color: AppTheme.brandNavy,
            ),
            label: Text(
              buttonLabel,
              style: GoogleFonts.inter(
                color: AppTheme.brandNavy,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: AppTheme.brandNavy.withAlpha(120)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
