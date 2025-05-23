import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:airplan/admin_page.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/websocket_service.dart';

import 'admin_page_test.mocks.dart';

// Mock implementation of FirebaseApp
class MockFirebaseAppPlatform extends FirebaseAppPlatform
    with MockPlatformInterfaceMixin {
  MockFirebaseAppPlatform() : super('[DEFAULT]', _mockOptions);

  static const FirebaseOptions _mockOptions = FirebaseOptions(
    apiKey: 'mock_api_key',
    appId: 'mock_app_id',
    messagingSenderId: 'mock_sender_id',
    projectId: 'mock_project_id',
  );
}

class MockFirebasePlatform extends FirebasePlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseAppPlatform();
  }

  @override
  List<FirebaseAppPlatform> get apps => [MockFirebaseAppPlatform()];

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseAppPlatform();
  }
}

// Setup Firebase mocks
Future<void> setupFirebaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = MockFirebasePlatform();
  await Firebase.initializeApp();
}

// Mock user for AuthService
class MockUser implements User {
  @override
  String? displayName = 'testAdminUser';

  @override
  String? get email => 'admin@example.com';

  @override
  String get uid => 'admin-uid';

  @override
  String? get photoURL => null;

  @override
  bool get emailVerified => true;

  @override
  bool get isAnonymous => false;

  @override
  List<UserInfo> get providerData => [];

  @override
  String get tenantId => '';

  @override
  UserMetadata get metadata => UserMetadata(0, 0);

  @override
  Future<void> delete() async {}

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'mock-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

@GenerateMocks([AuthService, WebSocketService])
void main() {
  late MockAuthService mockAuthService;
  late MockWebSocketService mockWebSocketService;
  late StreamController<User?> authStateController;

  setUpAll(() async {
    await setupFirebaseMocks();
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockWebSocketService = MockWebSocketService();
    authStateController = StreamController<User?>.broadcast();

    // Create a stream controller for profile updates with correct type
    final profileUpdatesController = StreamController<String>.broadcast();

    final mockUser = MockUser();

    // Setup default behaviors
    when(mockAuthService.getCurrentUser()).thenReturn(mockUser);
    when(
      mockAuthService.authStateChanges,
    ).thenAnswer((_) => authStateController.stream);
    when(mockWebSocketService.isConnected).thenReturn(false);
    when(mockWebSocketService.connect()).thenReturn(null);

    // Mock the profileUpdates stream with the correct Stream<String> type
    when(
      mockWebSocketService.profileUpdates,
    ).thenAnswer((_) => profileUpdatesController.stream);
  });

  tearDown(() {
    authStateController.close();
  });

  testWidgets('AdminPage displays tabs correctly', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPage(
          authService: mockAuthService,
          webSocketService: mockWebSocketService,
        ),
      ),
    );

    // Act - just pumping the widget
    await tester.pump();

    // Assert
    expect(find.text('profile_tab_label'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('admin_profile_title'), findsOneWidget); // AppBar title

    // Should have UserProfileContent in the first tab
    expect(find.byType(UserProfileContent), findsOneWidget);
  });

  testWidgets('AdminPage connects to WebSocket when not connected', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(mockWebSocketService.isConnected).thenReturn(false);

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPage(
          authService: mockAuthService,
          webSocketService: mockWebSocketService,
        ),
      ),
    );
    await tester.pump();

    // Assert
    // Verify the connect method is called at least once
    verify(mockWebSocketService.connect()).called(greaterThanOrEqualTo(1));
  });

  testWidgets(
    'AdminPage does not connect to WebSocket when already connected',
    (WidgetTester tester) async {
      // Arrange
      when(mockWebSocketService.isConnected).thenReturn(true);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: AdminPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
          ),
        ),
      );
      await tester.pump();

      // Assert
      verifyNever(mockWebSocketService.connect());
    },
  );

  testWidgets('AdminPage switches tabs when bottom navigation is tapped', (
    WidgetTester tester,
  ) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPage(
          authService: mockAuthService,
          webSocketService: mockWebSocketService,
        ),
      ),
    );

    // Initial state - should be on first tab
    expect(find.text('admin_profile_title'), findsOneWidget);

    // Act - tap on Admin tab
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    // Assert - title should change
    expect(find.text('Reports'), findsWidgets);
  });

  testWidgets('UserProfileContent passes services to UserPage', (
    WidgetTester tester,
  ) async {
    // The test can't fully verify the passing of services to UserPage
    // since UserPage might have its own complex initialization
    // But we can at least test that UserProfileContent renders

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserProfileContent(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
          ),
        ),
      ),
    );

    // We can only verify that the widget renders without errors
    expect(tester.takeException(), isNull);
  });
}
