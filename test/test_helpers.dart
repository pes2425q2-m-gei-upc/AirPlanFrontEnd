// test_helpers.dart
import 'package:airplan/services/websocket_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';

@GenerateMocks([http.Client, WebSocketService])
import 'test_helpers.mocks.dart';

// Firebase test configuration
class FirebaseTestSetup {
  static MockFirebaseAuth? _auth;
  static MockWebSocketService? _webSocketService;
  static MockClient? _httpClient;

  /// Initialize Firebase mocks for testing
  static void setupFirebaseMocks() {
    // Create mock user
    final mockUser = MockUser(
      displayName: 'testuser',
      email: 'test@example.com',
      uid: 'test-uid-123',
    );

    // Initialize mock auth with the user
    _auth = MockFirebaseAuth(mockUser: mockUser);

    // Initialize mock WebSocket service
    _webSocketService = MockWebSocketService();
    when(_webSocketService!.isConnected).thenReturn(true);
    when(_webSocketService!.clientId).thenReturn('test-client-id');

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

  /// Get the mock WebSocket service
  static MockWebSocketService getWebSocketService() {
    if (_webSocketService == null) setupFirebaseMocks();
    return _webSocketService!;
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
  final MockWebSocketService? webSocketService;

  const TestWrapper({
    super.key,
    required this.child,
    this.auth,
    this.webSocketService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: child));
  }
}
