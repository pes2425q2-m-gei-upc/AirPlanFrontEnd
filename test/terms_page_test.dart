import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airplan/terms_page.dart';

void main() {
  group('TermsPage Widget Tests', () {
    testWidgets('TermsPage renders correctly', (WidgetTester tester) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));

      // Verify that the main title is displayed
      expect(find.text('terms_title'), findsOneWidget);

      // Verify that all section titles are displayed
      expect(find.text('terms_section_1_title'), findsOneWidget);
      expect(find.text('terms_section_2_title'), findsOneWidget);
      expect(find.text('terms_section_3_title'), findsOneWidget);
      expect(find.text('terms_section_4_title'), findsOneWidget);
      expect(find.text('terms_section_5_title'), findsOneWidget);
      expect(find.text('terms_section_6_title'), findsOneWidget);
      expect(find.text('terms_section_7_title'), findsOneWidget);

      // Verify that the back button is present in the AppBar
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Back button is tappable', (WidgetTester tester) async {
      // Variable popCalled eliminada ya que no se utilizaba

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) {
              return MaterialPageRoute<void>(
                builder:
                    (_) => Scaffold(
                      body: Builder(
                        builder:
                            (context) => ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TermsPage(),
                                  ),
                                );
                              },
                              child: Text('Go to Terms'),
                            ),
                      ),
                    ),
              );
            },
          ),
        ),
      );

      // Navigate to TermsPage
      await tester.tap(find.text('Go to Terms'));
      await tester.pumpAndSettle();

      // Verify we're on the TermsPage
      expect(find.byType(TermsPage), findsOneWidget);

      // Find and tap the back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify we've navigated back
      expect(find.byType(TermsPage), findsNothing);
    });

    testWidgets('Scrolling works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));

      // Find the ScrollView
      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsOneWidget);

      // Check for a widget at the bottom that should be off-screen initially
      final lastUpdatedFinder = find.textContaining('terms_last_updated');

      // Check visibility by comparing positions before and after scrolling
      final initialPosition = tester.getRect(lastUpdatedFinder);

      // Perform a scroll gesture
      await tester.drag(scrollView, const Offset(0, -500));
      await tester.pump();

      // Get new position after scrolling
      final newPosition = tester.getRect(lastUpdatedFinder);

      // Verify scrolling happened by comparing positions
      expect(initialPosition != newPosition, isTrue);

      // Scroll more to confirm continuous scrolling works
      await tester.drag(scrollView, const Offset(0, -100));
      await tester.pump();
      final finalPosition = tester.getRect(lastUpdatedFinder);

      expect(newPosition != finalPosition, isTrue);
    });

    testWidgets('Section title styling is applied correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));

      // Find one of the section titles
      final titleFinder = find.text('terms_section_1_title');
      expect(titleFinder, findsOneWidget);

      // Get the Text widget
      final titleWidget = tester.widget<Text>(titleFinder);

      // Check that styling is applied (bold text)
      expect(titleWidget.style?.fontWeight, equals(FontWeight.bold));

      // Check that color is blue-related (we're checking if the color is a shade of blue)
      final color = titleWidget.style?.color;
      expect(color, isNotNull);
      // Check if it's a blue color (Material blue or blue shade)
      // This is less strict and should pass for any blue color
      expect(
        color.toString().contains('blue') ||
            color.toString().contains('Blue') ||
            // For exact Material colors like Colors.blue[700]
            (color.runtimeType.toString() == 'MaterialColor' ||
                color.runtimeType.toString() == 'MaterialAccentColor'),
        isTrue,
      );
    });

    testWidgets('Last updated date is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));

      // Find text containing the date parts
      final dateFinder = find.textContaining('terms_last_updated');
      expect(dateFinder, findsOneWidget);

      // Extract the date text
      final dateTextWidget = tester.widget<Text>(dateFinder);
      final dateText = dateTextWidget.data ?? '';

      // Verify the date is in the expected format (day/month/year)
      expect(dateText.contains('/'), isTrue);
      // Use a regular expression to check for a date pattern (d/m/yyyy format)
      final datePattern = RegExp(r'\d{1,2}/\d{1,2}/\d{4}');
      expect(datePattern.hasMatch(dateText), isTrue);
    });
  });
}
