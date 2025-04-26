// authentication_error_handling_test.dart
// Import dart:async for Completer
import 'dart:convert'; // Add import for Encoding class
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MockFirebaseAuthWithError extends MockFirebaseAuth {
  final FirebaseAuthException exceptionToThrow;
  final bool isSignIn;

  MockFirebaseAuthWithError.signIn(this.exceptionToThrow) : isSignIn = true;
  MockFirebaseAuthWithError.register(this.exceptionToThrow) : isSignIn = false;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (isSignIn) throw exceptionToThrow;
    return super.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!isSignIn) throw exceptionToThrow;
    return super.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}

class MockHttpClient extends Mock implements http.Client {
  // Add explicit implementation to avoid null safety issues with Mockito
  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    // This implementation will be overridden by when().thenAnswer()
    return super.noSuchMethod(
      Invocation.method(
        #post,
        [url],
        {#headers: headers, #body: body, #encoding: encoding},
      ),
      returnValue: Future.value(http.Response('', 200)),
    );
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    // This implementation will be overridden by when().thenAnswer()
    return super.noSuchMethod(
      Invocation.method(#get, [url], {#headers: headers}),
      returnValue: Future.value(http.Response('', 200)),
    );
  }
}

// Helper function to create a Future that throws
Future<T> futureThatThrows<T>(Object exception) {
  return Future.error(exception);
}

void main() {
  // Remove FakeUri and fallback registration, use any<Uri>(fallback) directly in stubs

  // No fallback registration needed; use untyped `any` matcher for URIs

  setUp(() {});

  group('Authentication Error Handling Tests', () {
    test('Handles incorrect password error', () async {
      final auth = MockFirebaseAuthWithError.signIn(
        FirebaseAuthException(
          code: 'wrong-password',
          message: 'The password is invalid',
        ),
      );

      expect(
        () => auth.signInWithEmailAndPassword(
          email: 'wrong@example.com',
          password: 'wrongPassword123',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Handles user not found error', () async {
      final auth = MockFirebaseAuthWithError.signIn(
        FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for that email.',
        ),
      );

      expect(
        () => auth.signInWithEmailAndPassword(
          email: 'nonexistent@example.com',
          password: 'anyPassword',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Handles email already in use during registration', () async {
      final auth = MockFirebaseAuthWithError.register(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email is already in use.',
        ),
      );

      expect(
        () => auth.createUserWithEmailAndPassword(
          email: 'existing@example.com',
          password: 'anyPassword',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('Network Connectivity Error Tests', () {
    testWidgets('Handles API timeout during profile update', (
      WidgetTester tester,
    ) async {
      final httpClient = MockHttpClient();

      // Use simpler mock setup that avoids matcher issues
      when(
        httpClient.post(
          Uri.parse('https://api.airplan.com/profile'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) => futureThatThrows(http.ClientException('Connection timed out')),
      );

      String? errorMessageText;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder:
                (context, setState) => Scaffold(
                  body: Column(
                    children: [
                      ElevatedButton(
                        key: const Key('updateButton'),
                        onPressed: () async {
                          try {
                            // Ensure the Uri matches what the mock expects or use any<Uri>()
                            await httpClient.post(
                              Uri.parse('https://api.airplan.com/profile'),
                              headers: {'Content-Type': 'application/json'},
                              body: '{"name": "Test User"}',
                            );
                            setState(() => errorMessageText = null);
                          } catch (e) {
                            setState(
                              () =>
                                  errorMessageText =
                                      'Error de conexión: intenta de nuevo más tarde.',
                            );
                          }
                        },
                        child: const Text('Actualizar Perfil'),
                      ),
                      if (errorMessageText != null)
                        Text(
                          errorMessageText!,
                          key: const Key('errorMessage'),
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('updateButton')));
      // Pump longer or pumpAndSettle if waiting for async operations and UI updates
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('errorMessage')), findsOneWidget);
      expect(
        find.text('Error de conexión: intenta de nuevo más tarde.'),
        findsOneWidget,
      );
    });

    testWidgets('Shows offline indicator when device is offline', (
      WidgetTester tester,
    ) async {
      bool isOffline = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder:
                (context, setState) => Scaffold(
                  appBar: AppBar(
                    title: const Text('AirPlan'),
                    actions: [
                      if (isOffline)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.cloud_off,
                            key: Key('offlineIcon'),
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                  body: Center(
                    child: ElevatedButton(
                      child: const Text('Cambiar estado de red'),
                      onPressed: () => setState(() => isOffline = !isOffline),
                    ),
                  ),
                ),
          ),
        ),
      );

      expect(find.byKey(const Key('offlineIcon')), findsOneWidget);

      await tester.tap(find.text('Cambiar estado de red'));
      await tester.pump();

      expect(find.byKey(const Key('offlineIcon')), findsNothing);
    });

    testWidgets('Retries failed operations when connection is restored', (
      WidgetTester tester,
    ) async {
      bool isOnline = false;
      int apiCallCount = 0;
      String status = "Initial";

      // Remove Completer as it's causing issues and not needed for this test
      // No need for: late Completer<bool> apiCallCompleter;

      Future<bool> simulateApiCall() async {
        apiCallCount++;
        if (!isOnline) {
          throw http.ClientException('No internet connection');
        }
        return true; // Success
      }

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder:
                (context, setState) => Scaffold(
                  body: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Llamadas API: $apiCallCount',
                        key: const Key('apiCallCountText'),
                      ),
                      Text('Status: $status', key: const Key('statusText')),
                      ElevatedButton(
                        key: const Key('apiButton'),
                        onPressed: () async {
                          try {
                            setState(() => status = "Calling API (Offline)");
                            await simulateApiCall();
                            setState(
                              () =>
                                  status =
                                      "API Call Success (should not happen offline)",
                            );
                          } catch (e) {
                            setState(
                              () => status = "API Call Failed (Offline)",
                            );
                          }
                        },
                        child: const Text('Llamar API'),
                      ),
                      ElevatedButton(
                        key: const Key('networkButton'),
                        onPressed: () {
                          // Simplified to avoid async operations within button callbacks
                          setState(() {
                            isOnline = true;
                            status = "Connection Restored";
                          });
                        },
                        child: const Text('Restaurar Conexión'),
                      ),
                      ElevatedButton(
                        key: const Key('retryButton'),
                        onPressed: () {
                          // Separate retry button for better test control
                          simulateApiCall()
                              .then((result) {
                                setState(() => status = "Retry Success");
                              })
                              .catchError((error) {
                                setState(() => status = "Retry Failed");
                              });
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
          ),
        ),
      );

      // Initial state
      expect(find.text('Llamadas API: 0'), findsOneWidget);
      expect(find.text('Status: Initial'), findsOneWidget);

      // Tap button while offline
      await tester.tap(find.byKey(const Key('apiButton')));
      await tester
          .pumpAndSettle(); // Use pumpAndSettle to wait for all animations and async operations

      expect(find.text('Llamadas API: 1'), findsOneWidget);
      expect(find.text('Status: API Call Failed (Offline)'), findsOneWidget);

      // Tap button to restore connection
      await tester.tap(find.byKey(const Key('networkButton')));
      await tester.pumpAndSettle();

      expect(find.text('Status: Connection Restored'), findsOneWidget);

      // Now tap retry button
      await tester.tap(find.byKey(const Key('retryButton')));
      await tester.pumpAndSettle();

      expect(find.text('Llamadas API: 2'), findsOneWidget);
      expect(find.text('Status: Retry Success'), findsOneWidget);
    });

    testWidgets('Handle HTTP error gracefully', (WidgetTester tester) async {
      final mockHttpClient = MockHttpClient();

      // Use a concrete URI instead of 'any' matcher
      when(
        mockHttpClient.get(Uri.parse('http://example.com/data')),
      ).thenAnswer((_) async => http.Response('Server Error', 500));

      // Use a simpler approach without GlobalKey<StatefulBuilderState>
      String? displayError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder:
                  (context, setState) => Column(
                    children: [
                      ElevatedButton(
                        key: const Key('fetchButton'),
                        onPressed: () async {
                          try {
                            final response = await mockHttpClient.get(
                              Uri.parse('http://example.com/data'),
                            );
                            if (response.statusCode >= 400) {
                              setState(
                                () =>
                                    displayError =
                                        'Error: ${response.statusCode}',
                              );
                            } else {
                              setState(() => displayError = null);
                            }
                          } catch (e) {
                            setState(
                              () =>
                                  displayError =
                                      'Exception caught: ${e.toString()}',
                            );
                          }
                        },
                        child: const Text('Fetch Data'),
                      ),
                      if (displayError != null)
                        Container(
                          key: const Key('errorDisplay'),
                          padding: const EdgeInsets.all(16),
                          color: Colors.red.shade100,
                          child: Text(
                            displayError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
            ),
          ),
        ),
      );

      // Verify initial state - no error display
      expect(find.byKey(const Key('errorDisplay')), findsNothing);

      // Tap button to trigger HTTP request
      await tester.tap(find.byKey(const Key('fetchButton')));
      await tester.pumpAndSettle(); // Allow async operations and UI to update

      // Verify error is displayed
      expect(find.byKey(const Key('errorDisplay')), findsOneWidget);
      expect(find.text('Error: 500'), findsOneWidget);
    });
  });
}
