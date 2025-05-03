import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:airplan/edit_profile_page.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/websocket_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/login_page.dart';

import 'edit_profile_page_test.mocks.dart';

// Definir el controller global para tests
late StreamController<Map<String, dynamic>> profileUpdateStreamController;

// Mock Firebase Platform Implementation
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

// Mock notification service para tests
class MockNotificationService extends NotificationService {
  @override
  void showError(BuildContext context, String message) {
    // Mock implementation: Do nothing
  }

  @override
  void showInfo(BuildContext context, String message) {
    // Mock implementation: Do nothing
  }

  @override
  void showSuccess(BuildContext context, String message) {
    // Mock implementation: Do nothing
  }
}

Future<void> setupFirebaseCoreMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = MockFirebasePlatform();
  await Firebase.initializeApp();
}

@GenerateMocks([AuthService, User, http.Client, WebSocketService])
void main() {
  late MockAuthService mockAuthService;
  late MockUser mockUser;
  late MockWebSocketService mockWebSocketService;
  late StreamController<User?> authStateController;
  late StreamController<String> profileUpdateController;

  setUpAll(() async {
    await setupFirebaseCoreMocks();
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockUser = MockUser();
    mockWebSocketService = MockWebSocketService();
    authStateController = StreamController<User?>.broadcast();
    profileUpdateController = StreamController<String>.broadcast();

    // Setup default mock behaviors
    when(mockAuthService.getCurrentUser()).thenReturn(mockUser);
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('testuser');
    // Return null for photoURL to avoid network requests
    when(mockUser.photoURL).thenReturn(null);
    when(
      mockAuthService.authStateChanges,
    ).thenAnswer((_) => authStateController.stream);
    when(mockUser.reload()).thenAnswer((_) => Future<void>.value());

    // Setup WebSocketService mock
    when(
      mockWebSocketService.profileUpdates,
    ).thenAnswer((_) => profileUpdateController.stream);
    when(mockWebSocketService.clientId).thenReturn('test-client-id');
    when(mockWebSocketService.isConnected).thenReturn(true);
    when(
      mockWebSocketService.connect(),
    ).thenAnswer((_) => Future<void>.value());

    // Initialize global controller para tests
    profileUpdateStreamController =
        StreamController<Map<String, dynamic>>.broadcast();
  });

  tearDown(() {
    authStateController.close();
    profileUpdateController.close();
    profileUpdateStreamController.close();
  });

  // Create a testable version of EditProfilePage with fixed size to avoid layout issues
  Widget createTestableEditProfilePage() {
    return MaterialApp(
      routes: {'/login': (context) => const LoginPage()},
      home: SizedBox(
        width: 800,
        height: 600,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: 800, maxHeight: 600),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: 600),
                child: EditProfilePage(
                  authService: mockAuthService,
                  webSocketService: mockWebSocketService,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('EditProfilePage initializes with correct user data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestableEditProfilePage());
    await tester.pumpAndSettle();

    // Simulate successful user data load
    profileUpdateStreamController.add({'type': 'app_launched'});
    await tester.pumpAndSettle();

    // Verify the username from Firebase is displayed
    expect(find.text('testuser'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
  });

  testWidgets('Validate empty name field shows error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestableEditProfilePage());
    await tester.pumpAndSettle();

    // Enter empty name
    await tester.enterText(find.widgetWithText(TextField, 'Nombre').first, '');

    // Use NotificationService mock instead of finding text in widget tree
    final saveButton = find.text('Guardar Cambios');
    await tester.dragUntilVisible(
      saveButton,
      find.byType(SingleChildScrollView),
      const Offset(0, 50),
    );

    // Tap save button
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Check that the error was reported via NotificationService mock
    expect(find.text('El nombre no puede estar vacío.'), findsOneWidget);
  });

  testWidgets('Validate invalid email format shows error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestableEditProfilePage());
    await tester.pumpAndSettle();

    // Enter an invalid email
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo Electrónico'),
      'invalid-email',
    );

    // Make sure name is not empty to pass that validation
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre').first,
      'Test Name',
    );

    // Scroll to make save button visible
    final saveButton = find.text('Guardar Cambios');
    await tester.dragUntilVisible(
      saveButton,
      find.byType(SingleChildScrollView),
      const Offset(0, 50),
    );

    // Tap save button
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Check that the error was reported via NotificationService mock
    expect(
      find.text('Por favor, introduce un correo electrónico válido.'),
      findsOneWidget,
    );
  });

  // Simplified test focusing only on password mismatch
  testWidgets('Password mismatch shows error', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableEditProfilePage());
    await tester.pumpAndSettle();

    // Scroll to password section
    final newPasswordField = find.widgetWithText(TextField, 'Nueva Contraseña');
    await tester.dragUntilVisible(
      newPasswordField,
      find.byType(SingleChildScrollView),
      const Offset(0, 50),
    );

    // --- Test mismatched passwords directly ---

    // Enter passwords: current, new, and mismatched confirmation
    await tester.enterText(
      find.widgetWithText(TextField, 'Contraseña Actual'),
      'currentpass', // Provide a current password
    );
    await tester.enterText(newPasswordField, 'newpass123');
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar Nueva Contraseña'),
      'different456', // Mismatched password
    );

    // Find the button text
    final updateButtonText = find.text('Actualizar Contraseña');
    await tester.dragUntilVisible(
      updateButtonText,
      find.byType(SingleChildScrollView),
      const Offset(0, 50),
    );

    // Ensure the button text is visible and tap it
    await tester.ensureVisible(updateButtonText);
    await tester.pumpAndSettle();
    await tester.tap(
      updateButtonText,
      warnIfMissed: false,
    ); // Tap text directly

    // Wait for UI updates, potentially adding a small explicit delay
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100)); // Small delay

    // Check for the error message directly in the UI
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('User logs out when authStateChanges emits null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfilePage(
          authService: mockAuthService,
          webSocketService: mockWebSocketService,
        ),
        routes: {'/login': (context) => const LoginPage()},
      ),
    );

    await tester.pumpAndSettle();

    // Simulate user logout
    authStateController.add(null);
    await tester.pumpAndSettle();

    // Expect navigation to login page
    expect(find.byType(EditProfilePage), findsNothing);
  });

  testWidgets('Image selection UI shows correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestableEditProfilePage());
    await tester.pumpAndSettle();

    // Verify image button is present
    expect(find.text('Cambiar Foto de Perfil'), findsOneWidget);

    // Verify profile image is displayed - CircleAvatar should exist
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('Real-time updates from WebSocketService refresh UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestableEditProfilePage());
    await tester.pumpAndSettle();

    // Setup reload method mock to verify it's called
    when(mockUser.reload()).thenAnswer((_) => Future.value());

    // Simulate a WebSocket update
    profileUpdateController.add(
      json.encode({
        'type': 'PROFILE_UPDATE',
        'username': 'testuser',
        'email': 'test@example.com',
        'updatedFields': ['displayName', 'email'],
      }),
    );

    await tester.pumpAndSettle();

    // Verify the user reload was called
    verify(mockUser.reload()).called(1);
  });
}
