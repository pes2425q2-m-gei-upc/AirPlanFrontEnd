// map_service.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'air_quality.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flexible_polyline_dart/converter.dart';
import 'package:flexible_polyline_dart/flutter_flexible_polyline.dart';
import 'package:flexible_polyline_dart/latlngz.dart';

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

  Future<List<LatLng>> getRoute(int option, LatLng source, LatLng destination) async {
    if (option == 10) {
      return _getPublicTransportRoute(source, destination);
    }
    return _getRoute(option, source, destination);
  }

  Future<List<LatLng>> _getPublicTransportRoute(LatLng source, LatLng destination) async {
    String endpoint = 'https://transit.router.hereapi.com/v8/routes';
    String key = 'jhVniBOPipoZG6-U5QE6TrXevfFn79heo_ddEw6qPe8';
    try {
      final response = await http.get(Uri.parse(endpoint).replace(queryParameters: {
        'apikey': key,
        'origin': '${source.latitude},${source.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'return': 'polyline',
      }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<LatLng> allPoints = [];

        if (data['routes'] != null) {
          for (var route in data['routes']) {
            if (route['sections'] != null) {
              for (var section in route['sections']) {
                if (section['polyline'] != null) {
                  try {
                    final List<LatLngZ> decodedPoints = FlexiblePolyline.decode(section['polyline']);
                    // Validate points before adding
                    final validPoints = decodedPoints.where((point) =>
                    point.lat >= -90 && point.lat <= 90 &&
                        point.lng >= -180 && point.lng <= 180
                    );
                    allPoints.addAll(validPoints.map((point) => LatLng(point.lat, point.lng)));
                  } catch (e) {
                    print('Error decoding polyline: $e');
                    continue;
                  }
                }
              }
            }
          }
        }

        // Return empty list if no valid points found
        if (allPoints.isEmpty) {
          print('No valid route points found');
          return [];
        }

        return allPoints;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception in _getPublicTransportRoute: $e');
      return [];
    }
  }

  Future<List<LatLng>> _getRoute(int option, LatLng source, LatLng destination) async {
    String profile = 'driving-car'; // Default profile
    switch (option) {
      case 1:
        profile = 'driving-car';
        break;
      case 2:
        profile = 'driving-hgv';
        break;
      case 3:
        profile = 'foot-walking';
        break;
      case 4:
        profile = 'foot-hiking';
        break;
      case 5:
        profile = 'cycling-regular';
        break;
      case 6:
        profile = 'cycling-road';
        break;
      case 7:
        profile = 'cycling-mountain';
        break;
      case 8:
        profile = 'cycling-electric';
        break;
      case 9:
        profile = 'wheelchair';
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
      ]
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
        final encodedPolyline = data['routes'][0]['geometry'];
        final decodedPoints = PolylinePoints().decodePolyline(encodedPolyline);
        return decodedPoints.map((point) =>
            LatLng(point.latitude, point.longitude)).toList();
      } else {
        throw Exception('Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Exception: $e');
    }
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