import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/chat_websocket_service.dart';

class Message {
  final String senderUsername;
  final String receiverUsername;
  final DateTime timestamp;
  final String content;

  Message({
    required this.senderUsername,
    required this.receiverUsername,
    required this.timestamp,
    required this.content,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      senderUsername: json['usernameSender'],
      receiverUsername: json['usernameReceiver'],
      timestamp: DateTime.parse(json['dataEnviament']),
      content: json['missatge'],
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
  void _setupWebSocketListeners() {
    _chatWebSocketService.chatMessages.listen((messageData) {
      // Si el mensaje tiene la marca 'fromHistory', significa que viene del historial inicial
      bool isFromHistory =
          messageData.containsKey('fromHistory') &&
          messageData['fromHistory'] == true;

      // Añadimos el mensaje recibido a la caché
      if (messageData.containsKey('usernameSender') &&
          messageData.containsKey('usernameReceiver') &&
          messageData.containsKey('missatge') &&
          messageData.containsKey('dataEnviament')) {
        final message = Message(
          senderUsername: messageData['usernameSender'],
          receiverUsername: messageData['usernameReceiver'],
          timestamp: DateTime.parse(messageData['dataEnviament']),
          content: messageData['missatge'],
        );

        // Para mensajes del historial, solo verificamos si ya existe un duplicado exacto
        // Para mensajes nuevos, aplicamos la verificación con tolerancia de tiempo
        bool isDuplicate;

        if (isFromHistory) {
          // Verificación estricta para mensajes históricos (solo duplicados exactos)
          isDuplicate = _messageCache.any(
            (m) =>
                m.senderUsername == message.senderUsername &&
                m.receiverUsername == message.receiverUsername &&
                m.content == message.content &&
                m.timestamp.isAtSameMomentAs(message.timestamp),
          );
        } else {
          // Verificación con tolerancia para mensajes nuevos
          isDuplicate = _messageCache.any(
            (m) =>
                m.senderUsername == message.senderUsername &&
                m.receiverUsername == message.receiverUsername &&
                m.content == message.content &&
                (m.timestamp.difference(message.timestamp).inSeconds.abs() < 5),
          ); // Tolerancia de 5 segundos
        }

        if (!isDuplicate) {
          _messageCache.add(message);
        }
      }
    });
  }

  // Send a message to another user using WebSocket
  Future<bool> sendMessage(String receiverUsername, String content) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.displayName == null) {
        return false;
      }

      // Crear el mensaje
      final message = Message(
        senderUsername: currentUser.displayName!,
        receiverUsername: receiverUsername,
        timestamp: DateTime.now(),
        content: content,
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
      );
    } catch (e) {
      print('Error sending message: $e');
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

      // Limpiar la caché específica para esta conversación para evitar acumulación de mensajes
      _cleanCacheForConversation(currentUser.displayName!, otherUsername);

      // Primero intentamos conectar al chat WebSocket para empezar a recibir mensajes en tiempo real
      _chatWebSocketService.connectToChat(otherUsername);

      // Luego obtenemos el historial de mensajes desde el backend
      final response = await http.get(
        Uri.parse(
          ApiConfig().buildUrl(
            'chat/${currentUser.displayName}/$otherUsername',
          ),
        ),
      );

      // Lista para almacenar todos los mensajes
      List<Message> allMessages = [];

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        allMessages = jsonData.map((data) => Message.fromJson(data)).toList();
      }

      // Añadimos los mensajes de la caché que pertenecen a esta conversación
      for (var message in _messageCache) {
        if ((message.senderUsername == currentUser.displayName &&
                message.receiverUsername == otherUsername) ||
            (message.senderUsername == otherUsername &&
                message.receiverUsername == currentUser.displayName)) {
          // Verificación más robusta de duplicados con tolerancia de tiempo
          bool isDuplicate = allMessages.any(
            (m) =>
                m.senderUsername == message.senderUsername &&
                m.receiverUsername == message.receiverUsername &&
                m.content == message.content &&
                (m.timestamp.difference(message.timestamp).inSeconds.abs() < 5),
          ); // Tolerancia de 5 segundos

          if (!isDuplicate) {
            allMessages.add(message);
          }
        }
      }

      // Normalizar formato de fechas
      _normalizeMessageDates(allMessages);

      // Ordenar por fecha de forma estable
      allMessages.sort((a, b) {
        int dateCompare = a.timestamp.compareTo(b.timestamp);
        if (dateCompare == 0) {
          // Si las fechas son iguales, ordenar por contenido para estabilidad
          return a.content.compareTo(b.content);
        }
        return dateCompare;
      });

      return allMessages;
    } catch (e) {
      print('Error getting conversation: $e');
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
      );

      messages[i] = Message(
        senderUsername: messages[i].senderUsername,
        receiverUsername: messages[i].receiverUsername,
        content: messages[i].content,
        timestamp: normalizedDate,
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
        print('Error getting chats: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting all chats: $e');
      return [];
    }
  }

  // Método para limpiar la conexión del WebSocket cuando el usuario sale de la pantalla de chat
  void disconnectFromChat() {
    _chatWebSocketService.disconnectChat();
  }
}
