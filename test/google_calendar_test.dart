import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:airplan/services/google_calendar_service.dart';
import 'package:airplan/services/sync_preferences_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

@GenerateMocks([
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
  SyncPreferencesService,
  http.Client,
])
import 'google_calendar_test.mocks.dart';
void main() {
  late GoogleCalendarService calendarService;
  late MockGoogleSignIn mockGoogleSignIn;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    calendarService = GoogleCalendarService(googleSignIn: mockGoogleSignIn);
  });

  group('GoogleCalendarService tests', () {
    test('sincronizarEvento falla cuando no hay sesión iniciada', () async {
      // Configurar el mock para simular fallo de inicio de sesión
      when(mockGoogleSignIn.signInSilently()).thenAnswer((_) async => null);
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      // Crear datos de prueba
      final titulo = "Evento de prueba";
      final inicio = DateTime.now();
      final fin = inicio.add(const Duration(hours: 1));

      // Verificar que se lanza la excepción esperada
      expect(
              () => calendarService.sincronizarEvento(titulo, inicio, fin),
          throwsA(predicate((e) =>
          e is Exception &&
              e.toString().contains('No se pudo iniciar sesión con Google')
          ))
      );
    });

    test('deleteEvent falla cuando no hay sesión iniciada', () async {
      // Configurar el mock para simular fallo de inicio de sesión
      when(mockGoogleSignIn.signInSilently()).thenAnswer((_) async => null);
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      // Verificar que se maneja la excepción silenciosamente
      // ya que deleteEvent está diseñado para no propagar errores
      await calendarService.deleteEvent("Título de prueba");

      // Verificar que se intentó el inicio de sesión
      verify(mockGoogleSignIn.signInSilently()).called(1);
    });
  });
}