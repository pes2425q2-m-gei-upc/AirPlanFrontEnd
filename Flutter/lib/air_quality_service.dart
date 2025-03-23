//air_quality_service.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'air_quality.dart';

class AirQualityService {
  static Future<List<CircleMarker>> fetchAirQualityData(contaminantsPerLocation) async {
    final url = Uri.parse('https://analisi.transparenciacatalunya.cat/resource/tasf-thgu.json?data=${DateTime.now().toString().substring(0, 10)}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return createCirclesFromAirQualityData(data, contaminantsPerLocation);
    } else {
      throw Exception('Failed to load air quality data');
    }
  }

  static List<CircleMarker> createCirclesFromAirQualityData(dynamic data, contaminantsPerLocation) {
    for (var entry in data) {
      LatLng position = LatLng(
          double.parse(entry['latitud']), double.parse(entry['longitud']));
      Contaminant contaminant = Contaminant.SO2;
      try {
        contaminant = parseContaminant(entry['contaminant']);
        AirQualityData aqd = getLastAirQualityData(entry);
        //guarda el valor de la última hora pel contaminant que s'ha mesurat
        if (contaminantsPerLocation[position] == null) {
          Map<Contaminant, AirQualityData> contaminants = {};
          contaminantsPerLocation[position] = contaminants;
        }
        if (contaminantsPerLocation[position]![contaminant] == null ||
            (aqd.lastDateHour.isAfter(
                contaminantsPerLocation[position]?[contaminant]!
                    .lastDateHour as DateTime))) {
          contaminantsPerLocation[position]?[contaminant] = aqd;
        }
      } catch (e) {
        //TODO informar de que hi ha un contaminant desconegut i no es mostrarà
      }
    }
    List<CircleMarker> circles = [];
    contaminantsPerLocation.forEach((LatLng pos,Map<Contaminant,AirQualityData> contaminants) {
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
        radius: 20, // Radius in pixels
      ));
    });

    return circles;
  }
}