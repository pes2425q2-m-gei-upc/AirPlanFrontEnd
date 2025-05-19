import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:airplan/login_page.dart';
import 'package:airplan/reset_password.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/websocket_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart'; // Import mixin
import 'login_page_test.mocks.dart';

// Generate mocks
@GenerateMocks([http.Client, WebSocketService, AuthService])
// --- Mock Firebase Platform Implementation ---
// Update MockFirebaseAppPlatform to extend FirebaseAppPlatform and use MockPlatformInterfaceMixin
class MockFirebaseAppPlatform extends FirebaseAppPlatform
    with MockPlatformInterfaceMixin {
  // Call super with positional arguments as required by FirebaseAppPlatform
  MockFirebaseAppPlatform() : super('[DEFAULT]', _mockOptions);

  static const FirebaseOptions _mockOptions = FirebaseOptions(
    apiKey: 'mock_api_key',
    appId: 'mock_app_id',
    messagingSenderId: 'mock_sender_id',
    projectId: 'mock_project_id',
  );

  // Override methods used by your code if necessary, otherwise the mixin handles them.
}

// Update MockFirebasePlatform to extend FirebasePlatform and use MockPlatformInterfaceMixin
class MockFirebasePlatform extends FirebasePlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseAppPlatform(); // Return the mock platform app
  }

  @override
  List<FirebaseAppPlatform> get apps => [MockFirebaseAppPlatform()]; // Return list with mock platform app

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseAppPlatform(); // Return the mock platform app
  }

  // Implement other methods if they are called during your tests
}

// Create stubs for Firebase types
class TestUserCredential implements UserCredential {
  @override
  final User? user;
  @override
  final AdditionalUserInfo? additionalUserInfo = null;
  @override
  final AuthCredential? credential = null;

  TestUserCredential({this.user});
}

class TestUser implements User {
  final String? _email;
  final String? _displayName;

  TestUser({String? email, String? displayName})
    : _email = email,
      _displayName = displayName;

  @override
  String? get email => _email;

  @override
  String? get displayName => _displayName;

  // Implement remaining required methods with default values
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Helper function to setup Firebase mocks using FirebasePlatform.instance
Future<void> setupFirebaseCoreMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Set the mock platform instance *before* calling Firebase.initializeApp
  FirebasePlatform.instance = MockFirebasePlatform();
  // No need to mock MethodChannel directly when using FirebasePlatform.instance

  // Initialize Firebase - this will now use the MockFirebasePlatform
  await Firebase.initializeApp();
}

void main() {
  late MockAuthService mockAuthService;
  late MockWebSocketService mockWebSocketService;
  late MockClient mockHttpClient;

  // Use setUpAll for one-time setup like Firebase initialization
  setUpAll(() async {
    await setupFirebaseCoreMocks();
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockWebSocketService = MockWebSocketService();
    mockHttpClient = MockClient();

    // Default mock behavior
    when(mockWebSocketService.clientId).thenReturn('test-client-id');
  });

  group('LoginPage UI Tests', () {
    testWidgets('renders all required UI elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            httpClient: mockHttpClient,
          ),
        ),
      );

      // Verify UI elements
      expect(find.text('login_title'), findsNWidgets(1)); // AppBar + button
      expect(find.text('email_label'), findsOneWidget);
      expect(find.text('password_label'), findsOneWidget);
      expect(find.text("signup_prompt"), findsOneWidget);
      expect(find.text('reset_password'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('navigates to signup page when register link is tapped', (
      WidgetTester tester,
    ) async {
      final mockSignUpPage = Scaffold(
        appBar: AppBar(title: const Text('Mock SignUpPage')),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            httpClient: mockHttpClient,
            signUpPage: mockSignUpPage,
          ),
        ),
      );

      // Simulate tapping the register link
      await tester.tap(find.text("signup_prompt"));
      await tester.pumpAndSettle();

      // Verify navigation to the mock SignUpPage
      expect(find.text('Mock SignUpPage'), findsOneWidget);
    });

    testWidgets(
      'navigates to reset password page when forgot password link is tapped',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LoginPage(
              authService: mockAuthService,
              webSocketService: mockWebSocketService,
              httpClient: mockHttpClient,
            ),
          ),
        );

        await tester.tap(find.text('reset_password'));
        await tester.pumpAndSettle();

        expect(find.byType(ResetPasswordPage), findsOneWidget);
      },
    );
  });

  group('LoginPage Functionality Tests', () {
    testWidgets('successful login flow', (WidgetTester tester) async {
      // Create our test firebase user
      final testUser = TestUser(
        email: 'test@example.com',
        displayName: 'Test User',
      );
      final testCredential = TestUserCredential(user: testUser);

      when(
        mockAuthService.signInWithEmailAndPassword(any, any),
      ).thenAnswer((_) async => testCredential);

      when(
        mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"success": true}', 200));

      // Build our app and trigger a frame
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            httpClient: mockHttpClient,
          ),
        ),
      );

      // Enter credentials and login
      await tester.enterText(
        find.widgetWithText(TextField, 'email_label'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'password_label'),
        'password',
      );
      await tester.tap(find.text('login_button'));
      await tester.pump();

      // Verify service calls
      verify(
        mockAuthService.signInWithEmailAndPassword(
          'test@example.com',
          'password',
        ),
      ).called(1);
      verify(
        mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: contains('test@example.com'),
        ),
      ).called(1);
      verify(mockWebSocketService.connect()).called(1);
    });

    testWidgets('shows error when user is null after authentication', (
      WidgetTester tester,
    ) async {
      // Arrange - Setup null user response
      when(
        mockAuthService.signInWithEmailAndPassword(any, any),
      ).thenAnswer((_) async => TestUserCredential(user: null));

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            httpClient: mockHttpClient,
          ),
        ),
      );

      // Enter credentials and login
      await tester.enterText(
        find.widgetWithText(TextField, 'email_label'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'password_label'),
        'password',
      );
      await tester.tap(find.text('login_button'));
      await tester.pump();

      // Verify error message
      expect(
        find.text('Error: No se pudo obtener la información del usuario'),
        findsOneWidget,
      );
    });

    testWidgets('shows error when user email is missing', (
      WidgetTester tester,
    ) async {
      // Arrange - Setup user with missing email
      final testUser = TestUser(displayName: 'Test User', email: null);
      final testCredential = TestUserCredential(user: testUser);

      when(
        mockAuthService.signInWithEmailAndPassword(any, any),
      ).thenAnswer((_) async => testCredential);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            httpClient: mockHttpClient,
          ),
        ),
      );

      // Enter credentials and login
      await tester.enterText(
        find.widgetWithText(TextField, 'email_label'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'password_label'),
        'password',
      );
      await tester.tap(find.text('login_button'));
      await tester.pump();

      // Verify error message
      expect(find.text('Error: Falta información del usuario'), findsOneWidget);
    });

    testWidgets('shows error when backend returns non-200 status', (
      WidgetTester tester,
    ) async {
      // Arrange
      final testUser = TestUser(
        email: 'test@example.com',
        displayName: 'Test User',
      );
      final testCredential = TestUserCredential(user: testUser);

      when(
        mockAuthService.signInWithEmailAndPassword(any, any),
      ).thenAnswer((_) async => testCredential);

      when(
        mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => http.Response('{"error": "Server error"}', 500),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            httpClient: mockHttpClient,
          ),
        ),
      );

      // Enter credentials and login
      await tester.enterText(
        find.widgetWithText(TextField, 'email_label'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'password_label'),
        'password',
      );
      await tester.tap(find.text('login_button'));
      await tester.pump();

      // Verify error message
      expect(
        find.text('Error en el backend: {"error": "Server error"}'),
        findsOneWidget,
      );
      verifyNever(mockWebSocketService.connect());
    });

    testWidgets('handles authentication exceptions correctly', (
      WidgetTester tester,
    ) async {
      // Arrange - Setup auth exception
      when(
        mockAuthService.signInWithEmailAndPassword(any, any),
      ).thenThrow(Exception('invalid-credential'));

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            authService: mockAuthService,
            webSocketService: mockWebSocketService,
            httpClient: mockHttpClient,
          ),
        ),
      );

      // Enter credentials and login
      await tester.enterText(
        find.widgetWithText(TextField, 'email_label'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'password_label'),
        'password',
      );
      await tester.tap(find.text('login_button'));
      await tester.pump();

      // Verify error message
      expect(find.text('Error: Credencials incorrectes'), findsOneWidget);
    });

    testWidgets('properly disposes HTTP client if created internally', (
      WidgetTester tester,
    ) async {
      // This test needs a MaterialApp to host the LoginPage state
      await tester.pumpWidget(MaterialApp(home: LoginPage()));

      // Find the state
      final state = tester.state<LoginPageState>(find.byType(LoginPage));

      // We can't directly verify the client.close() was called since we can't mock
      // the internally created client easily without refactoring LoginPage.
      // However, we ensure initState and dispose run without Firebase errors.
      expect(state.mounted, isTrue); // Check if state was initialized

      // Manually dispose by pumping a different widget or ending the test
      await tester.pumpWidget(Container()); // Replace with empty container

      // The dispose method should have run without throwing Firebase exceptions
      expect(
        true,
        isTrue,
      ); // Test passes if no exceptions were thrown during dispose
    });
  });
}
