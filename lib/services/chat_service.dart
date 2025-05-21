import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/services/auth_service.dart'; // Importar AuthService
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
  final String? photoURL; // Nueva propiedad para la URL de la foto

  Chat({
    required this.otherUsername,
    required this.lastMessage,
    required this.lastMessageTime,
    this.isRead = false,
    this.photoURL, // Nueva propiedad opcional
  });

  factory Chat.fromMessage(
    Message message,
    String currentUsername, {
    String? photoURL,
  }) {
    final isReceiver = message.receiverUsername == currentUsername;
    final otherUser =
        isReceiver ? message.senderUsername : message.receiverUsername;

    return Chat(
      otherUsername: otherUser,
      lastMessage: message.content,
      lastMessageTime: message.timestamp,
      photoURL: photoURL, // Asignar la URL de la foto desde el parámetro
    );
  }
}

class ChatService {
  // Singleton instance
  static ChatService? _instance;

  // Factory with dependency injection, lazy singleton creation
  factory ChatService({
    ChatWebSocketService? chatWebSocketService,
    AuthService? authService,
  }) {
    if (_instance == null) {
      _instance = ChatService._internal(
        chatWebSocketService: chatWebSocketService,
        authService: authService,
      );
    } else {
      if (chatWebSocketService != null) {
        _instance!._chatWebSocketService = chatWebSocketService;
      }
      if (authService != null) {
        _instance!._authService = authService;
      }
    }
    return _instance!;
  }

  // Private internal constructor with optional injections
  ChatService._internal({
    ChatWebSocketService? chatWebSocketService,
    AuthService? authService,
  }) {
    _chatWebSocketService = chatWebSocketService ?? ChatWebSocketService();
    _authService = authService ?? AuthService();
  }

  // Referencias a servicios
  late ChatWebSocketService _chatWebSocketService;
  late AuthService _authService;

  // Send a message to another user using WebSocket
  Future<bool> sendMessage(String receiverUsername, String content, DateTime creationTime) async {
    try {
      // Enviar mensaje usando ChatWebSocketService
      return await _chatWebSocketService.sendChatMessage(
        receiverUsername,
        content,
        creationTime,
      );
    } catch (e) {
      debugPrint('Error sending message via WebSocket: $e');
      return false;
    }
  }

  // Get conversation history between current user and another user via HTTP
  Future<List<Message>> getConversation(String otherUsername) async {
    try {
      // Usar AuthService en lugar de Firebase Auth directamente
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null || currentUser.displayName == null) {
        debugPrint('User not logged in for getConversation');
        return [];
      }

      // Connect WebSocket for real-time updates (if not already connected)
      // The listener in ChatDetailPage will handle incoming messages.
      _chatWebSocketService.connectToChat(otherUsername);

      // Fetch historical messages from the backend
      final response = await http.get(
        Uri.parse(
          ApiConfig().buildUrl(
            'chat/${currentUser.displayName}/$otherUsername',
          ),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        List<Message> historyMessages =
            jsonData.map((data) => Message.fromJson(data)).toList();

        // Sort by timestamp
        historyMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return historyMessages;
      } else {
        debugPrint(
          'Error fetching conversation history: ${response.statusCode} ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Error getting conversation history: $e');
      return [];
    }
  }

  // Get all chats for the current user
  Future<List<Chat>> getAllChats() async {
    try {
      // Usar AuthService en lugar de Firebase Auth directamente
      final currentUser = _authService.getCurrentUser();
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

          // Extraer la URL de la foto de perfil si está disponible
          String? photoUrl;
          if (messageData.containsKey('photoURL')) {
            photoUrl = messageData['photoURL'];
          }

          // Evitar duplicados (un chat por usuario)
          if (!addedUsers.contains(otherUsername)) {
            chats.add(
              Chat.fromMessage(
                message,
                currentUser.displayName!,
                photoURL: photoUrl, // Pasar la URL de la foto
              ),
            );
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

  // Method to disconnect the WebSocket when leaving the chat screen
  Future<bool> editMessage(
      String receiverUsername,
      String originalTimestamp,
      String newContent,
      ) async {
    // Use the WebSocket service to send the edited message
    try{
      return await _chatWebSocketService.sendEditMessage(
        receiverUsername,
        originalTimestamp,
        newContent,
      );
    } catch (e) {
      debugPrint('Error editing message via WebSocket: $e');
      return false;
    }
  }

  Future<bool> deleteMessage(String receiverUsername, String timestamp) async {
    try {
      final success = await _chatWebSocketService.sendDeleteMessage(receiverUsername, timestamp);
      return success;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }

  Future<dynamic> reportUser({
    required String reportedUsername,
    required String reporterUsername,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        //Uri.parse(ApiConfig().buildUrl('api/report')),
        Uri.parse("http://127.0.0.1:8080/api/report"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reportedUsername': reportedUsername,
          'reporterUsername': reporterUsername,
          'reason': reason,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 409) {
        return 'already_reported';
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error reporting user: $e');
      return false;
    }
  }

  // Método para limpiar la conexión del WebSocket cuando el usuario sale de la pantalla de chat
  void disconnectFromChat() {
    _chatWebSocketService.disconnectChat();
  }
}
