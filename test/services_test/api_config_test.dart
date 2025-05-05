import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:airplan/services/api_config.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([])
void main() {
  group('ApiConfig Tests', () {
    late ApiConfig apiConfig;

    setUp(() {
      apiConfig = ApiConfig();
    });

    test('initialize with custom URL', () {
      final customUrl = 'https://test-api.example.com';
      apiConfig.initialize(customUrl: customUrl);
      expect(apiConfig.baseUrl, equals(customUrl));
    });

    test('initialize with empty custom URL uses default based on platform', () {
      apiConfig.initialize(customUrl: '');
      if (kIsWeb) {
        expect(apiConfig.baseUrl, equals('http://localhost:8080'));
      } else {
        expect(apiConfig.baseUrl, equals('http://192.168.1.69:8080'));
      }
    });

    test('buildUrl constructs proper URL', () {
      final customUrl = 'https://test-api.example.com';
      apiConfig.initialize(customUrl: customUrl);

      // Test with endpoint that has leading slash
      expect(
        apiConfig.buildUrl('/users'),
        equals('https://test-api.example.com/users'),
      );

      // Test with endpoint that doesn't have leading slash
      expect(
        apiConfig.buildUrl('users'),
        equals('https://test-api.example.com/users'),
      );
    });

    // Esta prueba es más compleja porque necesitamos simular kIsWeb
    // En una prueba real necesitaríamos usar un approach diferente para probar
    // el comportamiento específico de plataforma, como dependency injection
    test('initialize uses correct URL based on platform', () {
      apiConfig.initialize();
      if (kIsWeb) {
        expect(apiConfig.baseUrl, equals('http://localhost:8080'));
      } else {
        expect(apiConfig.baseUrl, equals('http://192.168.1.69:8080'));
      }
    });
  });
}
