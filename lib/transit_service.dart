import 'dart:convert';
import 'package:flexible_polyline_dart/flutter_flexible_polyline.dart';
import 'package:flexible_polyline_dart/latlngz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  final List<String> instructions;
  final String line;
  final DateTime departure;
  final DateTime arrival;
  final List<LatLng> points;
  final String station;
  final Color color;

  TransitStep({
    required this.mode,
    required this.instructions,
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
  final int duration;
  final int distance;
  final DateTime departure;
  final DateTime arrival;
  final LatLng origin;
  final LatLng destination;
  final int option;

  TransitRoute({
    required this.fullRoute,
    required this.steps,
    required this.duration,
    required this.distance,
    required this.departure,
    required this.arrival,
    required this.origin,
    required this.destination,
    required this.option,
  });
}

Future<TransitRoute> calculatePublicTransportRoute(bool departure, bool arrival, DateTime departureTime, DateTime arrivalTime, LatLng source, LatLng destination) async {
  String hereEndpoint = 'http://nattech.fib.upc.edu:40350/api/rutas/calculate/publictransport';

  try {
    final response = await http.get(Uri.parse(hereEndpoint).replace(queryParameters: {
      'origin': '${source.latitude},${source.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'departureTime': departure ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(departureTime) : DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now()),
      if (arrival) 'arrivalTime': DateFormat('yyyy-MM-ddTHH:mm:ss').format(arrivalTime),
      'return': 'polyline,actions,travelSummary',
      'lang': 'ca'
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
        int totalDuration = totalDurationD.round();
        int totalDistance = totalDistanceD.round();

        for (var section in sections) {
          String mode = section['transport']['mode'];
          List<LatLng> sectionPoints = [];

          if (mode == 'pedestrian') {
            // Use OpenRouteService for walking segments
            final walkStart = section['departure']['place']['location'];
            final walkEnd = section['arrival']['place']['location'];
            try {
              final walkingRoute = await calculateRoute(
                false,
                false,
                DateTime.now(),
                DateTime.now(),
                3,
                LatLng(walkStart['lat'], walkStart['lng']),
                LatLng(walkEnd['lat'], walkEnd['lng']),
              );
              sectionPoints = walkingRoute.fullRoute;
              // Add detailed walking steps
              for (var step in walkingRoute.steps) {
                steps.add(TransitStep(
                    mode: _translateMode(mode), 
                    instructions: step.instructions, 
                    line: '',
                    departure: DateTime.parse(section['departure']['time']).add(Duration(hours: 2)),
                    arrival: DateTime.parse(section['arrival']['time']).add(Duration(hours: 2)),
                    points: step.points, 
                    station: '', 
                    color: step.color));
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
            if (sectionPoints.isNotEmpty) {
              List<String> instructions = [_getInstruction(section)];
              steps.add(TransitStep(
                  mode: _translateMode(mode),
                  instructions: instructions,
                  line: section['transport']?['name'] ?? '',
                  departure: DateTime.parse(section['departure']['time']).add(Duration(hours: 2)),
                  arrival: DateTime.parse(section['arrival']['time']).add(Duration(hours: 2)),
                  points: sectionPoints,
                  station: section['departure']['place']['name'] ?? '',
                  color: _translateColor(section)
              ));
              allPoints.addAll(sectionPoints);
            }
          }
        }

        return TransitRoute(
          fullRoute: allPoints,
          steps: steps,
          duration: totalDuration,
          distance: totalDistance,
          departure: DateTime.parse(sections[0]['departure']['time']).add(Duration(hours: 2)),
          arrival: DateTime.parse(sections[sections.length - 1]['arrival']['time']).add(Duration(hours: 2)),
          origin: source,
          destination: destination,
          option: 10
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

Future<TransitRoute> calculateRoute(bool departure, bool arrival, DateTime departureTime, DateTime arrivalTime, int option, LatLng source, LatLng destination) async {
  String profile = 'foot-walking'; // Default profile
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

  String orsEndpoint = 'http://nattech.fib.upc.edu:40350/api/rutas/calculate/simple';

  try {
    final response = await http.get(Uri.parse(orsEndpoint).replace(queryParameters: {
      'profile': profile,
      'origin': '${source.latitude},${source.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'language': "es-es"
    }));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final route = data['routes'][0];
      final summary = route['summary'];
      final segments = route['segments'][0];

      final List<LatLng> fullRoute = PolylinePoints()
          .decodePolyline(route['geometry'])
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      List<String> instructions = [];
      for (var step in segments['steps']) {
        instructions.add(step['instruction']);
      }
      DateTime salida;
      DateTime llegada;
      if (departure) {
        if (DateTime.now().isBefore(departureTime)) {
          throw Exception("No és possible viatjar en el temps, l'hora de sortida més aviat possible és a les ${DateFormat.Hm().format(DateTime.now())}");
        }
        salida = departureTime;
        llegada = salida.add(Duration(minutes: (summary['duration'] / 60).round()));
      } else if (arrival) {
        if (DateTime.now().add(Duration(minutes: (summary['duration'] / 60).round())).isAfter(arrivalTime)) {
          throw Exception("No és possible arribar a temps, l'hora d'arribada més aviat possible és a les ${DateFormat.Hm().format(DateTime.now().add(Duration(minutes: (summary['duration'] / 60).round())))}");
        }
        llegada = arrivalTime;
        salida = llegada.subtract(Duration(minutes: (summary['duration'] / 60).round()));
      } else {
        salida = DateTime.now();
        llegada = salida.add(Duration(minutes: (summary['duration'] / 60).round()));
      }
      List<TransitStep> steps = [TransitStep(
        mode: vehicleType,
        instructions: instructions,
        line: '',
        departure: salida,
        arrival: llegada,
        points: fullRoute, // Steps don't include individual geometries in this response
        station: '',
        color: color, // Default color for driving
      )];
      return TransitRoute(
        fullRoute: fullRoute,
        steps: steps,
        duration: (summary['duration'] / 60).round(),
        distance: (summary['distance']).round(),
        departure: salida,
        arrival: llegada,
        origin: source,
        destination: destination,
        option: option
      );
    } else {
      throw Exception('Error: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    throw Exception('Exception: $e');
  }
}

String translateTipusVehicle(TipusVehicle tipus) {
  switch (tipus) {
    case TipusVehicle.cotxe:
      return 'Cotxe';
    case TipusVehicle.moto:
      return 'Moto';
    case TipusVehicle.metro:
      return 'Metro';
    case TipusVehicle.tren:
      return 'Tren';
    case TipusVehicle.autobus:
      return 'Autobus';
    case TipusVehicle.bicicleta:
      return 'Bicicleta';
    default:
      return 'Cap'; // Default case
  }
}