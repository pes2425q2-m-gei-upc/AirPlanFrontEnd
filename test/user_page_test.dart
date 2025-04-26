// user_page_test.dart
import 'package:airplan/user_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_helpers.dart';

void main() {
  setUp(() {
    // Initialize Firebase mocks before each test
    FirebaseTestSetup.setupFirebaseMocks();
  });

  // Helper function to build UserInfoCard widget for testing
  Widget createUserInfoCard() {
    return const TestWrapper(
      child: UserInfoCard(
        realName: 'Test User',
        username: 'testuser',
        email: 'test@example.com',
        isClient: true,
        userLevel: 3,
        isLoading: false,
      ),
    );
  }

  testWidgets('UserInfoCard displays user data correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createUserInfoCard());

    // Verify the card displays the correct information
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('testuser'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('UserInfoCard shows loading indicator when isLoading is true', (
    WidgetTester tester,
  ) async {
    // Build a UserInfoCard with loading state
    await tester.pumpWidget(
      const TestWrapper(
        child: UserInfoCard(
          realName: 'Test User',
          username: 'testuser',
          email: 'test@example.com',
          isClient: true,
          userLevel: 3,
          isLoading: true,
        ),
      ),
    );

    // Verify CircularProgressIndicator is shown
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
