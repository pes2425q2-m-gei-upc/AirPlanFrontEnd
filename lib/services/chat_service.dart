import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/services/api_config.dart';
import 'dart:async';
import 'package:airplan/services/websocket_service.dart';

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
      receiverUsername:
          json['usernameReceiver'], // Corregido de usernameReciever a usernameReceiver
      timestamp: DateTime.parse(json['dataEnviament']),
      content: json['missatge'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usernameSender': senderUsername,
      'usernameReceiver':
          receiverUsername, // Corregido de usernameReciever a usernameReceiver
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
}

class ChatService {
  // Singleton instance
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  // Controller para transmitir mensajes en tiempo real
  final StreamController<Message> _messageStreamController =
      StreamController<Message>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _chatMessageSubscription;

  // Obtener el stream de mensajes
  Stream<Message> get messageStream => _messageStreamController.stream;

  ChatService._internal() {
    // Inicializar la suscripción en el constructor interno
    _initializeSubscription();
  }

  // Inicializar o reiniciar la suscripción a mensajes de chat
  void _initializeSubscription() {
    // Cancelar suscripción existente si hay alguna
    _chatMessageSubscription?.cancel();

    // Asegurar que WebSocket está conectado
    if (!WebSocketService().isConnected) {
      WebSocketService().connect();
    }

    // Suscribirse al stream específico de mensajes de chat
    _chatMessageSubscription = WebSocketService().chatMessages.listen((data) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.displayName != null) {
          // Comprobar si el mensaje es para este usuario
          if (data['usernameReceiver'] == currentUser.displayName ||
              data['usernameSender'] == currentUser.displayName) {
            // Convertir a objeto Message y añadirlo al stream
            final newMessage = Message.fromJson(data);
            _messageStreamController.add(newMessage);
          }
        }
      } catch (e) {
        print('Error procesando mensaje de chat: $e');
      }
    });
  }

  // Método público para compatibilidad con código existente
  void initialize() {
    // Asegurar que la conexión WebSocket está establecida
    if (!WebSocketService().isConnected) {
      WebSocketService().connect();
    }

    // Solo reiniciar la suscripción si es necesario
    if (_chatMessageSubscription == null) {
      _initializeSubscription();
    }
  }

  // Liberar recursos cuando ya no se necesitan
  void dispose() {
    _chatMessageSubscription?.cancel();
    _messageStreamController.close();
  }

  // Send a message to another user
  Future<bool> sendMessage(String receiverUsername, String content) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.displayName == null) {
        return false;
      }

      final message = Message(
        senderUsername: currentUser.displayName!,
        receiverUsername: receiverUsername,
        timestamp: DateTime.now(),
        content: content,
      );

      // Enviamos un mensaje de tipo CHAT_MESSAGE al servidor WebSocket
      final chatMessage = {
        ...message.toJson(),
        'type': 'CHAT_MESSAGE',
        'clientId': WebSocketService().clientId,
      };

      // IMPORTANTE: Añadir el mensaje al stream local inmediatamente
      // para que aparezca en la interfaz del remitente sin esperar al WebSocket
      _messageStreamController.add(message);

      // Si el WebSocket está conectado, enviamos el mensaje a través de él
      if (WebSocketService().isConnected) {
        WebSocketService().sendMessage(jsonEncode(chatMessage));
        return true;
      } else {
        // Si WebSocket no está disponible, realizamos una petición HTTP como fallback
        final response = await http.post(
          Uri.parse(ApiConfig().buildUrl('chat/send')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(message.toJson()),
        );
        return response.statusCode == 201;
      }
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

      final response = await http.get(
        Uri.parse(
          ApiConfig().buildUrl(
            'chat/${currentUser.displayName}/$otherUsername',
          ),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((data) => Message.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting conversation: $e');
      return [];
    }
  }

  // Get all chats for the current user (this would require backend support)
  // For now, we'll implement a simpler version that returns conversations from local storage
  Future<List<Chat>> getAllChats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.displayName == null) {
        return [];
      }

      // In a real implementation, you would have an endpoint to get all chats
      // For now, we'll return an empty list
      return [];
    } catch (e) {
      print('Error getting all chats: $e');
      return [];
    }
  }
}
