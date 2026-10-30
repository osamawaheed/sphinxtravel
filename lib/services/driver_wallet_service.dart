import '../models/wallet_models.dart';
import './api_client.dart';

/// Thrown when the Odoo wallet API is not available yet (404 / 405 / 501).
class WalletUnavailableException implements Exception {
  const WalletUnavailableException();
}

/// Integration-ready Driver Wallet service.
///
/// Odoo 17 is the source of truth. No balance is ever computed or faked here.
/// The backend identifies the driver from the Bearer token (no driver_id).
///
/// Expected (to be provided by the Odoo developer):
///   GET  /api/v1/driver/wallet
///   GET  /api/v1/driver/wallet/transactions
///   GET  /api/v1/driver/wallet/bank-details
///   PUT  /api/v1/driver/wallet/bank-details
///   POST /api/v1/driver/wallet/payouts
class DriverWalletService {
  final ApiClient _apiClient;

  DriverWalletService(this._apiClient);

  static const String _base = '/api/v1/driver/wallet';

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405 || e.statusCode == 501) {
        throw const WalletUnavailableException();
      }
      rethrow;
    }
  }

  Map<String, dynamic> _map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  Future<WalletSummary> getWallet() => _guard(() async {
    final res = await _apiClient.get(_base);
    return WalletSummary.fromJson(_map(res.data));
  });

  Future<List<WalletTransaction>> getTransactions({String? currency}) => _guard(
    () async {
      final res = await _apiClient.get(
        '$_base/transactions',
        queryParams: currency == null ? null : {'currency': currency},
      );
      final data = _map(res.data);
      final raw = data['transactions'];
      if (raw is! List) return <WalletTransaction>[];
      return raw
          .whereType<Map>()
          .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    },
  );

  Future<PayoutBankDetails> getBankDetails() => _guard(() async {
    final res = await _apiClient.get('$_base/bank-details');
    return PayoutBankDetails.fromJson(_map(res.data));
  });

  Future<PayoutBankDetails> saveBankDetails(PayoutBankDetails details) =>
      _guard(() async {
        final res = await _apiClient.put(
          '$_base/bank-details',
          data: details.toJson(),
        );
        final data = _map(res.data);
        return data.isEmpty ? details : PayoutBankDetails.fromJson(data);
      });

  /// Creates a PENDING payout request. The amount is reserved by Odoo only
  /// after it confirms; [idempotencyKey] prevents duplicate submissions.
  Future<PayoutResult> requestPayout({
    required double amount,
    required String currency,
    required PayoutBankDetails details,
    required String idempotencyKey,
    String? bookingId,
  }) => _guard(() async {
    final res = await _apiClient.post(
      '$_base/payouts',
      data: {
        'amount': amount,
        'currency': currency,
        if (bookingId != null && bookingId.isNotEmpty)
          'booking_id': int.tryParse(bookingId) ?? bookingId,
        ...details.toJson(),
        'idempotency_key': idempotencyKey,
      },
    );
    return PayoutResult.fromJson(_map(res.data));
  });
}
