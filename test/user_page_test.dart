import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:airplan/user_page.dart';
import 'package:airplan/user_services.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/websocket_service.dart';
import 'user_page_test.mocks.dart';

// --- Mock Firebase Platform Implementation ---
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

// Helper function to setup Firebase mocks
Future<void> setupFirebaseCoreMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = MockFirebasePlatform();
  await Firebase.initializeApp();
}

// Definir las funciones mock para inyección
Future<String> mockGetUserRealName(String username) async => 'Test User';
Future<Map<String, dynamic>> mockGetUserTypeAndLevel(String username) async => {
  'tipo': 'cliente',
  'nivell': 2,
};

@GenerateMocks([AuthService, User, UserService, WebSocketService])
void main() {
  // Ensure Firebase is initialized for all tests
  setUpAll(() async {
    await setupFirebaseCoreMocks();
  });

  // Test UserInfoCard widget
  group('UserInfoCard', () {
    testWidgets('displays correct user information for client user', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoCard(
              realName: 'Juan Pérez',
              username: 'juanp',
              email: 'juan@example.com',
              isClient: true,
              userLevel: 3,
              isLoading: false,
            ),
          ),
        ),
      );

      // Verify all user info is displayed correctly
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('juanp'), findsOneWidget);
      expect(find.text('juan@example.com'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('displays correct information for non-client user', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoCard(
              realName: 'Admin User',
              username: 'admin',
              email: 'admin@example.com',
              isClient: false,
              userLevel: 0,
              isLoading: false,
            ),
          ),
        ),
      );

      // Verify user info displayed correctly
      expect(find.text('Admin User'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
      expect(find.text('admin@example.com'), findsOneWidget);
      // Level should not be shown for non-client users
      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('displays loading indicators when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoCard(
              realName: 'Loading User',
              username: 'user',
              email: 'user@example.com',
              isClient: true,
              userLevel: 2,
              isLoading: true,
            ),
          ),
        ),
      );

      // Find CircularProgressIndicator widgets
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  // Test UserPage widget con inyección de dependencias
  group('UserPage', () {
    late MockAuthService mockAuthService;
    late MockUser mockUser;
    late MockWebSocketService mockWebSocketService;

    setUp(() {
      mockAuthService = MockAuthService();
      mockUser = MockUser();
      mockWebSocketService = MockWebSocketService();

      // Setup User mock
      when(mockUser.displayName).thenReturn('testuser');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.photoURL).thenReturn(null);

      // Setup AuthService mock
      when(mockAuthService.getCurrentUser()).thenReturn(mockUser);

      // Setup WebSocketService mock - Use StreamController for better control
      final controller = StreamController<String>();
      controller.add(json.encode({'type': 'TEST'}));
      when(
        mockWebSocketService.profileUpdates,
      ).thenAnswer((_) => controller.stream);
      when(mockWebSocketService.isConnected).thenReturn(true);
    });

    testWidgets('loads user data on initialization using injected functions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            getUserRealNameFunc: mockGetUserRealName,
            getUserTypeAndLevelFunc: mockGetUserTypeAndLevel,
          ),
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify user data was loaded using mock functions
      expect(find.text('Test User'), findsWidgets); // From mockGetUserRealName
      expect(find.text('testuser'), findsWidgets);
      expect(find.text('test@example.com'), findsWidgets);
      expect(find.text('2'), findsOneWidget); // From mockGetUserTypeAndLevel
    });

    testWidgets('shows profile buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            getUserRealNameFunc: mockGetUserRealName,
            getUserTypeAndLevelFunc: mockGetUserTypeAndLevel,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify buttons are shown
      expect(find.text('view_ratings'), findsOneWidget);
      expect(find.text('my_requests'), findsOneWidget);
      expect(find.text('blocked_users'), findsOneWidget);
      expect(find.text('edit_profile'), findsOneWidget);
      expect(find.text('delete_account'), findsOneWidget);
      expect(find.text('close_session'), findsOneWidget);
    });

    testWidgets('logout button shows confirmation dialog', (
      WidgetTester tester,
    ) async {
      // Set a larger surface for the test to make buttons visible
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugPrint('Starting test for logout button');
      await tester.pumpWidget(
        MaterialApp(
          home: UserPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            getUserRealNameFunc: mockGetUserRealName,
            getUserTypeAndLevelFunc: mockGetUserTypeAndLevel,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the logout button and ensure it's visible by scrolling to it
      final logoutButtonFinder = find.text('close_session');
      await tester.scrollUntilVisible(logoutButtonFinder, 500);
      await tester.pumpAndSettle();
      // Tap logout button
      await tester.tap(logoutButtonFinder);
      await tester.pumpAndSettle();

      // Verify dialog appears

      expect(find.text('cancel'), findsOneWidget);
      // The button text appears twice: once on the main page, once in the dialog
      expect(find.text('close_session'), findsWidgets);

      // Reset size after test
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetDevicePixelRatio);
      });
    });

    testWidgets('delete account button shows confirmation dialog', (
      WidgetTester tester,
    ) async {
      // Set a larger surface for the test to make buttons visible
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: UserPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            getUserRealNameFunc: mockGetUserRealName,
            getUserTypeAndLevelFunc: mockGetUserTypeAndLevel,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the delete button and ensure it's visible by scrolling to it
      final deleteButtonFinder = find.text('delete_account');
      await tester.scrollUntilVisible(deleteButtonFinder, 500);
      await tester.pumpAndSettle();

      // Tap delete account button
      await tester.tap(deleteButtonFinder);
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('confirm_delete_account_message'), findsOneWidget);
      expect(find.text('cancel'), findsOneWidget);
      expect(find.text('delete'), findsOneWidget);

      // Reset size after test
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetDevicePixelRatio);
      });
    });
  });
}
