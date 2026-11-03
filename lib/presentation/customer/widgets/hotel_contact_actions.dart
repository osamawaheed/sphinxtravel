import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// Single source of truth for the height of itinerary action buttons
/// (Call Hotel, Maps and "View / Update status"). The height is enforced
/// explicitly so it can never drift due to theme padding / minimum sizes.
const double kItineraryActionButtonHeight = 38;

/// "Call hotel" / "Open in Maps" buttons. Each button is hidden when its
/// value is empty; renders nothing when both are empty.
class HotelContactActions extends StatelessWidget {
  static const double buttonRadius = 12;
  static const double buttonIconSize = 13;
  static const double buttonFontSize = 13;
  static const double buttonBorderWidth = 1;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(buttonRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: kItineraryActionButtonHeight,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, kItineraryActionButtonHeight),
            maximumSize: const Size(
              double.infinity,
              kItineraryActionButtonHeight,
            ),
            fixedSize: const Size.fromHeight(kItineraryActionButtonHeight),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            side: const BorderSide(
              color: AppTheme.luxuryAccent,
              width: buttonBorderWidth,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: buttonIconSize, color: AppTheme.luxuryAccent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: GoogleFonts.inter(
                    color: AppTheme.luxuryAccent,
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.trim().isNotEmpty;
    final hasMap = mapUrl.trim().isNotEmpty;
    if (!hasPhone && !hasMap) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            if (hasPhone)
              Expanded(
                child: _button(
                  icon: Icons.call_rounded,
                  label: l10n.callHotel,
                  onTap: _call,
                ),
              ),
            if (hasPhone && hasMap) const SizedBox(width: 10),
            if (hasMap)
              Expanded(
                child: _button(
                  icon: Icons.map_outlined,
                  label: l10n.hotelMapsShort,
                  onTap: _openMap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
