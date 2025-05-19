import 'package:flutter/material.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:airplan/services/user_block_service.dart';
import 'package:easy_localization/easy_localization.dart';

class ChatDetailPage extends StatefulWidget {
  final String username; // Used for backend calls
  final String? name; // Used for UI display
  final AuthService? authService; // Inyección de servicio de autenticación
  final ChatService? chatService; // Inyección de servicio de chat
  final ChatWebSocketService?
  webSocketService; // Inyección de servicio WebSocket
  final UserBlockService? userBlockService; // Inyección de servicio de bloqueo

  const ChatDetailPage({
    super.key,
    required this.username,
    this.name,
    this.authService,
    this.chatService,
    this.webSocketService,
    this.userBlockService,
  });

  @override
  ChatDetailPageState createState() => ChatDetailPageState();
}

class ChatDetailPageState extends State<ChatDetailPage> {
  late final ChatService _chatService;
  late final ChatWebSocketService _chatWebSocketService;
  late final UserBlockService _userBlockService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AuthService _authService;
  final NotificationService _notificationService = NotificationService();
  List<Message> _messages = [];
  String? _currentUsername;

  // Estados de carga y bloqueo
  bool _isLoading = true;
  bool _isSending = false;
  bool _isInitializing = true;
  bool _currentUserBlockedOther = false;
  bool _otherUserBlockedCurrent = false;

  // Suscripción a mensajes de WebSocket
  StreamSubscription? _chatSubscription;

  // Getter para determinar si el chat está bloqueado
  bool get _isChatBlocked =>
      _currentUserBlockedOther || _otherUserBlockedCurrent;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _chatService = widget.chatService ?? ChatService();
    _chatWebSocketService = widget.webSocketService ?? ChatWebSocketService();
    _userBlockService = widget.userBlockService ?? UserBlockService();
    _initializeChat();
  }

  // Método combinado para inicializar el chat
  Future<void> _initializeChat() async {
    _getCurrentUsername();
    _setupWebSocketListener();
    _connectToChat();
  }

  void _connectToChat() {
    if (_currentUsername != null) {
      _chatWebSocketService.connectToChat(widget.username);
      setState(() => _isInitializing = false);
    } else {
      // Intentar de nuevo después de un breve retraso
      Future.delayed(const Duration(milliseconds: 300), () {
        _getCurrentUsername();
        _connectToChat();
      });
    }
  }

  void _setupWebSocketListener() {
    _chatSubscription = _chatWebSocketService.chatMessages.listen(
      _handleIncomingMessage,
    );
  }

  // Método para manejar mensajes entrantes - separado para mayor legibilidad
  void _handleIncomingMessage(dynamic messageData) {
    if (!mounted) return;

    // Log para debug

    // Procesar por tipo de mensaje
    if (messageData.containsKey('type')) {
      final messageType = messageData['type'];

      if (messageType == 'DELETE') {
        final sender = messageData['usernameSender'];
        final originalTimestamp = messageData['originalTimestamp'];

        setState(() {
          _messages.removeWhere(
            (message) =>
                message.senderUsername == sender &&
                message.timestamp.toIso8601String() == originalTimestamp,
          );
        });
        return;
      }

      // Manejar actualizaciones de estado de bloqueo
      if (messageType == 'blockStatusUpdate' &&
          messageData.containsKey('blockStatus')) {
        _updateBlockStatus(messageData['blockStatus']);
        return;
      }

      // Manejar notificaciones de bloqueo
      if (messageType == 'BLOCK_NOTIFICATION') {
        _handleBlockNotification(messageData);
        return;
      }

      // Manejar notificaciones de desbloqueo
      if (messageType == 'UNBLOCK_NOTIFICATION') {
        _handleUnblockNotification(messageData);
        return;
      }

      // Manejar historial de mensajes
      if (messageType == 'history') {
        _processMessageHistory(messageData);
        return;
      }
      if (messageData.containsKey('type') && messageData['type'] == 'EDIT') {
        final sender = messageData['usernameSender'];
        final originalTimestamp = messageData['originalTimestamp'];
        final newContent = messageData['newContent'];

        // Solo actualizar el mensaje si todos los campos necesarios están presentes
        if (sender != null && originalTimestamp != null && newContent != null) {
          setState(() {
            for (int i = 0; i < _messages.length; i++) {
              // Compare the timestamp strings to avoid precision issues
              if (_messages[i].senderUsername == sender &&
                  _messages[i].timestamp.toIso8601String() ==
                      originalTimestamp) {
                _messages[i] = Message(
                  senderUsername: _messages[i].senderUsername,
                  receiverUsername: _messages[i].receiverUsername,
                  timestamp: _messages[i].timestamp,
                  content: newContent,
                  isEdited: true,
                );
                break;
              }
            }
          });
        }
        return;
      } // Manejar mensajes de error
      if (messageType == 'ERROR' && messageData.containsKey('message')) {
        if (mounted) {
          final errorMessage = messageData['message'] as String;

          // Verificar si es un error relacionado con edición de mensaje
          final isEditError =
              errorMessage.contains("edita") ||
              errorMessage.contains("edit") ||
              errorMessage.contains("El contenido editado");

          // Borrar el último mensaje si NO es un error de edición
          if (_messages.isNotEmpty &&
              _messages.last.senderUsername == _currentUsername &&
              !isEditError) {
            setState(() {
              _messages.removeLast();
            });
            // After removal, scroll to bottom to update view
            _scrollToBottom();
          }
          _notificationService.showError(context, errorMessage);
        }
        return;
      }
    }

    // Procesar mensajes normales
    _processRegularMessage(messageData);
  }

  // Métodos auxiliares para procesar diferentes tipos de mensajes
  void _handleBlockNotification(Map<String, dynamic> data) {
    final blocker = data['blockerUsername'];
    final blocked = data['blockedUsername']; // Puede ser null

    // Si solo recibimos el bloqueador pero no el bloqueado
    if (blocker != null && mounted) {
      setState(() {
        // Si el bloqueador es el otro usuario, entonces nos está bloqueando a nosotros
        if (blocker == widget.username) {
          _otherUserBlockedCurrent = true;
        }
        // Si el bloqueador somos nosotros, entonces estamos bloqueando al otro
        else if (blocker == _currentUsername) {
          _currentUserBlockedOther = true;
        }

        // Procesar también con la información completa si está disponible
        if (blocked != null) {
          if (blocker == _currentUsername && blocked == widget.username) {
            _currentUserBlockedOther = true;
          } else if (blocker == widget.username &&
              blocked == _currentUsername) {
            _otherUserBlockedCurrent = true;
          }
        }
      });
    }
  }

  void _handleUnblockNotification(Map<String, dynamic> data) {
    // El servidor puede enviar 'unblockerUsername' o 'blockerUsername' para la misma acción
    final unblocker = data['unblockerUsername'] ?? data['blockerUsername'];
    final unblocked = data['unblockedUsername']; // Puede ser null

    // Si tenemos al menos el usuario que desbloquea
    if (unblocker != null && mounted) {
      // Comprobar si estamos en un chat con el usuario que ha hecho el desbloqueo
      bool shouldUpdate = false;
      bool shouldUpdateCurrentUserBlockedOther = false;
      bool shouldUpdateOtherUserBlockedCurrent = false;

      // Caso 1: El otro usuario (partner) nos ha desbloqueado a nosotros
      if (unblocker == widget.username &&
          (_currentUsername == unblocked || unblocked == null)) {
        shouldUpdate = true;
        shouldUpdateOtherUserBlockedCurrent = true;
      }
      // Caso 2: Nosotros hemos desbloqueado al otro usuario (partner)
      else if (unblocker == _currentUsername &&
          (widget.username == unblocked || unblocked == null)) {
        shouldUpdate = true;
        shouldUpdateCurrentUserBlockedOther = true;
      }

      // Actualizar estado si es necesario
      if (shouldUpdate) {
        setState(() {
          if (shouldUpdateOtherUserBlockedCurrent) {
            _otherUserBlockedCurrent = false;
          }
          if (shouldUpdateCurrentUserBlockedOther) {
            _currentUserBlockedOther = false;
          }
        });
      }
    }
  }

  void _processRegularMessage(Map<String, dynamic> data) {
    if (!data.containsKey('usernameSender') ||
        !data.containsKey('usernameReceiver') ||
        !data.containsKey('missatge')) {
      return;
    }

    final sender = data['usernameSender'];
    final receiver = data['usernameReceiver'];

    // Evitar duplicados: si ya existe un mensaje con mismo remitente y timestamp
    if (data.containsKey('dataEnviament')) {
      final ts = data['dataEnviament'] as String;
      if (_messages.any(
        (m) =>
            m.senderUsername == sender && m.timestamp.toIso8601String() == ts,
      )) {
        return;
      }
    }

    // Solo procesar mensajes de esta conversación
    if ((sender == _currentUsername && receiver == widget.username) ||
        (sender == widget.username && receiver == _currentUsername)) {
      final newMessage = Message(
        senderUsername: data['usernameSender'],
        receiverUsername: data['usernameReceiver'],
        content: data['missatge'],
        timestamp:
            data.containsKey('dataEnviament')
                ? DateTime.parse(data['dataEnviament'])
                : DateTime.now(),
        isEdited: data['isEdited'] ?? false,
      );

      if (mounted) {
        setState(() {
          if (_isLoading) _isLoading = false;
          _messages.add(newMessage);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      }

      _scrollToBottom();
    }
  }

  void _processMessageHistory(Map<String, dynamic> data) {
    // Procesar mensajes del historial
    if (data.containsKey('messages') && data['messages'] is List) {
      final List<dynamic> historyMessages = data['messages'];

      if (mounted) {
        setState(() {
          _messages =
              historyMessages
                  .map(
                    (msg) => Message(
                      senderUsername: msg['usernameSender'],
                      receiverUsername: msg['usernameReceiver'],
                      content: msg['missatge'],
                      timestamp: DateTime.parse(msg['dataEnviament']),
                      isEdited: msg['isEdited'] ?? false,
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

          _isLoading = false;
        });
      }

      _scrollToBottom();
    }

    // Procesar información de bloqueo inicial
    if (data.containsKey('blockStatus')) {
      _updateBlockStatus(data['blockStatus']);
    } else if (_isLoading && mounted) {
      setState(() {
        _currentUserBlockedOther = false;
        _otherUserBlockedCurrent = false;
        _isLoading = false;
      });
    }
  }

  void _updateBlockStatus(Map<String, dynamic> blockStatus) {
    final String user1 = blockStatus['user1'] ?? '';
    final String user2 = blockStatus['user2'] ?? '';
    final bool user1BlockedUser2 = blockStatus['user1BlockedUser2'] ?? false;
    final bool user2BlockedUser1 = blockStatus['user2BlockedUser1'] ?? false;

    if (user1.isEmpty || user2.isEmpty) {
      if (_currentUsername != null) {
        // Fallback menos fiable
        setState(() {
          _currentUserBlockedOther = user1BlockedUser2;
          _otherUserBlockedCurrent = user2BlockedUser1;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        if (_currentUsername == user1) {
          _currentUserBlockedOther = user1BlockedUser2;
          _otherUserBlockedCurrent = user2BlockedUser1;
        } else if (_currentUsername == user2) {
          _currentUserBlockedOther = user2BlockedUser1;
          _otherUserBlockedCurrent = user1BlockedUser2;
        } else {
          if (_isLoading) {
            _currentUserBlockedOther = false;
            _otherUserBlockedCurrent = false;
          }
        }

        if (_isLoading) _isLoading = false;
      });
    }
  }

  void _getCurrentUsername() {
    final user = _authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _currentUsername = user.displayName);
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

    setState(() => _isSending = true);

    try {
      DateTime now = DateTime.now();
      DateTime timestamp = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
        3, // Exactly 3 milliseconds
      );
      // Optimistic UI: insert message locally
      final newMessage = Message(
        senderUsername: _currentUsername!,
        receiverUsername: widget.username,
        content: message,
        timestamp: timestamp,
        isEdited: false,
      );
      setState(() {
        _messages.add(newMessage);
        // ...messages assumed already in chronological order, no sort needed
      });
      _scrollToBottom();

      // Send via WebSocket
      final success = await _chatService.sendMessage(
        widget.username,
        message,
        timestamp,
      );

      if (success && mounted) {
        _messageController.clear();
      } else if (mounted) {
        _notificationService.showError(
          context,
          'Error al enviar el mensaje. Inténtalo de nuevo.',
        );
      }
    } catch (e) {
      if (mounted) {
        _notificationService.showError(
          context,
          'Error al enviar el mensaje: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
      return DateFormat.Hm().format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Ayer, ${DateFormat.Hm().format(timestamp)}';
    } else {
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
      builder:
          (context) => AlertDialog(
            title: const Text('Editar mensaje'),
            content: SizedBox(
              width: 250, // Ajusta el ancho del campo de texto
              child: TextField(
                controller: editingController,
                decoration: const InputDecoration(
                  hintText: 'Edita tu mensaje...',
                ),
                autofocus: true,
                maxLines: null,
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween, // Alinear a la izquierda y derecha
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showDeleteConfirmationDialog(message);
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Eliminar mensaje',
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _updateMessage(
                            message,
                            editingController.text.trim(),
                          );
                        },
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmationDialog(Message message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar mensaje'),
            content: const Text(
              '¿Estás seguro de que deseas eliminar este mensaje?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteMessage(message);
                },
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _deleteMessage(Message message) {
    _chatService.deleteMessage(
      message.receiverUsername,
      message.timestamp.toIso8601String(),
    );
  }

  Future<void> _updateMessage(Message message, String newContent) async {
    if (newContent.isEmpty || newContent == message.content) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Send the edited message through the ChatService
      // No actualizamos el mensaje localmente, esperamos a que el servidor
      // confirme la edición a través de un mensaje WebSocket de tipo EDIT
      final success = await _chatService.editMessage(
        widget.username,
        message.timestamp.toIso8601String(),
        newContent,
      );

      if (!success && mounted) {
        _notificationService.showError(
          context,
          'Error al editar el mensaje. Inténtalo de nuevo.',
        );
      }
      // Ya no actualizamos el mensaje aquí, el servidor enviará un mensaje WebSocket
      // con la confirmación y se actualizará en el método handleIncomingMessage
    } catch (e) {
      if (mounted) {
        _notificationService.showError(
          context,
          'Error al editar el mensaje: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _chatService.disconnectFromChat();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isChatBlocked) _buildBlockBanner(),
          Expanded(child: _buildMessageList()),
          if (!_isChatBlocked) _buildMessageInput(),
        ],
      ),
    );
  }

  // Métodos de construcción de UI separados para mejorar la legibilidad
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.name != null ? widget.name! : widget.username,
      ), // Use name if available, otherwise username
      elevation: 1,
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuItemClick,
          itemBuilder:
              (BuildContext context) => [
                if (_currentUserBlockedOther)
                  PopupMenuItem<String>(
                    value: 'unblock',
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Prevent overflow
                      children: [
                        Icon(Icons.lock_open, color: Colors.green),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'chat_unblock_user'.tr(),
                            style: TextStyle(color: Colors.green),
                            overflow:
                                TextOverflow.ellipsis, // Handle text overflow
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Prevent overflow
                      children: [
                        Icon(Icons.block, color: Colors.red),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'chat_block_user'.tr(),
                            style: TextStyle(color: Colors.red),
                            overflow:
                                TextOverflow.ellipsis, // Handle text overflow
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
        ),
      ],
    );
  }

  Widget _buildBlockBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Colors.red.withAlpha(
        25,
      ), // Reemplazado withOpacity(0.1) por withAlpha(25)
      child: Row(
        children: [
          const Icon(Icons.block, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'chat_blocked'.tr(),
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentUserBlockedOther
                      ? 'chat_blocked_message'.tr()
                      : 'chat_blocked_by_other'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isInitializing || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No hay mensajes en esta conversación.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderUsername == _currentUsername;
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'chat_message_placeholder'.tr(),
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
                        : Text(
                          'chat_send'.tr(),
                          style: TextStyle(color: Colors.white),
                        ),
              ),
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
        onLongPress:
            isMe && _isMessageEditable(message)
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
                      color:
                          isMe
                              ? Colors.white70
                              : Colors
                                  .black54, // Reemplazado withAlpha(204) por Colors.white70
                      fontSize: 12,
                    ),
                  ),
                  if (message.isEdited)
                    Text(
                      " · Editado",
                      style: TextStyle(
                        color:
                            isMe ? Colors.white.withAlpha(204) : Colors.black54,
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

  void _handleMenuItemClick(String value) {
    switch (value) {
      case 'block':
        _showBlockUserDialog();
        break;
      case 'unblock':
        _showUnblockUserDialog();
        break;
    }
  }

  Future<void> _showBlockUserDialog() async {
    final confirmResult = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('chat_confirm_block_title'.tr()),
            content: Text('chat_confirm_block_message'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('chat_block_user'.tr()),
              ),
            ],
          ),
    );

    if (confirmResult == true) {
      await _blockUser();
    }
  }

  Future<void> _blockUser() async {
    final user = _authService.getCurrentUser();

    if (user == null || user.displayName == null) {
      _notificationService.showError(
        context,
        'No se pudo identificar tu usuario. Por favor, inicia sesión nuevamente.',
      );
      return;
    }

    _showProgressSnackbar('Bloqueando usuario...');

    try {
      // Usar UserBlockService que ahora envía directamente por WebSocket
      final result = await _userBlockService.blockUser(
        user.displayName!,
        widget.username,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (result) {
          // Actualizar el estado local
          setState(() => _currentUserBlockedOther = true);

          // Ya no es necesario enviar otra notificación por WebSocket aquí
          // porque UserBlockService ya lo hizo internamente

          _notificationService.showSuccess(
            context,
            'Has bloqueado a ${widget.username}',
          );
        } else {
          _notificationService.showError(
            context,
            'No se pudo bloquear al usuario. Inténtalo de nuevo más tarde.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _notificationService.showError(
          context,
          'Error al bloquear usuario: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _showUnblockUserDialog() async {
    final confirmResult = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('chat_confirm_unblock_title'.tr()),
            content: Text('chat_confirm_unblock_message'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: Text('chat_unblock_user'.tr()),
              ),
            ],
          ),
    );

    if (confirmResult == true) {
      await _unblockUser();
    }
  }

  Future<void> _unblockUser() async {
    final user = _authService.getCurrentUser();

    if (user == null || user.displayName == null) {
      _notificationService.showError(
        context,
        'No se pudo identificar tu usuario. Por favor, inicia sesión nuevamente.',
      );
      return;
    }

    _showProgressSnackbar('Desbloqueando usuario...');

    try {
      // Usar UserBlockService que ahora envía directamente por WebSocket
      final result = await _userBlockService.unblockUser(
        user.displayName!,
        widget.username,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (result) {
          // Actualizar el estado local
          setState(() => _currentUserBlockedOther = false);

          // Ya no es necesario enviar otra notificación por WebSocket aquí
          // porque UserBlockService ya lo hizo internamente

          _notificationService.showSuccess(
            context,
            'Has desbloqueado a ${widget.username}',
          );
        } else {
          _notificationService.showError(
            context,
            'No se pudo desbloquear al usuario. Inténtalo de nuevo más tarde.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _notificationService.showError(
          context,
          'Error al desbloquear usuario: ${e.toString()}',
        );
      }
    }
  }

  // Helper para mostrar un SnackBar de progreso
  void _showProgressSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }
}
