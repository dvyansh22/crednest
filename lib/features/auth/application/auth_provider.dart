import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

final apiClientProvider = Provider((ref) => ApiClient());
final secureStorageProvider = Provider((ref) => SecureStorage());

final authRepositoryProvider = Provider((ref) {
  return AuthRepository(
    dio: ref.watch(apiClientProvider).dio,
    secureStorage: ref.watch(secureStorageProvider),
  );
});

enum AuthStatus { initial, otpSent, loading, authenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repository;

  AuthNotifier(this.repository) : super(AuthState());

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await repository.sendOtp(phone);
      state = state.copyWith(status: AuthStatus.otpSent);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await repository.verifyOtp(phone: phone, otp: otp);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await repository.logout();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});