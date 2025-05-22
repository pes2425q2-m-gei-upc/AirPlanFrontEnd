import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/blocked_users_page.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/user_block_service.dart';
import 'package:airplan/services/notification_service.dart';

import 'blocked_users_page_test.mocks.dart';

// Mock FirebaseUser for getCurrentUser() return value
class MockUser implements User {
  @override
  String? get displayName => 'testuser';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock for NotificationService
class MockNotificationService extends Mock implements NotificationService {
  @override
  void showSuccess(BuildContext context, String message) {
    // Do nothing in tests - no timers
  }

  @override
  void showError(BuildContext context, String message) {
    // Do nothing in tests - no timers
  }
}

@GenerateMocks([UserBlockService, AuthService])
void main() {
  late MockUserBlockService mockBlockService;
  late MockAuthService mockAuthService;
  late MockNotificationService mockNotificationService;

  // Define test data
  final testBlockedUsers = [
    {'blockedUsername': 'TestUser1', 'blockDate': '2025-05-01T12:00:00.000Z'},
    {'blockedUsername': 'TestUser2', 'blockDate': '2025-05-01T13:00:00.000Z'},
  ];

  setUp(() {
    mockBlockService = MockUserBlockService();
    mockAuthService = MockAuthService();
    mockNotificationService = MockNotificationService();

    // Default behavior for mocks
    when(
      mockBlockService.getBlockedUsers(any),
    ).thenAnswer((_) async => testBlockedUsers);
    when(mockBlockService.unblockUser(any, any)).thenAnswer((_) async => true);
    when(mockAuthService.getCurrentUser()).thenReturn(MockUser());
  });

  // Helper function to create a testable widget
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlockedUsersPage(
        username: 'testuser',
        authService: mockAuthService,
        blockService: mockBlockService,
        notificationService:
            mockNotificationService, // Pass mock NotificationService
      ),
    );
  }

  testWidgets('BlockedUsersPage shows loading indicator initially', (
    WidgetTester tester,
  ) async {
    // Prevent the Future from completing immediately
    final completer = Completer<List<dynamic>>();
    when(
      mockBlockService.getBlockedUsers(any),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(createWidgetUnderTest());

    // Should show loading indicator before the future completes
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the Future to avoid pending timers
    completer.complete(testBlockedUsers);
    await tester.pumpAndSettle();
  });

  testWidgets('BlockedUsersPage displays list of blocked users', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Need to wait for the Future to complete and UI to update
    await tester.pumpAndSettle();

    // Verify that the blocked users are displayed
    expect(find.text('TestUser1'), findsOneWidget);
    expect(find.text('TestUser2'), findsOneWidget);
  });

  testWidgets('BlockedUsersPage shows empty message when no blocked users', (
    WidgetTester tester,
  ) async {
    // Return empty list
    when(mockBlockService.getBlockedUsers(any)).thenAnswer((_) async => []);

    await tester.pumpWidget(createWidgetUnderTest());

    // Wait for the Future to complete and UI to update
    await tester.pumpAndSettle();

    // Verify empty state message
    expect(find.text('no_blocked_users_message'), findsOneWidget);
  });

  testWidgets('BlockedUsersPage shows error state on fetch error', (
    WidgetTester tester,
  ) async {
    // Simulate an error
    final error = Exception('Network error');
    when(mockBlockService.getBlockedUsers(any)).thenThrow(error);

    await tester.pumpWidget(createWidgetUnderTest());

    // Wait for the error to propagate
    await tester.pumpAndSettle();

    // Verify error state - using partial text match since the actual error message includes exception details
    expect(find.textContaining('error_loading_blocked_users'), findsOneWidget);
    expect(find.text('retry_button'), findsOneWidget);
  });

  testWidgets('BlockedUsersPage retry button reloads data after error', (
    WidgetTester tester,
  ) async {
    // First load with error
    when(
      mockBlockService.getBlockedUsers(any),
    ).thenThrow(Exception('Network error'));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify error state
    expect(find.textContaining('error_loading_blocked_users'), findsOneWidget);

    // Setup mock for second call
    final completer = Completer<List<dynamic>>();
    when(
      mockBlockService.getBlockedUsers(any),
    ).thenAnswer((_) => completer.future);

    // Tap retry button
    await tester.tap(find.text('retry_button'));
    await tester.pump(); // Process tap event

    // Now the UI should be in loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the future to finish the test
    completer.complete(testBlockedUsers);
    await tester.pumpAndSettle();

    // Verify data loaded
    expect(find.text('TestUser1'), findsOneWidget);
  });

  // Tests that involve interaction with the dialog
  testWidgets(
    'BlockedUsersPage shows confirmation dialog when unblock button is pressed',
    (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle(); // Wait for initial data to load

      // Find the unblock button by translation key
      final unblockButton = find.text('unblock_button');
      expect(unblockButton, findsWidgets, reason: 'No unblock buttons found');

      // Tap the first unblock button
      await tester.tap(unblockButton.first);
      await tester.pumpAndSettle(); // Wait for dialog animation

      // Verify dialog content
      expect(find.textContaining('unblock_user_dialog_title'), findsOneWidget);
      expect(
        find.textContaining('unblock_user_dialog_content'),
        findsOneWidget,
      );
    },
  );

  testWidgets('BlockedUsersPage calls unblockUser when confirmed', (
    WidgetTester tester,
  ) async {
    // Use a Completer to control async behavior without triggering timers
    final completer = Completer<bool>();
    when(
      mockBlockService.unblockUser(any, any),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(createWidgetUnderTest());

    // Use multiple pump calls instead of pumpAndSettle to avoid timeouts
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Find the unblock button with text 'unblock_button'
    final unblockButton = find.text('unblock_button');
    expect(unblockButton, findsWidgets, reason: 'No unblock buttons found');

    // Tap the first unblock button
    await tester.tap(unblockButton.first);

    // Use multiple pump calls to let dialog appear
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Find and tap confirm button in dialog
    final confirmButton =
        find.widgetWithText(TextButton, 'unblock_button').last;
    expect(
      confirmButton,
      findsOneWidget,
      reason: 'Confirm button not found in dialog',
    );

    // Tap the button in dialog
    await tester.tap(confirmButton);
    await tester.pump();

    // Complete unblock operation immediately
    completer.complete(true);

    // Pump a few times to process the completion
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Verify the unblockUser method was called with correct parameters
    verify(mockBlockService.unblockUser('testuser', 'TestUser1')).called(1);
  });

  testWidgets('BlockedUsersPage does not call unblockUser when canceled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Use multiple pump calls instead of pumpAndSettle to avoid timeouts
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Find the unblock button with text 'unblock_button'
    final unblockButton = find.text('unblock_button');
    expect(unblockButton, findsWidgets, reason: 'No unblock buttons found');

    // Tap the first unblock button
    await tester.tap(unblockButton.first);

    // Use multiple pump calls to let dialog appear
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Find and tap cancel button
    final cancelButton = find.widgetWithText(TextButton, 'cancel_button');
    expect(
      cancelButton,
      findsOneWidget,
      reason: 'Cancel button not found in dialog',
    );

    await tester.tap(cancelButton);

    // Multiple pumps to process the action
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Verify unblockUser was never called
    verifyNever(mockBlockService.unblockUser(any, any));
  });
}
