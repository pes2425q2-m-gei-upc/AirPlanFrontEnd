// activity_service.dart
import 'dart:convert';
import 'package:airplan/user_services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as client;
import 'services/api_config.dart';
import 'services/google_calendar_service.dart';
import 'services/sync_preferences_service.dart';

class ActivityService {
  final GoogleCalendarService _googleCalendarService;
  final SyncPreferencesService _syncPreferencesService;

  ActivityService({
    GoogleCalendarService? googleCalendarService,
    SyncPreferencesService? syncPreferencesService,
  })  : _googleCalendarService = googleCalendarService ?? GoogleCalendarService(),
        _syncPreferencesService = syncPreferencesService ?? SyncPreferencesService();

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

    // Sincronizar con Google Calendar si está habilitado
    try {
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      if (isSyncEnabled) {
        final startTime = DateTime.parse(activityData['startDate']!);
        final endTime = DateTime.parse(activityData['endDate']!);

        // Asegurarse de que el título no sea nulo
        final title = activityData['title'];
        if (title != null && title.isNotEmpty) {
          await _googleCalendarService.sincronizarEvento(
            'Activitat: $title',
            startTime,
            endTime,
          );
        } else {
         if(kDebugMode) print('Error: El título de la actividad es nulo o vacío');
        }
      }
    } catch (e) {
      if(kDebugMode) print('Error al sincronizar con Google Calendar: $e');
      // No lanzamos la excepción para que no interrumpa el flujo principal
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
    try {
      if (kDebugMode) print('=== PASO 1: Obteniendo información de la actividad ===');

      // 1. PRIMERO: Obtener la información de la actividad ANTES de eliminarla
      final activity = await fetchActivityById(activityId);
      if (activity == null) {
        if (kDebugMode) print('✗ No se encontró la actividad con ID: $activityId');
        throw Exception('Actividad no encontrada');
      }
      if (kDebugMode) print('✓ Actividad encontrada: "${activity['nom']}"');

      // 2. SEGUNDO: Eliminar de Google Calendar ANTES de eliminar del backend
      if (kDebugMode) print('\n=== PASO 2: Eliminando del Google Calendar ===');
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      if (kDebugMode) print('Sincronización habilitada: $isSyncEnabled');

      if (isSyncEnabled) {
        try {
          final eventTitle = 'Activitat: ${activity['nom']}';
          if (kDebugMode) print('Intentando eliminar evento: "$eventTitle"');
          await _googleCalendarService.deleteEvent(eventTitle);
          if (kDebugMode) print('✓ Evento eliminado del calendario exitosamente');
        } catch (e) {
          if (kDebugMode) print('✗ Error al eliminar evento del calendario: $e');
          // No propagamos este error para continuar con la eliminación del backend
        }
      } else {
        if (kDebugMode) print('Sincronización deshabilitada, omitiendo eliminación del calendario');
      }

      // 3. TERCERO: Eliminar del backend
      if (kDebugMode) print('\n=== PASO 3: Eliminando del servidor ===');
      final url = Uri.parse(ApiConfig().buildUrl('api/activitats/$activityId'));
      if (kDebugMode) print('Eliminando desde: $url');

      final response = await http.delete(url);

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar la actividad del servidor. Status: ${response.statusCode}');
      }

      if (kDebugMode) print('✓ Actividad eliminada exitosamente del servidor');
      if (kDebugMode) print('=== ELIMINACIÓN COMPLETADA ===');

    } catch (e) {
      if (kDebugMode) print('✗ Error completo en deleteActivityFromBackend: $e');
      throw Exception('Error al eliminar la actividad: $e');
    }
  }

  Future<void> updateActivityInBackend(String activityId, Map<String, String> updatedActivity) async {
    try {
      // 1. Validar las fechas primero
      validateActivityDates(updatedActivity);

      // 2. Obtener la actividad antigua antes de actualizarla
      final oldActivity = await fetchActivityById(activityId);
      if (oldActivity == null) {
        throw Exception('No se encontró la actividad a actualizar');
      }

      // 3. Preparar los datos para la actualización
      final url = Uri.parse(ApiConfig().buildUrl('api/activitats/editar/$activityId'));
      final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
      final ubicacioParts = updatedActivity['location']!.split(',');
      final ubicacio = <String, double>{
        'latitud': double.parse(ubicacioParts[0]),
        'longitud': double.parse(ubicacioParts[1]),
      };

      // 4. Actualizar en el backend
      final body = <String, dynamic>{
        'id': activityId,
        'nom': updatedActivity['title'],
        'descripcio': updatedActivity['description'],
        'ubicacio': ubicacio,
        'dataInici': dateFormat.format(DateTime.parse(updatedActivity['startDate']!)),
        'dataFi': dateFormat.format(DateTime.parse(updatedActivity['endDate']!)),
        'creador': updatedActivity['user'],
      };

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al actualizar la actividad en el servidor');
      }

      // 5. Actualizar en Google Calendar si está habilitado
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      if (isSyncEnabled) {
        try {
          // Eliminar el evento antiguo usando el MISMO formato que al crear
          final oldEventTitle = 'Activitat: ${oldActivity['nom']}';
          if (kDebugMode) print('Intentando eliminar evento antiguo: $oldEventTitle');
          await _googleCalendarService.deleteEvent(oldEventTitle);

          // Crear el nuevo evento usando el MISMO formato
          final startTime = DateTime.parse(updatedActivity['startDate']!);
          final endTime = DateTime.parse(updatedActivity['endDate']!);
          final newEventTitle = 'Activitat: ${updatedActivity['title']}';

          await _googleCalendarService.sincronizarEvento(
            newEventTitle,
            startTime,
            endTime,
          );

          if (kDebugMode) {
            print('✓ Evento antiguo eliminado: $oldEventTitle');
            print('✓ Nuevo evento creado: $newEventTitle');
          }
        } catch (e) {
          if (kDebugMode) print('Error en la sincronización con Calendar: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error en updateActivityInBackend: $e');
      throw Exception('Error al actualizar la actividad: $e');
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

  Future<void> syncActivityWithGoogleCalendar(Map<String, dynamic> activity) async {
    try {
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      if (!isSyncEnabled) {
        throw Exception('La sincronización con Google Calendar no está habilitada');
      }

      final startTime = DateTime.parse(activity['dataInici']);
      final endTime = DateTime.parse(activity['dataFi']);

      await _googleCalendarService.sincronizarEvento(
        'Activitat: ${activity['nom']}',
        startTime,
        endTime,
      );

      // Aquí podrías agregar lógica adicional para marcar la actividad como sincronizada
      // Por ejemplo, guardando el estado en SharedPreferences o en tu backend

    } catch (e) {
      throw Exception('Error al sincronizar con Google Calendar: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchActivityById(String activityId) async {
    try {
      final url = Uri.parse(ApiConfig().buildUrl('api/activitats/$activityId'));
      if (kDebugMode) print('Consultando actividad en: $url');
      final response = await client.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> toggleSyncPreference(bool enabled) async {
    try {
      final previousState = await _syncPreferencesService.isSyncEnabled();
      await _syncPreferencesService.setSyncEnabled(enabled);

      // Si estamos desactivando la sincronización, eliminar todos los eventos
      if (previousState && !enabled) {
        if (kDebugMode) print('Desactivando sincronización: eliminando eventos del calendario');

        // Obtener todas las actividades
        final activities = await fetchActivities();

        // Eliminar cada evento del calendario
        for (final activity in activities) {
          try {
            final eventTitle = 'Activitat: ${activity['nom']}';
            if (kDebugMode) print('Intentando eliminar evento: $eventTitle');
            await _googleCalendarService.deleteEvent(eventTitle);
          } catch (e) {
            if (kDebugMode) print('Error al eliminar evento individual: $e');
            // Continuar con el siguiente evento incluso si hay error
          }
        }

        if (kDebugMode) print('Eventos eliminados correctamente');
      }
    } catch (e) {
      if (kDebugMode) print('Error en toggleSyncPreference: $e');
      throw Exception('Error al cambiar preferencia de sincronización: $e');
    }
  }

  Future<bool> isSyncEnabled() async {
    return _syncPreferencesService.isSyncEnabled();
  }
}
