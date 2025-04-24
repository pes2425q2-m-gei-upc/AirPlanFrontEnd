// activity_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'services/api_config.dart'; // Importar la configuración de API

class ActivityService {
  Future<List<Map<String, dynamic>>> fetchActivities() async {
    final url = Uri.parse(ApiConfig().buildUrl('api/activitats'));
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al cargar las actividades');
    }
  }

  Future<void> sendActivityToBackend(Map<String, String> activityData) async {
    final url = Uri.parse(ApiConfig().buildUrl('api/activitats/crear'));
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final ubicacioParts = activityData['location']!.split(',');
    final ubicacio = <String, double>{
      'latitud': double.parse(ubicacioParts[0]),
      'longitud': double.parse(ubicacioParts[1]),
    };

    final body = <String, dynamic>{
      'id': '1',
      'nom': activityData['title']!,
      'descripcio': activityData['description']!,
      'ubicacio': ubicacio,
      'dataInici': dateFormat.format(
        DateTime.parse(activityData['startDate']!),
      ),
      'dataFi': dateFormat.format(DateTime.parse(activityData['endDate']!)),
      'creador': activityData['user']!,
    };

    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Error al crear la actividad: ${response.body}');
    }
  }

  Future<void> deleteActivityFromBackend(String activityId) async {
    final url = Uri.parse(ApiConfig().buildUrl('api/activitats/$activityId'));
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar la actividad: ${response.body}');
    }
  }

  Future<void> updateActivityInBackend(
    String activityId,
    Map<String, String> activityData,
  ) async {
    final url = Uri.parse(
      ApiConfig().buildUrl('api/activitats/editar/$activityId'),
    );
    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final ubicacioParts = activityData['location']!.split(',');
    final ubicacio = <String, double>{
      'latitud': double.parse(ubicacioParts[0]),
      'longitud': double.parse(ubicacioParts[1]),
    };

    final body = <String, dynamic>{
      'id': activityId,
      'nom': activityData['title']!,
      'descripcio': activityData['description']!,
      'ubicacio': ubicacio,
      'dataInici': dateFormat.format(
        DateTime.parse(activityData['startDate']!),
      ),
      'dataFi': dateFormat.format(DateTime.parse(activityData['endDate']!)),
      'creador': activityData['user']!,
    };

    final response = await http.put(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar la actividad: ${response.body}');
    }
  }
}
