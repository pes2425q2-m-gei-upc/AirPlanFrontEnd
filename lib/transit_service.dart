import 'dart:convert';
import 'dart:ui';
import 'package:flexible_polyline_dart/flutter_flexible_polyline.dart';
import 'package:flexible_polyline_dart/latlngz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum TipusVehicle {
  cotxe,
  moto,
  metro,
  tren,
  autobus,
  bicicleta,
  cap
}

class TransitStep {
  final TipusVehicle mode;
  final String instruction;
  final String line;
  final String departure;
  final String arrival;
  final List<LatLng> points;
  final String station;
  final Color color;

  TransitStep({
    required this.mode,
    required this.instruction,
    required this.line,
    required this.departure,
    required this.arrival,
    required this.points,
    required this.station,
    required this.color,
  });
}

class TransitRoute {
  final List<LatLng> fullRoute;
  final List<TransitStep> steps;
  final String duration;
  final String distance;

  TransitRoute({
    required this.fullRoute,
    required this.steps,
    required this.duration,
    required this.distance,
  });
}

Future<TransitRoute> calculatePublicTransportRoute(LatLng source, LatLng destination) async {
  String hereEndpoint = 'https://transit.router.hereapi.com/v8/routes';
  String hereKey = 'jhVniBOPipoZG6-U5QE6TrXevfFn79heo_ddEw6qPe8';

  try {
    final response = await http.get(Uri.parse(hereEndpoint).replace(queryParameters: {
      'apikey': hereKey,
      'origin': '${source.latitude},${source.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'return': 'polyline,actions,travelSummary'
    }));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<LatLng> allPoints = [];
      List<TransitStep> steps = [];

      if (data['routes']?[0] != null) {
        final route = data['routes'][0];
        final sections = route['sections'];
        double totalDurationD = 0.0;
        double totalDistanceD = 0.0;
        for (var section in sections) {
          totalDurationD += section["travelSummary"]["duration"];
          totalDistanceD += section["travelSummary"]["length"];
        }
        totalDurationD = (totalDurationD / 60).roundToDouble();
        String totalDuration = '$totalDurationD min';
        String totalDistance = '$totalDistanceD m';

        for (var section in sections) {
          String mode = section['transport']['mode'];
          List<LatLng> sectionPoints = [];

          if (mode == 'pedestrian') {
            // Use OpenRouteService for walking segments
            final walkStart = section['departure']['place']['location'];
            final walkEnd = section['arrival']['place']['location'];
            try {
              final walkingRoute = await calculateRoute(
                  3,
                  LatLng(walkStart['lat'], walkStart['lng']),
                  LatLng(walkEnd['lat'], walkEnd['lng']),
              );
              sectionPoints = walkingRoute.fullRoute;
              // Add detailed walking steps
              for (var step in walkingRoute.steps) {
                steps.add(TransitStep(
                  mode: TipusVehicle.cap,
                  instruction: step.instruction,
                  line: '',
                  departure: section['departure']['time'] ?? '',
                  arrival: section['arrival']['time'] ?? '',
                  points: sectionPoints, // Could be enhanced to include segment points
                  station: '',
                  color: Colors.blue, // Default color for walking
                ));
              }
            } catch (e) {
              // Fallback to HERE polyline if ORS fails
              final polyline = section['polyline'];
              if (polyline != null) {
                final List<LatLngZ> decoded = FlexiblePolyline.decode(polyline);
                sectionPoints = decoded
                    .map((point) => LatLng(point.lat, point.lng))
                    .where((point) =>
                point.latitude.abs() <= 90 &&
                    point.longitude.abs() <= 180)
                    .toList();
              }
            }
          } else {
            // Decode HERE transit polyline
            final polyline = section['polyline'];
            if (polyline != null) {
              final List<LatLngZ> decoded = FlexiblePolyline.decode(polyline);
              sectionPoints = decoded
                  .map((point) => LatLng(point.lat, point.lng))
                  .where((point) =>
              point.latitude.abs() <= 90 &&
                  point.longitude.abs() <= 180)
                  .toList();
            }
          }

          // Add step if we have valid points
          if (sectionPoints.isNotEmpty) {
            steps.add(TransitStep(
              mode: _translateMode(mode),
              instruction: _getInstruction(section),
              line: section['transport']?['name'] ?? '',
              departure: section['departure']['time'] ?? '',
              arrival: section['arrival']['time'] ?? '',
              points: sectionPoints,
              station: section['departure']['place']['name'] ?? '',
              color: _translateColor(section)
            ));
            allPoints.addAll(sectionPoints);
          }
        }

        return TransitRoute(
          fullRoute: allPoints,
          steps: steps,
          duration: totalDuration,
          distance: totalDistance,
        );
      }
    }
    throw Exception('Failed to fetch route');
  } catch (e) {
    throw Exception('Error calculating route: $e');
  }
}

Color _translateColor(Map<String, dynamic> section) {
  if (section['type'] == 'pedestrian') {
    return Colors.blue; // Default color for walking
  }
  else if (section['transport'].containsKey('color')) {
    String color = section['transport']['color'];
    final hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
  else {
    switch(section['transport']['mode']) {
      case 'car':
        return Colors.red;
      case 'bus':
        return Colors.green;
      case 'train':
        return Colors.orange;
      case 'bike':
        return Colors.purple;
      default:
        return Colors.grey; // Default color for unknown modes
    }
  }
}

TipusVehicle _translateMode(String mode) {
  switch (mode) {
    case 'car':
      return TipusVehicle.cotxe;
    case 'bus':
      return TipusVehicle.autobus;
    case 'regionalTrain':
      return TipusVehicle.tren;
    case 'bike':
      return TipusVehicle.bicicleta;
    case 'pedestrian':
      return TipusVehicle.cap;
    case 'subway':
      return TipusVehicle.metro;
    default:
      return TipusVehicle.cap; // Default to "cap" for unknown modes
  }
}

String _getInstruction(Map<String, dynamic> section) {
  if (section['type'] == 'pedestrian') {
    return 'Camina fins a ${section['arrival']['place']['name'] ?? 'la teva destinacio'}';
  }
  return 'Agafa un ${section['transport']['name'] ?? 'transit'} fins a ${section['arrival']['place']['name'] ?? 'el teu desti'}';
}

Future<TransitRoute> calculateRoute(int option, LatLng source, LatLng destination) async {
  String profile = 'driving-car'; // Default profile
  TipusVehicle vehicleType = TipusVehicle.cap;
  Color color = Colors.red;
  switch (option) {
    case 1:
      profile = 'driving-car';
      vehicleType = TipusVehicle.cotxe;
      color = Colors.red;
      break;
    case 2:
      profile = 'driving-car';
      vehicleType = TipusVehicle.moto;
      color = Colors.black;
      break;
    case 3:
      profile = 'foot-walking';
      vehicleType = TipusVehicle.cap;
      color = Colors.blue;
      break;
    case 4:
      profile = 'cycling-regular';
      vehicleType = TipusVehicle.bicicleta;
      color = Colors.pinkAccent;
      break;
    default:
      throw Exception('Invalid option');
  }
  String endpoint = 'https://api.openrouteservice.org/v2/directions/$profile';
  String key = '5b3ce3597851110001cf624894358dbf577d491caa423c03348f27d2';
  final Map<String, dynamic> body = {
    "coordinates": [
      [source.longitude, source.latitude],
      [destination.longitude, destination.latitude]
    ],
    'instructions': true,
    'language': "es-es"
  };

  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': key,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final route = data['routes'][0];
      final summary = route['summary'];
      final segments = route['segments'][0];

      final List<LatLng> fullRoute = PolylinePoints()
          .decodePolyline(route['geometry'])
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      List<TransitStep> steps = [];
      for (var step in segments['steps']) {
        steps.add(TransitStep(
          mode: vehicleType,
          instruction: step['instruction'],
          line: '',
          departure: '',
          arrival: '',
          points: fullRoute, // Steps don't include individual geometries in this response
          station: step['name'] ?? '',
          color: color, // Default color for driving
        ));
      }

      return TransitRoute(
        fullRoute: fullRoute,
        steps: steps,
        duration: '${(summary['duration'] / 60).round()} min',
        distance: '${(summary['distance'] / 1000).toStringAsFixed(2)} km',
      );
    } else {
      throw Exception('Error: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    throw Exception('Exception: $e');
  }
}