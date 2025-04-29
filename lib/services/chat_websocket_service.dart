import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:airplan/services/api_config.dart';

/// Servicio específico para gestionar la conexión WebSocket del chat
class ChatWebSocketService {
  static final ChatWebSocketService _instance =
      ChatWebSocketService._internal();
  WebSocketChannel? _chatChannel;

  // Controlador para mensajes de chat
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isChatConnected = false;
  String _currentUsername = '';
  String? _currentChatPartner;
  Timer? _chatPingTimer;

  // Singleton factory
  factory ChatWebSocketService() {
    return _instance;
  }

  ChatWebSocketService._internal() {
    // Escuchar cambios de autenticación
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        disconnectChat();
      }
    });
  }

  // Stream para mensajes de chat que otros widgets pueden escuchar
  Stream<Map<String, dynamic>> get chatMessages =>
      _chatMessageController.stream;

  // Verificar si el WebSocket de chat está conectado
  bool get isChatConnected => _isChatConnected;

  // Obtener el nombre de usuario con el que se está chateando actualmente
  String? get currentChatPartner => _currentChatPartner;

  // Conectar al WebSocket de chat con un usuario específico
  void connectToChat(String otherUsername) {
    if (_isChatConnected &&
        _chatChannel != null &&
        _currentChatPartner == otherUsername) {
      return; // Ya está conectado al mismo chat
    }

    disconnectChat(); // Cerrar cualquier conexión de chat existente

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.displayName == null) {
      return;
    }

    _currentUsername = user.displayName!;
    _currentChatPartner = otherUsername;

    try {
      final baseUrl = ApiConfig().baseUrl.replaceFirst('http://', 'ws://');

      // Conectar al endpoint de chat usando el formato de la ruta del backend
      _chatChannel = WebSocketChannel.connect(
        Uri.parse('$baseUrl/ws/chat/$_currentUsername/$otherUsername'),
      );

      _isChatConnected = true;

      // Escuchar mensajes entrantes del chat
      _chatChannel!.stream.listen(
        (message) {
          _handleIncomingChatMessage(message.toString());
        },
        onDone: () {
          _isChatConnected = false;
          // No reconectamos automáticamente para el chat
        },
        onError: (error) {
          _isChatConnected = false;
          debugPrint('Error en WebSocket de chat: $error');
        },
      );

      _startChatPingTimer();
    } catch (e) {
      _isChatConnected = false;
      debugPrint('Error al conectar WebSocket de chat: $e');
    }
  }

  // Enviar un mensaje a través del WebSocket de chat
  Future<bool> sendChatMessage(String receiverUsername, String content) async {
    if (!_isChatConnected || _chatChannel == null) {
      // Si no hay conexión activa, intentar conectar primero
      connectToChat(receiverUsername);
      // Esperar un poco para que la conexión se establezca
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isChatConnected || _chatChannel == null) {
        debugPrint('No se pudo establecer conexión WebSocket para el chat');
        return false;
      }
    }

    try {
      final message = {
        'usernameSender': _currentUsername,
        'usernameReceiver': receiverUsername,
        'dataEnviament': DateTime.now().toIso8601String(),
        'missatge': content,
      };

      _chatChannel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      debugPrint('Error al enviar mensaje por WebSocket: $e');
      return false;
    }
  }

  // Manejar mensajes entrantes del WebSocket de chat
  void _handleIncomingChatMessage(String messageText) {
    try {
      debugPrint('Mensaje de chat recibido: $messageText');

      // Intentar parsear el mensaje como JSON
      final dynamic messageData = jsonDecode(messageText);

      // Verificar si es un mensaje de historial completo
      if (messageData is Map &&
          messageData['type'] == 'history' &&
          messageData['messages'] is List) {
        final List<dynamic> messages = messageData['messages'];
        debugPrint('Recibido historial de ${messages.length} mensajes');

        // Procesar cada mensaje del historial
        for (var msg in messages) {
          if (msg is Map &&
              msg.containsKey('usernameSender') &&
              msg.containsKey('usernameReceiver') &&
              msg.containsKey('dataEnviament') &&
              msg.containsKey('missatge') &&
              msg.containsKey('isEdited')) {
            _chatMessageController.add({
              'usernameSender': msg['usernameSender'],
              'usernameReceiver': msg['usernameReceiver'],
              'dataEnviament': msg['dataEnviament'],
              'missatge': msg['missatge'],
              'isEdited': msg['isEdited'] ?? false,
              'fromHistory': true, // Marcamos que viene del historial
            });
          }
        }
        return;
      }

      if (messageData is Map && messageData['type'] == 'EDIT') {
        debugPrint('Received edit notification');

        final editData = {
          'type': 'EDIT',
          'usernameSender': messageData['usernameSender'],
          'originalTimestamp': messageData['originalTimestamp'],
          'newContent': messageData['newContent'],
          'isEdited': messageData['isEdited'] ?? true
        };

        _chatMessageController.add(editData);
        return;
      }

      // Verificar si es un mensaje individual en formato JSON
      if (messageData is Map &&
          messageData.containsKey('usernameSender') &&
          messageData.containsKey('usernameReceiver') &&
          messageData.containsKey('dataEnviament') &&
          messageData.containsKey('missatge')) {
        // Enviar el mensaje al controlador de mensajes de chat
        _chatMessageController.add({
          'usernameSender': messageData['usernameSender'],
          'usernameReceiver': messageData['usernameReceiver'],
          'dataEnviament': messageData['dataEnviament'],
          'missatge': messageData['missatge'],
          'isEdited': messageData['isEdited'] ?? false,
        });
        return;
      }

      // Si el mensaje contiene un error, registrarlo
      if (messageData is Map && messageData.containsKey('error')) {
        debugPrint('Error recibido del servidor: ${messageData['error']}');
        return;
      }

      // Para compatibilidad con versiones anteriores, intentar procesar el mensaje
      // con formato "De [remitente] a [destinatario]: [contenido]"
      if (messageText.startsWith('De ') &&
          messageText.contains(' a ') &&
          messageText.contains(': ')) {
        // Usamos una expresión regular para extraer las partes del mensaje
        final regex = RegExp(r'De (.*?) a (.*?): (.*)');
        final match = regex.firstMatch(messageText);

        if (match != null && match.groupCount >= 3) {
          final sender = match.group(1) ?? '';
          final receiver = match.group(2) ?? '';
          final content = match.group(3) ?? '';

          final legacyMessageData = {
            'usernameSender': sender,
            'usernameReceiver': receiver,
            'dataEnviament': DateTime.now().toIso8601String(),
            'missatge': content,
          };

          _chatMessageController.add(legacyMessageData);
          return;
        }
      }

      // Si llegamos aquí, no pudimos procesar el mensaje correctamente
      debugPrint('No se pudo procesar el formato del mensaje: $messageText');
    } catch (e) {
      debugPrint('Error al procesar mensaje de chat: $e');

      // Intento fallback para el formato antiguo
      try {
        if (messageText.startsWith('De ') &&
            messageText.contains(' a ') &&
            messageText.contains(': ')) {
          // Usamos una expresión regular para extraer las partes del mensaje
          final regex = RegExp(r'De (.*?) a (.*?): (.*)');
          final match = regex.firstMatch(messageText);

          if (match != null && match.groupCount >= 3) {
            final sender = match.group(1) ?? '';
            final receiver = match.group(2) ?? '';
            final content = match.group(3) ?? '';

            final legacyMessageData = {
              'usernameSender': sender,
              'usernameReceiver': receiver,
              'dataEnviament': DateTime.now().toIso8601String(),
              'missatge': content,
            };

            _chatMessageController.add(legacyMessageData);
          }
        }
      } catch (e2) {
        debugPrint('Error en fallback del procesamiento del mensaje: $e2');
      }
    }
  }

  // Iniciar timer para enviar pings periódicos al servidor de chat
  void _startChatPingTimer() {
    _chatPingTimer?.cancel();
    _chatPingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isChatConnected && _chatChannel != null) {
        try {
          _chatChannel!.sink.add('{"type":"PING"}');
        } catch (e) {
          _isChatConnected = false;
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Desconectar del servidor WebSocket de chat
  void disconnectChat() {
    _chatPingTimer?.cancel();

    if (_chatChannel != null) {
      try {
        _chatChannel!.sink.close();
      } catch (e) {
        debugPrint('Error al cerrar WebSocket de chat: $e');
      } finally {
        _isChatConnected = false;
        _chatChannel = null;
        _currentChatPartner = null;
      }
    }
  }

  // Liberar recursos
  void dispose() {
    disconnectChat();
    _chatMessageController.close();
  }

  Future<bool> sendEditMessage(
      String receiverUsername,
      String originalTimestamp,
      String newContent
      ) async {
    if (!_isChatConnected || _chatChannel == null) {
      // If no active connection, try to connect first
      connectToChat(receiverUsername);
      // Wait a bit for the connection to establish
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isChatConnected || _chatChannel == null) {
        debugPrint('No se pudo establecer conexión WebSocket para editar el mensaje');
        return false;
      }
    }

    try {
      final message = {
        'type': 'EDIT',
        'usernameSender': _currentUsername,
        'usernameReceiver': receiverUsername,
        'originalTimestamp': originalTimestamp,
        'newContent': newContent,
        'editTimestamp': DateTime.now().toIso8601String(),
      };

      _chatChannel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      debugPrint('Error al enviar edición por WebSocket: $e');
      return false;
    }
  }
}
