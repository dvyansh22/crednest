import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import '../security/token_manager.dart';
import '../constants/api_constants.dart';
import 'api_interceptors.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  ) {
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        secureStorage: SecureStorage(),
        tokenManager: TokenManager(),
      ),
    );
  }
}