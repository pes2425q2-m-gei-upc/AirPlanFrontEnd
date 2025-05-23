import 'dart:convert';
import 'package:airplan/services/api_config.dart';
import 'package:flexible_polyline_dart/flutter_flexible_polyline.dart';
import 'package:flexible_polyline_dart/latlngz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';

enum TipusVehicle { cotxe, moto, metro, tren, autobus, bicicleta, cap }

enum TipusInstruccio {
  esquerra,
  dreta,
  esquerraBrusca,
  dretaBrusca,
  esquerraSuau,
  dretaSuau,
  recta,
  entrarRotonda,
  sortirRotonda,
  girEnU,
  destinacio,
  sortida,
  mantenirEsquerra,
  mantenirDreta,
  transportPublic,
}

class TransitStep {
  final TipusVehicle mode;
  final String instruction;
  final TipusInstruccio type;
  final String line;
  final DateTime departure;
  final DateTime arrival;
  final double distance;
  final List<LatLng> points;
  final String station;
  final Color color;

  TransitStep({
    required this.mode,
    required this.instruction,
    required this.type,
    required this.line,
    required this.departure,
    required this.arrival,
    required this.distance,
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

Future<TransitRoute> calculatePublicTransportRoute(
  bool departure,
  bool arrival,
  DateTime departureTime,
  DateTime arrivalTime,
  LatLng source,
  LatLng destination,
) async {
  final url = Uri.parse(
    ApiConfig().buildUrl('api/rutas/calculate/publictransport'),
  );

  try {
    final response = await http.get(
      url.replace(
        queryParameters: {
          'origin': '${source.latitude},${source.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'departureTime':
              departure
                  ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(departureTime)
                  : DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now()),
          if (arrival)
            'arrivalTime': DateFormat(
              'yyyy-MM-ddTHH:mm:ss',
            ).format(arrivalTime),
          'return': 'polyline,actions,travelSummary',
          'lang': 'ca',
        },
      ),
    );

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
                true,
                false,
                DateTime.parse(
                  section['departure']['time'],
                ).add(Duration(hours: 2)),
                DateTime.now(),
                3,
                LatLng(walkStart['lat'], walkStart['lng']),
                LatLng(walkEnd['lat'], walkEnd['lng']),
              );
              sectionPoints = walkingRoute.fullRoute;
              // Add detailed walking steps
              for (var step in walkingRoute.steps) {
                steps.add(step);
              }
            } catch (e) {
              // Fallback to HERE polyline if ORS fails
              final polyline = section['polyline'];
              if (polyline != null) {
                final List<LatLngZ> decoded = FlexiblePolyline.decode(polyline);
                sectionPoints =
                    decoded
                        .map((point) => LatLng(point.lat, point.lng))
                        .where(
                          (point) =>
                              point.latitude.abs() <= 90 &&
                              point.longitude.abs() <= 180,
                        )
                        .toList();
              }
            }
          } else {
            // Decode HERE transit polyline
            final polyline = section['polyline'];
            if (polyline != null) {
              final List<LatLngZ> decoded = FlexiblePolyline.decode(polyline);
              sectionPoints =
                  decoded
                      .map((point) => LatLng(point.lat, point.lng))
                      .where(
                        (point) =>
                            point.latitude.abs() <= 90 &&
                            point.longitude.abs() <= 180,
                      )
                      .toList();
            }
            if (sectionPoints.isNotEmpty) {
              steps.add(
                TransitStep(
                  mode: _translateMode(mode),
                  instruction: _getInstruction(section),
                  type: TipusInstruccio.transportPublic,
                  line: section['transport']?['name'] ?? '',
                  departure: DateTime.parse(
                    section['departure']['time'],
                  ).add(Duration(hours: 2)),
                  arrival: DateTime.parse(
                    section['arrival']['time'],
                  ).add(Duration(hours: 2)),
                  distance: section['travelSummary']['length'].toDouble(),
                  points: sectionPoints,
                  station: section['departure']['place']['name'] ?? '',
                  color: _translateColor(section),
                ),
              );
              allPoints.addAll(sectionPoints);
            }
          }
        }

        return TransitRoute(
          fullRoute: allPoints,
          steps: steps,
          duration: totalDuration,
          distance: totalDistance,
          departure: DateTime.parse(
            sections[0]['departure']['time'],
          ).add(Duration(hours: 2)),
          arrival: DateTime.parse(
            sections[sections.length - 1]['arrival']['time'],
          ).add(Duration(hours: 2)),
          origin: source,
          destination: destination,
          option: 10,
        );
      }
    }
    throw Exception('transit_service_error_fetch_route'.tr());
  } catch (e) {
    throw Exception('${'transit_service_error_calculating_route'.tr()}: $e');
  }
}

Color _translateColor(Map<String, dynamic> section) {
  if (section['type'] == 'pedestrian') {
    return Colors.blue; // Default color for walking
  } else if (section['transport'].containsKey('color')) {
    String color = section['transport']['color'];
    final hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  } else {
    switch (section['transport']['mode']) {
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

TipusInstruccio _translateType(int type) {
  switch (type) {
    case 0:
      return TipusInstruccio.esquerra;
    case 1:
      return TipusInstruccio.dreta;
    case 2:
      return TipusInstruccio.esquerraBrusca;
    case 3:
      return TipusInstruccio.dretaBrusca;
    case 4:
      return TipusInstruccio.esquerraSuau;
    case 5:
      return TipusInstruccio.dretaSuau;
    case 6:
      return TipusInstruccio.recta;
    case 7:
      return TipusInstruccio.entrarRotonda;
    case 8:
      return TipusInstruccio.sortirRotonda;
    case 9:
      return TipusInstruccio.girEnU;
    case 10:
      return TipusInstruccio.destinacio;
    case 11:
      return TipusInstruccio.sortida;
    case 12:
      return TipusInstruccio.mantenirEsquerra;
    case 13:
      return TipusInstruccio.mantenirDreta;
    default:
      throw Exception('Unknown instruction type');
  }
}

String _getInstruction(Map<String, dynamic> section) {
  final arrivalPlaceName = section['arrival']?['place']?['name'];
  final transportName = section['transport']?['name'];

  if (section['type'] == 'pedestrian') {
    return 'transit_service_walk_to'.tr(
      args: [arrivalPlaceName ?? 'transit_service_your_destination'.tr()],
    );
  }
  return 'transit_service_take_transport_to'.tr(
    args: [
      transportName ?? 'transit_service_transit_default'.tr(),
      arrivalPlaceName ?? 'transit_service_your_destination'.tr(),
    ],
  );
}

Future<TransitRoute> calculateRoute(
  bool departure,
  bool arrival,
  DateTime departureTime,
  DateTime arrivalTime,
  int option,
  LatLng source,
  LatLng destination,
) async {
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

  final url = Uri.parse(ApiConfig().buildUrl('api/rutas/calculate/simple'));

  try {
    final response = await http.get(
      url.replace(
        queryParameters: {
          'profile': profile,
          'origin': '${source.latitude},${source.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'language': "es-es",
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final route = data['routes'][0];
      final summary = route['summary'];
      final segments = route['segments'][0];

      final List<LatLng> fullRoute =
          PolylinePoints()
              .decodePolyline(route['geometry'])
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

      DateTime salida;
      DateTime llegada;
      if (departure) {
        if (DateTime.now().isAfter(departureTime)) {
          throw Exception(
            'transit_service_error_time_travel_departure'.tr(
              args: [DateFormat.Hm().format(DateTime.now())],
            ),
          );
        }
        salida = departureTime;
        llegada = salida.add(
          Duration(minutes: (summary['duration'] / 60).round()),
        );
      } else if (arrival) {
        if (DateTime.now()
            .add(Duration(minutes: (summary['duration'] / 60).round()))
            .isAfter(arrivalTime)) {
          throw Exception(
            'transit_service_error_time_travel_arrival'.tr(
              args: [
                DateFormat.Hm().format(
                  DateTime.now().add(
                    Duration(minutes: (summary['duration'] / 60).round()),
                  ),
                ),
              ],
            ),
          );
        }
        llegada = arrivalTime;
        salida = llegada.subtract(
          Duration(minutes: (summary['duration'] / 60).round()),
        );
      } else {
        salida = DateTime.now();
        llegada = salida.add(
          Duration(minutes: (summary['duration'] / 60).round()),
        );
      }

      List<TransitStep> steps = [];
      DateTime salidaTemp = salida;
      DateTime llegadaTemp = salidaTemp;
      for (var step in segments['steps']) {
        llegadaTemp = salidaTemp.add(
          Duration(
            minutes: (step['duration'] / 60).toInt(),
            seconds: (step['duration'] % 60).toInt(),
          ),
        );
        double distance = step['distance'];
        // Extract points for this specific step using waypoint indices
        var waypoints = [step['way_points'][0], step['way_points'][1]];
        var stepPoints = fullRoute.sublist(waypoints[0], waypoints[1] + 1);
        TipusInstruccio type = _translateType(step['type']);
        steps.add(
          TransitStep(
            mode: vehicleType,
            instruction: step['instruction'],
            type: type,
            line: '',
            departure: salidaTemp,
            arrival: llegadaTemp,
            distance: distance,
            points: stepPoints,
            station: '',
            color: color, // Default color for driving
          ),
        );
        salidaTemp = llegadaTemp;
      }
      return TransitRoute(
        fullRoute: fullRoute,
        steps: steps,
        duration: (summary['duration'] / 60).round(),
        distance: (summary['distance']).round(),
        departure: salida,
        arrival: llegada,
        origin: source,
        destination: destination,
        option: option,
      );
    } else {
      throw Exception(
        'transit_service_error_status'.tr(
          args: ['${response.statusCode}', response.body],
        ),
      );
    }
  } catch (e) {
    throw Exception('${'transit_service_exception'.tr()}: $e');
  }
}

String translateTipusVehicle(TipusVehicle tipus) {
  switch (tipus) {
    case TipusVehicle.cotxe:
      return 'vehicle_type_car'.tr();
    case TipusVehicle.moto:
      return 'vehicle_type_motorcycle'.tr();
    case TipusVehicle.metro:
      return 'vehicle_type_metro'.tr();
    case TipusVehicle.tren:
      return 'vehicle_type_train'.tr();
    case TipusVehicle.autobus:
      return 'vehicle_type_bus'.tr();
    case TipusVehicle.bicicleta:
      return 'vehicle_type_bicycle'.tr();
    default:
      return 'vehicle_type_none'.tr(); // Default case
  }
}

IconData getDirectionIcon(TipusInstruccio type) {
  switch (type) {
    case TipusInstruccio.esquerra:
      return Icons.turn_left;
    case TipusInstruccio.dreta:
      return Icons.turn_right;
    case TipusInstruccio.esquerraBrusca:
      return Icons.turn_sharp_left;
    case TipusInstruccio.dretaBrusca:
      return Icons.turn_sharp_right;
    case TipusInstruccio.esquerraSuau:
      return Icons.turn_slight_left;
    case TipusInstruccio.dretaSuau:
      return Icons.turn_slight_right;
    case TipusInstruccio.recta:
      return Icons.straight;
    case TipusInstruccio.entrarRotonda:
      return Icons.roundabout_left;
    case TipusInstruccio.sortirRotonda:
      return Icons.roundabout_right;
    case TipusInstruccio.girEnU:
      return Icons.u_turn_left;
    case TipusInstruccio.destinacio:
      return Icons.place;
    case TipusInstruccio.sortida:
      return Icons.exit_to_app;
    case TipusInstruccio.mantenirEsquerra:
      return Icons.fork_left;
    case TipusInstruccio.mantenirDreta:
      return Icons.fork_right;
    default:
      return Icons.arrow_forward;
  }
}
