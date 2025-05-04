// map_service.dart
import 'dart:convert';
import 'package:airplan/transit_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'air_quality.dart';

class MapService {
  Future<List<CircleMarker>> fetchAirQualityData(Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation) async {
    final url = Uri.parse('https://analisi.transparenciacatalunya.cat/resource/tasf-thgu.json?data=${DateTime.now().toString().substring(0,10)}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return createCirclesFromAirQualityData(data, contaminantsPerLocation);
    } else {
      throw Exception('Failed to load air quality data');
    }
  }

  List<CircleMarker> createCirclesFromAirQualityData(dynamic data, Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation) {

    for (var entry in data) {
      LatLng position = LatLng(double.parse(entry['latitud']), double.parse(entry['longitud']));
      Contaminant contaminant = Contaminant.so2;
      try {
         contaminant = parseContaminant(entry['contaminant']);
         AirQualityData aqd = getLastAirQualityData(entry);
         if (contaminantsPerLocation[position] == null) {
           contaminantsPerLocation[position] = {};
         }
         if (contaminantsPerLocation[position]![contaminant] == null || aqd.lastDateHour.isAfter(contaminantsPerLocation[position]![contaminant]!.lastDateHour)) {
           contaminantsPerLocation[position]![contaminant] = aqd;
         }
      }
      catch (e) {
        continue;
      }
    }

    List<CircleMarker> circles = [];
    contaminantsPerLocation.forEach((LatLng pos, Map<Contaminant, AirQualityData> contaminants) {
      AirQuality worstAQI = AirQuality.excelent;
      contaminants.forEach((Contaminant key, AirQualityData aqd) {
        if (aqd.aqi.index > worstAQI.index) {
          worstAQI = aqd.aqi;
        }
      });
      Color color = getColorForAirQuality(worstAQI);
      circles.add(CircleMarker(
        point: pos,
        color: color,
        borderStrokeWidth: 2.0,
        borderColor: color,
        radius: 20,
      ));
    });

    return circles;
  }

  Future<String> fetchPlaceDetails(LatLng position) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['display_name'] ?? "No address found";
    } else {
      throw Exception('Failed to load place details');
    }
  }

  Future<TransitRoute> getPublicTransportRoute(bool departure, bool arrival, DateTime departureTime, DateTime arrivalTime, LatLng source, LatLng destination) async {
    return await calculatePublicTransportRoute(departure, arrival, departureTime, arrivalTime, source, destination);
  }

  Future<TransitRoute> getRoute(bool departure, bool arrival, DateTime departureTime, DateTime arrivalTime, int option, LatLng source, LatLng destination) async {
    return await calculateRoute(departure, arrival, departureTime, arrivalTime, option, source, destination);
  }

  Future<int> sendRouteToBackend(TransitRoute ruta) async {
    final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/rutas');
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final origen = <String, double>{
      'latitud': ruta.origin.latitude,
      'longitud': ruta.origin.longitude,
    };
    final desti = <String, double>{
      'latitud': ruta.destination.latitude,
      'longitud': ruta.destination.longitude,
    };

    String tipusVehicle = '';
    for (var step in ruta.steps) {
      if (step.mode == TipusVehicle.autobus || step.mode == TipusVehicle.tren || step.mode == TipusVehicle.metro) {
        tipusVehicle = 'TransportPublic';
        break;
      }
    }
    if (tipusVehicle.isEmpty) {
      tipusVehicle = translateTipusVehicle(ruta.steps.first.mode);
    }

    final body = <String, dynamic>{
      'origen': origen,
      'desti': desti,
      'client': FirebaseAuth.instance.currentUser?.displayName,
      'data': dateFormat.format(ruta.departure),
      'id': 1,
      'duracioMin': ruta.duration,
      'duracioMax': ruta.duration,
      'tipusVehicle': tipusVehicle,
    };

    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Error al crear la ruta: ${response.body}');
    }

    return json.decode(response.body);
  }

  Future<void> updateRouteInBackend(MapEntry<int, TransitRoute> route) async {
    final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/rutas/${route.key}');
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final origen = <String, double>{
      'latitud': route.value.origin.latitude,
      'longitud': route.value.origin.longitude,
    };
    final desti = <String, double>{
      'latitud': route.value.destination.latitude,
      'longitud': route.value.destination.longitude,
    };

    String tipusVehicle = '';
    for (var step in route.value.steps) {
      if (step.mode == TipusVehicle.autobus || step.mode == TipusVehicle.tren || step.mode == TipusVehicle.metro) {
        tipusVehicle = 'TransportPublic';
        break;
      }
    }
    if (tipusVehicle.isEmpty) {
      tipusVehicle = translateTipusVehicle(route.value.steps.first.mode);
    }

    final body = <String, dynamic>{
      'origen': origen,
      'desti': desti,
      'client': FirebaseAuth.instance.currentUser?.displayName,
      'data': dateFormat.format(route.value.departure),
      'id': route.key,
      'duracioMin': route.value.duration,
      'duracioMax': route.value.duration,
      'tipusVehicle': tipusVehicle,
    };

    final response = await http.put(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualitzar la ruta: ${response.body}');
    }
  }

  Future<void> deleteRouteInBackend(int routeId) async {
    final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/rutas/$routeId');
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar la ruta: ${response.body}');
    }
  }

  Future<List<Map<String,dynamic>>> fetchRoutes() async {
    final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/rutas?username=${FirebaseAuth.instance.currentUser?.displayName}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al carregar les rutes');
    }
  }

  IconData getDirectionTypeIcon(TipusInstruccio type) {
    return getDirectionIcon(type);
  }
}