// note_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/models/nota.dart';
import 'package:airplan/services/sync_preferences_service.dart';
import 'package:airplan/services/google_calendar_service.dart';

class NoteService {
  final http.Client client;
  final SyncPreferencesService _syncPreferencesService;
  final GoogleCalendarService _googleCalendarService;

  NoteService({
    http.Client? client,
    SyncPreferencesService? syncPreferencesService,
    GoogleCalendarService? googleCalendarService,
  }) : client = client ?? http.Client(),
        _syncPreferencesService = syncPreferencesService ?? SyncPreferencesService(),
        _googleCalendarService = googleCalendarService ?? GoogleCalendarService();

  // Método helper para generar el título consistente del evento
  String _generateEventTitle(Nota nota) {
    return 'Nota: ${nota.comentario}';
  }

  Future<void> syncNoteWithGoogleCalendar(Nota nota) async {
    try {
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      if (!isSyncEnabled) return;

      // Usar el método helper para generar título consistente
      final noteTitle = _generateEventTitle(nota);

      // Parsear la hora del recordatorio
      final timeParts = nota.horarecordatorio.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Crear DateTime para inicio y fin
      final startTime = DateTime(
        nota.fechacreacion.year,
        nota.fechacreacion.month,
        nota.fechacreacion.day,
        hour,
        minute,
      );
      final endTime = startTime.add(const Duration(hours: 1));

      try {
        if (kDebugMode) print('Creando/actualizando evento: $noteTitle');
        await _googleCalendarService.sincronizarEvento(
          noteTitle,
          startTime,
          endTime,
        );
      } catch (e) {
        if (kDebugMode) print('Error al sincronizar nota con Google Calendar: $e');
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) print('Error en syncNoteWithGoogleCalendar: $e');
    }
  }

  Future<List<Nota>> fetchUserNotes(String username) async {
    final url = Uri.parse(ApiConfig().buildUrl('notas/$username'));
    final response = await client.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map<Nota>((json) => Nota.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar las notas del usuario');
    }
  }

  Future<void> createNote(Nota nota) async {
    final url = Uri.parse(ApiConfig().buildUrl('notas'));

    final Map<String, dynamic> data = {
      'username': nota.username,
      'fechaCreacion': DateFormat('yyyy-MM-dd').format(nota.fechacreacion),
      'horaRecordatorio': nota.horarecordatorio,
      'comentario': nota.comentario
    };

    final response = await client.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 201) {
      throw Exception('Error al crear la nota: ${response.body}');
    }

    // Sincronizar con Google Calendar después de crear
    await syncNoteWithGoogleCalendar(nota);
  }

  Future<void> updateNote(int id, Nota nota) async {
    try {
      // 1. Obtener la nota anterior para poder eliminar el evento anterior del calendario
      final oldNote = await _getNote(id);

      // 2. Actualizar la nota en el backend
      final url = Uri.parse(ApiConfig().buildUrl('notas/$id'));

      final Map<String, dynamic> data = {
        'username': nota.username,
        'fechaCreacion': DateFormat('yyyy-MM-dd').format(nota.fechacreacion),
        'horaRecordatorio': nota.horarecordatorio,
        'comentario': nota.comentario
      };

      final response = await client.put(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al actualizar la nota: ${response.body}');
      }

      // 3. Sincronizar con Google Calendar
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      if (isSyncEnabled) {
        // Eliminar el evento anterior si existía
        if (oldNote != null) {
          try {
            final oldEventTitle = _generateEventTitle(oldNote);
            await _googleCalendarService.deleteEvent(oldEventTitle);
            if (kDebugMode) print('Evento anterior eliminado: $oldEventTitle');
          } catch (e) {
            if (kDebugMode) print('Error al eliminar evento anterior: $e');
          }
        }

        // Crear el nuevo evento
        await syncNoteWithGoogleCalendar(nota);
      }
    } catch (e) {
      throw Exception('Error al actualizar la nota: $e');
    }
  }

  Future<void> deleteNote(int id, {String? username}) async {
    try {
      Nota? note;

      // 1. PRIMERO: Obtener la información de la nota ANTES de eliminarla
      if (kDebugMode) print('=== PASO 1: Obteniendo información de la nota ===');
      if (username != null) {
        if (kDebugMode) print('Buscando nota con ID $id para usuario $username');
        final userNotes = await fetchUserNotes(username);
        if (kDebugMode) print('Se encontraron ${userNotes.length} notas para el usuario');

        try {
          note = userNotes.firstWhere((n) => n.id == id);
          if (kDebugMode) print('✓ Nota encontrada: "${note.comentario}"');
        } catch (e) {
          if (kDebugMode) print('✗ No se encontró la nota con ID $id en las notas del usuario');
          if (kDebugMode) print('IDs disponibles: ${userNotes.map((n) => n.id).toList()}');
          note = null;
        }
      } else {
        if (kDebugMode) print('Intentando obtener nota directamente por ID $id');
        note = await _getNote(id);
        if (note != null) {
          if (kDebugMode) print('✓ Nota obtenida: "${note.comentario}"');
        } else {
          if (kDebugMode) print('✗ No se pudo obtener la nota por ID');
        }
      }

      // 2. SEGUNDO: Eliminar del Google Calendar ANTES de eliminar del backend
      if (kDebugMode) print('\n=== PASO 2: Eliminando del Google Calendar ===');
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      if (kDebugMode) print('Sincronización habilitada: $isSyncEnabled');

      if (isSyncEnabled && note != null) {
        try {
          final eventTitle = _generateEventTitle(note);
          if (kDebugMode) print('Intentando eliminar evento: "$eventTitle"');
          await _googleCalendarService.deleteEvent(eventTitle);
          if (kDebugMode) print('✓ Evento eliminado del calendario exitosamente');
        } catch (e) {
          if (kDebugMode) print('✗ Error al eliminar evento del calendario: $e');
          // No propagamos este error ya que continuaremos con la eliminación del backend
        }
      } else if (isSyncEnabled && note == null) {
        if (kDebugMode) print('⚠️ Advertencia: No se puede eliminar del calendario sin información de la nota');
      } else {
        if (kDebugMode) print('Sincronización deshabilitada, omitiendo eliminación del calendario');
      }

      // 3. TERCERO: Finalmente eliminar del backend
      if (kDebugMode) print('\n=== PASO 3: Eliminando del servidor ===');
      final url = Uri.parse(ApiConfig().buildUrl('notas/$id'));
      if (kDebugMode) print('Eliminando desde: $url');

      final response = await client.delete(url);

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar la nota del servidor. Status: ${response.statusCode}, Body: ${response.body}');
      }

      if (kDebugMode) print('✓ Nota eliminada exitosamente del servidor');
      if (kDebugMode) print('=== ELIMINACIÓN COMPLETADA ===');

    } catch (e) {
      if (kDebugMode) print('✗ Error completo en deleteNote: $e');
      throw Exception('Error al eliminar la nota: $e');
    }
  }

  // Método auxiliar para obtener una nota por ID
  Future<Nota?> _getNote(int id) async {
    try {
      final url = Uri.parse(ApiConfig().buildUrl('notas/id/$id'));
      if (kDebugMode) print('Solicitando nota desde: $url');

      final response = await client.get(url);
      if (kDebugMode) print('Respuesta del servidor - Status: ${response.statusCode}');
      if (kDebugMode) print('Respuesta del servidor - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) print('Datos decodificados - Tipo: ${data.runtimeType}');

        // Verificar si la respuesta es una lista o un objeto
        if (data is List) {
          if (kDebugMode) print('Respuesta es una lista con ${data.length} elementos');
          // Si es una lista, buscar la nota con el ID correcto
          for (var item in data) {
            if (item is Map<String, dynamic>) {
              if (kDebugMode) print('Revisando item con ID: ${item['id']}');
              if (item['id'] == id) {
                if (kDebugMode) print('¡Encontrada nota con ID $id!');
                return Nota.fromJson(item);
              }
            }
          }
          if (kDebugMode) print('No se encontró nota con ID $id en la lista');
          return null;
        } else if (data is Map<String, dynamic>) {
          if (kDebugMode) print('Respuesta es un objeto único');
          // Si es un objeto único, convertirlo directamente
          return Nota.fromJson(data);
        } else {
          if (kDebugMode) print('Formato de respuesta inesperado: ${data.runtimeType}');
          return null;
        }
      } else {
        if (kDebugMode) print('Error del servidor: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error al obtener la nota: $e');
      return null;
    }
  }

  Future<List<Nota>> fetchUserNotesForDay(String username, DateTime day) async {
    final notes = await fetchUserNotes(username);
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dayFormatted = dateFormat.format(day);

    return notes.where((note) {
      final noteDate = DateTime(note.fechacreacion.year, note.fechacreacion.month, note.fechacreacion.day);
      return dateFormat.format(noteDate) == dayFormatted;
    }).toList();
  }

  // Método para sincronizar todas las notas existentes
  Future<void> syncAllNotes(String username) async {
    try {
      final isSyncEnabled = await _syncPreferencesService.isSyncEnabled();
      if (!isSyncEnabled) return;

      final notes = await fetchUserNotes(username);
      for (var note in notes) {
        await syncNoteWithGoogleCalendar(note);
      }
    } catch (e) {
      if (kDebugMode) print('Error al sincronizar todas las notas: $e');
    }
  }
}