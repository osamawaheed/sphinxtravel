import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// "Call hotel" / "Open in Maps" buttons. Each button is hidden when its
/// value is empty; renders nothing when both are empty.
class HotelContactActions extends StatelessWidget {
  final String phone;
  final String mapUrl;
  final AppLocalizations l10n;

  const HotelContactActions({
    super.key,
    required this.phone,
    required this.mapUrl,
    required this.l10n,
  });

  Future<void> _call() async {
    final dialable = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (dialable.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: dialable));
    } catch (_) {}
  }

  Future<void> _openMap() async {
    final uri = Uri.tryParse(mapUrl.trim());
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _button({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppTheme.luxuryAccent),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: AppTheme.luxuryAccent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minimumSize: const Size(0, 38),
        side: const BorderSide(color: AppTheme.luxuryAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.trim().isNotEmpty;
    final hasMap = mapUrl.trim().isNotEmpty;
    if (!hasPhone && !hasMap) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (hasPhone)
            _button(
              icon: Icons.call_rounded,
              label: l10n.callHotel,
              onTap: _call,
            ),
          if (hasMap)
            _button(
              icon: Icons.map_outlined,
              label: l10n.trackingOpenInMaps,
              onTap: _openMap,
            ),
        ],
      ),
    );
  }
}
