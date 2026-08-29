import 'models/user_profile_model.dart';
import 'user_local_storage.dart';

/// Source of truth for the user's financial profile.
///
/// Priority is backend profile -> local cache -> null (caller decides the
/// fallback). There is no backend profile endpoint yet, so [getProfile]
/// currently reads local cache only — swap in the remote call inside this
/// method once `GET /user/profile` exists, without touching callers.
class UserProfileRepository {
  UserProfileRepository({UserProfileLocalStorage? localStorage})
      : _localStorage = localStorage ?? UserProfileLocalStorage();

  final UserProfileLocalStorage _localStorage;

  Future<UserProfileModel?> getProfile(String uid) async {
    // TODO(backend): try GET /user/profile first and fall back to cache
    // when offline, e.g.:
    //   final remote = await _remoteDataSource.fetchProfile(uid);
    //   if (remote != null) {
    //     await _localStorage.saveProfile(uid, remote);
    //     return remote;
    //   }
    return _localStorage.getProfile(uid);
  }

  Future<void> saveProfile(String uid, UserProfileModel profile) async {
    // TODO(backend): also PUT /user/profile once available.
    await _localStorage.saveProfile(uid, profile);
  }
}
