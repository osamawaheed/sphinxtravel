import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/wallet_models.dart';
import '../../../services/api_client.dart';
import '../../../services/driver_wallet_service.dart';
import '../../../theme/app_theme.dart';
import './wallet_strings.dart';
import './wallet_transaction_card.dart';

/// Payout request screen. Pops with `true` after a successful request.
class PayoutRequestScreen extends StatefulWidget {
  final DriverWalletService service;
  final WalletBalance balance;
  final List<WalletBooking> bookings;
  final WalletStrings strings;
  final bool isDark;

  const PayoutRequestScreen({
    super.key,
    required this.service,
    required this.balance,
    this.bookings = const [],
    required this.strings,
    required this.isDark,
  });

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  WalletBank? _bank;
  WalletBooking? _booking;
  bool _loadingDetails = true;
  bool _submitting = false;
  String? _error;

  /// Bookings of this currency that still have something available.
  List<WalletBooking> get _bookingOptions => widget.bookings
      .where((b) => b.available > 0 && b.currency == widget.balance.currency)
      .toList();

  bool get _bookingRequired => widget.bookings.isNotEmpty;

  /// Max payable amount: the chosen booking's available, else the balance.
  double get _maxAmount => _booking?.available ?? widget.balance.available;

  /// One key per screen session so retries of the same request are idempotent.
  final String _idempotencyKey =
      'payout-${DateTime.now().microsecondsSinceEpoch}';

  WalletStrings get s => widget.strings;
  bool get isDark => widget.isDark;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.balance.available > 0
        ? widget.balance.available.toStringAsFixed(2)
        : '';
    _amountCtrl.addListener(() => setState(() {}));
    _loadSavedDetails();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _ibanCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDetails() async {
    try {
      final d = await widget.service.getBankDetails();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = d.beneficiaryName;
        _ibanCtrl.text = d.iban;
        _taxCtrl.text = d.taxId;
        _bank = d.bank;
      });
    } catch (_) {
      // No saved details yet (or unavailable): the driver fills them in.
    }
    if (mounted) setState(() => _loadingDetails = false);
  }

  double? get _amount =>
      double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));

  double get _remaining {
    final a = _amount ?? 0;
    final r = _maxAmount - a;
    return r < 0 ? 0 : r;
  }

  Future<void> _submit() async {
    if (_submitting) return; // prevents duplicate requests
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = _amount!;
    final details = PayoutBankDetails(
      beneficiaryName: _nameCtrl.text.trim(),
      bank: _bank,
      iban: _ibanCtrl.text.trim(),
      taxId: _taxCtrl.text.trim(),
    );
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Save/update details for future requests, then create the request.
      await widget.service.saveBankDetails(details);
      final result = await widget.service.requestPayout(
        amount: amount,
        currency: widget.balance.currency,
        details: details,
        idempotencyKey: _idempotencyKey,
        bookingId: _booking?.bookingId,
      );
      if (!mounted) return;
      if (result.payoutId.isEmpty) {
        setState(() => _error = s.requestFailed);
        return;
      }
      final ref = result.bookingReference.isNotEmpty
          ? result.bookingReference
          : (_booking?.bookingReference ?? '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.isNotEmpty ? s.requestSubmittedFor(ref) : s.requestSubmitted,
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on WalletUnavailableException {
      if (mounted) setState(() => _error = s.unavailableBody);
    } catch (e) {
      if (mounted) {
        setState(() => _error = ApiException.messageOf(e) ?? s.requestFailed);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label) {
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final fill = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    OutlineInputBorder b(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: 1.3),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: fill,
      labelStyle: GoogleFonts.inter(
        color: isDark ? AppTheme.darkSecondaryText : AppTheme.secondaryText,
        fontSize: 14,
      ),
      enabledBorder: b(border),
      border: b(border),
      focusedBorder: b(AppTheme.luxuryAccent),
      errorBorder: b(AppTheme.errorRed),
      focusedErrorBorder: b(AppTheme.errorRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkBackground : const Color(0xFFF7F5F0);
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final cur = widget.balance.currency;
    final inputStyle = GoogleFonts.inter(color: textColor, fontSize: 15);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          s.payoutTitle,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.brandNavy,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.availableBalance.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white.withAlpha(179),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${WalletTransactionCard.formatAmount(widget.balance.available)} $cur',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_bookingRequired) ...[
                      DropdownButtonFormField<WalletBooking>(
                        initialValue: _booking,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? AppTheme.darkCard
                            : AppTheme.cardWhite,
                        style: inputStyle,
                        decoration: _decoration(s.booking),
                        hint: Text(
                          s.selectBooking,
                          style: GoogleFonts.inter(
                            color: subColor,
                            fontSize: 15,
                          ),
                        ),
                        items: _bookingOptions
                            .map(
                              (b) => DropdownMenuItem<WalletBooking>(
                                value: b,
                                child: Text(
                                  s.bookingAvailable(
                                    b.bookingReference,
                                    WalletTransactionCard.formatAmount(
                                      b.available,
                                    ),
                                    b.currency,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (b) => setState(() {
                                _booking = b;
                                if (b != null) {
                                  _amountCtrl.text = b.available
                                      .toStringAsFixed(2);
                                }
                              }),
                        validator: (v) => v == null ? s.fieldRequired : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _amountCtrl,
                      enabled: !_submitting,
                      style: inputStyle,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _decoration('${s.requestedAmount} ($cur)'),
                      validator: (v) {
                        if (widget.balance.available <= 0) return s.noBalance;
                        final a = double.tryParse(
                          (v ?? '').trim().replaceAll(',', '.'),
                        );
                        if (a == null || a <= 0) return s.invalidAmount;
                        if (a > _maxAmount) {
                          return s.amountExceeds;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${s.remainingAvailable}: ${WalletTransactionCard.formatAmount(_remaining)} $cur',
                      style: GoogleFonts.inter(color: subColor, fontSize: 12.5),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      s.bankDetails,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingDetails)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.luxuryAccent,
                          ),
                        ),
                      )
                    else ...[
                      TextFormField(
                        controller: _nameCtrl,
                        enabled: !_submitting,
                        style: inputStyle,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(s.beneficiaryName),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? s.fieldRequired : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<WalletBank>(
                        initialValue: _bank,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? AppTheme.darkCard
                            : AppTheme.cardWhite,
                        style: inputStyle,
                        decoration: _decoration(s.bankName),
                        hint: Text(
                          s.selectBank,
                          style: GoogleFonts.inter(
                            color: subColor,
                            fontSize: 15,
                          ),
                        ),
                        items: WalletBank.values
                            .map(
                              (b) => DropdownMenuItem<WalletBank>(
                                value: b,
                                child: Text(b.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (b) => setState(() => _bank = b),
                        validator: (v) => v == null ? s.fieldRequired : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _ibanCtrl,
                        enabled: !_submitting,
                        style: inputStyle,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _decoration(s.iban),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? s.fieldRequired : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _taxCtrl,
                        enabled: !_submitting,
                        style: inputStyle,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(s.taxId),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? s.fieldRequired : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: subColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.savedSecurely,
                            style: GoogleFonts.inter(
                              color: subColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          color: AppTheme.errorRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (_submitting || _loadingDetails)
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandNavy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.brandNavy.withAlpha(
                            120,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                s.confirmRequest,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
