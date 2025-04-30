// user_block_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/chat_websocket_service.dart';

/// Servicio para gestionar el bloqueo/desbloqueo de usuarios
class UserBlockService {
  // Singleton
  static final UserBlockService _instance = UserBlockService._internal();
  factory UserBlockService() => _instance;
  UserBlockService._internal();

  // Instancia del servicio de WebSocket para chat
  final _chatWebSocketService = ChatWebSocketService();

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
        final response = await http.post(
          Uri.parse(ApiConfig().buildUrl('api/blocks/create')),
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
        final response = await http.post(
          Uri.parse(ApiConfig().buildUrl('api/blocks/remove')),
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
      final response = await http.get(
        Uri.parse(
          ApiConfig().buildUrl(
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
      final response = await http.get(
        Uri.parse(ApiConfig().buildUrl('api/blocks/list/$email')),
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
}
