import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:airplan/reset_password.dart';
import 'package:airplan/services/auth_service.dart';

import 'reset_password_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(home: ResetPasswordPage(authService: mockAuthService));
  }

  testWidgets('ResetPasswordPage UI displays correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Verify that the title is displayed
    expect(find.text('Restablir Contrasenya'), findsOneWidget);

    // Verify that the instruction text is displayed
    expect(
      find.text(
        'Introdueix el teu correu electrònic per rebre un enllaç de restabliment de contrasenya.',
      ),
      findsOneWidget,
    );

    // Verify that the email field is displayed
    expect(find.widgetWithText(TextField, 'Correu electrònic'), findsOneWidget);

    // Verify that the submit button is displayed
    expect(
      find.widgetWithText(ElevatedButton, 'Enviar correu de restabliment'),
      findsOneWidget,
    );
  });

  testWidgets('ResetPasswordPage calls resetPassword when button is pressed', (
    WidgetTester tester,
  ) async {
    // Setup mock to return success
    when(mockAuthService.resetPassword(any)).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());

    // Enter an email
    await tester.enterText(find.byType(TextField), 'test@example.com');

    // Tap the button
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Enviar correu de restabliment'),
    );
    await tester.pump();

    // Verify the service was called with the correct email
    verify(mockAuthService.resetPassword('test@example.com')).called(1);
  });

  testWidgets(
    'ResetPasswordPage shows success message when resetPassword succeeds',
    (WidgetTester tester) async {
      // Setup mock to return success
      when(mockAuthService.resetPassword(any)).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest());

      // Enter an email
      await tester.enterText(find.byType(TextField), 'test@example.com');

      // Tap the button
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enviar correu de restabliment'),
      );
      await tester.pump();

      // Verify the success message is shown
      expect(
        find.text(
          "Correu de restabliment enviat! Revisa la teva safata d'entrada.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ResetPasswordPage shows error message when resetPassword fails',
    (WidgetTester tester) async {
      // Setup mock to throw an error
      when(
        mockAuthService.resetPassword(any),
      ).thenThrow(Exception('Invalid email'));

      await tester.pumpWidget(createWidgetUnderTest());

      // Enter an email
      await tester.enterText(find.byType(TextField), 'invalid@example');

      // Tap the button
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enviar correu de restabliment'),
      );
      await tester.pump();

      // Verify error message contains the expected text
      expect(
        find.textContaining('Error: Exception: Invalid email'),
        findsOneWidget,
      );
    },
  );
}
