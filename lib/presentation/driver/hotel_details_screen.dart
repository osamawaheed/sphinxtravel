import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';

/// Popup modal showing a hotel's name and phone, with "Get Directions",
/// "Call Hotel" and "Close". All values come from the linked hotel record in
/// Odoo — the map URL is opened exactly as stored and nothing is guessed.
class HotelDetailsScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String googleMapUrl;

  const HotelDetailsScreen({
    super.key,
    required this.name,
    this.phone = '',
    this.googleMapUrl = '',
  });

  /// Opens the hotel popup over the current page (no navigation to a new page).
  static Future<void> show(
    BuildContext context, {
    required String name,
    String phone = '',
    String googleMapUrl = '',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => HotelDetailsScreen(
        name: name,
        phone: phone,
        googleMapUrl: googleMapUrl,
      ),
    );
  }

  @override
  State<HotelDetailsScreen> createState() => _HotelDetailsScreenState();
}

class _HotelDetailsScreenState extends State<HotelDetailsScreen> {
  @override
  void initState() {
    super.initState();
    LocalizationService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _getDirections(AppLocalizations l10n) async {
    final url = widget.googleMapUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || !uri.hasScheme) {
      _toast(l10n.hotelMapUnavailable);
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast(l10n.hotelActionFailed);
    } catch (_) {
      _toast(l10n.hotelActionFailed);
    }
  }

  Future<void> _callHotel(AppLocalizations l10n) async {
    final phone = widget.phone.trim();
    if (phone.isEmpty) {
      _toast(l10n.hotelPhoneUnavailable);
      return;
    }
    final dialable = phone.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: dialable));
      if (!ok) _toast(l10n.hotelActionFailed);
    } catch (_) {
      _toast(l10n.hotelActionFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.fromService(LocalizationService.instance);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final hasPhone = widget.phone.trim().isNotEmpty;
    final hasMap = widget.googleMapUrl.trim().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.luxuryAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.hotel_rounded,
                      color: AppTheme.luxuryAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: isDark ? textColor : AppTheme.brandNavy,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                size: 13,
                                color: subColor,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  hasPhone
                                      ? widget.phone.trim()
                                      : l10n.hotelPhoneUnavailable,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: hasPhone ? textColor : subColor,
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
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: subColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasMap ? () => _getDirections(l10n) : null,
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: Text(
                          l10n.getDirections,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasPhone ? () => _callHotel(l10n) : null,
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: Text(
                          l10n.callHotel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.luxuryAccent,
                          side: BorderSide(
                            color: hasPhone ? AppTheme.luxuryAccent : border,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
