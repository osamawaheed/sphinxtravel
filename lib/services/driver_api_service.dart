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
    required String plateNumber,
    required String vehicleModel,
    required String vehicleColor,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/driver/profile/submit',
      data: {
        'plate_number': plateNumber,
        'vehicle_model': vehicleModel,
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
}
