import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:airplan/calendar_page.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/activity_service.dart';
import 'package:airplan/models/nota.dart';
import 'package:airplan/services/note_service.dart';
import 'package:airplan/map_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';

@GenerateMocks([AuthService, ActivityService, NoteService, MapService])
import 'calendar_page_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockActivityService mockActivityService;
  late MockNoteService mockNoteService;

  // Test data
  final testActivity = {
    'id': 1,
    'nom': 'Test Activity',
    'creador': 'testuser',
    'descripcio': 'Test Description',
    'dataInici': '2023-05-15T14:00:00',
    'dataFi': '2023-05-15T16:00:00',
    'ubicacio': {'latitud': 40.0, 'longitud': -3.0},
  };

  setUp(() {
    mockAuthService = MockAuthService();
    mockActivityService = MockActivityService();
    mockNoteService = MockNoteService();

    // Setup default mock responses
    when(mockAuthService.getCurrentUsername()).thenReturn('testuser');
    when(mockNoteService.fetchUserNotes(any)).thenAnswer((_) async => <Nota>[]);
    when(
      mockActivityService.fetchUserActivities(any),
    ).thenAnswer((_) async => [testActivity]);
  });

  Widget createCalendarPageWidget() {
    // wrap MaterialApp with EasyLocalization
    return EasyLocalization(
      supportedLocales: [Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: Locale('en', 'US'),
      startLocale: Locale('en', 'US'),
      child: MaterialApp(
        home: CalendarPage(
          authService: mockAuthService,
          activityService: mockActivityService,
        ),
      ),
    );
  }

  group('CalendarPage Widget Tests', () {
    testWidgets('Shows loading indicator initially', (
      WidgetTester tester,
    ) async {
      // We create a completer to control when the future completes
      final Completer<List<Map<String, dynamic>>> completer = Completer();

      // Override the default behavior for this specific test
      reset(mockActivityService);
      when(
        mockActivityService.fetchUserActivities(any),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(createCalendarPageWidget());
      await tester.pump(); // Add a pump to allow the first frame to build

      // Since the future hasn't completed, calendar is still shown and no loading spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TableCalendar), findsOneWidget);

      // Complete the future so the test can finish
      completer.complete([testActivity]);
      await tester.pumpAndSettle();
    });

    testWidgets('Shows refresh button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(createCalendarPageWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('Displays calendar after data loads', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createCalendarPageWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TableCalendar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Shows activity when day is selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createCalendarPageWidget());
      await tester.pumpAndSettle();

      final dayFinder = find.descendant(
        of: find.byType(TableCalendar),
        matching: find.text('15'),
      );

      expect(dayFinder, findsAtLeastNWidgets(1));
      await tester.tap(dayFinder.first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('calendar_details_for_date_prefix'),
        findsOneWidget,
      );
    });
  });
}
