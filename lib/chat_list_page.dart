import 'package:flutter/material.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/chat_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  ChatListPageState createState() => ChatListPageState();
}

class ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  List<Chat> _chats = [];
  bool _isLoading = true;
  StreamSubscription<Message>? _messageSubscription;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _getCurrentUsername();
    _loadChats();

    // Inicializar el servicio de chat para WebSockets
    _chatService.initialize();

    // Suscribirse al stream de mensajes para actualizar la lista de chats en tiempo real
    _messageSubscription = _chatService.messageStream.listen(_handleNewMessage);
  }

  void _getCurrentUsername() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUsername = user.displayName;
    }
  }

  // Manejar mensajes nuevos para actualizar la lista de chats
  void _handleNewMessage(Message message) {
    if (_currentUsername == null) return;

    // Verificar si el mensaje es relevante para este usuario
    if (message.senderUsername == _currentUsername ||
        message.receiverUsername == _currentUsername) {
      // Recargar la lista de chats para incluir el nuevo mensaje
      _loadChats();
    }
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chats = await _chatService.getAllChats();
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NotificationService.showError(
          context,
          'Error al cargar los chats: ${e.toString()}',
        );
      }
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
      return 'Ayer';
    } else if (now.difference(messageDate).inDays < 7) {
      // Within a week, show day name
      return DateFormat.E('es').format(timestamp);
    } else {
      // Older, show date
      return DateFormat.yMMMd('es').format(timestamp);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tienes ninguna conversación',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando envíes un mensaje a alguien, aparecerá aquí.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadChats(),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(chat.otherUsername[0].toUpperCase()),
            ),
            title: Text(chat.otherUsername),
            subtitle: Text(
              chat.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(chat.lastMessageTime),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                if (!chat.isRead)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ChatDetailPage(username: chat.otherUsername),
                ),
              ).then((_) => _loadChats());
            },
          );
        },
      ),
    );
  }
}
