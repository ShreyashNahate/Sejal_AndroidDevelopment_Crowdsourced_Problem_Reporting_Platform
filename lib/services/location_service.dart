import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Handles GPS location and reverse geocoding
class LocationService {
  /// Get current GPS position with permission handling
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get position with high accuracy
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  /// Convert coordinates to city name using reverse geocoding
  static Future<String> getCityFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return place.locality ?? place.administrativeArea ?? 'Unknown';
      }
    } catch (e) {
      // Fall through to default
    }
    return 'Unknown';
  }

  /// Get full address string from coordinates
  static Future<String> getAddressFromCoordinates(
      double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.street,
          place.locality,
          place.administrativeArea,
        ].where((p) => p != null && p.isNotEmpty).toList();
        return parts.join(', ');
      }
    } catch (e) {
      // Fall through
    }
    return 'Location not available';
  }
}
