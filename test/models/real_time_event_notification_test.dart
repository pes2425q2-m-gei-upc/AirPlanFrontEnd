import 'package:flutter_test/flutter_test.dart';
import 'package:airplan/models/real_time_event_notification.dart';

void main() {
  group('RealTimeEventNotification', () {
    test('debe crearse correctamente desde el constructor', () {
      final notification = RealTimeEventNotification(
        type: 'ACTIVITY_REMINDER',
        message: 'Yoga Class,15',
        username: 'instructor1',
        timestamp: 1632145200000, // Un timestamp fijo para pruebas
      );

      expect(notification.type, 'ACTIVITY_REMINDER');
      expect(notification.message, 'Yoga Class,15');
      expect(notification.username, 'instructor1');
      expect(notification.timestamp, 1632145200000);
    });

    test('debe crearse correctamente desde JSON', () {
      final json = {
        'type': 'INVITACIONS',
        'message': '123,TestHost',
        'username': 'host1',
        'timestamp': 1632145200000,
      };

      final notification = RealTimeEventNotification.fromJson(json);

      expect(notification.type, 'INVITACIONS');
      expect(notification.message, '123,TestHost');
      expect(notification.username, 'host1');
      expect(notification.timestamp, 1632145200000);
    });

    test('debe convertirse correctamente a JSON', () {
      final notification = RealTimeEventNotification(
        type: 'MESSAGE',
        message: 'Hello there',
        username: 'user2',
        timestamp: 1632145200000,
      );

      final json = notification.toJson();

      expect(json['type'], 'MESSAGE');
      expect(json['message'], 'Hello there');
      expect(json['username'], 'user2');
      expect(json['timestamp'], 1632145200000);
    });

    test('debe usar valores predeterminados para campos faltantes en JSON', () {
      final incompleteJson = {
        'type': 'NOTE_REMINDER',
        // Campos faltantes
      };

      final notification = RealTimeEventNotification.fromJson(incompleteJson);

      expect(notification.type, 'NOTE_REMINDER');
      expect(notification.message, '');
      expect(notification.username, '');
      expect(notification.timestamp, isA<int>());
    });

    test('debe poder procesar diferentes tipos de eventos', () {
      final types = ['ACTIVITY_REMINDER', 'INVITACIONS', 'MESSAGE', 'NOTE_REMINDER'];

      for (final type in types) {
        final json = {
          'type': type,
          'message': 'Test message',
          'username': 'tester',
          'timestamp': 1632145200000,
        };

        final notification = RealTimeEventNotification.fromJson(json);
        expect(notification.type, type);
      }
    });
  });
}