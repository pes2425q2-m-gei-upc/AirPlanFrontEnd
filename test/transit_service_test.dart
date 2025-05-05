import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:airplan/transit_service.dart';

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
}