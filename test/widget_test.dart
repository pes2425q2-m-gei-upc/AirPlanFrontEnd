// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_helpers.dart';

void main() {
  setUp(() {
    // Initialize Firebase mocks before each test
    FirebaseTestSetup.setupFirebaseMocks();
  });

  // Simple smoke test - verify that our test environment works
  testWidgets('Basic widget test smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TestWrapper(child: Text('Testing')));

    expect(find.text('Testing'), findsOneWidget);
  });
}
