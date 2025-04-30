import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

@GenerateMocks([http.Client])
import 'test_helpers.mocks.dart';

class FirebaseTestSetup {
  static MockFirebaseAuth? _auth;
  static MockClient? _httpClient;

  /// Initialize Firebase mocks for testing
  static void setupFirebaseMocks() {
    final mockUser = MockUser(
      displayName: 'testuser',
      email: 'test@example.com',
      uid: 'test-uid-123',
    );

    // Initialize mock auth with the user
    _auth = MockFirebaseAuth(mockUser: mockUser);

    // Initialize mock HTTP client
    _httpClient = MockClient();
    when(
      _httpClient!.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => http.Response('{"success": true}', 200));
  }

  /// Get the mock Firebase Auth instance
  static MockFirebaseAuth getFirebaseAuth() {
    if (_auth == null) setupFirebaseMocks();
    return _auth!;
  }

  /// Get the mock HTTP client
  static MockClient getHttpClient() {
    if (_httpClient == null) setupFirebaseMocks();
    return _httpClient!;
  }
}

/// Test wrapper that provides mock services to widget trees
class TestWrapper extends StatelessWidget {
  final Widget child;
  final MockFirebaseAuth? auth;

  const TestWrapper({
    super.key,
    required this.child,
    this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: child));
  }
}
