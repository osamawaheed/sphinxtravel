import 'dart:typed_data';

import '../models/customer_bootstrap_model.dart';
import '../models/driver_bootstrap_model.dart';
import './api_client.dart';

/// Handles all driver profile API calls.
/// The backend identifies the driver from the Bearer token — no driver_id sent.
class DriverApiService {
  final ApiClient _apiClient;

  DriverApiService(this._apiClient);

  /// POST /api/v1/driver/profile/photo
  /// slot: personal_1..personal_3, vehicle_1..vehicle_5
  /// imageBase64: base64 JPEG/PNG (max 5 MB)
  /// response: {"success": true, "slot": "personal_1"}
  Future<Map<String, dynamic>> uploadProfilePhoto({
    required String slot,
    required String imageBase64,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/driver/profile/photo',
      data: {'slot': slot, 'image_base64': imageBase64},
    );
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  /// POST /api/v1/driver/profile/submit
  /// response: {"success": true, "profile_completed": true}
  Future<Map<String, dynamic>> submitProfile({
    required String vehicleModel,
    required String vehicleYear,
    required String vehicleColor,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/driver/profile/submit',
      data: {
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_color': vehicleColor,
      },
    );
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  /// GET /api/v1/driver/bootstrap — refresh after profile completion
  Future<DriverBootstrapModel> refreshBootstrap() async {
    final response = await _apiClient.get('/api/v1/driver/bootstrap');
    return DriverBootstrapModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /api/v1/driver/trips  -> {"trips": [...]}
  Future<List<DriverTripListItem>> loadTrips() async {
    final response = await _apiClient.get('/api/v1/driver/trips');
    return DriverTripListItem.listFromResponse(response.data);
  }

  /// GET /api/v1/driver/trips/{id}  -> trip object at the root
  Future<CustomerHomeTrip> loadTripDetail(int id) async {
    final response = await _apiClient.get('/api/v1/driver/trips/$id');
    final data = response.data;
    final tripJson = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    return CustomerHomeTrip.fromJson(tripJson);
  }

  /// GET /api/v1/driver/ratings
  Future<DriverRatingsResult> loadRatings() async {
    final response = await _apiClient.get('/api/v1/driver/ratings');
    final data = response.data;
    return DriverRatingsResult.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  /// POST /api/v1/driver/trips/{id}/sim-delivery
  Future<Map<String, dynamic>> confirmSimDelivery({
    required dynamic tripId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/driver/trips/$tripId/sim-delivery',
      data: payload,
    );
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  /// GET /api/v1/driver/trips/{id}/customer-name-report
  /// Returns the original Odoo 17 "Customer Name (English)" Sales Order PDF
  /// as raw bytes (application/pdf). Access is limited by the backend to the
  /// driver assigned to the booking (403 FORBIDDEN otherwise).
  Future<Uint8List> fetchCustomerNameReport(int tripId) async {
    final response = await _apiClient.getBytes(
      '/api/v1/driver/trips/$tripId/customer-name-report',
    );
    final data = response.data;
    final bytes = data is Uint8List
        ? data
        : Uint8List.fromList(List<int>.from(data as List));
    final isPdf =
        bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
    if (!isPdf) {
      throw const ApiException(
        code: ApiException.internalError,
        message: '',
        statusCode: 0,
      );
    }
    return bytes;
  }
}
