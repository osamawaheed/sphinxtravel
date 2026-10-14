import '../models/customer_bootstrap_model.dart';
import './api_client.dart';
import './token_manager.dart';

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
    }
    return data;
  }

  Future<CustomerBootstrapModel> loadBootstrap() async {
    final response = await _apiClient.get('/api/v1/customer/bootstrap');
    return CustomerBootstrapModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/api/v1/auth/logout');
    } catch (_) {}
    await TokenManager.clearTokens();
  }
}
