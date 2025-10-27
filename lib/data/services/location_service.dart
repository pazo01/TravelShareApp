import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> safeGetCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }
}
