import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../theme/app_theme.dart';

/// Customer SIM delivery card (same visual language as the driver eSIM row).
///
/// Receipt / non-receipt state comes from Odoo (`customer_receipt_status`);
/// it is independent from the driver's delivery status. Actions are delegated
/// to the parent, which calls Odoo and reloads.
class CustomerSimCard extends StatelessWidget {
  final HomeExtraService service;
  final int totalQty;
  final AppLocalizations l10n;
  final bool busy;
  final Future<void> Function() onConfirmReceived;
  final Future<void> Function() onReportNotReceived;

  const CustomerSimCard({
    super.key,
    required this.service,
    required this.totalQty,
    required this.l10n,
    required this.onConfirmReceived,
    required this.onReportNotReceived,
    this.busy = false,
  });

  Future<bool> _confirmDialog(
    BuildContext context, {
    required String question,
    required String confirmLabel,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              service.isFlowers
                  ? Icons.local_florist_outlined
                  : Icons.sim_card_outlined,
              color: AppTheme.luxuryAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                service.isFlowers
                    ? l10n.flowersTitle
                    : service.isESim
                    ? l10n.eSimCardTitle
                    : l10n.simCardTitle,
                style: GoogleFonts.inter(
                  color: AppTheme.navyText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          question,
          style: GoogleFonts.inter(color: AppTheme.secondaryText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancelAction,
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              confirmLabel,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final received = service.isCustomerReceived;
    final reported = service.isNotReceivedReported;
    final title = service.isFlowers
        ? l10n.flowersTitle
        : service.isESim
        ? l10n.eSimCardTitle
        : l10n.simCardTitle;

    String statusText;
    Color statusColor;
    if (received) {
      statusText = service.isFlowers
          ? l10n.flowersReceivedLabel
          : l10n.simReceivedLabel;
      statusColor = AppTheme.successGreen;
    } else if (reported) {
      statusText = l10n.simNotReceivedReported;
      statusColor = AppTheme.errorRed;
    } else if (service.isDelivered) {
      statusText = l10n.simStatusDelivered;
      statusColor = AppTheme.luxuryAccent;
    } else {
      statusText = l10n.simStatusPending;
      statusColor = AppTheme.secondaryText;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.softGoldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    service.isFlowers
                        ? Icons.local_florist_outlined
                        : Icons.sim_card_outlined,
                    color: AppTheme.luxuryAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: AppTheme.navyText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (totalQty > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '$totalQty ${service.isFlowers ? l10n.flowersCount : l10n.simCardsCount}',
                            style: GoogleFonts.inter(
                              color: AppTheme.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(28),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    received
                        ? Icons.check_circle_rounded
                        : reported
                        ? Icons.report_gmailerrorred_rounded
                        : Icons.local_shipping_outlined,
                    size: 15,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      statusText,
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!received) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await _confirmDialog(
                            context,
                            question: service.isFlowers
                                ? l10n.flowersReceivedQuestion
                                : l10n.simReceivedQuestion,
                            confirmLabel: l10n.confirmReceipt,
                          );
                          if (ok) await onConfirmReceived();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    service.isFlowers
                        ? l10n.confirmFlowersReceived
                        : l10n.confirmSimReceived,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (!reported) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await _confirmDialog(
                              context,
                              question: service.isFlowers
                                  ? l10n.flowersNotReceivedQuestion
                                  : l10n.simNotReceivedQuestion,
                              confirmLabel: l10n.reportNotReceived,
                            );
                            if (ok) await onReportNotReceived();
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navyText,
                      side: const BorderSide(
                        color: AppTheme.luxuryAccent,
                        width: 1.3,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      service.isFlowers
                          ? l10n.flowersNotReceivedYet
                          : l10n.simNotReceivedYet,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
