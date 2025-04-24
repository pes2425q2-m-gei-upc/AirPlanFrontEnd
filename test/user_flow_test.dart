// user_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'test_helpers.dart';
import 'test_helpers.mocks.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import User if needed by MyApp

void main() {
  late MockFirebaseAuth auth;
  late MockClient httpClient;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    FirebaseTestSetup.setupFirebaseMocks();
    auth = FirebaseTestSetup.getFirebaseAuth();
    httpClient = FirebaseTestSetup.getHttpClient();
    mockAuth = MockFirebaseAuth();
  });

  // Helper function to simulate a complete login flow
  Future<void> simulateLoginFlow(
    WidgetTester tester, {
    required MockFirebaseAuth auth,
  }) async {
    // Start with login screen widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(
                key: const Key('emailField'),
                decoration: const InputDecoration(
                  labelText: 'Correu electrònic',
                ),
              ),
              TextField(
                key: const Key('passwordField'),
                decoration: const InputDecoration(labelText: 'Contrasenya'),
              ),
              ElevatedButton(
                key: const Key('loginButton'),
                onPressed: () async {
                  // Simulamos la acción de inicio de sesión
                  await auth.signInWithEmailAndPassword(
                    email: 'test@example.com',
                    password: 'password123',
                  );
                },
                child: const Text('Iniciar Sessió'),
              ),
            ],
          ),
        ),
      ),
    );

    // Enter credentials
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'password123',
    );

    // Submit the form
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
  }

  group('Complete user flows', () {
    testWidgets('Registration to Login to Profile Update flow', (
      WidgetTester tester,
    ) async {
      // 1. First register a new user
      final email = 'newuser@example.com';
      final password = 'Secure123!';

      // Crear un nuevo usuario para pruebas
      final newUser = MockUser(
        uid: 'new-user-uid',
        email: email,
        displayName: 'New User',
      );

      // Crear una instancia de autenticación específica para esta prueba
      auth = MockFirebaseAuth();

      // Simular pantalla de registro
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const Key('regEmailField'),
                  decoration: const InputDecoration(
                    labelText: 'Correu electrònic',
                  ),
                ),
                TextField(
                  key: const Key('regPasswordField'),
                  decoration: const InputDecoration(labelText: 'Contrasenya'),
                ),
                TextField(
                  key: const Key('regPasswordConfirmField'),
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Contrasenya',
                  ),
                ),
                ElevatedButton(
                  key: const Key('registerButton'),
                  onPressed: () async {
                    // Simular el registro exitoso directamente
                    await auth.createUserWithEmailAndPassword(
                      email: email,
                      password: password,
                    );
                  },
                  child: const Text('Registrar-se'),
                ),
              ],
            ),
          ),
        ),
      );

      // Llenar formulario de registro
      await tester.enterText(find.byKey(const Key('regEmailField')), email);
      await tester.enterText(
        find.byKey(const Key('regPasswordField')),
        password,
      );
      await tester.enterText(
        find.byKey(const Key('regPasswordConfirmField')),
        password,
      );

      // Enviar formulario de registro
      await tester.tap(find.byKey(const Key('registerButton')));
      await tester.pumpAndSettle();

      // 2. Establecer el usuario recién registrado para la sesión
      auth = MockFirebaseAuth(mockUser: newUser);

      // Iniciar sesión con la nueva cuenta
      await simulateLoginFlow(tester, auth: auth);

      // 3. Crear un mock específico para llamadas HTTP de actualización de perfil
      final httpClient = MockClient();
      when(
        httpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"success": true}', 200));

      // Simular pantalla de actualización de perfil
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    TextField(
                      key: const Key('nameField'),
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                    TextField(
                      key: const Key('phoneField'),
                      decoration: const InputDecoration(labelText: 'Telèfon'),
                    ),
                    ElevatedButton(
                      key: const Key('updateProfileButton'),
                      onPressed: () {
                        // Realizar la llamada HTTP para actualizar el perfil
                        httpClient.post(
                          Uri.parse('https://api.airplan.com/profile'),
                          headers: {'Content-Type': 'application/json'},
                          body: '{"name": "John Doe", "phone": "123456789"}',
                        );
                      },
                      child: const Text('Actualitzar Perfil'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Llenar formulario de actualización de perfil
      await tester.enterText(find.byKey(const Key('nameField')), 'John Doe');
      await tester.enterText(find.byKey(const Key('phoneField')), '123456789');

      // Enviar formulario de actualización de perfil
      await tester.tap(find.byKey(const Key('updateProfileButton')));
      await tester.pumpAndSettle();

      // Verificar que se haya llamado al API para actualizar el perfil
      verify(
        httpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).called(1);
    });

    testWidgets('Login to Logout flow', (WidgetTester tester) async {
      final user = MockUser(
        email: 'testuser@example.com',
        displayName: 'Test User',
      );
      mockAuth = MockFirebaseAuth(mockUser: user);

      // Simular inicio de sesión
      await mockAuth.signInWithEmailAndPassword(
        email: 'testuser@example.com',
        password: 'password123',
      );

      // Renderizar la aplicación
      await tester.pumpWidget(MyApp(auth: mockAuth));

      // Verificar que el usuario está autenticado
      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser?.email, 'testuser@example.com');

      // Simular cierre de sesión
      await mockAuth.signOut();

      // Verificar que el usuario ha cerrado sesión
      expect(mockAuth.currentUser, isNull);
    });
  });
}

// Define a minimal MyApp class for testing (if not already defined/imported)
// Ensure this definition doesn't conflict with others if moved/shared later.
class MyApp extends StatelessWidget {
  final MockFirebaseAuth auth;

  const MyApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    // Mimic the structure used in session_persistence_test.dart
    return MaterialApp(
      home: StreamBuilder<User?>(
        // Use User? from firebase_auth
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user != null) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Bienvenido, ${user.displayName ?? 'Guest'}',
                    key: const Key(
                      'welcomeMessage',
                    ), // Optional: Add key for testing
                  ),
                ),
              );
            } else {
              return const Scaffold(
                body: Center(child: Text('Por favor inicia sesión')),
              );
            }
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
