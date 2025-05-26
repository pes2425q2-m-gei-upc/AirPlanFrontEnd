import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:airplan/services/note_service.dart';
import 'package:airplan/models/nota.dart';
import 'package:airplan/services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';


@GenerateMocks([http.Client])
import 'note_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteService', () {
    late MockClient mockClient;
    late NoteService noteService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'token': 'mock_token',
        'username': 'testuser'
      });
      mockClient = MockClient();
      noteService = NoteService(client: mockClient);
    });

    test('fetchUserNotes returns a list of notes on success', () async {
      // Setup mock response with the correct URL pattern
      final testUrl = Uri.parse(ApiConfig().buildUrl('notas/testuser'));
      when(mockClient.get(testUrl)).thenAnswer((_) async => http.Response(
          '[{"id":1,"username":"testuser","fechaCreacion":"2023-05-15","horaRecordatorio":"14:30","comentario":"Test note"}]',
          200));

      final notes = await noteService.fetchUserNotes('testuser');

      expect(notes.length, 1);
      expect(notes[0].id, 1);
      expect(notes[0].username, 'testuser');
      expect(notes[0].comentario, 'Test note');
    });

    test('fetchUserNotes throws an exception on error', () async {
      // Setup mock response with the correct URL pattern
      final testUrl = Uri.parse(ApiConfig().buildUrl('notas/testuser'));
      when(mockClient.get(testUrl)).thenAnswer((_) async => http.Response(
          'Error', 404));

      expect(() => noteService.fetchUserNotes('testuser'),
          throwsException);
    });

    test('createNote sends correct data', () async {
      // Setup mock response with the correct URL pattern
      final testUrl = Uri.parse(ApiConfig().buildUrl('notas'));
      when(mockClient.post(
        testUrl,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Created', 201));

      final nota = Nota(
        username: 'testuser',
        fechacreacion: DateTime(2023, 5, 15),
        horarecordatorio: '14:30',
        comentario: 'New note',
      );

      await noteService.createNote(nota);

      // Verify post was called with correct data
      verify(mockClient.post(
        testUrl,
        headers: {'Content-Type': 'application/json'},
        body: contains('"username":"testuser"'),
      )).called(1);
    });

    test('updateNote sends correct data', () async {
      SharedPreferences.setMockInitialValues({
        'token': 'mock_token',
        'username': 'testuser'
      });

      final noteId = 1;
      final getUrl = Uri.parse(ApiConfig().buildUrl('notas/id/$noteId'));
      final updateUrl = Uri.parse(ApiConfig().buildUrl('notas/$noteId'));

      when(mockClient.get(getUrl)).thenAnswer((_) async => http.Response(
          '{"id":1,"username":"testuser","fechaCreacion":"2023-05-15","horaRecordatorio":"14:30","comentario":"Old note"}',
          200
      ));

      when(mockClient.put(
        updateUrl,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Updated', 200));

      final nota = Nota(
        id: noteId,
        username: 'testuser',
        fechacreacion: DateTime(2023, 5, 15),
        horarecordatorio: '14:30',
        comentario: 'Updated note',
      );

      await noteService.updateNote(noteId, nota);

      verify(mockClient.get(getUrl)).called(1);
      verify(mockClient.put(
        updateUrl,
        headers: {'Content-Type': 'application/json'},
        body: contains('"comentario":"Updated note"'),
      )).called(1);
    });

    test('updateNote throws exception on error', () async {
      final noteId = 1;
      final testUrl = Uri.parse(ApiConfig().buildUrl('notas/$noteId'));
      when(mockClient.put(
        testUrl,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Not found', 404));

      final nota = Nota(
        id: noteId,
        username: 'testuser',
        fechacreacion: DateTime(2023, 5, 15),
        horarecordatorio: '14:30',
        comentario: 'Updated note',
      );

      expect(() => noteService.updateNote(noteId, nota), throwsException);
    });

    test('deleteNote sends correct request', () async {
      final noteId = 1;
      final testUrl = Uri.parse(ApiConfig().buildUrl('notas/$noteId'));
      when(mockClient.delete(testUrl))
          .thenAnswer((_) async => http.Response('Deleted', 200));

      await noteService.deleteNote(noteId);

      verify(mockClient.delete(testUrl)).called(1);
    });

    test('deleteNote throws exception on error', () async {
      final noteId = 1;
      final testUrl = Uri.parse(ApiConfig().buildUrl('notas/$noteId'));
      when(mockClient.delete(testUrl))
          .thenAnswer((_) async => http.Response('Error', 404));

      expect(() => noteService.deleteNote(noteId), throwsException);
    });

    test('fetchUserNotesForDay returns filtered notes for specific day', () async {
      final testUrl = Uri.parse(ApiConfig().buildUrl('notas/testuser'));
      when(mockClient.get(testUrl)).thenAnswer((_) async => http.Response(
          '[{"id":1,"username":"testuser","fechaCreacion":"2023-05-15","horaRecordatorio":"14:30","comentario":"Note 1"},'
              '{"id":2,"username":"testuser","fechaCreacion":"2023-05-15","horaRecordatorio":"16:00","comentario":"Note 2"},'
              '{"id":3,"username":"testuser","fechaCreacion":"2023-05-16","horaRecordatorio":"10:00","comentario":"Note 3"}]',
          200));

      final day = DateTime(2023, 5, 15);
      final notes = await noteService.fetchUserNotesForDay('testuser', day);

      expect(notes.length, 2);
      expect(notes[0].id, 1);
      expect(notes[1].id, 2);
      expect(notes[0].fechacreacion.day, 15);
      expect(notes[1].fechacreacion.day, 15);
    });

    test('fetchUserNotesForDay returns empty list when no notes match', () async {
      final testUrl = Uri.parse(ApiConfig().buildUrl('notas/testuser'));
      when(mockClient.get(testUrl)).thenAnswer((_) async => http.Response(
          '[{"id":1,"username":"testuser","fechaCreacion":"2023-05-15","horaRecordatorio":"14:30","comentario":"Note 1"}]',
          200));

      final day = DateTime(2023, 5, 16);
      final notes = await noteService.fetchUserNotesForDay('testuser', day);

      expect(notes.length, 0);
    });
  });
}