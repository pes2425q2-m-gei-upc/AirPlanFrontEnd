// Clase para manejar la configuración de API
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Singleton instance
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  // URL base para el backend, configurable según entorno
  String _baseUrl = '';

  // Método para inicializar la configuración
  void initialize({String? customUrl}) {
    // Si se proporciona una URL personalizada, úsala
    if (customUrl != null && customUrl.isNotEmpty) {
      _baseUrl = customUrl;
      return;
    }

    // Si estamos en web, usar localhost
    if (kIsWeb) {
      _baseUrl = 'http://localhost:8080';
    }
    // Si estamos en un dispositivo móvil Android o iOS,
    // usar la IP local del ordenador
    else {
      // Reemplaza esta IP con la dirección IP de tu ordenador en tu red local
      // Puedes encontrarla ejecutando 'ipconfig' en Windows o 'ifconfig' en Mac/Linux
      _baseUrl = 'http://192.168.1.69:8080';
    }
  }

  // Getter para obtener la URL base
  String get baseUrl => _baseUrl;

  // Método para construir URLs completas
  String buildUrl(String endpoint) {
    // Asegurarnos de que endpoint no comienza con /
    final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$_baseUrl/$path';
  }
}
