import 'package:flutter/material.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/notification_service.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUsername;
  StreamSubscription<Message>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentUsername();
    _loadMessages();

    // Inicializar el servicio de chat para WebSockets
    _chatService.initialize();

    // Suscribirse al stream de mensajes
    _messageSubscription = _chatService.messageStream.listen(_handleNewMessage);
  }

  void _getCurrentUsername() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUsername = user.displayName;
    }
  }

  // Manejar los mensajes nuevos recibidos por WebSocket
  void _handleNewMessage(Message message) {
    // Solo procesamos mensajes relevantes para esta conversación
    if ((message.senderUsername == _currentUsername &&
            message.receiverUsername == widget.username) ||
        (message.receiverUsername == _currentUsername &&
            message.senderUsername == widget.username)) {
      setState(() {
        // Añadir el mensaje y ordenar por tiempo
        _messages.add(message);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });

      // Desplazar al último mensaje
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await _chatService.getConversation(widget.username);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Scroll to bottom after messages load
      _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final success = await _chatService.sendMessage(widget.username, message);

      if (success) {
        _messageController.clear();
        // No necesitamos recargar todos los mensajes ya que el WebSocket nos enviará el mensaje
        // El backend ya retornará el mensaje a través de WebSocket
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
      return 'Ayer ${DateFormat.Hm().format(timestamp)}';
    } else if (now.difference(messageDate).inDays < 7) {
      // Within a week, show day name and time
      return '${DateFormat.E('es').format(timestamp)} ${DateFormat.Hm().format(timestamp)}';
    } else {
      // Older, show date and time
      return DateFormat.yMMMd('es').add_Hm().format(timestamp);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
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
                        'No hay mensajes. Envía uno para comenzar a chatear.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      padding: const EdgeInsets.all(12),
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
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
