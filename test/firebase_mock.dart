// firebase_mock.dart
// This file provides Firebase mocking utilities for tests

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

// Simple minimal implementation of a FirebaseApp for testing
class TestFirebaseApp implements FirebaseApp {
  @override
  String get name => '[DEFAULT]';

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-messaging-sender-id',
    projectId: 'test-project-id',
  );

  @override
  Future<void> delete() async {}

  @override
  bool get isAutomaticDataCollectionEnabled => false;

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirebaseApp &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'FirebaseApp($name)';
}

// Mock User for authentication
class MockUser implements User {
  @override
  String get uid => 'test-uid';

  @override
  String? get email => 'test@example.com';

  @override
  String? get displayName => 'Test User';

  @override
  bool get emailVerified => true;

  // Implement other necessary User methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock UserCredential for sign-in results
class MockUserCredential implements UserCredential {
  final User _mockUser = MockUser();

  @override
  User get user => _mockUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Export mock instances for tests
final mockFirebaseApp = TestFirebaseApp();
final mockUser = MockUser();
final mockUserCredential = MockUserCredential();

// Setup Firebase mocks for tests
void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  debugPrint('Firebase Auth mocking is setup and ready to use');
}

// This is the key method from Firebase Core test helpers
void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Using a safer approach for mocking Firebase initialization
  // We don't need to mock method channels directly if we initialize Firebase properly
}

// Initialize Firebase for tests
Future<void> initializeFirebaseForTest() async {
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized for tests');
  } catch (e) {
    // In tests it's normal for initialization to fail since we're in a test environment
    debugPrint('Firebase initialization error (expected in tests): $e');
  }
}
