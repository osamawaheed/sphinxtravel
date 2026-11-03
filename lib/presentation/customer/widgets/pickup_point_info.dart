import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';

/// Optional exact pickup point: address text under the pickup city plus a
/// small maps button. Renders nothing when there is nothing to show.
class PickupPointInfo extends StatelessWidget {
  final String? address;

  /// Full URL to open when the button is tapped. Button hidden when empty.
  final String? mapUrl;
  final String buttonLabel;
  final Color addressColor;
  final double addressFontSize;
  final bool onDarkBackground;

  const PickupPointInfo({
    super.key,
    required this.address,
    required this.mapUrl,
    required this.buttonLabel,
    required this.addressColor,
    this.addressFontSize = 13,
    this.onDarkBackground = false,
  });

  Future<void> _open() async {
    final url = (mapUrl ?? '').trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final addr = (address ?? '').trim();
    final hasUrl = (mapUrl ?? '').trim().isNotEmpty;
    if (addr.isEmpty && !hasUrl) return const SizedBox.shrink();

    final accent = onDarkBackground ? Colors.white : AppTheme.brandNavy;

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
              fontSize: addressFontSize,
              height: 1.4,
            ),
          ),
        ],
        if (hasUrl) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _open,
            icon: Icon(Icons.map_outlined, size: 16, color: accent),
            label: Text(
              buttonLabel,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: accent.withAlpha(120)),
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
