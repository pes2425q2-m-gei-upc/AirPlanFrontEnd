// map_service.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
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
}