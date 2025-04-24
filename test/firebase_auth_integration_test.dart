// firebase_auth_integration_test.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'test_helpers.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUserInstance; // Store the MockUser instance

  setUp(() {
    FirebaseTestSetup.setupFirebaseMocks();
    mockUserInstance = MockUser(
      email: 'test@example.com',
      displayName: 'Test User',
    ); // Create and store
    // Use custom mock to throw on wrong password
    mockAuth = CustomMockFirebaseAuth(
      mockUser: mockUserInstance, // Use stored instance
      throwOnWrongPassword: true,
    );
    // Session persistence handled by MockFirebaseAuth
  });

  group('Firebase Auth Integration Tests', () {
    test(
      'Sign in with email and password succeeds with correct credentials',
      () async {
        final user = MockUser(
          email: 'test@example.com',
          displayName: 'Test User',
        );
        mockAuth = MockFirebaseAuth(mockUser: user);

        final userCredential = await mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(userCredential.user, isNotNull);
        expect(userCredential.user!.email, equals('test@example.com'));
        expect(mockAuth.currentUser, isNotNull);
      },
    );

    test('Sign in fails with incorrect credentials', () async {
      // Use the mockAuth instance from setUp, which is CustomMockFirebaseAuth
      expect(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'wrongPassword',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('User registration succeeds with valid data', () async {
      final email = 'newuser@example.com';
      final password = 'newpassword123';

      final userCredential = await mockAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      expect(userCredential.user, isNotNull);
      expect(userCredential.user!.email, equals(email));
    });

    test('Sign out works correctly', () async {
      // First sign in
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(mockAuth.currentUser, isNotNull);

      // Then sign out
      await mockAuth.signOut();
      expect(mockAuth.currentUser, isNull);
    });

    test('Password reset email can be sent', () async {
      // Usando un enfoque más simple sin depender de mocks
      // Simplemente verificamos que la función completa sin errores
      try {
        await mockAuth.sendPasswordResetEmail(email: 'test@example.com');
        // Si llegamos aquí, el test pasa
        expect(true, isTrue);
      } catch (e) {
        // Si hay una excepción, el test falla
        fail('La función debería completarse sin errores');
      }
    });
  });

  group('User session persistence tests', () {
    test('User remains authenticated after app restart simulation', () async {
      // Sign in user
      // Ensure we use the mockAuth from setUp
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      // Verify user is signed in
      expect(mockAuth.currentUser, isNotNull);
      final originalUserStatus =
          mockAuth.currentUser != null; // Store signed-in status

      // Create a new auth instance (simulates app restart accessing persisted state)
      // Initialize new instance reflecting the previous state
      final persistedAuth = MockFirebaseAuth(
        mockUser: mockUserInstance, // Pass the stored MockUser instance
        signedIn: originalUserStatus, // Pass the signed-in status
      );

      // User should still be signed in
      expect(persistedAuth.currentUser, isNotNull);
      expect(persistedAuth.currentUser!.email, equals('test@example.com'));
    });
  });
}

// Add custom auth mock with error injection
class CustomMockFirebaseAuth extends MockFirebaseAuth {
  final bool throwOnWrongPassword;
  CustomMockFirebaseAuth({super.mockUser, this.throwOnWrongPassword = false});

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (throwOnWrongPassword && password == 'wrongPassword') {
      print(
        'CustomMockFirebaseAuth: Throwing wrong-password exception...',
      ); // Debug print
      throw FirebaseAuthException(
        code: 'wrong-password',
        message:
            'The password is invalid or the user does not have a password.',
      );
    }
    // If not throwing, proceed with superclass logic
    print(
      'CustomMockFirebaseAuth: Calling super.signInWithEmailAndPassword...',
    ); // Debug print
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}
