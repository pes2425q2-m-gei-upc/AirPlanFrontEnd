// activity_service.dart
import 'dart:convert';
import 'package:airplan/user_services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_config.dart'; // Importar la configuración de API

class ActivityService {
  Future<List<Map<String, dynamic>>> fetchActivities() async {
    String? currentUsername = FirebaseAuth.instance.currentUser?.displayName;

    // URL base para obtener todas las actividades
    String apiPath = 'api/activitats';

    // Si hay un usuario autenticado, añadir su nombre para filtrar actividades de usuarios bloqueados
    if (currentUsername != null) {
      apiPath = 'api/activitats';
    }

    final url = Uri.parse(ApiConfig().buildUrl(apiPath));
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(body);
      final activities = data.cast<Map<String, dynamic>>();
      for (var activity in activities) {
        // Añadir el campo 'esExterna' a cada actividad
        activity['esExterna'] = (await UserService.getUserData(activity['creador']))['esExtern'];
      }
      return activities;
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
      throw Exception("required_date".tr());
    }

    if (endDateString == null || endDateString.isEmpty) {
      throw Exception('end_date_required'.tr());
    }

    DateTime startDate;
    DateTime endDate;

    try {
      startDate = DateTime.parse(startDateString);
    } catch (e) {
      throw Exception('format_date_start_invalid'.tr());
    }

    try {
      endDate = DateTime.parse(endDateString);
    } catch (e) {
      throw Exception('format_date_end_invalid'.tr());
    }

    // Check if start date is after end date
    if (startDate.isAfter(endDate)) {
      throw Exception('start_date_after_end_date'.tr());
    }

    // Optional: Check if dates are in the past
    final now = DateTime.now();
    if (startDate.isBefore(now)) {
      throw Exception('start_date_in_past'.tr());
    }
  }

  Future<void> deleteActivityFromBackend(String activityId) async {
    final url = Uri.parse(ApiConfig().buildUrl('api/activitats/$activityId'));
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('${'error_deleting_activity'.tr()} ${response.body}');
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
      throw Exception('${'error_refreshing'.tr()}${response.body}');
    }
  }

  Future<bool> isActivityFavorite(int activityId, String username) async {
    final url = Uri.parse(
      ApiConfig().buildUrl('api/activitats/favorita/$activityId/$username'),
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['esFavorita'] as bool;
    } else {
      throw Exception('${'error_checking_favorite'.tr()}${response.body}');
    }
  }

  Future<void> addActivityToFavorites(int activityId, String username) async {
    final url = Uri.parse(
      ApiConfig().buildUrl(
        'api/activitats/favorita/anadir/$activityId/$username',
      ),
    );
    final response = await http.post(url);

    if (response.statusCode != 201) {
      throw Exception('${'error_adding_favorites'.tr()} ${response.body}');
    }
  }

  Future<void> removeActivityFromFavorites(
    int activityId,
    String username,
  ) async {
    final url = Uri.parse(
      ApiConfig().buildUrl(
        'api/activitats/favorita/eliminar/$activityId/$username',
      ),
    );
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception(
        '${'error_deleting_from_favorites'.tr()} ${response.body}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchFavoriteActivities(
    String username,
  ) async {
    final url = Uri.parse(
      ApiConfig().buildUrl('api/activitats/favoritas/$username'),
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final activities = data.cast<Map<String, dynamic>>();
      for (var activity in activities) {
        // Añadir el campo 'esExterna' a cada actividad
        activity['esExterna'] = (await UserService.getUserData(activity['creador']))['esExtern'];
      }
      return activities;
    } else {
      throw Exception('${'error_obtaining_favorites'.tr()} ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserActivities(String username) {
    final url = Uri.parse(ApiConfig().buildUrl('api/activitats/participant/$username'));
    return http.get(url).then((response) async {
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final activities = data.cast<Map<String, dynamic>>();
        for (var activity in activities) {
          // Añadir el campo 'esExterna' a cada actividad
          activity['esExterna'] = (await UserService.getUserData(activity['creador']))['esExtern'];
        }
        return activities;
      } else {
        throw Exception('Error al cargar las actividades del usuario');
      }
    });
  }
}
