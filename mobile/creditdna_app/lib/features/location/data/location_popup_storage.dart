import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the post-auth location explanation popup has already been
/// shown, independent of the actual OS permission state, so a user who
/// taps "Not Now" isn't asked again on every subsequent login.
class LocationPopupStorage {
  static const _key = 'location_popup_shown';

  Future<bool> hasShownPopup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markPopupShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
