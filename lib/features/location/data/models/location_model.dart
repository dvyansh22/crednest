/// Real, device-resolved location — every field here is either raw GPS
/// output or the result of reverse geocoding that GPS. Nothing in this
/// model is ever fabricated; when a value isn't known yet it's null.
class LocationModel {
  final double? latitude;
  final double? longitude;
  final String? locality;
  final String? administrativeArea;
  final String? country;
  final DateTime? lastUpdated;
  final bool permissionGranted;
  final bool locationServiceEnabled;

  const LocationModel({
    this.latitude,
    this.longitude,
    this.locality,
    this.administrativeArea,
    this.country,
    this.lastUpdated,
    this.permissionGranted = false,
    this.locationServiceEnabled = false,
  });

  bool get hasResolvedPlace => (locality != null && locality!.isNotEmpty) || (administrativeArea != null && administrativeArea!.isNotEmpty);

  /// "`Locality, State`" — falls back gracefully as fewer parts resolve.
  /// Never returns a placeholder city; callers should check
  /// [hasResolvedPlace] before displaying this.
  String get readableLocation {
    final parts = [locality, administrativeArea]
        .where((part) => part != null && part.trim().isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return country ?? '';
  }
}
