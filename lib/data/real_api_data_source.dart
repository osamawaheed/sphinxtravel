import '../services/api_client.dart';
import '../models/customer_bootstrap_model.dart';
import '../models/driver_bootstrap_model.dart';

class RealApiDataSource {
  final ApiClient _apiClient;

  RealApiDataSource(this._apiClient);

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final response = await _apiClient.post(
      '/api/v1/auth/customer/request-otp',
      data: {'phone': phone},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp, {
    String requestId = '',
  }) async {
    final response = await _apiClient.post(
      '/api/v1/auth/customer/verify-otp',
      data: {'phone': phone, 'request_id': requestId, 'otp': otp},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> driverLogin(
    String username,
    String password,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/auth/driver/login',
      data: {'username': username, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<CustomerBootstrapModel> getCustomerBootstrap() async {
    final response = await _apiClient.get('/api/v1/customer/bootstrap');
    return CustomerBootstrapModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<DriverBootstrapModel> getDriverBootstrap() async {
    final response = await _apiClient.get('/api/v1/driver/bootstrap');
    return DriverBootstrapModel.fromJson(response.data as Map<String, dynamic>);
  }
}
