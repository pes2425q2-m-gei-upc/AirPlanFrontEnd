import 'package:flutter/material.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatDetailPage extends StatefulWidget {
  final String username;

  const ChatDetailPage({Key? key, required this.username}) : super(key: key);

  @override
  ChatDetailPageState createState() => ChatDetailPageState();
}

class ChatDetailPageState extends State<ChatDetailPage> {
  final ChatService _chatService = ChatService();
  final ChatWebSocketService _chatWebSocketService = ChatWebSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUsername;

  // Suscripción a mensajes de WebSocket
  StreamSubscription? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentUsername();
    _loadMessages();
    _setupWebSocketListener();
  }

  // Configurar el listener de WebSocket para recibir mensajes en tiempo real
  void _setupWebSocketListener() {
    _chatSubscription = _chatWebSocketService.chatMessages.listen((
      messageData,
    ) {
      if (!mounted) return;

      if (messageData.containsKey('usernameSender') &&
          messageData.containsKey('usernameReceiver') &&
          messageData.containsKey('missatge')) {
        final sender = messageData['usernameSender'];
        final receiver = messageData['usernameReceiver'];

        // Solo procesamos mensajes que pertenecen a esta conversación
        if ((sender == _currentUsername && receiver == widget.username) ||
            (sender == widget.username && receiver == _currentUsername)) {
          // Recargar los mensajes para mostrar el nuevo mensaje
          // Esto incluirá tanto los mensajes del servidor como los de la caché local
          _loadMessages();
        }
      }
    });
  }

  void _getCurrentUsername() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUsername = user.displayName;
    }
  }

  Future<void> _loadMessages() async {
    // Mantenemos el estado de loading solo en la primera carga
    if (_messages.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final messages = await _chatService.getConversation(widget.username);

      // Solo actualizamos el estado si hay cambios en los mensajes
      if (_messages.length != messages.length ||
          (_messages.isNotEmpty &&
              messages.isNotEmpty &&
              _messages.last.timestamp != messages.last.timestamp)) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // Scroll to bottom after messages load
        _scrollToBottom();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NotificationService.showError(
          context,
          'Error al cargar los mensajes: ${e.toString()}',
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Enviar el mensaje usando el WebSocket a través del ChatService
      final success = await _chatService.sendMessage(widget.username, message);

      if (success) {
        _messageController.clear();
        _loadMessages(); // Recargar mensajes para mostrar el mensaje enviado
      } else {
        if (mounted) {
          NotificationService.showError(
            context,
            'Error al enviar el mensaje. Inténtalo de nuevo.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Error al enviar el mensaje: ${e.toString()}',
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      // Today, show only time
      return DateFormat.Hm().format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Ayer, ${DateFormat.Hm().format(timestamp)}';
    } else {
      // Other dates, show full date and time
      return DateFormat.yMMMd('es').add_Hm().format(timestamp);
    }
  }

  @override
  void dispose() {
    // Cancelar la suscripción al WebSocket
    _chatSubscription?.cancel();

    // Desconectar del WebSocket de chat cuando se sale de la página
    _chatService.disconnectFromChat();

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.username), elevation: 1),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? const Center(
                      child: Text(
                        'No hay mensajes. ¡Envía el primero!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderUsername == _currentUsername;

                        return _buildMessageBubble(message, isMe);
                      },
                    ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Color(0xFFEEEEEE),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child:
                          _isSending
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white.withOpacity(0.8) : Colors.black54,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}
