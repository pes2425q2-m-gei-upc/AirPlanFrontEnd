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
    });

    testWidgets('Should display favorite activities', (WidgetTester tester) async {
      when(mockAuthService.getCurrentUsername()).thenReturn('test_user');
      when(mockActivityService.fetchFavoriteActivities('test_user')).thenAnswer(
            (_) async => [
          {'id': 1, 'nom': 'Activity 1', 'creador': 'test_user'},
          {'id': 2, 'nom': 'Activity 2', 'creador': 'other_user'},
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: MapPage(),
      ));

      // Simulate pressing the favorite button
      final favoriteButton = find.byIcon(Icons.favorite);
      expect(favoriteButton, findsOneWidget);
      await tester.tap(favoriteButton);
      await tester.pumpAndSettle();

      // Verify favorite activities are displayed
      expect(find.text('Activity 1'), findsOneWidget);
      expect(find.text('Activity 2'), findsOneWidget);
    });

    testWidgets('Should show message when no favorite activities', (WidgetTester tester) async {
      when(mockAuthService.getCurrentUsername()).thenReturn('test_user');
      when(mockActivityService.fetchFavoriteActivities('test_user')).thenAnswer(
            (_) async => [],
      );

      await tester.pumpWidget(MaterialApp(
        home: MapPage(),
      ));

      // Simulate pressing the favorite button
      final favoriteButton = find.byIcon(Icons.favorite);
      expect(favoriteButton, findsOneWidget);
      await tester.tap(favoriteButton);
      await tester.pumpAndSettle();

      // Verify message is displayed
      expect(find.text('No tienes actividades favoritas'), findsOneWidget);
    });

    testWidgets('Should add activity to favorites', (WidgetTester tester) async {
      when(mockAuthService.getCurrentUsername()).thenReturn('test_user');
      when(mockActivityService.addActivityToFavorites(1, 'test_user')).thenAnswer(
            (_) async => null,
      );

      await tester.pumpWidget(MaterialApp(
        home: MapPage(),
      ));

      // Simulate adding activity to favorites
      final favoriteIcon = find.byIcon(Icons.favorite_border);
      expect(favoriteIcon, findsOneWidget);
      await tester.tap(favoriteIcon);
      await tester.pumpAndSettle();

      // Verify the activity was added
      verify(mockActivityService.addActivityToFavorites(1, 'test_user')).called(1);
    });

    testWidgets('Should remove activity from favorites', (WidgetTester tester) async {
      when(mockAuthService.getCurrentUsername()).thenReturn('test_user');
      when(mockActivityService.removeActivityFromFavorites(1, 'test_user')).thenAnswer(
            (_) async => null,
      );

      await tester.pumpWidget(MaterialApp(
        home: MapPage(),
      ));

      // Simulate removing activity from favorites
      final favoriteIcon = find.byIcon(Icons.favorite);
      expect(favoriteIcon, findsOneWidget);
      await tester.tap(favoriteIcon);
      await tester.pumpAndSettle();

      // Verify the activity was removed
      verify(mockActivityService.removeActivityFromFavorites(1, 'test_user')).called(1);
    });
  });
}