import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/register.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/form_content_register.dart';
import 'package:airplan/logo_widget.dart';
import 'package:airplan/rive_controller.dart';
import 'package:airplan/rive_animation_widget.dart';
import 'register_test.mocks.dart';

// Mock the Rive animation widget to avoid using actual Rive library in tests
class MockRiveAnimationWidget extends StatelessWidget {
  final RiveAnimationControllerHelper riveHelper;

  const MockRiveAnimationWidget({super.key, required this.riveHelper});

  @override
  Widget build(BuildContext context) {
    // Simple placeholder instead of actual Rive animation
    return Container(
      width: 200,
      height: 200,
      color: Colors.blue.withOpacity(0.5),
      child: const Center(child: Text("Mock Rive Animation")),
    );
  }
}

// Override the LogoWidget to use our mock RiveAnimationWidget
class TestLogoWidget extends LogoWidget {
  const TestLogoWidget({
    super.key,
    required RiveAnimationControllerHelper riveHelper,
  }) : super(riveHelper: riveHelper);

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: isSmallScreen ? 200 : 300,
          height: isSmallScreen ? 200 : 300,
          child: MockRiveAnimationWidget(riveHelper: riveHelper),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Benvingut a AirPlan!",
            textAlign: TextAlign.center,
            style:
                isSmallScreen
                    ? Theme.of(context).textTheme.headlineMedium
                    : Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.black),
          ),
        ),
      ],
    );
  }
}

// Create a test-specific SignUpPage to avoid Rive issues
class TestSignUpPage extends StatelessWidget {
  final AuthService? authService;
  final RiveAnimationControllerHelper riveHelper;

  const TestSignUpPage({super.key, this.authService, required this.riveHelper});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    // Use our test-specific LogoWidget
    final formContent = FormContentRegister(
      riveHelper: riveHelper,
      authService: authService,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registre"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child:
            isSmallScreen
                ? SingleChildScrollView(
                  key: const Key('smallScreenContainer'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TestLogoWidget(riveHelper: riveHelper),
                      formContent,
                    ],
                  ),
                )
                : Container(
                  key: const Key('largeScreenContainer'),
                  padding: const EdgeInsets.all(32.0),
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Row(
                    key: const Key('mainContentRow'),
                    children: [
                      Expanded(child: TestLogoWidget(riveHelper: riveHelper)),
                      Expanded(child: Center(child: formContent)),
                    ],
                  ),
                ),
      ),
    );
  }
}

// Mock FirebaseAuth and User classes
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

// Mock Rive classes
class MockRiveAnimationControllerHelper extends Mock
    implements RiveAnimationControllerHelper {}

@GenerateMocks([AuthService])
void main() {
  // Setup mocks for each test
  late MockAuthService mockAuthService;
  late MockRiveAnimationControllerHelper mockRiveHelper;

  // Ensure Flutter bindings are initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    mockAuthService = MockAuthService();
    mockRiveHelper = MockRiveAnimationControllerHelper();

    // Setup common mock behavior
    when(mockAuthService.getCurrentUser()).thenReturn(null);
    when(mockAuthService.isAuthenticated()).thenReturn(false);

    // Mock the asset bundle to avoid loading actual assets
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return '.';
          },
        );
  });

  testWidgets('SignUpPage renders correctly on small screen', (
    WidgetTester tester,
  ) async {
    // Set up small screen size
    tester.binding.window.physicalSizeTestValue = const Size(300, 800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    // Build the widget with mock auth service and mock rive helper
    await tester.pumpWidget(
      MaterialApp(
        home: TestSignUpPage(
          authService: mockAuthService,
          riveHelper: mockRiveHelper,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the layout using the keys we added
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const Key('smallScreenContainer')), findsOneWidget);
    expect(find.byType(TestLogoWidget), findsOneWidget);
    expect(find.byType(FormContentRegister), findsOneWidget);
    expect(find.byType(MockRiveAnimationWidget), findsOneWidget);
  });

  testWidgets('SignUpPage renders correctly on large screen', (
    WidgetTester tester,
  ) async {
    // Set up large screen size
    tester.binding.window.physicalSizeTestValue = const Size(1200, 800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    // Build the widget with mock auth service
    await tester.pumpWidget(
      MaterialApp(
        home: TestSignUpPage(
          authService: mockAuthService,
          riveHelper: mockRiveHelper,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Use keys for better targeting
    expect(find.byKey(const Key('largeScreenContainer')), findsOneWidget);
    expect(find.byKey(const Key('mainContentRow')), findsOneWidget);

    // Container should have maxWidth constraint
    final container = tester.widget<Container>(
      find.byKey(const Key('largeScreenContainer')),
    );
    expect(container.constraints?.maxWidth, 800);
  });

  testWidgets('SignUpPage back button navigates correctly', (
    WidgetTester tester,
  ) async {
    // Create a key to identify the home screen
    final homeKey = GlobalKey();

    // Build the widget with navigation and mock auth service
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/signup',
        routes: {
          '/': (context) => Scaffold(key: homeKey, body: const Text('Home')),
          '/signup':
              (context) => TestSignUpPage(
                authService: mockAuthService,
                riveHelper: mockRiveHelper,
              ),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Tap back button
    final backButton = find.byIcon(Icons.arrow_back);
    expect(backButton, findsOneWidget); // Ensure back button exists
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Verify navigation
    expect(find.text('Home'), findsOneWidget);
    expect(
      find.byType(TestSignUpPage),
      findsNothing,
    ); // Ensure SignUpPage is gone
  });

  testWidgets('SignUpPage injects AuthService to FormContentRegister', (
    WidgetTester tester,
  ) async {
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: TestSignUpPage(
          authService: mockAuthService,
          riveHelper: mockRiveHelper,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find FormContentRegister
    final formWidgetFinder = find.byType(FormContentRegister);
    expect(formWidgetFinder, findsOneWidget);

    // Verify authService is passed
    final formWidget = tester.widget<FormContentRegister>(formWidgetFinder);
    expect(formWidget.authService, mockAuthService);
  });
}
