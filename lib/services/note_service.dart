// note_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/models/nota.dart';

class NoteService {
  final http.Client client;

  NoteService({http.Client? client}) : client = client ?? http.Client();

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

    // Format data with camelCase field names to match Kotlin backend
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
  }

  Future<void> updateNote(int id, Nota nota) async {
    final url = Uri.parse(ApiConfig().buildUrl('notas/$id'));

    // Format data with camelCase field names to match Kotlin backend
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
  }

  Future<void> deleteNote(int id) async {
    final url = Uri.parse(ApiConfig().buildUrl('notas/$id'));
    final response = await client.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar la nota: ${response.body}');
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
}