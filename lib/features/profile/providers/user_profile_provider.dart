import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/models/user_profile_model.dart';
import '../data/user_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository();
});

class UserProfileState {
  final bool isLoading;
  final UserProfileModel? profile;

  const UserProfileState({this.isLoading = false, this.profile});

  bool get isProfileCompleted => profile?.profileCompleted ?? false;

  /// First name to greet the user with, or null if unavailable — the UI
  /// decides the fallback ("Hello 👋") rather than ever showing "null".
  String? get firstName {
    final name = profile?.firstName;
    if (name == null || name.isEmpty) return null;
    return name;
  }

  UserProfileState copyWith({bool? isLoading, UserProfileModel? profile}) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier(this._repository, this._ref) : super(const UserProfileState());

  final UserProfileRepository _repository;
  final Ref _ref;

  Future<void> loadProfile() async {
    final uid = _ref.read(authProvider).user?.id;
    if (uid == null) {
      state = const UserProfileState();
      return;
    }
    state = state.copyWith(isLoading: true);
    final profile = await _repository.getProfile(uid);
    state = UserProfileState(isLoading: false, profile: profile);
  }

  Future<void> saveProfile(UserProfileModel profile) async {
    final uid = _ref.read(authProvider).user?.id;
    if (uid == null) return;
    await _repository.saveProfile(uid, profile);
    state = UserProfileState(profile: profile);
  }

  /// Clears in-memory profile state only (used on logout) — persisted data
  /// stays on disk so the same user sees their profile again after logging
  /// back in.
  void reset() {
    state = const UserProfileState();
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  return UserProfileNotifier(ref.watch(userProfileRepositoryProvider), ref);
});
