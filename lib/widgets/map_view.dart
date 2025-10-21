import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapView extends StatelessWidget {
  final LatLng center;
  final double radiusM;
  final LatLng? current;

  const MapView({
    super.key,
    required this.center,
    required this.radiusM,
    this.current,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 17,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.peyek_absensi',
        ),
        // Lingkaran geofence (meter)
        CircleLayer(
          circles: [
            CircleMarker(
              point: center,
              radius: radiusM,
              useRadiusInMeter: true,
              color: Colors.teal.withOpacity(0.15),
              borderColor: Colors.teal,
              borderStrokeWidth: 2,
            ),
          ],
        ),
        // Penanda titik pusat & posisi user (jika ada)
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child:
                  const Icon(Icons.location_on, color: Colors.teal, size: 36),
            ),
            if (current != null)
              Marker(
                point: current!,
                width: 36,
                height: 36,
                child: const Icon(Icons.my_location, size: 28),
              ),
          ],
        ),
      ],
    );
  }
}
