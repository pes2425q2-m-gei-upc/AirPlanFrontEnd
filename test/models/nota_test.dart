import 'package:flutter_test/flutter_test.dart';
import 'package:airplan/models/nota.dart';

void main() {
  group('Nota Model Tests', () {
    test('Create Nota from constructor', () {
      final nota = Nota(
        id: 1,
        username: 'testuser',
        fechacreacion: DateTime(2023, 5, 15),
        horarecordatorio: '14:30',
        comentario: 'Test comment',
      );

      expect(nota.id, 1);
      expect(nota.username, 'testuser');
      expect(nota.fechacreacion, DateTime(2023, 5, 15));
      expect(nota.horarecordatorio, '14:30');
      expect(nota.comentario, 'Test comment');
    });

    test('Convert Nota to JSON', () {
      final nota = Nota(
        id: 1,
        username: 'testuser',
        fechacreacion: DateTime(2023, 5, 15),
        horarecordatorio: '14:30',
        comentario: 'Test comment',
      );

      final json = nota.toJson();
      expect(json['id'], 1);
      expect(json['username'], 'testuser');
      expect(json['fecha_creacion'], '2023-05-15');
      expect(json['hora_recordatorio'], '14:30');
      expect(json['comentario'], 'Test comment');
    });

    test('Create Nota from JSON', () {
      final json = {
        'id': 1,
        'username': 'testuser',
        'fechaCreacion': '2023-05-15',
        'horaRecordatorio': '14:30',
        'comentario': 'Test comment',
      };

      final nota = Nota.fromJson(json);
      expect(nota.id, 1);
      expect(nota.username, 'testuser');
      expect(nota.fechacreacion, DateTime(2023, 5, 15));
      expect(nota.horarecordatorio, '14:30');
      expect(nota.comentario, 'Test comment');
    });
  });
}