import '../models/customer_bootstrap_model.dart';
import './api_client.dart';
import './token_manager.dart';
import './chat/odoo/odoo_chat_secure_session.dart';
import './driver_review_notifications.dart';
import './sim_delivery_notifications.dart';
import './push_device_registration_service.dart';

class CustomerAuthService {
  final ApiClient _apiClient;

  CustomerAuthService(this._apiClient);

  Future<Map<String, dynamic>> requestOtp({required String phoneNumber}) async {
    final response = await _apiClient.post(
      '/api/v1/auth/customer/request-otp',
      data: {'phone': phoneNumber},
    );

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String requestId,
    required String otp,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/auth/customer/verify-otp',
      data: {'phone': phoneNumber, 'request_id': requestId, 'otp': otp},
    );

    final data = response.data as Map<String, dynamic>;

    if (data['access_token'] != null) {
      await TokenManager.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String? ?? '',
        role: 'customer',
      );

      // Register Firebase push device after successful login.
      await PushDeviceRegistrationService.instance.registerAfterLogin();
    }

    return data;
  }

  Future<CustomerBootstrapModel> loadBootstrap() async {
    final response = await _apiClient.get('/api/v1/customer/bootstrap');

    return CustomerBootstrapModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Loads all customer trips.
  Future<List<CustomerTripListItem>> loadTrips() async {
    final response = await _apiClient.get('/api/v1/customer/trips');

    return CustomerTripListItem.listFromResponse(response.data);
  }

  /// Loads complete trip details.
  Future<CustomerHomeTrip> loadTripDetail(int id) async {
    final response = await _apiClient.get('/api/v1/customer/trips/$id');

    final data = response.data;

    Map<String, dynamic> json = <String, dynamic>{};

    if (data is Map) {
      final root = Map<String, dynamic>.from(data);

      final inner = root['trip'] ?? root['active_trip'];

      json = inner is Map ? Map<String, dynamic>.from(inner) : root;
    }

    return CustomerHomeTrip.fromJson(json);
  }

  Future<DriverReviewEvent?> rateDriver({
    required int tripId,
    required int driverId,
    required int rating10,
    required String comment,
    int? transportationId,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/customer/trips/$tripId/rate-driver',
      data: {
        'driver_id': driverId,
        'rating_10': rating10,
        'comment': comment,
        if (transportationId != null && transportationId > 0)
          'transportation_id': transportationId,
      },
    );

    // Dispatch only an event actually returned by Odoo.
    final data = response.data;

    if (data is Map) {
      final raw =
          data['event'] ?? (data['data'] is Map ? data['data']['event'] : null);

      return DriverReviewNotifications.dispatch(raw);
    }

    return null;
  }

  Future<void> rateHotel({
    required int tripId,
    required int hotelId,
    required int rating,
    required String comment,
  }) async {
    await _apiClient.post(
      '/api/v1/customer/trips/$tripId/rate-hotel',
      data: {'hotel_id': hotelId, 'rating': rating, 'comment': comment},
    );
  }

  /// Customer confirms SIM receipt.
  Future<SimDeliveryEvent?> confirmSimReceived({
    required int tripId,
    required int customerId,
    required int extraServiceId,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/customer/trips/$tripId/sim-receipt',
      data: {
        'trip_id': tripId,
        'customer_id': customerId,
        'extra_service_id': extraServiceId,
        'status': 'received',
        'received_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    return _simEventFrom(response.data);
  }

  /// Customer reports SIM not received.
  Future<SimDeliveryEvent?> reportSimNotReceived({
    required int tripId,
    required int customerId,
    required int extraServiceId,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/customer/trips/$tripId/sim-not-received',
      data: {
        'trip_id': tripId,
        'customer_id': customerId,
        'extra_service_id': extraServiceId,
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    return _simEventFrom(response.data);
  }

  /// Extracts and dispatches SIM delivery events.
  SimDeliveryEvent? _simEventFrom(dynamic data) {
    if (data is Map) {
      final raw =
          data['event'] ?? (data['data'] is Map ? data['data']['event'] : null);

      return SimNotifications.dispatch(raw);
    }

    return null;
  }

  /// Logs out the customer and clears local session data.
  Future<void> logout() async {
    try {
      await _apiClient.post('/api/v1/auth/logout');
    } catch (_) {
      // Local logout must continue even if the API is unavailable.
    }

    await ChatSecureSession.clearAll();
    await TokenManager.clearTokens();
  }
}
