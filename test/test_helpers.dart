// test_helpers.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Clase de configuración para mocks de Firebase
class FirebaseTestSetup {
  // Mock de usuario
  static final mockUser = MockUser(
    uid: 'test-uid',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  // Mock de Auth
  static final mockAuth = MockFirebaseAuth(
    mockUser: mockUser,
    signedIn: false, // Comenzamos sin sesión iniciada
  );

  // Configurar los mocks de Firebase necesarios antes de las pruebas
  static Future<void> setupFirebaseMocks() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp();
      // No asignamos directamente a FirebaseAuth.instance,
      // en su lugar, usaremos el mockAuth en los tests
    } catch (e) {
      // Ignoramos errores de inicialización que pueden ocurrir durante los tests
      print('Firebase initialization error (expected in tests): $e');
    }
  }

  // Método estático para obtener la instancia de auth mockeada
  static MockFirebaseAuth getAuth() {
    return mockAuth;
  }
}
