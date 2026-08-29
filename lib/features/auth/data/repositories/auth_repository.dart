import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  final Dio dio;
  final SecureStorage secureStorage;

  AuthRepository({required this.dio, required this.secureStorage});

  /// Step 1: send OTP to a phone number
  Future<void> sendOtp(String phone) async {
    try {
      await dio.post(ApiEndpoints.sendOtp, data: {'phone': phone});
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// Step 2: verify OTP, returns the logged-in user on success
  Future<UserModel> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await dio.post(
        ApiEndpoints.verifyOtp,
        data: {'phone': phone, 'otp': otp},
      );

      final accessToken = response.data['accessToken'] as String;
      final refreshToken = response.data['refreshToken'] as String;

      await secureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      return UserModel.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// Fetch the current logged-in user (used on app restart to validate session)
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await dio.get(ApiEndpoints.currentUser);
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> logout() async {
    await secureStorage.clearTokens();
  }

  String _extractError(DioException e) {
    if (e.response?.data is Map && e.response?.data['message'] != null) {
      return e.response!.data['message'] as String;
    }
    return 'Something went wrong. Please try again.';
  }
}