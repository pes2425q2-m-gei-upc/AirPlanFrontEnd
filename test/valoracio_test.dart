import 'package:flutter_test/flutter_test.dart';

//The constructor test correctly verifies that all properties are set properly when creating a new instance.
//
//
// The fromJson test confirms that JSON data is properly converted to a Valoracio object with expected values.
//
//
// The null comentario test ensures the class handles null values properly in the comentario field.
//
//
// The toJson test validates that a Valoracio object is properly serialized to JSON format.
//
// The test cases cover the main functionalities of the Valoracio class, ensuring that it behaves as expected in different scenarios.

class Valoracio {
  final String username;
  final int idActivitat;
  final double valoracion;
  final String? comentario;
  final DateTime fecha;

  Valoracio({
    required this.username,
    required this.idActivitat,
    required this.valoracion,
    this.comentario,
    required this.fecha,
  });

  factory Valoracio.fromJson(Map<String, dynamic> json) {
    return Valoracio(
      username: json['username'],
      idActivitat: json['idActivitat'],
      valoracion: json['valoracion'].toDouble(),
      comentario: json['comentario'],
      fecha: DateTime.parse(json['fechaValoracion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'idActivitat': idActivitat,
      'valoracion': valoracion,
      'comentario': comentario,
      'fechaValoracion': fecha.toIso8601String(),
    };
  }
}

void main() {
  group('Valoracio', () {
    test('should create a Valoracio instance using constructor', () {
      final valoracio = Valoracio(
        username: 'testUser',
        idActivitat: 1,
        valoracion: 4.5,
        comentario: 'Great activity!',
        fecha: DateTime(2023, 5, 15),
      );

      expect(valoracio.username, equals('testUser'));
      expect(valoracio.idActivitat, equals(1));
      expect(valoracio.valoracion, equals(4.5));
      expect(valoracio.comentario, equals('Great activity!'));
      expect(valoracio.fecha, equals(DateTime(2023, 5, 15)));
    });

    test('should create a Valoracio instance from JSON', () {
      final json = {
        'username': 'testUser',
        'idActivitat': 1,
        'valoracion': 4.5,
        'comentario': 'Great activity!',
        'fechaValoracion': '2023-05-15T00:00:00.000',
      };

      final valoracio = Valoracio.fromJson(json);

      expect(valoracio.username, equals('testUser'));
      expect(valoracio.idActivitat, equals(1));
      expect(valoracio.valoracion, equals(4.5));
      expect(valoracio.comentario, equals('Great activity!'));
      expect(valoracio.fecha, equals(DateTime(2023, 5, 15)));
    });

    test('should handle null comentario in JSON', () {
      final json = {
        'username': 'testUser',
        'idActivitat': 1,
        'valoracion': 4.5,
        'comentario': null,
        'fechaValoracion': '2023-05-15T00:00:00.000',
      };

      final valoracio = Valoracio.fromJson(json);

      expect(valoracio.username, equals('testUser'));
      expect(valoracio.idActivitat, equals(1));
      expect(valoracio.valoracion, equals(4.5));
      expect(valoracio.comentario, isNull);
      expect(valoracio.fecha, equals(DateTime(2023, 5, 15)));
    });

    test('should convert Valoracio to JSON', () {
      final valoracio = Valoracio(
        username: 'testUser',
        idActivitat: 1,
        valoracion: 4.5,
        comentario: 'Great activity!',
        fecha: DateTime(2023, 5, 15),
      );

      final json = valoracio.toJson();

      expect(json['username'], equals('testUser'));
      expect(json['idActivitat'], equals(1));
      expect(json['valoracion'], equals(4.5));
      expect(json['comentario'], equals('Great activity!'));
      expect(json['fechaValoracion'], equals('2023-05-15T00:00:00.000'));
    });
  });
}