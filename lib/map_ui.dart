import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapUI extends StatelessWidget {
  final MapController mapController;
  final LatLng currentPosition;
  final List<CircleMarker> circles;
  final Function(TapPosition, LatLng) onMapTapped;
  final List<Map<String, dynamic>> activities;
  final Function(Map<String, dynamic>) onActivityTap;
  final List<Marker> markers;
  final List<LatLng>? route; // Make route nullable

  const MapUI({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.circles,
    required this.markers,
    required this.onMapTapped,
    required this.activities,
    required this.onActivityTap,
    this.route, // Optional parameter
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: currentPosition,
        initialZoom: 15.0,
        onTap: (tapPosition, latLng) => onMapTapped(tapPosition, latLng),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        ),
        CircleLayer(circles: circles),
        MarkerLayer(
          markers: [
            ...markers,
            ...activities.map((activity) {
              final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
              final lat = ubicacio['latitud'] as double;
              final lon = ubicacio['longitud'] as double;
              return Marker(
                point: LatLng(lat, lon),
                child: GestureDetector(
                  onTap: () => onActivityTap(activity),
                  child: Icon(Icons.event, color: Colors.blue, size: 40),
                ),
              );
            }),
          ],
        ),
        if (route != null && route!.isNotEmpty) // Check if route is not null and not empty
          PolylineLayer(
            polylines: [
              Polyline(
                points: route!,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
      ],
    );
  }
}