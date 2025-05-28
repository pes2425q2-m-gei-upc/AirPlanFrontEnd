import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:airplan/map_page.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/activity_service.dart';

@GenerateMocks([AuthService, ActivityService])
import 'favorite_activities_test.mocks.dart';

void main() {
  group('Favorite Activities Tests', () {
    late MockAuthService mockAuthService;
    late MockActivityService mockActivityService;

    setUp(() {
      mockAuthService = MockAuthService();
      mockActivityService = MockActivityService();
      // Stub fetchActivities to prevent real network calls
      when(
        mockActivityService.fetchActivities(),
      ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    });

    testWidgets('Should display favorite activities', (
      WidgetTester tester,
    ) async {
      when(mockAuthService.getCurrentUsername()).thenReturn('test_user');
      when(mockActivityService.fetchFavoriteActivities('test_user')).thenAnswer(
        (_) async => [
          {'id': 1, 'nom': 'Activity 1', 'creador': 'test_user'},
          {'id': 2, 'nom': 'Activity 2', 'creador': 'other_user'},
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MapPage(
            authService: mockAuthService,
            activityService: mockActivityService,
          ),
        ),
      );

      // Simulate pressing the favorite button
      final favoriteButton = find.byIcon(Icons.favorite);
      expect(favoriteButton, findsOneWidget);
      await tester.tap(favoriteButton);
      await tester.pumpAndSettle();

      // Verify favorite activities are displayed
      expect(find.text('Activity 1'), findsOneWidget);
      expect(find.text('Activity 2'), findsOneWidget);
    });

    testWidgets('Should show message when no favorite activities', (
      WidgetTester tester,
    ) async {
      when(mockAuthService.getCurrentUsername()).thenReturn('test_user');
      when(
        mockActivityService.fetchFavoriteActivities('test_user'),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: MapPage(
            authService: mockAuthService,
            activityService: mockActivityService,
          ),
        ),
      );

      // Simulate pressing the favorite button
      final favoriteButton = find.byIcon(Icons.favorite);
      expect(favoriteButton, findsOneWidget);
      await tester.tap(favoriteButton);
      await tester.pumpAndSettle();

      // Verify message is displayed
      expect(find.text('no_favorites_found'), findsOneWidget);
    });

    testWidgets('Should add activity to favorites', (
      WidgetTester tester,
    ) async {
      when(mockAuthService.getCurrentUsername()).thenReturn('test_user');
      when(
        mockActivityService.addActivityToFavorites(1, 'test_user'),
      ).thenAnswer((_) async {});

      // Provide a dummy activity so the favorite button is present
      when(mockActivityService.fetchActivities()).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'nom': 'Act',
            'creador': 'test_user',
            'ubicacio': {'latitud': 0.0, 'longitud': 0.0},
            'dataInici': '',
            'dataFi': '',
            'descripcio': '',
            'esExterna': false,
          },
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MapPage(
            authService: mockAuthService,
            activityService: mockActivityService,
          ),
        ),
      );
      // wait for initState fetchActivities to complete
      await tester.pumpAndSettle();

      // Directly invoke addActivityToFavorites on the state
      final state = tester.state<MapPageState>(find.byType(MapPage));
      await state.addActivityToFavorites(1);

      // Verify the activity was added
      verify(
        mockActivityService.addActivityToFavorites(1, 'test_user'),
      ).called(1);
    });

    testWidgets('Should remove activity from favorites', (
      WidgetTester tester,
    ) async {
      when(mockAuthService.getCurrentUsername()).thenReturn('test_user');
      when(
        mockActivityService.removeActivityFromFavorites(1, 'test_user'),
      ).thenAnswer((_) async {});

      // Provide a dummy activity so the favorite button is present
      when(mockActivityService.fetchActivities()).thenAnswer(
        (_) async => [
          {
            'id': 1,
            'nom': 'Act',
            'creador': 'test_user',
            'ubicacio': {'latitud': 0.0, 'longitud': 0.0},
            'dataInici': '',
            'dataFi': '',
            'descripcio': '',
            'esExterna': false,
          },
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MapPage(
            authService: mockAuthService,
            activityService: mockActivityService,
          ),
        ),
      );
      // wait for initState fetchActivities to complete
      await tester.pumpAndSettle();

      // Directly invoke removeActivityFromFavorites on the state
      final state = tester.state<MapPageState>(find.byType(MapPage));
      await state.removeActivityFromFavorites(1);

      // Verify the activity was removed
      verify(
        mockActivityService.removeActivityFromFavorites(1, 'test_user'),
      ).called(1);
    });
  });
}
