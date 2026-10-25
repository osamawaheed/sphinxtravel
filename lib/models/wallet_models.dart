/// Driver wallet models. Odoo 17 is the source of truth — nothing here is
/// computed locally; values are only parsed from backend responses.
library;

enum PayoutStatus { pending, approved, paid, rejected }

enum WalletTransactionType {
  tripEarning,
  payoutRequest,
  payoutApproved,
  payoutPaid,
  payoutRejected,
}

enum WalletBank { tbc, bog }

extension WalletBankX on WalletBank {
  /// Value exchanged with the backend.
  String get apiValue => this == WalletBank.tbc ? 'tbc' : 'bog';

  /// Bank names are proper nouns and are never translated.
  String get displayName =>
      this == WalletBank.tbc ? 'TBC Bank' : 'Bank of Georgia';

  static WalletBank? fromApi(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'tbc':
        return WalletBank.tbc;
      case 'bog':
        return WalletBank.bog;
      default:
        return null;
    }
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}

/// Balance for ONE currency (balances are kept separately per currency).
class WalletBalance {
  final String currency;
  final double available;
  final double totalEarnings;
  final double pendingPayouts;

  const WalletBalance({
    required this.currency,
    required this.available,
    required this.totalEarnings,
    required this.pendingPayouts,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      currency: (json['currency']?.toString() ?? 'GEL').toUpperCase(),
      available: _toDouble(json['available']),
      totalEarnings: _toDouble(json['total_earnings']),
      pendingPayouts: _toDouble(json['pending_payouts']),
    );
  }
}

class WalletSummary {
  final List<WalletBalance> balances;

  const WalletSummary({required this.balances});

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['balances'];
    final list = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => WalletBalance.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <WalletBalance>[];
    return WalletSummary(balances: list);
  }

  /// Balance for [currency]; returns a zero balance if Odoo reports none.
  WalletBalance forCurrency(String currency) {
    for (final b in balances) {
      if (b.currency == currency) return b;
    }
    return WalletBalance(
      currency: currency,
      available: 0,
      totalEarnings: 0,
      pendingPayouts: 0,
    );
  }
}

/// One wallet history entry. A payout is ONE transaction (identified by
/// [payoutId]) whose [status] changes — it is never duplicated per stage.
class WalletTransaction {
  final String id;
  final WalletTransactionType type;
  final String bookingReference;
  final double amount;
  final String currency;
  final String status;
  final String? payoutId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.bookingReference,
    required this.amount,
    required this.currency,
    required this.status,
    this.payoutId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPayout => type != WalletTransactionType.tripEarning;

  static WalletTransactionType _typeFrom(String? v, String status) {
    switch (v) {
      case 'trip_earning':
        return WalletTransactionType.tripEarning;
      case 'payout_request':
      case 'payout':
        // A payout is a single record: derive the stage from its status.
        switch (status) {
          case 'approved':
            return WalletTransactionType.payoutApproved;
          case 'paid':
            return WalletTransactionType.payoutPaid;
          case 'rejected':
            return WalletTransactionType.payoutRejected;
          default:
            return WalletTransactionType.payoutRequest;
        }
      case 'payout_approved':
        return WalletTransactionType.payoutApproved;
      case 'payout_paid':
        return WalletTransactionType.payoutPaid;
      case 'payout_rejected':
        return WalletTransactionType.payoutRejected;
      default:
        return WalletTransactionType.tripEarning;
    }
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final status = (json['status']?.toString() ?? 'completed').toLowerCase();
    final refs = json['booking_reference']?.toString() ?? '';
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: _typeFrom(json['type']?.toString(), status),
      bookingReference: refs,
      amount: _toDouble(json['amount']),
      currency: (json['currency']?.toString() ?? 'GEL').toUpperCase(),
      status: status,
      payoutId: json['payout_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  /// Positive for earnings, negative for any payout operation.
  double get signedAmount => isPayout ? -amount.abs() : amount.abs();

  DateTime? get displayDate => updatedAt ?? createdAt;
}

class PayoutBankDetails {
  final String beneficiaryName;
  final WalletBank? bank;
  final String iban;
  final String taxId;

  const PayoutBankDetails({
    this.beneficiaryName = '',
    this.bank,
    this.iban = '',
    this.taxId = '',
  });

  bool get isEmpty =>
      beneficiaryName.isEmpty && bank == null && iban.isEmpty && taxId.isEmpty;

  factory PayoutBankDetails.fromJson(Map<String, dynamic> json) {
    return PayoutBankDetails(
      beneficiaryName: json['beneficiary_name']?.toString() ?? '',
      bank: WalletBankX.fromApi(json['bank']),
      iban: json['iban']?.toString() ?? '',
      taxId: json['tax_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'beneficiary_name': beneficiaryName,
    'bank': bank?.apiValue,
    'iban': iban,
    'tax_id': taxId,
  };
}

class PayoutResult {
  final String payoutId;
  final String status;
  final double availableAfter;

  const PayoutResult({
    required this.payoutId,
    required this.status,
    required this.availableAfter,
  });

  factory PayoutResult.fromJson(Map<String, dynamic> json) {
    return PayoutResult(
      payoutId: json['payout_id']?.toString() ?? '',
      status: (json['status']?.toString() ?? '').toLowerCase(),
      availableAfter: _toDouble(json['available_after']),
    );
  }
}
