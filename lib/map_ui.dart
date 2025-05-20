import 'dart:math' as math;

import 'package:airplan/transit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';

class MapUI extends StatelessWidget {
  final MapController mapController;
  final LatLng currentPosition;
  final List<CircleMarker> circles;
  final Function(TapPosition, LatLng) onMapTapped;
  final List<Map<String, dynamic>> activities;
  final Function(Map<String, dynamic>) onActivityTap;
  final List<Marker> markers;
  final List<LatLng>? route; // Make route nullable
  final List<TransitStep>? steps;
  final double? userHeading;
  final bool isNavigationMode;

  const MapUI({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.circles,
    required this.markers,
    required this.onMapTapped,
    required this.activities,
    required this.onActivityTap,
    this.route,
    this.steps, // Add this parameter
    this.userHeading,
    required this.isNavigationMode,
  });

  @override
  Widget build(BuildContext context) {
    // Group activities by location
    final Map<String, List<Map<String, dynamic>>> groupedActivities = {};

    for (var activity in activities) {
      final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
      final lat = ubicacio['latitud'] as double;
      final lon = ubicacio['longitud'] as double;
      final key = '$lat,$lon';

      if (!groupedActivities.containsKey(key)) {
        groupedActivities[key] = [];
      }
      groupedActivities[key]!.add(activity);
    }

    // Create activity markers based on grouped activities
    final List<Marker> activityMarkers = [];

    groupedActivities.forEach((locationKey, activitiesList) {
      final coords = locationKey.split(',');
      final lat = double.parse(coords[0]);
      final lon = double.parse(coords[1]);

      if (activitiesList.length == 1) {
        // For single activities, show regular icon
        activityMarkers.add(
          Marker(
            width: 40.0,
            height: 40.0,
            point: LatLng(lat, lon),
            child: GestureDetector(
              onTap: () => onActivityTap(activitiesList.first),
              child: Icon(Icons.event, color: Colors.blue, size: 40),
            ),
          ),
        );
      } else {
        // For multiple activities, show number badge
        activityMarkers.add(
          Marker(
            width: 40.0,
            height: 40.0,
            point: LatLng(lat, lon),
            child: GestureDetector(
              onTap: () => _showActivitiesDialog(context, activitiesList),
              child: Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    activitiesList.length.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });

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
        MarkerLayer(markers: [...markers, ...activityMarkers]),
        if (steps != null && steps!.isNotEmpty)
          PolylineLayer(
            polylines:
                steps!
                    .map(
                      (step) => Polyline(
                        points: step.points,
                        strokeWidth: 4.0,
                        color: step.color,
                      ),
                    )
                    .toList(),
          ),
        if (userHeading != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentPosition,
                width: 60.0,
                height: 60.0,
                child: Transform.rotate(
                  angle:
                      (userHeading! *
                          (math.pi / 180)), // Convert degrees to radians
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.blue,
                    size: 40.0,
                  ),
                ),
              ),
            ],
          ),
        Positioned(
          top: isNavigationMode ? 0 : 65,
          child: const MapCompass.cupertino(
            hideIfRotatedNorth: true,
            alignment: Alignment.topLeft,
          ),
        ),
      ],
    );
  }

  void _showActivitiesDialog(
    BuildContext context,
    List<Map<String, dynamic>> activities,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Activities at this location'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return ListTile(
                  title: Text(activity['nom'] ?? 'Unnamed activity'),
                  onTap: () {
                    Navigator.pop(context);
                    onActivityTap(activity);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
