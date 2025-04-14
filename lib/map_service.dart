// map_service.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'air_quality.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

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
    const String apiKey = '5b3ce3597851110001cf624894358dbf577d491caa423c03348f27d2'; // Replace with your API key
    String profile = 'driving-car'; // Default profile
    switch (option) {
      case 1:
        profile = 'driving-car';
        break;
      case 3:
        profile = 'foot-walking';
        break;
      default:
        throw Exception('Invalid option');
    }
    String endpoint = 'https://api.openrouteservice.org/v2/directions/$profile';

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
          'Authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final encodedPolyline = data['routes'][0]['geometry'];
        final decodedPoints = PolylinePoints().decodePolyline(encodedPolyline);
        return decodedPoints.map((point) => LatLng(point.latitude, point.longitude)).toList();
      } else {
        throw Exception('Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Exception: $e');
    }
  }
}