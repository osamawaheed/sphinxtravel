import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/mock_api_data_source.dart';
import '../../../models/wallet_models.dart';
import '../../../services/api_client.dart';
import '../../../services/driver_wallet_service.dart';
import '../../../services/localization_service.dart';
import '../../../theme/app_theme.dart';
import './payout_request_screen.dart';
import './wallet_strings.dart';
import './wallet_transaction_card.dart';

/// Driver Wallet tab body. All data comes from Odoo via
/// [DriverWalletService]; when the API is not ready an "unavailable" state is
/// shown instead of any fake balance.
class DriverWalletView extends StatefulWidget {
  final bool isDark;
  const DriverWalletView({super.key, required this.isDark});

  @override
  State<DriverWalletView> createState() => _DriverWalletViewState();
}

enum _WalletLoad { loading, ready, unavailable, error }

class _DriverWalletViewState extends State<DriverWalletView> {
  static const String _currency = 'GEL';

  DriverWalletService? _service;
  _WalletLoad _state = _WalletLoad.loading;
  WalletSummary? _summary;
  List<WalletTransaction> _transactions = const [];

  WalletStrings get s =>
      WalletStrings(LocalizationService.instance.currentLanguage);
  bool get isDark => widget.isDark;

  @override
  void initState() {
    super.initState();
    if (MockApiDataSource.useMock) {
      // Mock mode has no wallet backend; never show fabricated balances.
      _state = _WalletLoad.unavailable;
    } else {
      _service = DriverWalletService(ApiClient());
      _load();
    }
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) return;
    setState(() => _state = _WalletLoad.loading);
    try {
      final results = await Future.wait([
        service.getWallet(),
        service.getTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as WalletSummary;
        _transactions = results[1] as List<WalletTransaction>;
        _state = _WalletLoad.ready;
      });
    } on WalletUnavailableException {
      if (mounted) setState(() => _state = _WalletLoad.unavailable);
    } catch (_) {
      if (mounted) setState(() => _state = _WalletLoad.error);
    }
  }

  Future<void> _openPayout() async {
    final service = _service;
    final summary = _summary;
    if (service == null || summary == null) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PayoutRequestScreen(
          service: service,
          balance: summary.forCurrency(_currency),
          strings: s,
          isDark: isDark,
        ),
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return RefreshIndicator(
      color: AppTheme.luxuryAccent,
      onRefresh: () async {
        if (_service != null) await _load();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.wallet,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _buildOverview(),
            const SizedBox(height: 24),
            Text(
              s.transactions,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildBody(cardBg, border, subColor, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview() {
    final ready = _state == _WalletLoad.ready && _summary != null;
    final b = ready ? _summary!.forCurrency(_currency) : null;
    String fmt(double? v) =>
        v == null ? '—' : '${WalletTransactionCard.formatAmount(v)} $_currency';

    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(179),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    final canRequest = ready && (b?.available ?? 0) > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.brandNavy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.availableBalance.toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(179),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmt(b?.available),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat(s.totalEarnings, fmt(b?.totalEarnings)),
              const SizedBox(width: 12),
              stat(s.pendingPayouts, fmt(b?.pendingPayouts)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: canRequest ? _openPayout : null,
              icon: const Icon(Icons.account_balance_outlined, size: 18),
              label: Text(
                s.requestPayout,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.luxuryAccent,
                foregroundColor: AppTheme.brandNavy,
                disabledBackgroundColor: Colors.white.withAlpha(30),
                disabledForegroundColor: Colors.white.withAlpha(110),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    Color cardBg,
    Color border,
    Color subColor,
    Color textColor,
  ) {
    Widget panel({
      required IconData icon,
      required String title,
      String? body,
      Widget? action,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(icon, color: subColor, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: subColor, fontSize: 13),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action],
          ],
        ),
      );
    }

    switch (_state) {
      case _WalletLoad.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.luxuryAccent),
          ),
        );
      case _WalletLoad.unavailable:
        return panel(
          icon: Icons.cloud_off_outlined,
          title: s.unavailableTitle,
          body: s.unavailableBody,
        );
      case _WalletLoad.error:
        return panel(
          icon: Icons.error_outline_rounded,
          title: s.loadError,
          action: TextButton(
            onPressed: _load,
            child: Text(
              s.retry,
              style: GoogleFonts.inter(
                color: AppTheme.luxuryAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case _WalletLoad.ready:
        if (_transactions.isEmpty) {
          return panel(
            icon: Icons.receipt_long_outlined,
            title: s.noTransactions,
          );
        }
        return Column(
          children: [
            for (final t in _transactions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: WalletTransactionCard(
                  key: ValueKey(t.payoutId ?? t.id),
                  transaction: t,
                  strings: s,
                  isDark: isDark,
                ),
              ),
          ],
        );
    }
  }
}
