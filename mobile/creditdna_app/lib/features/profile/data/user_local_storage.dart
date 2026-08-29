import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/user_profile_model.dart';

/// Persists the user's financial profile locally, keyed by uid so switching
/// accounts on the same device never shows a previous user's data.
///
/// Profile data (name, phone, employment/income category) is not sensitive
/// like an auth token, so SharedPreferences is appropriate here — auth
/// tokens continue to use flutter_secure_storage via SecureStorage.
class UserProfileLocalStorage {
  String _keyFor(String uid) => 'user_profile_$uid';

  Future<UserProfileModel?> getProfile(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(uid));
    if (raw == null) return null;
    try {
      return UserProfileModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(String uid, UserProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(uid), jsonEncode(profile.toJson()));
  }
}
