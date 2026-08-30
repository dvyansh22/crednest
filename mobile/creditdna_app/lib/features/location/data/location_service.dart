import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'models/location_model.dart';

/// All actual device location logic lives here — geolocator/geocoding calls
/// never happen outside this class. UI and providers only ever see
/// [LocationModel] and [LocationPermission].
class LocationService {
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  /// Resolves real coordinates to a human-readable place. If reverse
  /// geocoding fails (offline, no result, platform error) the coordinates
  /// are still returned — callers decide how to present a place-less
  /// location rather than this silently inventing a city.
  Future<LocationModel> reverseGeocode({required double latitude, required double longitude}) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return LocationModel(
          latitude: latitude,
          longitude: longitude,
          lastUpdated: DateTime.now(),
          permissionGranted: true,
          locationServiceEnabled: true,
        );
      }
      final place = placemarks.first;
      final locality = (place.locality?.isNotEmpty ?? false) ? place.locality : place.subAdministrativeArea;
      return LocationModel(
        latitude: latitude,
        longitude: longitude,
        locality: locality,
        administrativeArea: place.administrativeArea,
        country: place.country,
        lastUpdated: DateTime.now(),
        permissionGranted: true,
        locationServiceEnabled: true,
      );
    } catch (_) {
      return LocationModel(
        latitude: latitude,
        longitude: longitude,
        lastUpdated: DateTime.now(),
        permissionGranted: true,
        locationServiceEnabled: true,
      );
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
