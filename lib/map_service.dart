// map_service.dart
import 'dart:convert';
import 'dart:ui';
import 'package:airplan/transit_service.dart';
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

  Future<TransitRoute> getPublicTransportRoute(LatLng source, LatLng destination) async {
    return await calculatePublicTransportRoute(source, destination);
  }

  Future<TransitRoute> getRoute(int option, LatLng source, LatLng destination) async {
    return await calculateRoute(option, source, destination);
  }

  Future<void> sendRouteToBackend(Map<String, String> rutaData) async {
    final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/rutas/crear');
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final origen = <String, double>{
      'latitud': double.parse(rutaData['origen']!.split(',')[0]),
      'longitud': double.parse(rutaData['origen']!.split(',')[1]),
    };
    final desti = <String, double>{
      'latitud': double.parse(rutaData['desti']!.split(',')[0]),
      'longitud': double.parse(rutaData['desti']!.split(',')[1]),
    };

    final body = <String, dynamic>{
      'origen': origen,
      'desti': desti,
      'clientUsername': rutaData['clientUsername']!,
      'data': dateFormat.format(DateTime.parse(rutaData['data']!)),
      'duracioMin': rutaData['duracioMin']!,
      'duracioMax': rutaData['duracioMax']!,
      'tipusVehicle': rutaData['tipusVehicle']!,
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
  }

  Future<List<dynamic>> fetchRoutes() {
    final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/rutas');
    return http.get(url).then((response) {
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> rutes = [];
        for (var entry in data) {
          final origen = LatLng(entry['origen']['latitud'], entry['origen']['longitud']);
          final desti = LatLng(entry['desti']['latitud'], entry['desti']['longitud']);
          final ruta = {
            'origen': origen,
            'desti': desti,
            'clientUsername': entry['clientUsername'],
            'data': entry['data'],
            'duracioMin': entry['duracioMin'],
            'duracioMax': entry['duracioMax'],
            'tipusVehicle': entry['tipusVehicle'],
          };
          rutes.add(ruta);
        }
        return rutes;
      } else {
        throw Exception('Failed to load routes');
      }
    }).catchError((error) {
      throw Exception('Error fetching routes: $error');
    });
  }
}