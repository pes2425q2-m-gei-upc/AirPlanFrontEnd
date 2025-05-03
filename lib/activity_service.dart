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
    // Validate dates first
    validateActivityDates(activityData);

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

  void validateActivityDates(Map<String, String> activityData) {


    final String? startDateString = activityData['startDate'];
    final String? endDateString = activityData['endDate'];

    if (startDateString == null || startDateString.isEmpty) {
      throw Exception('La fecha de inicio es obligatoria');
    }

    if (endDateString == null || endDateString.isEmpty) {
      throw Exception('La fecha de fin es obligatoria');
    }

    DateTime startDate;
    DateTime endDate;

    try {
      startDate = DateTime.parse(startDateString);
    } catch (e) {
      throw Exception('El formato de la fecha de inicio no es válido');
    }

    try {
      endDate = DateTime.parse(endDateString);
    } catch (e) {
      throw Exception('El formato de la fecha de fin no es válido');
    }

    // Check if start date is after end date
    if (startDate.isAfter(endDate)) {
      throw Exception('La fecha de inicio no puede ser posterior a la fecha de fin');
    }

    // Optional: Check if dates are in the past
    final now = DateTime.now();
    if (startDate.isBefore(now)) {
      throw Exception('La fecha de inicio no puede ser en el pasado');
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
    // Validate dates first
    validateActivityDates(activityData);

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
      // Fixed the context retrieval
      throw Exception('Error al actualizar la actividad: ${response.body}');
    }
  }
  Future<bool> isActivityFavorite(int activityId, String username) async {
    //final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/activitats/favorita/$activityId/$username');
    final url = Uri.parse('http://127.0.0.1:8080/api/activitats/favorita/$activityId/$username');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['esFavorita'] as bool;
    } else {
      throw Exception('Error checking if activity is favorite: ${response.body}');
    }
  }

  Future<void> addActivityToFavorites(int activityId, String username) async {
    //final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/activitats/favorita/anadir/$activityId/$username');
    final url = Uri.parse('http://127.0.0.1:8080/api/activitats/favorita/anadir/$activityId/$username');
    final response = await http.post(url);

    if (response.statusCode != 201) {
      throw Exception('Error adding activity to favorites: ${response.body}');
    }
  }

  Future<void> removeActivityFromFavorites(int activityId, String username) async {
    //final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/activitats/favorita/eliminar/$activityId/$username');
    final url = Uri.parse('http://127.0.0.1:8080/api/activitats/favorita/eliminar/$activityId/$username');
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Error removing activity from favorites: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFavoriteActivities(String username) async {
    //final url = Uri.parse('http://nattech.fib.upc.edu:40350/api/activitats/favoritas/$username');
    final url = Uri.parse('http://127.0.0.1:8080/api/activitats/favoritas/$username');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al obtener actividades favoritas: ${response.body}');
    }
  }
}