import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airplan/services/notification_service.dart';

void main() {
  late NotificationService service;
  late BuildContext testContext;

  setUp(() {
    service = NotificationService();
  });

  Future<void> _pumpTestApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            testContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
  }

  testWidgets('showSuccess displays a green notification and auto-dismisses', (
    tester,
  ) async {
    await _pumpTestApp(tester);

    service.showSuccess(testContext, 'Success!');

    // Begin animation in
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // animation in

    // Notification should be visible
    final textFinder = find.text('Success!');
    expect(textFinder, findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(of: textFinder, matching: find.byType(Container)),
    );
    expect((container.decoration as BoxDecoration).color, Colors.green);

    // Wait for auto-dismiss timer and reverse animation
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300)); // animation out

    expect(find.text('Success!'), findsNothing);
  });

  testWidgets('showError displays a red notification', (tester) async {
    await _pumpTestApp(tester);
    service.showError(testContext, 'Error occurred');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Error occurred'), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('Error occurred'),
        matching: find.byType(Container),
      ),
    );
    expect((container.decoration as BoxDecoration).color, Colors.red);
    // Auto-dismiss after duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Error occurred'), findsNothing);
  });

  testWidgets('showInfo displays a blue notification', (tester) async {
    await _pumpTestApp(tester);
    service.showInfo(testContext, 'Info message');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Info message'), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('Info message'),
        matching: find.byType(Container),
      ),
    );
    expect((container.decoration as BoxDecoration).color, Colors.blue);
    // Auto-dismiss after duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Info message'), findsNothing);
  });

  testWidgets('showWarning displays an amber notification', (tester) async {
    await _pumpTestApp(tester);
    NotificationService.showWarning(testContext, 'Warning!');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Warning!'), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('Warning!'),
        matching: find.byType(Container),
      ),
    );
    expect((container.decoration as BoxDecoration).color, Colors.amber);
    // Auto-dismiss after duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Warning!'), findsNothing);
  });

  testWidgets('manually tap close dismisses the notification', (tester) async {
    await _pumpTestApp(tester);
    service.showSuccess(testContext, 'TapClose');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('TapClose'), findsOneWidget);
    // Tap close icon
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TapClose'), findsNothing);
  });
}
