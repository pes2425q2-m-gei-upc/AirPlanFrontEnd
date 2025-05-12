// Clase para manejar la configuración de API
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Singleton instance con posibilidad de inyección de dependencias
  static final ApiConfig _instance = ApiConfig._internal();

  // Factory constructor que permite inyectar dependencias
  factory ApiConfig({
    bool? isWebPlatform,
    String? defaultWebUrl,
    String? defaultMobileUrl,
  }) {
    // Si se proporcionan nuevas dependencias, actualizamos la instancia
    if (isWebPlatform != null) {
      _instance._isWebPlatform = isWebPlatform;
    }
    if (defaultWebUrl != null) {
      _instance._defaultWebUrl = defaultWebUrl;
    }
    if (defaultMobileUrl != null) {
      _instance._defaultMobileUrl = defaultMobileUrl;
    }
    return _instance;
  }

  // Variables privadas para inyección
  bool _isWebPlatform = kIsWeb;
  String _defaultWebUrl = 'http://localhost:8080';
  String _defaultMobileUrl = 'http://localhost:8080';

  // Constructor interno
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
    if (_isWebPlatform) {
      _baseUrl = _defaultWebUrl;
    }
    // Si estamos en un dispositivo móvil Android o iOS,
    // usar la IP local del ordenador
    else {
      // Reemplaza esta IP con la dirección IP de tu ordenador en tu red local
      // Puedes encontrarla ejecutando 'ipconfig' en Windows o 'ifconfig' en Mac/Linux
      _baseUrl = _defaultMobileUrl;
    }
  }

  // Getter para obtener la URL base
  String get baseUrl => _baseUrl;

  // Método para construir URLs completas
  String buildUrl(String endpoint) {
    // Si la URL base no ha sido inicializada, inicializarla con valores por defecto
    if (_baseUrl.isEmpty) {
      initialize();
    }

    // Asegurarnos de que endpoint no comienza con /
    final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$_baseUrl/$path';
  }
}
