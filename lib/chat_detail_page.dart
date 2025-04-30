import 'package:flutter/material.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatDetailPage extends StatefulWidget {
  final String username;

  const ChatDetailPage({super.key, required this.username});

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

      if (messageData.containsKey('type') && messageData['type'] == 'EDIT') {
        final sender = messageData['usernameSender'];
        final originalTimestamp = messageData['originalTimestamp'];
        final newContent = messageData['newContent'];

        setState(() {
          for (int i = 0; i < _messages.length; i++) {
            // Compare the timestamp strings to avoid precision issues
            if (_messages[i].senderUsername == sender &&
                _messages[i].timestamp.toIso8601String() == originalTimestamp) {
              _messages[i] = Message(
                  senderUsername: _messages[i].senderUsername,
                  receiverUsername: _messages[i].receiverUsername,
                  timestamp: _messages[i].timestamp,
                  content: newContent,
                  isEdited: true
              );
              break;
            }
          }
        });
        return;
      }

      if (messageData.containsKey('usernameSender') &&
          messageData.containsKey('usernameReceiver') &&
          messageData.containsKey('missatge')) {
        final sender = messageData['usernameSender'];
        final receiver = messageData['usernameReceiver'];

        // Solo procesamos mensajes que pertenecen a esta conversación
        if ((sender == _currentUsername && receiver == widget.username) ||
            (sender == widget.username && receiver == _currentUsername)) {
          // Crear un nuevo objeto Message directamente a partir de los datos recibidos
          final newMessage = Message(
            senderUsername: messageData['usernameSender'],
            receiverUsername: messageData['usernameReceiver'],
            content: messageData['missatge'],
            isEdited: messageData['isEdited'],
            // Si el mensaje tiene timestamp, lo usamos; de lo contrario, usamos la fecha actual
            timestamp:
                messageData.containsKey('dataEnviament')
                    ? DateTime.parse(messageData['dataEnviament'])
                    : DateTime.now(),
          );

          // Añadimos directamente el mensaje sin verificar duplicados,
          // permitiendo así mensajes con contenido idéntico consecutivos
          setState(() {
            _messages.add(newMessage);
            // Asegurarnos de que los mensajes están ordenados por fecha
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          });

          // Hacer scroll hacia el último mensaje
          _scrollToBottom();
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
      DateTime timestamp = DateTime.now();
      // Enviar el mensaje usando el WebSocket a través del ChatService
      final success = await _chatService.sendMessage(widget.username, message, timestamp);

      if (success) {
        // Crear un objeto Message localmente para añadirlo inmediatamente a la UI
        final newMessage = Message(
          senderUsername: _currentUsername!,
          receiverUsername: widget.username,
          content: message,
          timestamp: timestamp,
          isEdited: false,
        );

        print("Mensaje enviado: ${newMessage.content}, Enviado por: ${newMessage.senderUsername}, Recibido por: ${newMessage.receiverUsername}, Timestamp: ${newMessage.timestamp}, IsEdited: ${newMessage.isEdited}");

        setState(() {
          // Añadir el mensaje directamente a la lista local sin verificar duplicados
          _messages.add(newMessage);
          // Ordenar por fecha
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          // Limpiar el campo de texto
          _messageController.clear();
        });

        // Scroll al final para ver el nuevo mensaje
        _scrollToBottom();

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

  bool _isMessageEditable(Message message) {
    // Only allow editing of own messages that are less than 20 minutes old
    if (message.senderUsername != _currentUsername) return false;

    final now = DateTime.now();
    final differenceInMinutes = now.difference(message.timestamp).inMinutes;
    return differenceInMinutes < 20;
  }

  void _showEditDialog(Message message) {
    final editingController = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mensaje'),
        content: TextField(
          controller: editingController,
          decoration: const InputDecoration(
            hintText: 'Edita tu mensaje...',
          ),
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateMessage(message, editingController.text.trim());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMessage(Message message, String newContent) async {
    if (newContent.isEmpty || newContent == message.content) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Send the edited message through the ChatService
      final success = await _chatService.editMessage(
          widget.username,
          message.timestamp.toIso8601String(),
          newContent
      );

      if (success) {
        setState(() {
          // Update the message locally
          final index = _messages.indexWhere((m) =>
          m.senderUsername == message.senderUsername &&
              m.timestamp == message.timestamp);

          if (index != -1) {
            _messages[index] = Message(
              senderUsername: message.senderUsername,
              receiverUsername: message.receiverUsername,
              content: newContent,
              timestamp: message.timestamp,
              isEdited: true,
            );
          }
        });
      } else {
        if (mounted) {
          NotificationService.showError(
            context,
            'Error al editar el mensaje. Inténtalo de nuevo.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Error al editar el mensaje: ${e.toString()}',
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
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
                        // print ('Mensaje: ${message.content}, Enviado por: ${message.senderUsername}, Recibido por: ${message.receiverUsername}, Timestamp: ${message.timestamp}, IsEdited: ${message.isEdited}',);
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
      child: GestureDetector(
        onLongPress: isMe && _isMessageEditable(message)
            ? () => _showEditDialog(message)
            : null,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white.withAlpha(204) : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  if (message.isEdited)
                    Text(
                      " · Editado",
                      style: TextStyle(
                        color: isMe ? Colors.white.withAlpha(204) : Colors.black54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
