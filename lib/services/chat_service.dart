import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:flutter/foundation.dart';

class Message {
  final String senderUsername;
  final String receiverUsername;
  final DateTime timestamp;
  final String content;
  final bool isEdited;
  bool isHovered;

  Message({
    required this.senderUsername,
    required this.receiverUsername,
    required this.timestamp,
    required this.content,
    required this.isEdited,
    this.isHovered = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      senderUsername: json['usernameSender'],
      receiverUsername: json['usernameReceiver'],
      timestamp: DateTime.parse(json['dataEnviament']),
      content: json['missatge'],
      isEdited: json['isEdited'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usernameSender': senderUsername,
      'usernameReceiver': receiverUsername,
      'dataEnviament': timestamp.toIso8601String(),
      'missatge': content,
    };
  }
}

class Chat {
  final String otherUsername;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isRead;

  Chat({
    required this.otherUsername,
    required this.lastMessage,
    required this.lastMessageTime,
    this.isRead = false,
  });

  factory Chat.fromMessage(Message message, String currentUsername) {
    final isReceiver = message.receiverUsername == currentUsername;
    return Chat(
      otherUsername:
          isReceiver ? message.senderUsername : message.receiverUsername,
      lastMessage: message.content,
      lastMessageTime: message.timestamp,
    );
  }
}

class ChatService {
  // Singleton instance
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal() {
    // Inicializa la escucha de mensajes WebSocket
    _chatWebSocketService = ChatWebSocketService();
    _setupWebSocketListeners();
  }

  // Referencia al servicio WebSocket específico para chat
  late final ChatWebSocketService _chatWebSocketService;

  // Mensajes recibidos a través de WebSocket
  final List<Message> _messageCache = [];

  // Configura los escuchadores para el WebSocket
  final _messageUpdateController = StreamController<List<Message>>.broadcast();

  // Expose a stream that UI can subscribe to
  Stream<List<Message>> get onMessageUpdate => _messageUpdateController.stream;

  void _setupWebSocketListeners() {
    final processedMessageIds = <String>{};

    _chatWebSocketService.chatMessages.listen((messageData) {
      // Handle EDIT messages
      if (messageData.containsKey('type') && messageData['type'] == 'EDIT') {
        final sender = messageData['usernameSender'];
        final originalTimestamp = messageData['originalTimestamp'];
        final newContent = messageData['newContent'];
        bool wasUpdated = false;

        // Find and update the message in cache
        for (int i = 0; i < _messageCache.length; i++) {
          if (_messageCache[i].senderUsername == sender &&
              _messageCache[i].timestamp.toIso8601String() == originalTimestamp) {
            _messageCache[i] = Message(
                senderUsername: _messageCache[i].senderUsername,
                receiverUsername: _messageCache[i].receiverUsername,
                timestamp: _messageCache[i].timestamp,
                content: newContent,
                isEdited: true
            );
            wasUpdated = true;
            break;
          }
        }

        // Notify listeners that messages were updated
        if (wasUpdated) {
          _messageUpdateController.add(_messageCache.toList());
        }
        return;
      }

      // For regular messages
      if (messageData.containsKey('usernameSender') &&
          messageData.containsKey('usernameReceiver') &&
          messageData.containsKey('missatge') &&
          messageData.containsKey('dataEnviament')) {

        // Create unique identifier for this message
        final String messageId = '${messageData['usernameSender']}_${messageData['dataEnviament']}_${messageData['missatge']}';

        // Skip if we've already processed this message
        if (processedMessageIds.contains(messageId)) {
          return;
        }

        // Mark as processed
        processedMessageIds.add(messageId);

        final message = Message(
          senderUsername: messageData['usernameSender'],
          receiverUsername: messageData['usernameReceiver'],
          timestamp: DateTime.parse(messageData['dataEnviament']),
          content: messageData['missatge'],
          isEdited: messageData['isEdited'] ?? false,
        );

        // Existing duplicate check for historical messages
        bool isDuplicate = _messageCache.any(
              (m) =>
          m.senderUsername == message.senderUsername &&
              m.receiverUsername == message.receiverUsername &&
              m.content == message.content &&
              m.timestamp.isAtSameMomentAs(message.timestamp),
        );

        if (!isDuplicate) {
          _messageCache.add(message);
        }
      }
    });
  }

  // Send a message to another user using WebSocket
  Future<bool> sendMessage(String receiverUsername, String content, DateTime creationTime) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.displayName == null) {
        return false;
      }

      // Crear el mensaje
      final message = Message(
        senderUsername: currentUser.displayName!,
        receiverUsername: receiverUsername,
        timestamp: creationTime,
        content: content,
        isEdited: false,
      );

      // Verificar si el mensaje ya existe en la caché antes de añadirlo
      bool isDuplicate = _messageCache.any(
        (m) =>
            m.senderUsername == message.senderUsername &&
            m.receiverUsername == message.receiverUsername &&
            m.content == message.content &&
            (m.timestamp.difference(message.timestamp).inSeconds.abs() < 5),
      ); // Tolerancia de 5 segundos

      // Solo añadir a la caché si no es un duplicado
      if (!isDuplicate) {
        _messageCache.add(message);
      }

      // Enviar mensaje usando ChatWebSocketService
      return await _chatWebSocketService.sendChatMessage(
        receiverUsername,
        content,
        creationTime,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  // Get conversation history between current user and another user
  Future<List<Message>> getConversation(String otherUsername) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.displayName == null) {
        return [];
      }

      // Clear any existing cache for this conversation
      _cleanCacheForConversation(currentUser.displayName!, otherUsername);

      // Connect to WebSocket first - this will start receiving history
      _chatWebSocketService.connectToChat(otherUsername);

      // Wait a moment to ensure the WebSocket has time to receive the history
      await Future.delayed(const Duration(milliseconds: 500));

      // If we already have messages in the cache for this conversation, use them
      // This way we avoid duplicating what the WebSocket already provided
      List<Message> conversationMessages = _messageCache
          .where((message) =>
      (message.senderUsername == currentUser.displayName! &&
          message.receiverUsername == otherUsername) ||
          (message.senderUsername == otherUsername &&
              message.receiverUsername == currentUser.displayName!))
          .toList();

      // Only fetch from API if we don't have messages from WebSocket
      if (conversationMessages.isEmpty) {
        final response = await http.get(
          Uri.parse(
            ApiConfig().buildUrl(
              'chat/${currentUser.displayName}/$otherUsername',
            ),
          ),
        );

        if (response.statusCode == 200) {
          final List<dynamic> jsonData = jsonDecode(response.body);
          conversationMessages = jsonData
              .map((data) => Message.fromJson(data))
              .toList();
        }
      }

      // Normalize message dates and sort
      _normalizeMessageDates(conversationMessages);
      conversationMessages.sort((a, b) {
        int dateCompare = a.timestamp.compareTo(b.timestamp);
        if (dateCompare == 0) {
          return a.content.compareTo(b.content);
        }
        return dateCompare;
      });

      return conversationMessages;
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return [];
    }
  }

  // Limpia la caché de mensajes específicos para una conversación
  void _cleanCacheForConversation(String user1, String user2) {
    // Mantener solo mensajes recientes (últimas 24 horas) para evitar acumulación
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));

    _messageCache.removeWhere(
      (message) =>
          ((message.senderUsername == user1 &&
                  message.receiverUsername == user2) ||
              (message.senderUsername == user2 &&
                  message.receiverUsername == user1)) &&
          message.timestamp.isBefore(cutoffTime),
    );
  }

  // Normaliza el formato de fechas para asegurar consistencia
  void _normalizeMessageDates(List<Message> messages) {
    for (int i = 0; i < messages.length; i++) {
      // Asegurarnos de que todas las fechas tienen la misma precisión (sin milisegundos)
      final normalizedDate = DateTime(
        messages[i].timestamp.year,
        messages[i].timestamp.month,
        messages[i].timestamp.day,
        messages[i].timestamp.hour,
        messages[i].timestamp.minute,
        messages[i].timestamp.second,
        messages[i].timestamp.millisecond,
      );

      messages[i] = Message(
        senderUsername: messages[i].senderUsername,
        receiverUsername: messages[i].receiverUsername,
        content: messages[i].content,
        timestamp: normalizedDate,
        isEdited: messages[i].isEdited,
      );
    }
  }

  // Get all chats for the current user
  Future<List<Chat>> getAllChats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.displayName == null) {
        return [];
      }

      // Llamar al endpoint del backend para obtener todos los chats
      final response = await http.get(
        Uri.parse(
          ApiConfig().buildUrl(
            'chat/conversaciones/${currentUser.displayName}',
          ),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        // Convertir cada mensaje a un objeto Chat
        final List<Chat> chats = [];
        final Set<String> addedUsers = {};

        // Convertir los mensajes en objetos Chat (uno por usuario)
        for (var messageData in jsonData) {
          final message = Message.fromJson(messageData);
          final otherUsername =
              message.senderUsername == currentUser.displayName
                  ? message.receiverUsername
                  : message.senderUsername;

          // Evitar duplicados (un chat por usuario)
          if (!addedUsers.contains(otherUsername)) {
            chats.add(Chat.fromMessage(message, currentUser.displayName!));
            addedUsers.add(otherUsername);
          }
        }

        return chats;
      } else {
        debugPrint('Error getting chats: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting all chats: $e');
      return [];
    }
  }

  Future<bool> editMessage(
      String receiverUsername,
      String originalTimestamp,
      String newContent,
      ) async {
    // Use the WebSocket service to send the edited message
    return _chatWebSocketService.sendEditMessage(
        receiverUsername,
        originalTimestamp,
        newContent
    );
  }

  Future<bool> deleteMessage(String receiverUsername, String timestamp) async {
    try {
      final success = await _chatWebSocketService.sendDeleteMessage(receiverUsername, timestamp);
      if (success) {
        // Eliminar el mensaje de la caché local
        _messageCache.removeWhere((message) =>
        message.receiverUsername == receiverUsername &&
            message.timestamp.toIso8601String() == timestamp);

        // Notificar a los oyentes que la caché ha cambiado
        _messageUpdateController.add(_messageCache.toList());
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }

  // Método para limpiar la conexión del WebSocket cuando el usuario sale de la pantalla de chat
  void disconnectFromChat() {
    _chatWebSocketService.disconnectChat();
  }
}
