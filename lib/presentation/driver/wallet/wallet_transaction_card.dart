import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/wallet_models.dart';
import '../../../theme/app_theme.dart';
import './wallet_strings.dart';

/// The ONE transaction card used for every wallet operation
/// (Trip Earning, Payout Request / Approved / Paid / Rejected).
class WalletTransactionCard extends StatelessWidget {
  final WalletTransaction transaction;
  final WalletStrings strings;
  final bool isDark;

  const WalletTransactionCard({
    super.key,
    required this.transaction,
    required this.strings,
    required this.isDark,
  });

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '${l.day} ${strings.shortMonth(l.month)} ${l.year} • $hh:$mm';
  }

  static String formatAmount(double v) {
    final fixed = v.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '$intPart.${parts[1]}';
  }

  Color _statusColor() {
    switch (transaction.status) {
      case 'pending':
        return AppTheme.luxuryAccent;
      case 'approved':
        return const Color(0xFF3F7CAC);
      case 'rejected':
        return AppTheme.errorRed;
      default:
        return AppTheme.successGreen;
    }
  }

  IconData _icon() {
    switch (transaction.type) {
      case WalletTransactionType.tripEarning:
        return Icons.south_west_rounded;
      case WalletTransactionType.payoutRejected:
        return Icons.undo_rounded;
      default:
        return Icons.north_east_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final goldBg = isDark ? AppTheme.darkSoftGoldBg : const Color(0xFFF2E8D5);

    final signed = transaction.signedAmount;
    final amountText =
        '${signed >= 0 ? '+' : '-'}${formatAmount(signed)} ${transaction.currency}';
    final amountColor = signed >= 0 ? AppTheme.successGreen : textColor;
    final statusColor = _statusColor();
    final date = _formatDate(transaction.displayDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: goldBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_icon(), color: AppTheme.luxuryAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.typeLabel(transaction.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (transaction.bookingReference.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    transaction.bookingReference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: subColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: GoogleFonts.inter(
                  color: amountColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  strings.statusLabel(transaction.status),
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
