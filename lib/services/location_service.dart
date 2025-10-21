import 'package:geolocator/geolocator.dart';

class LocationService {
  static bool isMocked(Position p) {
    // geolocator menyediakan p.isMocked (true di Android bila mock location)
    try {
      return p.isMocked;
    } catch (_) {
      return false; // platform selain Android/versi lama
    }
  }

  /// Memastikan izin lokasi diberikan & layanan lokasi aktif.
  static Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Di desktop bisa saja selalu true; di Android minta user aktifkan GPS
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  /// Ambil posisi saat ini (akurasi tinggi).
  static Future<Position> current() async {
    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  /// Hitung jarak (meter) antara 2 titik.
  static double distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
