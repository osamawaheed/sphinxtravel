import '../models/driver_bootstrap_model.dart';
import '../models/driver_profile_model.dart';
import './api_client.dart';
import './token_manager.dart';

class DriverAuthService {
  final ApiClient _apiClient;

  DriverAuthService(this._apiClient);

  /// POST /api/v1/auth/driver/login
  /// Saves tokens (role "driver") and returns the parsed `user`.
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
    }
    return parseLoginUser(data);
  }

  /// Extracts `user` from a login response.
  static DriverProfile parseLoginUser(Map<String, dynamic> data) {
    final user = data['user'];
    return user is Map<String, dynamic>
        ? DriverProfile.fromJson(user)
        : const DriverProfile();
  }

  Future<DriverBootstrapModel> loadBootstrap() async {
    final response = await _apiClient.get('/api/v1/driver/bootstrap');
    return DriverBootstrapModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/api/v1/auth/logout');
    } catch (_) {}
    await TokenManager.clearTokens();
  }
}
