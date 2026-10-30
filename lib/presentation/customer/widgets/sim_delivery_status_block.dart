import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../theme/app_theme.dart';

/// Compact eSIM delivery status shown inside the My Trip service row.
///
/// Every value comes from Odoo 17 via [HomeExtraService]. A "not received"
/// report is never shown as a delivery confirmation.
class SimDeliveryStatusBlock extends StatelessWidget {
  final HomeExtraService service;
  final AppLocalizations l10n;
  final Color textColor;
  final Color subColor;

  const SimDeliveryStatusBlock({
    super.key,
    required this.service,
    required this.l10n,
    required this.textColor,
    required this.subColor,
  });

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Formats an Odoo timestamp; falls back to the raw Odoo text if unparsable.
  static String formatTimestamp(String raw, AppLocalizations l10n) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final parsed = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (parsed == null) return s;
    final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
    // Odoo returns naive UTC timestamps; show them in the device local time.
    final d = hasZone
        ? parsed.toLocal()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
          ).toLocal();
    return '${l10n.shortDateWithYear(d)} · ${_two(d.hour)}:${_two(d.minute)}';
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(color: subColor, fontSize: 12),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = service.isSimConfirmed;
    final statusColor = confirmed
        ? AppTheme.successGreen
        : AppTheme.luxuryAccent;
    final statusText = confirmed
        ? l10n.simDeliveryConfirmedStatus
        : l10n.simAwaitingDeliveryStatus;
    final role = service.confirmedByRole;
    final at = SimDeliveryStatusBlock.formatTimestamp(
      service.confirmedAtText,
      l10n,
    );
    final qty = service.confirmedQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                confirmed
                    ? Icons.check_circle_rounded
                    : Icons.local_shipping_outlined,
                size: 13,
                color: statusColor,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (confirmed && role.isNotEmpty)
          _detail(
            l10n.simConfirmedByLabel,
            role == 'customer'
                ? l10n.simConfirmedByCustomer
                : l10n.simConfirmedByDriver,
          ),
        if (confirmed && at.isNotEmpty) _detail(l10n.simConfirmedAtLabel, at),
        if (confirmed && qty > 0)
          _detail(
            service.isFlowers
                ? l10n.flowersQuantityLabel
                : l10n.simQuantityLabel,
            '$qty',
          ),
      ],
    );
  }
}
