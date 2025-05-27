import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' show Client;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

class GoogleCalendarService {
  final GoogleSignIn _googleSignIn;
  static const _scopes = ['https://www.googleapis.com/auth/calendar'];

  GoogleCalendarService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn(
    scopes: _scopes,
    clientId: kIsWeb
        ? '751649023508-e62rslll2c8n864juq95j1rd7a8t26d0.apps.googleusercontent.com'
        : null,
  );

  Future<CalendarApi> _getCalendarApi() async {
    try {
      final account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) throw Exception('No se pudo iniciar sesión con Google');

      final auth = await account.authentication;
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          auth.accessToken!,
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        null,
        _scopes,
      );

      final client = authenticatedClient(
        Client(),
        credentials,
      );

      return CalendarApi(client);
    } catch (e) {
      throw Exception('Error al obtener Calendar API: $e');
    }
  }

  Future<void> sincronizarEvento(String titulo, DateTime inicio, DateTime fin) async {
    try {
      final api = await _getCalendarApi();

      // Primero verificar si ya existe un evento con este título
      await deleteEvent(titulo); // Eliminar cualquier evento existente con el mismo título

      // Crear el nuevo evento
      final evento = Event()
        ..summary = titulo
        ..start = (EventDateTime()
          ..dateTime = inicio.toUtc()
          ..timeZone = 'UTC')
        ..end = (EventDateTime()
          ..dateTime = fin.toUtc()
          ..timeZone = 'UTC');

      await api.events.insert(evento, 'primary');
    } catch (e) {
      throw Exception('Error al sincronizar evento: $e');
    }
  }

  Future<void> deleteEvent(String title) async {
    try {
      final api = await _getCalendarApi();

      // Buscar todos los eventos con el título especificado
      final events = await api.events.list(
        'primary',
        q: title, // Usar query para buscar más eficientemente
        maxResults: 50, // Limitar resultados para eficiencia
      );

      if (events.items != null && events.items!.isNotEmpty) {
        int deletedCount = 0;

        for (final event in events.items!) {
          if (event.summary != null && event.summary == title) {
            try {
              await api.events.delete('primary', event.id!);
              deletedCount++;
            } catch (e) {
              if (kDebugMode) {
                print('Error al eliminar evento individual ${event.id}: $e');
              }
            }
          }
        }

        if (deletedCount == 0) {
            if(kDebugMode) print('No se encontraron eventos exactos con título "$title"');
        } else {
            if(kDebugMode) print('Se eliminaron $deletedCount evento(s) con título "$title"');
        }
      } else {

          if(kDebugMode) print('No se encontraron eventos con título "$title"');

      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar evento de Google Calendar: $e');
      }
      // No propagamos el error para no interrumpir el flujo principal
    }
  }

  Future<void> updateEvent({
    required String oldTitle,
    required String newTitle,
    required DateTime startTime,
    required DateTime endTime
  }) async {
    try {
      final api = await _getCalendarApi();

      // Buscar el evento por título anterior
      final events = await api.events.list(
        'primary',
        q: oldTitle,
        maxResults: 10,
      );

      Event? targetEvent;
      if (events.items != null) {
        for (final event in events.items!) {
          if (event.summary == oldTitle) {
            targetEvent = event;
            break;
          }
        }
      }

      if (targetEvent != null) {
        // Actualizar el evento existente
        targetEvent.summary = newTitle;
        targetEvent.start = EventDateTime()
          ..dateTime = startTime.toUtc()
          ..timeZone = 'UTC';
        targetEvent.end = EventDateTime()
          ..dateTime = endTime.toUtc()
          ..timeZone = 'UTC';

        await api.events.update(targetEvent, 'primary', targetEvent.id!);
        if (kDebugMode) {
          print('Evento actualizado correctamente de "$oldTitle" a "$newTitle"');
        }
      } else {
        if (kDebugMode) {
          print('No se encontró el evento "$oldTitle", creando nuevo evento');
        }
        // Si no se encuentra el evento anterior, crear uno nuevo
        await sincronizarEvento(newTitle, startTime, endTime);
      }
    } catch (e) {
      throw Exception('Error al actualizar evento: $e');
    }
  }

  Future<Event?> findEventByTitle(String title) async {
    try {
      final api = await _getCalendarApi();
      final events = await api.events.list(
        'primary',
        q: title,
        maxResults: 10,
      );

      if (events.items != null) {
        for (final event in events.items!) {
          if (event.summary == title) {
            return event;
          }
        }
      }
      return null;
    } catch (e) {
      throw Exception('Error al buscar evento: $e');
    }
  }

  // Método para listar todos los eventos (útil para debugging)
  Future<void> listAllEvents() async {
    try {
      final api = await _getCalendarApi();
      final events = await api.events.list('primary', maxResults: 50);

      if (kDebugMode) {
        print('=== EVENTOS EN EL CALENDARIO ===');
      }
      if (events.items != null && events.items!.isNotEmpty) {
        for (final event in events.items!) {
          if (kDebugMode){
            print('Título: ${event.summary ?? "Sin título"}');
            print('ID: ${event.id}');
            print('Inicio: ${event.start?.dateTime ?? event.start?.date}');
            print('---');
          }
        }
      } else {
        if (kDebugMode) {
          print('No hay eventos en el calendario');
        }
      }
      if (kDebugMode) print('================================');
    } catch (e) {
      if (kDebugMode) print('Error al listar eventos: $e');
    }
  }

  Future<void> deleteAllEvents() async {
    try {
      final calendar = await _getCalendarApi();
      String? pageToken;
      int deletedCount = 0;

      do {
        final events = await calendar.events.list(
          'primary',
          maxResults: 100,
          pageToken: pageToken,
        );

        if (events.items != null) {
          for (var event in events.items!) {
            if (event.summary?.startsWith('Nota:') == true ||
                event.summary?.startsWith('Activitat:') == true) {
              try {
                await calendar.events.delete('primary', event.id!);
                deletedCount++;
              } catch (e) {
                if (kDebugMode) print('Error al eliminar evento ${event.id}: $e');
              }
            }
          }
        }

        pageToken = events.nextPageToken;
      } while (pageToken != null);

      if (kDebugMode) print('Se eliminaron $deletedCount eventos del calendario');
    } catch (e) {
      if (kDebugMode) print('Error al eliminar todos los eventos: $e');
      rethrow;
    }
  }

  GoogleSignIn getGoogleSignIn() {
    return _googleSignIn;
  }
}