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

  // Enviar notificación de bloqueo a través del WebSocket
  Future<bool> sendBlockNotification(
    String blockedUsername,
    bool isBlocking,
  ) async {
    if (!_isChatConnected || _chatChannel == null) {
      // Si no hay conexión activa, intentar conectar primero
      debugPrint('🔌 No hay conexión WebSocket activa. Intentando conectar...');
      connectToChat(blockedUsername);
      // Esperar un poco para que la conexión se establezca
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isChatConnected || _chatChannel == null) {
        debugPrint(
          '❌ No se pudo establecer conexión WebSocket para enviar notificación de bloqueo',
        );
        return false;
      }
      debugPrint('✅ Conexión WebSocket establecida correctamente');
    }

    try {
      // Formato modificado para coincidir con lo que espera el backend
      final notification = {
        'type': isBlocking ? 'BLOCK' : 'UNBLOCK',
        'blockerUsername': _currentUsername,
        'blockedUsername': blockedUsername,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final notificationJson = jsonEncode(notification);
      debugPrint(
        '📤 Enviando notificación de ${isBlocking ? "bloqueo" : "desbloqueo"}: $notificationJson',
      );
      _chatChannel!.sink.add(notificationJson);

      // Verificar que el mensaje fue enviado correctamente
      debugPrint('✅ Mensaje enviado correctamente al servidor WebSocket');

      // Para desbloqueos, forzar reconexión para actualizar el estado
      if (!isBlocking) {
        debugPrint(
          '🔄 Desbloqueo detectado, reconectando para forzar actualización de estado...',
        );
        // Pequeña pausa para permitir que el servidor procese el desbloqueo
        await Future.delayed(const Duration(milliseconds: 1000));

        // Reconectar para obtener estado actualizado
        disconnectChat();
        await Future.delayed(const Duration(milliseconds: 300));
        connectToChat(blockedUsername);
        debugPrint('♻️ Reconexión completada después del desbloqueo');
      }

      return true;
    } catch (e) {
      debugPrint(
        '❌ Error al enviar notificación de ${isBlocking ? "bloqueo" : "desbloqueo"} por WebSocket: $e',
      );
      return false;
    }
  }

  // Manejar mensajes entrantes del WebSocket de chat
  void _handleIncomingChatMessage(String messageText) {
    try {
      debugPrint('Mensaje de chat recibido: $messageText');

      // Intentar parsear el mensaje como JSON
      final dynamic messageData = jsonDecode(messageText);

      // Procesar diferentes tipos de mensajes
      if (messageData is Map && messageData.containsKey('type')) {
        final messageType = messageData['type'];
        debugPrint('📩 Procesando mensaje de tipo: $messageType');

        // Procesar respuestas y notificaciones de bloqueo
        if (messageType == 'BLOCK_ACTION' ||
            messageType == 'BLOCK' ||
            messageType == 'BLOCK_NOTIFICATION' ||
            messageType == 'BLOCK_RESPONSE') {
          // Determinar el bloqueador y el bloqueado según el formato del mensaje
          String? blocker;
          String? blocked;

          if (messageData.containsKey('blocker')) {
            blocker = messageData['blocker'];
            blocked = messageData['blocked'];
          } else if (messageData.containsKey('blockerUsername')) {
            blocker = messageData['blockerUsername'];
            blocked = messageData['blockedUsername'];

            // Si solo viene el bloqueador pero no el bloqueado, inferimos que el bloqueado es el usuario actual
            if (blocked == null && _currentUsername.isNotEmpty) {
              blocked = _currentUsername;
              debugPrint(
                'Inferido que el usuario bloqueado es el actual: $_currentUsername',
              );
            }
          }

          // Solo procesar si tenemos la información necesaria
          if (blocker != null) {
            // Para el caso especial donde solo recibimos el bloqueador
            if (blocked == null && _currentChatPartner != null) {
              if (blocker == _currentChatPartner) {
                // Si el bloqueador es el usuario con el que estamos chateando,
                // asumimos que nos ha bloqueado a nosotros
                blocked = _currentUsername;
                debugPrint(
                  'Inferido que el usuario bloqueado es el actual: $_currentUsername',
                );
              } else if (blocker == _currentUsername) {
                // Si el bloqueador somos nosotros, asumimos que hemos bloqueado
                // al usuario con el que estamos chateando
                blocked = _currentChatPartner;
                debugPrint(
                  'Inferido que el usuario bloqueado es la pareja de chat: $_currentChatPartner',
                );
              }
            }

            // Solo enviar si tenemos ambos usuarios o si es una notificación simple
            if (blocked != null || messageType == 'BLOCK_NOTIFICATION') {
              // Convertir al formato esperado por los listeners
              Map<String, dynamic> notification = {
                'type': 'BLOCK_NOTIFICATION',
                'blockerUsername': blocker,
                'timestamp':
                    messageData.containsKey('timestamp')
                        ? messageData['timestamp']
                        : DateTime.now().toIso8601String(),
              };

              // Añadir el usuario bloqueado si está disponible
              if (blocked != null) {
                notification['blockedUsername'] = blocked;
              }

              _chatMessageController.add(notification);

              debugPrint(
                '🔒 Notificación de bloqueo procesada: $blocker ha bloqueado${blocked != null ? ' a $blocked' : ''}',
              );
            }
          }
          return;
        }

        // Procesar respuestas y notificaciones de desbloqueo
        if (messageType == 'UNBLOCK_ACTION' ||
            messageType == 'UNBLOCK' ||
            messageType == 'UNBLOCK_NOTIFICATION' ||
            messageType == 'UNBLOCK_RESPONSE') {
          debugPrint('🔓 Recibida notificación de desbloqueo: $messageData');

          // Determinar el desbloqueador y el desbloqueado según el formato del mensaje
          String? unblocker;
          String? unblocked;

          if (messageData.containsKey('blocker')) {
            unblocker = messageData['blocker'];
            unblocked = messageData['blocked'];
          } else if (messageData.containsKey('blockerUsername')) {
            unblocker = messageData['blockerUsername'];
            unblocked = messageData['blockedUsername'];

            // Si solo viene el desbloqueador pero no el desbloqueado, inferimos que el desbloqueado es el usuario actual
            if (unblocked == null && _currentUsername.isNotEmpty) {
              unblocked = _currentUsername;
              debugPrint(
                'Inferido que el usuario desbloqueado es el actual: $_currentUsername',
              );
            }
          } else if (messageData.containsKey('unblockerUsername')) {
            unblocker = messageData['unblockerUsername'];
            unblocked = messageData['unblockedUsername'];
          }

          debugPrint(
            '🔓 Datos procesados - unblocker: $unblocker, unblocked: $unblocked, currentUsername: $_currentUsername, currentChatPartner: $_currentChatPartner',
          );

          // Solo procesar si tenemos la información necesaria
          if (unblocker != null) {
            // Para el caso especial donde solo recibimos el desbloqueador
            if (unblocked == null && _currentChatPartner != null) {
              if (unblocker == _currentChatPartner) {
                // Si el desbloqueador es el usuario con el que estamos chateando,
                // asumimos que nos ha desbloqueado a nosotros
                unblocked = _currentUsername;
                debugPrint(
                  'Inferido que el usuario desbloqueado es el actual: $_currentUsername',
                );
              } else if (unblocker == _currentUsername) {
                // Si el desbloqueador somos nosotros, asumimos que hemos desbloqueado
                // al usuario con el que estamos chateando
                unblocked = _currentChatPartner;
                debugPrint(
                  'Inferido que el usuario desbloqueado es la pareja de chat: $_currentChatPartner',
                );
              }
            }

            // Solo enviar si tenemos ambos usuarios o si es una notificación simple
            if (unblocked != null || messageType == 'UNBLOCK_NOTIFICATION') {
              // Convertir al formato esperado por los listeners
              Map<String, dynamic> notification = {
                'type': 'UNBLOCK_NOTIFICATION',
                'unblockerUsername': unblocker,
                'timestamp':
                    messageData.containsKey('timestamp')
                        ? messageData['timestamp']
                        : DateTime.now().toIso8601String(),
              };

              // Añadir el usuario desbloqueado si está disponible
              if (unblocked != null) {
                notification['unblockedUsername'] = unblocked;
              }

              debugPrint(
                '🔔 Enviando notificación a los listeners: $notification',
              );
              _chatMessageController.add(notification);

              debugPrint(
                '🔓 Notificación de desbloqueo procesada: $unblocker ha desbloqueado${unblocked != null ? ' a $unblocked' : ''}',
              );
            }
          }
          return;
        }

        // Verificar si es un mensaje de historial completo
        if (messageType == 'history' && messageData['messages'] is List) {
          final List<dynamic> messages = messageData['messages'];
          debugPrint('Recibido historial de ${messages.length} mensajes');

          // Primero, enviamos un mensaje especial con la información de bloqueo
          if (messageData.containsKey('blockStatus')) {
            _chatMessageController.add({
              'type': 'blockStatusUpdate',
              'blockStatus': messageData['blockStatus'],
            });
            debugPrint(
              'Enviando estado de bloqueo: ${messageData['blockStatus']}',
            );
          }

          // Luego procesamos cada mensaje del historial
          for (var msg in messages) {
            if (msg is Map &&
                msg.containsKey('usernameSender') &&
                msg.containsKey('usernameReceiver') &&
                msg.containsKey('dataEnviament') &&
                msg.containsKey('missatge')) {
              _chatMessageController.add({
                'usernameSender': msg['usernameSender'],
                'usernameReceiver': msg['usernameReceiver'],
                'dataEnviament': msg['dataEnviament'],
                'missatge': msg['missatge'],
                'fromHistory': true, // Marcamos que viene del historial
              });
            }
          }
          return;
        }
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
}
