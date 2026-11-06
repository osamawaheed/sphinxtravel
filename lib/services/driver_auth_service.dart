import '../models/driver_bootstrap_model.dart';
import '../models/driver_profile_model.dart';
import './api_client.dart';
import './token_manager.dart';
import './chat/odoo/odoo_chat_secure_session.dart';
import './push_device_registration_service.dart';

class DriverAuthService {
  final ApiClient _apiClient;

  DriverAuthService(this._apiClient);

  /// Driver login and Firebase push device registration.
  Future<DriverProfile> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/auth/driver/login',
      data: {'username': username, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;

    if (data['access_token'] != null) {
      await TokenManager.saveTokens(
        accessToken: data['access_token'].toString(),
        refreshToken: data['refresh_token']?.toString() ?? '',
        role: 'driver',
      );

      // Register Firebase device after successful driver authentication.
      await PushDeviceRegistrationService.instance.registerAfterLogin();
    }

    return parseLoginUser(data);
  }

  /// Extracts driver profile from login response.
  static DriverProfile parseLoginUser(Map<String, dynamic> data) {
    final user = data['user'];

    return user is Map<String, dynamic>
        ? DriverProfile.fromJson(user)
        : const DriverProfile();
  }

  /// Loads driver bootstrap information.
  Future<DriverBootstrapModel> loadBootstrap() async {
    final response = await _apiClient.get('/api/v1/driver/bootstrap');

    return DriverBootstrapModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Logs out the driver and clears local session data.
  Future<void> logout() async {
    try {
      await _apiClient.post('/api/v1/auth/logout');
    } catch (_) {
      // Continue local logout if the API is unavailable.
    }

    await ChatSecureSession.clearAll();
    await TokenManager.clearTokens();
  }
}
