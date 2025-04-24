// session_persistence_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart'; // Import for debugDumpApp

void main() {
  late MockFirebaseAuth auth;

  // Ensure the MockFirebaseAuth instance is explicitly initialized in each test
  setUp(() {
    final mockUser = MockUser(
      uid: 'test-uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    auth = MockFirebaseAuth(mockUser: mockUser);

    // Set up SharedPreferences mock for persistence testing
    SharedPreferences.setMockInitialValues({});
  });

  group('User Session Persistence Tests', () {
    testWidgets('User session data is saved to local storage on login', (
      WidgetTester tester,
    ) async {
      // Mock a successful login
      final user = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      // En lugar de crear manualmente UserCredential, usamos directamente los métodos de autenticación
      // proporcionados por MockFirebaseAuth
      auth = MockFirebaseAuth(mockUser: user);

      // Create a simple login widget that saves session data to shared preferences
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  key: const Key('loginButton'),
                  onPressed: () async {
                    // Login and save session data
                    final userCredential = await auth
                        .signInWithEmailAndPassword(
                          email: 'test@example.com',
                          password: 'password123',
                        );

                    if (userCredential.user != null) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('userId', userCredential.user!.uid);
                      await prefs.setString(
                        'userEmail',
                        userCredential.user!.email ?? '',
                      );
                      await prefs.setString(
                        'userName',
                        userCredential.user!.displayName ?? '',
                      );
                      await prefs.setBool('isLoggedIn', true);
                    }
                  },
                  child: const Text('Login'),
                ),
              );
            },
          ),
        ),
      );

      // Tap the login button
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pumpAndSettle();

      // Verify data was saved to shared preferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('userId'), 'test-uid');
      expect(prefs.getString('userEmail'), 'test@example.com');
      expect(prefs.getString('userName'), 'Test User');
      expect(prefs.getBool('isLoggedIn'), true);
    });

    testWidgets('User session is restored after app restart', (
      WidgetTester tester,
    ) async {
      // Set up SharedPreferences with saved user session
      SharedPreferences.setMockInitialValues({
        'userId': 'test-uid',
        'userEmail': 'test@example.com',
        'userName': 'Test User',
        'isLoggedIn': true,
      });

      // Create a widget that checks for existing session on startup
      bool sessionRestored = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final prefs = snapshot.data!;
                      sessionRestored = prefs.getBool('isLoggedIn') ?? false;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (sessionRestored)
                            Text(
                              'Bienvenido de nuevo, ${prefs.getString('userName')}',
                              key: const Key('welcomeMessage'),
                            )
                          else
                            const Text('Por favor inicia sesión'),

                          // Button to clear session data
                          ElevatedButton(
                            key: const Key('logoutButton'),
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.clear();
                            },
                            child: const Text('Cerrar Sesión'),
                          ),
                        ],
                      );
                    } else {
                      return const CircularProgressIndicator();
                    }
                  },
                ),
              );
            },
          ),
        ),
      );

      // Wait for FutureBuilder to complete
      await tester.pumpAndSettle();

      // Verify session was restored
      expect(sessionRestored, true);
      expect(find.byKey(const Key('welcomeMessage')), findsOneWidget);
      expect(find.text('Bienvenido de nuevo, Test User'), findsOneWidget);

      // Test logout
      await tester.tap(find.byKey(const Key('logoutButton')));
      await tester.pumpAndSettle();

      // Verify session was cleared (need to rebuild widget to see changes)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), null);
      expect(prefs.getString('userId'), null);
    });

    testWidgets('Authentication state persists across different screens', (
      WidgetTester tester,
    ) async {
      // Set up initial user state with an explicit displayName
      final testUser = MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
        isEmailVerified: true,
      );

      // Make sure the auth is signed in before using it
      auth = MockFirebaseAuth(mockUser: testUser, signedIn: true);

      // Verify the user is actually signed in
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser?.displayName, equals('Test User'));

      // Create app with multiple screens
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/home',
          routes: {
            '/home': (context) => HomeScreen(auth: auth),
            '/profile': (context) => ProfileScreen(auth: auth),
            '/settings': (context) => SettingsScreen(auth: auth),
          },
        ),
      );

      // Add more pumps to ensure the widget tree has fully built
      await tester.pumpAndSettle();

      // Verify welcome message on home screen
      expect(find.text('Bienvenido, Test User'), findsOneWidget);

      // Navigate to profile screen
      await tester.tap(find.text('Ir a Perfil'));
      await tester.pumpAndSettle();

      // Verify profile screen displays correctly
      expect(find.text('Perfil de Test User'), findsOneWidget);

      // Navigate to settings screen
      await tester.tap(find.text('Ir a Configuración'));
      await tester.pumpAndSettle();

      // Verify settings screen displays correctly
      expect(find.text('Configuración para test@example.com'), findsOneWidget);
    });

    testWidgets(
      'Authentication state persists across different screens (Navigation)',
      (WidgetTester tester) async {
        final testUser = MockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
          isEmailVerified: true,
        );

        // Ensure user is signed in initially
        auth = MockFirebaseAuth(mockUser: testUser, signedIn: true);

        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/home',
            routes: {
              '/home': (context) => HomeScreen(auth: auth),
              '/profile': (context) => ProfileScreen(auth: auth),
              '/settings': (context) => SettingsScreen(auth: auth),
            },
          ),
        );

        // Use pumpAndSettle to wait for initial frame and potential async operations
        await tester.pumpAndSettle();

        // Debug: Print widget tree to diagnose the issue
        debugDumpApp();

        // Verify welcome message on home screen
        expect(find.text('Bienvenido, Test User'), findsOneWidget);

        // Navigate to profile screen
        await tester.tap(find.text('Ir a Perfil'));
        await tester.pumpAndSettle();
        expect(find.text('Perfil de Test User'), findsOneWidget);

        // Navigate to settings screen
        await tester.tap(find.text('Ir a Configuración'));
        await tester.pumpAndSettle();
        expect(
          find.text('Configuración para test@example.com'),
          findsOneWidget,
        );
      },
    );
  });
}

// Simple screens for testing navigation while maintaining auth state
class HomeScreen extends StatelessWidget {
  final MockFirebaseAuth auth;

  const HomeScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bienvenido, ${auth.currentUser?.displayName}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/profile');
              },
              child: const Text('Ir a Perfil'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final MockFirebaseAuth auth;

  const ProfileScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Perfil de ${auth.currentUser?.displayName}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              child: const Text('Ir a Configuración'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final MockFirebaseAuth auth;

  const SettingsScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Configuración para ${auth.currentUser?.email}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/home');
              },
              child: const Text('Volver al Inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

// Update MyApp to mimic the behavior of MiApp
class MyApp extends StatelessWidget {
  final MockFirebaseAuth auth;

  const MyApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user != null) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Bienvenido, ${user.displayName ?? 'Guest'}',
                    key: const Key('welcomeMessage'),
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
