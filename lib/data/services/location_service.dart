// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Get current location once
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // works in Geolocator 12.x
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Listen to location changes
  static Stream<Position> getPositionStream({int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
