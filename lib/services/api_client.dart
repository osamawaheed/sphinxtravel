import 'package:dio/dio.dart';

import '../routes/app_routes.dart';
import './token_manager.dart';
import './localization_service.dart';

/// Error thrown for any non-2xx backend response.
/// Backend shape: {"success": false, "error": {"code": "...", "message": "..."}}
/// `message` is already translated by the backend — show it as-is.
class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  static const String invalidRequest = 'INVALID_REQUEST';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String forbidden = 'FORBIDDEN';
  static const String invalidOtp = 'INVALID_OTP';
  static const String otpExpired = 'OTP_EXPIRED';
  static const String otpTooManyAttempts = 'OTP_TOO_MANY_ATTEMPTS';
  static const String otpRateLimit = 'OTP_RATE_LIMIT';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String driverDisabled = 'DRIVER_DISABLED';
  static const String tripNotFound = 'TRIP_NOT_FOUND';
  static const String segmentNotFound = 'SEGMENT_NOT_FOUND';
  static const String internalError = 'INTERNAL_ERROR';

  /// Builds an ApiException from a failed Dio call.
  factory ApiException.fromDioException(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    String? code;
    String? message;

    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        code = err['code']?.toString();
        message = err['message']?.toString();
      } else if (err is String) {
        message = err;
      }
      message ??= data['message']?.toString();
    }

    return ApiException(
      code: (code != null && code.isNotEmpty) ? code : internalError,
      message: (message != null && message.isNotEmpty)
          ? message
          : (e.message ?? ''),
      statusCode: statusCode,
    );
  }

  /// Extracts the message to show to the user from any caught error.
  static String? messageOf(Object error) {
    if (error is ApiException && error.message.isNotEmpty) {
      return error.message;
    }
    return null;
  }

  @override
  String toString() => message;
}

class ApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://test.sphinx-travel.com',
  );

  /// API base URL (no trailing slash).
  static String get baseUrl => _baseUrl.endsWith('/')
      ? _baseUrl.substring(0, _baseUrl.length - 1)
      : _baseUrl;

  /// True only for the authorized Odoo testing environment.
  /// The debug OTP is never shown against any other (production) host.
  static bool get isTestEnvironment {
    final host = Uri.tryParse(_baseUrl)?.host.toLowerCase() ?? '';
    return host == 'test.sphinx-travel.com';
  }

  /// Returns the OTP the Odoo testing API included in a request-otp response
  /// (`debug_otp` or equivalent), or null when not available / not allowed.
  static String? debugOtpFrom(dynamic response) {
    if (!isTestEnvironment || response is! Map) return null;
    final data = response['data'] is Map ? response['data'] as Map : null;
    for (final key in const ['debug_otp', 'debugOtp', 'test_otp', 'otp']) {
      final raw = response[key] ?? data?[key];
      final value = raw?.toString().trim() ?? '';
      if (RegExp(r'^\d{4,8}$').hasMatch(value)) return value;
    }
    return null;
  }

  /// Resolves a relative path (e.g. "/web/image/...") against the API base URL.
  /// Absolute http(s) URLs are returned unchanged; empty input returns ''.
  static String resolveUrl(String? path) {
    final p = (path ?? '').trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return p.startsWith('/') ? '$baseUrl$p' : '$baseUrl/$p';
  }

  /// Headers needed to load protected images.
  static Future<Map<String, String>> authHeaders() async {
    final token = await TokenManager.getAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static const String _refreshPath = '/api/v1/auth/refresh';

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Inject Bearer token
          final token = await TokenManager.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Inject Accept-Language globally from LocalizationService singleton
          options.headers['Accept-Language'] =
              LocalizationService.instance.currentLanguage;
          handler.next(options);
        },
        onError: (error, handler) async {
          final isRefreshCall = error.requestOptions.path.endsWith(
            _refreshPath,
          );
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          // Login/OTP endpoints return 401 for bad credentials: that is not
          // an expired session, so never refresh or navigate away from them.
          final path = error.requestOptions.path;
          final isCredentialCall =
              path.endsWith('/auth/driver/login') ||
              path.endsWith('/auth/customer/request-otp') ||
              path.endsWith('/auth/customer/verify-otp');

          if (error.response?.statusCode == 401 &&
              !isRefreshCall &&
              !isCredentialCall &&
              !alreadyRetried) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              try {
                final token = await TokenManager.getAccessToken();
                error.requestOptions.headers['Authorization'] = 'Bearer $token';
                error.requestOptions.extra['retried'] = true;
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              } on DioException catch (retryError) {
                handler.reject(_toApiDioException(retryError));
                return;
              }
            }
            // Token refresh failed → clear tokens and go to role selection.
            await _handleSessionExpired();
          }
          handler.next(_toApiDioException(error));
        },
      ),
    );
  }

  /// Wraps the original DioException so that `error` carries an ApiException.
  DioException _toApiDioException(DioException e) {
    if (e.error is ApiException) return e;
    final apiException = ApiException.fromDioException(e);
    return DioException(
      requestOptions: e.requestOptions,
      response: e.response,
      type: e.type,
      error: apiException,
      message: apiException.message,
      stackTrace: e.stackTrace,
    );
  }

  Future<void> _handleSessionExpired() async {
    await TokenManager.clearTokens();
    await AppRoutes.refreshSessionState();
    try {
      appRouter.go(AppRoutes.userTypeSelection);
    } catch (_) {}
  }

  /// Kept for backward compatibility — language is now read from
  /// LocalizationService.instance automatically on every request.
  void setLanguage(String language) {
    // No-op: language is injected from LocalizationService.instance
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await TokenManager.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await _dio.post(
        _refreshPath,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await TokenManager.saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
          role: await TokenManager.getUserRole() ?? 'customer',
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Runs a request and rethrows any Dio failure as an [ApiException].
  Future<Response> _run(Future<Response> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDioException(e);
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    return _run(() => _dio.get(path, queryParameters: queryParams));
  }

  /// GET returning raw bytes (used for protected PDF downloads).
  Future<Response> getBytes(String path) {
    return _run(
      () => _dio.get(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      ),
    );
  }

  Future<Response> post(String path, {dynamic data}) {
    return _run(() => _dio.post(path, data: data));
  }

  Future<Response> put(String path, {dynamic data}) {
    return _run(() => _dio.put(path, data: data));
  }

  Future<Response> delete(String path) {
    return _run(() => _dio.delete(path));
  }
}
