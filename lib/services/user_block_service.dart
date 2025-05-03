// user_block_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/services/auth_service.dart'; // Importamos AuthService

/// Servicio para gestionar el bloqueo/desbloqueo de usuarios
class UserBlockService {
  // Singleton con posibilidad de inyección de dependencias
  static UserBlockService? _instance;

  factory UserBlockService({
    ChatWebSocketService? chatWebSocketService,
    ApiConfig? apiConfig,
    http.Client? httpClient,
    AuthService? authService,
  }) {
    // Create a new instance if none exists or any injection provided
    if (_instance == null ||
        chatWebSocketService != null ||
        apiConfig != null ||
        httpClient != null ||
        authService != null) {
      _instance = UserBlockService._internal(
        chatWebSocketService: chatWebSocketService,
        apiConfig: apiConfig,
        httpClient: httpClient,
        authService: authService,
      );
    }
    return _instance!;
  }

  // Dependencias del servicio
  late ChatWebSocketService _chatWebSocketService;
  late ApiConfig _apiConfig;
  late http.Client _httpClient;
  late AuthService _authService;

  UserBlockService._internal({
    ChatWebSocketService? chatWebSocketService,
    ApiConfig? apiConfig,
    http.Client? httpClient,
    AuthService? authService,
  }) : _chatWebSocketService = chatWebSocketService ?? ChatWebSocketService(),
       _apiConfig = apiConfig ?? ApiConfig(),
       _httpClient = httpClient ?? http.Client(),
       _authService = authService ?? AuthService();

  /// Bloquear a un usuario
  ///
  /// [usuarioQueBloquea] es el username del usuario que realiza el bloqueo
  /// [usuarioBloqueado] es el username del usuario que será bloqueado
  Future<bool> blockUser(
    String usuarioQueBloquea,
    String usuarioBloqueado,
  ) async {
    try {
      // Enviar la acción de bloqueo directamente por WebSocket
      final success = await _chatWebSocketService.sendBlockNotification(
        usuarioBloqueado,
        true,
      );

      // Si no se puede enviar por WebSocket (quizás no hay conexión),
      // utilizar el método HTTP como fallback
      if (!success) {
        final response = await _httpClient.post(
          Uri.parse(_apiConfig.buildUrl('api/blocks/create')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'blockerUsername': usuarioQueBloquea,
            'blockedUsername': usuarioBloqueado,
          }),
        );

        print(
          'Respuesta al bloquear (fallback HTTP): ${response.statusCode}, ${response.body}',
        );
        return response.statusCode == 200 || response.statusCode == 201;
      }

      return success;
    } catch (e) {
      print('Error al bloquear usuario: ${e.toString()}');
      return false;
    }
  }

  /// Desbloquear a un usuario
  ///
  /// [usuarioQueBloquea] es el username del usuario que realizó el bloqueo
  /// [usuarioBloqueado] es el username del usuario que será desbloqueado
  Future<bool> unblockUser(
    String usuarioQueBloquea,
    String usuarioBloqueado,
  ) async {
    try {
      // Enviar la acción de desbloqueo directamente por WebSocket
      final success = await _chatWebSocketService.sendBlockNotification(
        usuarioBloqueado,
        false,
      );

      // Si no se puede enviar por WebSocket, utilizar el método HTTP como fallback
      if (!success) {
        final response = await _httpClient.post(
          Uri.parse(_apiConfig.buildUrl('api/blocks/remove')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'blockerUsername': usuarioQueBloquea,
            'blockedUsername': usuarioBloqueado,
          }),
        );

        return response.statusCode == 200;
      }

      return success;
    } catch (e) {
      print('Error al desbloquear usuario: ${e.toString()}');
      return false;
    }
  }

  /// Verificar si un usuario está bloqueado por otro
  ///
  /// [usuarioQueBloquea] es el username del usuario que podría haber bloqueado
  /// [usuarioBloqueado] es el username del usuario que podría estar bloqueado
  Future<bool> isUserBlocked(
    String usuarioQueBloquea,
    String usuarioBloqueado,
  ) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(
          _apiConfig.buildUrl(
            'api/blocks/status/$usuarioQueBloquea/$usuarioBloqueado',
          ),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isBlocked'] == true;
      }
      return false;
    } catch (e) {
      print('Error al verificar bloqueo: ${e.toString()}');
      return false;
    }
  }

  /// Obtener lista de usuarios bloqueados por un usuario
  Future<List<dynamic>> getBlockedUsers(String email) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(_apiConfig.buildUrl('api/blocks/list/$email')),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error al obtener usuarios bloqueados: ${e.toString()}');
      return [];
    }
  }

  /// Obtener el email del usuario autenticado actual
  String? getCurrentUserEmail() {
    return _authService.getCurrentUser()?.email;
  }

  /// Obtener el username del usuario autenticado actual
  String? getCurrentUsername() {
    return _authService.getCurrentUsername();
  }
}
