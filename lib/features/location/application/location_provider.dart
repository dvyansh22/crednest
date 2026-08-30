import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../consent/application/consent_provider.dart';
import '../data/location_service.dart';
import '../data/models/location_model.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

enum LocationStatus {
  initial,
  checkingPermission,
  permissionRequired,
  loading,
  available,
  permissionDenied,
  permissionPermanentlyDenied,
  locationServicesDisabled,
  error,
}

class LocationState {
  final LocationStatus status;
  final LocationModel? model;
  final String? errorMessage;

  const LocationState({this.status = LocationStatus.initial, this.model, this.errorMessage});

  LocationState copyWith({LocationStatus? status, LocationModel? model, String? errorMessage}) {
    return LocationState(
      status: status ?? this.status,
      model: model ?? this.model,
      errorMessage: errorMessage,
    );
  }
}

/// Owns the real device-location flow end to end: permission checks,
/// native permission requests, GPS retrieval, reverse geocoding — and
/// keeps the 'location-data' entry in [consentProvider] in sync so the
/// Consent Center and Dashboard reflect the same, real state.
class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier(this._service, this._ref) : super(const LocationState());

  final LocationService _service;
  final Ref _ref;

  static const _consentExpiry = Duration(days: 15);

  /// Reads current permission/service state without prompting the user.
  /// If permission is already granted, this also refreshes the real
  /// location — matching "already granted -> refresh" from the required
  /// post-auth flow.
  Future<void> checkPermissionState() async {
    state = state.copyWith(status: LocationStatus.checkingPermission);
    try {
      final serviceEnabled = await _service.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(status: LocationStatus.locationServicesDisabled);
        return;
      }

      final permission = await _service.checkPermission();
      await _handlePermissionResult(permission);
    } catch (_) {
      state = state.copyWith(status: LocationStatus.error, errorMessage: 'Unable to check location permission right now.');
    }
  }

  /// Triggers the actual native OS permission dialog. Only call this after
  /// the user has explicitly agreed via the in-app explanation (popup or
  /// the "Enable Location" action in Consent Center) — never on app start.
  Future<bool> requestPermission() async {
    try {
      final serviceEnabled = await _service.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(status: LocationStatus.locationServicesDisabled);
        return false;
      }

      state = state.copyWith(status: LocationStatus.loading);
      final permission = await _service.requestPermission();
      return await _handlePermissionResult(permission);
    } catch (_) {
      state = state.copyWith(status: LocationStatus.error, errorMessage: 'Unable to request location permission right now.');
      return false;
    }
  }

  Future<bool> _handlePermissionResult(LocationPermission permission) async {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        await _fetchLocation();
        return state.status == LocationStatus.available;
      case LocationPermission.deniedForever:
        state = state.copyWith(status: LocationStatus.permissionPermanentlyDenied);
        await _syncConsentInactive();
        return false;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        state = state.copyWith(status: LocationStatus.permissionRequired);
        await _syncConsentInactive();
        return false;
    }
  }

  Future<void> _fetchLocation() async {
    state = state.copyWith(status: LocationStatus.loading);
    try {
      final position = await _service.getCurrentPosition();
      final model = await _service.reverseGeocode(latitude: position.latitude, longitude: position.longitude);
      state = state.copyWith(status: LocationStatus.available, model: model);
      await _syncConsentActive();
    } on TimeoutException {
      state = state.copyWith(status: LocationStatus.error, errorMessage: 'Location request timed out. Please try again.');
    } on LocationServiceDisabledException {
      state = state.copyWith(status: LocationStatus.locationServicesDisabled);
    } catch (_) {
      state = state.copyWith(status: LocationStatus.error, errorMessage: 'Unable to determine your location right now.');
    }
  }

  /// Re-checks permission and, if still granted, fetches a fresh position —
  /// used by "Refresh Location" and whenever the Consent Center reopens.
  Future<void> refreshLocation() async {
    final permission = await _service.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      await _fetchLocation();
    } else {
      await checkPermissionState();
    }
  }

  /// App-level "turn off" — stops the app from using location and clears
  /// the resolved place, without touching the OS-level permission (which
  /// only the user can change from device settings).
  Future<void> disableLocation() async {
    state = const LocationState(status: LocationStatus.permissionRequired);
    await _syncConsentInactive();
  }

  /// Called on logout — clears session location state. There's no
  /// continuous location stream to cancel (retrieval is one-shot), so this
  /// just resets in-memory state.
  void reset() {
    state = const LocationState();
  }

  Future<void> openAppSettings() => _service.openAppSettings();

  Future<void> openLocationSettings() => _service.openLocationSettings();

  Future<void> _syncConsentActive() {
    return _ref.read(consentProvider.notifier).activateConsent(
          'location-data',
          expiryDate: DateTime.now().add(_consentExpiry),
        );
  }

  Future<void> _syncConsentInactive() {
    return _ref.read(consentProvider.notifier).deactivateConsent('location-data');
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(ref.watch(locationServiceProvider), ref);
});
