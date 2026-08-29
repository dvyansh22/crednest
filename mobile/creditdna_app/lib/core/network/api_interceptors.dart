import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import '../security/token_manager.dart';
import 'api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final SecureStorage secureStorage;
  final TokenManager tokenManager;

  bool _isRefreshing = false;

  AuthInterceptor({
    required this.dio,
    required this.secureStorage,
    required this.tokenManager,
  });

  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    final path = options.path;
    final isPublicRoute = path.contains(ApiEndpoints.login) ||
        path.contains(ApiEndpoints.signup) ||
        path.contains(ApiEndpoints.forgotPassword);

    if (!isPublicRoute) {
      final token = await secureStorage.getAccessToken();
      if (token != null && !tokenManager.isExpired(token)) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isRetry = err.requestOptions.extra['retried'] == true;

    if (isUnauthorized && !isRetry && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await secureStorage.getRefreshToken();
        if (refreshToken == null) {
          await _forceLogout();
          _isRefreshing = false;
          return handler.next(err);
        }

        final response = await dio.post(
          ApiEndpoints.refreshToken,
          data: {'refreshToken': refreshToken},
        );

        final newAccessToken = (response.data['access_token'] ?? response.data['accessToken']) as String;
        final newRefreshToken = (response.data['refresh_token'] ?? response.data['refreshToken']) as String;

        await secureStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        // Retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        retryOptions.extra['retried'] = true;

        final retryResponse = await dio.fetch(retryOptions);
        _isRefreshing = false;
        return handler.resolve(retryResponse);
      } catch (_) {
        await _forceLogout();
        _isRefreshing = false;
        return handler.next(err);
      }
    }

    handler.next(err);
  }

  Future<void> _forceLogout() async {
    await secureStorage.clearTokens();
    // TODO: hook this into your router (e.g. a global navigatorKey)
    // to force navigation back to login_screen once auth state changes.
  }
}