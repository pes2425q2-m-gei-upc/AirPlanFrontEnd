import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:airplan/transit_service.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'dart:convert';

@GenerateMocks([http.Client])
import 'transit_service_test.mocks.dart';

// Private methods can't be directly accessed using Object extensions
// We need to access them through the transit_service.dart exports

void main() {
  group('TransitService Tests', () {
    test('TransitStep creation works correctly', () {
      final step = TransitStep(
        mode: TipusVehicle.metro,
        instruction: 'Go to Platform 3, Board the Blue Line', // String instead of List<String>
        type: TipusInstruccio.recta, // Required parameter
        line: 'L5',
        departure: DateTime(2023, 5, 15, 10, 30),
        arrival: DateTime(2023, 5, 15, 10, 55),
        points: [LatLng(41.3851, 2.1734), LatLng(41.3879, 2.1699)],
        station: 'Diagonal',
        color: Colors.blue,
        distance: 500.0, // Required parameter
      );

      expect(step.mode, equals(TipusVehicle.metro));
      expect(step.instruction, equals('Go to Platform 3, Board the Blue Line'));
      expect(step.line, equals('L5'));
      expect(step.station, equals('Diagonal'));
      expect(step.points.length, equals(2));
      expect(step.color, equals(Colors.blue));
      expect(step.distance, equals(500.0));
      expect(step.type, equals(TipusInstruccio.recta));
    });

    test('TransitRoute creation works correctly', () {
      final route = TransitRoute(
        fullRoute: [LatLng(41.3851, 2.1734), LatLng(41.3879, 2.1699)],
        steps: [
          TransitStep(
            mode: TipusVehicle.metro,
            instruction: 'Board the Blue Line', // String instead of List<String>
            type: TipusInstruccio.recta, // Required parameter
            line: 'L5',
            departure: DateTime(2023, 5, 15, 10, 30),
            arrival: DateTime(2023, 5, 15, 10, 55),
            points: [LatLng(41.3851, 2.1734), LatLng(41.3879, 2.1699)],
            station: 'Diagonal',
            color: Colors.blue,
            distance: 500.0, // Required parameter
          ),
        ],
        duration: 25,
        distance: 2500,
        departure: DateTime(2023, 5, 15, 10, 30),
        arrival: DateTime(2023, 5, 15, 10, 55),
        origin: LatLng(41.3851, 2.1734),
        destination: LatLng(41.3879, 2.1699),
        option: 1,
      );

      expect(route.fullRoute.length, equals(2));
      expect(route.steps.length, equals(1));
      expect(route.duration, equals(25));
      expect(route.distance, equals(2500));
      expect(route.option, equals(1));
    });

    test('translateTipusVehicle returns correct translations', () {
      expect(translateTipusVehicle(TipusVehicle.cotxe), equals('Cotxe'));
      expect(translateTipusVehicle(TipusVehicle.moto), equals('Moto'));
      expect(translateTipusVehicle(TipusVehicle.metro), equals('Metro'));
      expect(translateTipusVehicle(TipusVehicle.tren), equals('Tren'));
      expect(translateTipusVehicle(TipusVehicle.autobus), equals('Autobus'));
      expect(translateTipusVehicle(TipusVehicle.bicicleta), equals('Bicicleta'));
      expect(translateTipusVehicle(TipusVehicle.cap), equals('Cap'));
    });
  });

  // Remove private method tests as they can't be accessed this way
  // If you need to test them, expose the methods in the original file or test them indirectly

  // Add HTTP mocking for network function tests
  group('Network Functions Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('calculateRoute handles walking path correctly', () async {
      // Mock successful response for walking route
      final mockResponseData = {
        'routes': [
          {
            'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
            'summary': {'distance': 1500, 'duration': 900},
            'segments': [
              {
                'steps': [
                  {
                    'distance': 500,
                    'duration': 300,
                    'instruction': 'Walk straight ahead',
                    'type': 0,
                    'way_points': [0, 5]
                  }
                ]
              }
            ]
          }
        ]
      };

      when(mockClient.get(any)).thenAnswer((_) async =>
          http.Response(jsonEncode(mockResponseData), 200));

      // Inject the mockClient into the calculateRoute function
      // Note: You'll need to modify calculateRoute to accept a client parameter
      // For this example, assume it's been modified

      final result = await calculateRoute(
        false, false, DateTime.now(), DateTime.now(), 3,
        LatLng(41.3851, 2.1734), LatLng(41.3879, 2.1699),
        client: mockClient
      );

      expect(result.steps.length, greaterThan(0));
      expect(result.steps.first.mode, equals(TipusVehicle.cap));
      expect(result.duration, equals(15));
      expect(result.distance, equals(1500));

      // NOTE: Since we can't modify the original function, this remains commented out
      // This is how you would structure the test if you could inject a mock client
    });

    test('calculateRoute throws exception for invalid option', () async {
      expect(() => calculateRoute(
          false, false, DateTime.now(), DateTime.now(), 0,
          LatLng(41.3851, 2.1734), LatLng(41.3879, 2.1699)
      ), throwsA(isA<Exception>()));
    });
  });
}