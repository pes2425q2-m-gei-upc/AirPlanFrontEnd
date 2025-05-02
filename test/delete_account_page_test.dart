import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:airplan/delete_account_page.dart';
import 'package:airplan/login_page.dart';
import 'package:airplan/services/auth_service.dart';

import 'delete_account_page_test.mocks.dart';

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

// Mock navigator observer to track navigation
class MockNavigatorObserver extends Mock implements NavigatorObserver {
  List<Route> pushedRoutes = [];

  @override
  void didPush(Route route, Route? previousRoute) {
    pushedRoutes.add(route);
  }
}

@GenerateMocks([AuthService])
void main() {
  late MockAuthService mockAuthService;
  late MockNavigatorObserver mockNavigator;

  setUpAll(() async {
    await setupFirebaseMocks();
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockNavigator = MockNavigatorObserver();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      navigatorObservers: [mockNavigator],
      home: DeleteAccountPage(authService: mockAuthService),
    );
  }

  testWidgets('DeleteAccountPage displays delete button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Check if the delete button is displayed
    expect(find.text('Esborrar el meu compte'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets(
    'DeleteAccountPage shows confirmation dialog when delete button is pressed',
    (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap the delete button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify confirmation dialog is shown
      expect(find.text('Confirmació'), findsOneWidget);
      expect(
        find.text(
          'Segur que vols esborrar el teu compte? Aquesta acció és irreversible.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel·lar'), findsOneWidget);
      expect(find.text('Esborrar'), findsOneWidget);
    },
  );

  testWidgets(
    'DeleteAccountPage cancels deletion when Cancel button is pressed',
    (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap delete button and wait for dialog
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Tap Cancel button in dialog
      await tester.tap(find.text('Cancel·lar'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed and no deleteCurrentUser call was made
      expect(find.text('Confirmació'), findsNothing);
      verifyNever(mockAuthService.deleteCurrentUser());
    },
  );

  testWidgets('DeleteAccountPage calls deleteCurrentUser when confirmed', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(
      mockAuthService.deleteCurrentUser(),
    ).thenAnswer((_) => Future<void>.value());

    await tester.pumpWidget(createWidgetUnderTest());

    // Tap delete button and wait for dialog
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Tap Esborrar button in dialog
    await tester.tap(find.text('Esborrar'));
    await tester.pumpAndSettle();

    // Verify deleteCurrentUser was called
    verify(mockAuthService.deleteCurrentUser()).called(1);

    // Should show success message
    expect(find.text('Compte eliminat correctament'), findsOneWidget);
  });

  testWidgets('DeleteAccountPage shows error message on delete failure', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(mockAuthService.deleteCurrentUser()).thenThrow(
      FirebaseAuthException(code: 'error', message: 'Test error message'),
    );

    await tester.pumpWidget(createWidgetUnderTest());

    // Tap delete button and wait for dialog
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Tap Esborrar button in dialog
    await tester.tap(find.text('Esborrar'));
    await tester.pumpAndSettle();

    // Verify error message is shown
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets(
    'DeleteAccountPage shows specific message for requires-recent-login error',
    (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.deleteCurrentUser()).thenThrow(
        FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Requires recent login',
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      // Tap delete button and wait for dialog
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Tap Esborrar button in dialog
      await tester.tap(find.text('Esborrar'));
      await tester.pumpAndSettle();

      // Verify specific error message is shown
      expect(
        find.text('Has de tornar a iniciar sessió per esborrar el compte'),
        findsOneWidget,
      );
    },
  );
}
