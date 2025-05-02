import 'package:flutter/material.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:airplan/services/user_block_service.dart';

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
    print('💬 Mensaje recibido: $messageData');

    // Procesar por tipo de mensaje
    if (messageData.containsKey('type')) {
      final messageType = messageData['type'];

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
          print('🔒 El otro usuario ($blocker) te ha bloqueado.');
        }
        // Si el bloqueador somos nosotros, entonces estamos bloqueando al otro
        else if (blocker == _currentUsername) {
          _currentUserBlockedOther = true;
          print('🔒 Has bloqueado al otro usuario (${widget.username}).');
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

    print(
      '🔒 Notificación de bloqueo procesada: currentBlockedOther: $_currentUserBlockedOther, otherBlockedCurrent: $_otherUserBlockedCurrent',
    );
  }

  void _handleUnblockNotification(Map<String, dynamic> data) {
    // El servidor puede enviar 'unblockerUsername' o 'blockerUsername' para la misma acción
    final unblocker = data['unblockerUsername'] ?? data['blockerUsername'];
    final unblocked = data['unblockedUsername']; // Puede ser null

    print(
      '🔍 Procesando desbloqueo - unblocker: $unblocker, unblocked: $unblocked, currentUsername: $_currentUsername, otherUsername: ${widget.username}',
    );

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
        print(
          '🔓 CASO 1: El otro usuario (${widget.username}) te ha desbloqueado',
        );
      }
      // Caso 2: Nosotros hemos desbloqueado al otro usuario (partner)
      else if (unblocker == _currentUsername &&
          (widget.username == unblocked || unblocked == null)) {
        shouldUpdate = true;
        shouldUpdateCurrentUserBlockedOther = true;
        print(
          '🔓 CASO 2: Tú has desbloqueado al otro usuario (${widget.username})',
        );
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

          print(
            '🔄 Estado actualizado: currentUserBlockedOther: $_currentUserBlockedOther, otherUserBlockedCurrent: $_otherUserBlockedCurrent',
          );
        });
      }
    }

    print(
      '🔓 Notificación de desbloqueo procesada: currentBlockedOther: $_currentUserBlockedOther, otherBlockedCurrent: $_otherUserBlockedCurrent',
    );
  }

  void _processMessageHistory(Map<String, dynamic> data) {
    // Procesar mensajes del historial
    if (data.containsKey('messages') && data['messages'] is List) {
      final List<dynamic> historyMessages = data['messages'];
      print('📚 Recibidos ${historyMessages.length} mensajes de historial');

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

  void _processRegularMessage(Map<String, dynamic> data) {
    if (!data.containsKey('usernameSender') ||
        !data.containsKey('usernameReceiver') ||
        !data.containsKey('missatge')) {
      return;
    }

    final sender = data['usernameSender'];
    final receiver = data['usernameReceiver'];

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

  void _updateBlockStatus(Map<String, dynamic> blockStatus) {
    print('🔍 Procesando blockStatus: $blockStatus');

    final String user1 = blockStatus['user1'] ?? '';
    final String user2 = blockStatus['user2'] ?? '';
    final bool user1BlockedUser2 = blockStatus['user1BlockedUser2'] ?? false;
    final bool user2BlockedUser1 = blockStatus['user2BlockedUser1'] ?? false;

    if (user1.isEmpty || user2.isEmpty) {
      print("⚠️ Advertencia: blockStatus sin nombres de usuario");

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
          print("🛑 Error: Los nombres de usuario no coinciden");
          if (_isLoading) {
            _currentUserBlockedOther = false;
            _otherUserBlockedCurrent = false;
          }
        }

        if (_isLoading) _isLoading = false;
      });
    }

    print(
      '🔐 Estado de bloqueo: currentUserBlockedOther: $_currentUserBlockedOther, otherUserBlockedCurrent: $_otherUserBlockedCurrent',
    );
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
      final success = await _chatService.sendMessage(widget.username, message);

      if (success && mounted) {
        final newMessage = Message(
          senderUsername: _currentUsername!,
          receiverUsername: widget.username,
          content: message,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(newMessage);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _messageController.clear();
        });

        _scrollToBottom();
      } else if (mounted) {
        NotificationService.showError(
          context,
          'Error al enviar el mensaje. Inténtalo de nuevo.',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
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
        widget.name ?? widget.username,
      ), // Use name if available, otherwise username
      elevation: 1,
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuItemClick,
          itemBuilder:
              (BuildContext context) => [
                if (_currentUserBlockedOther)
                  const PopupMenuItem<String>(
                    value: 'unblock',
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Prevent overflow
                      children: [
                        Icon(Icons.lock_open, color: Colors.green),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Desbloquear usuario',
                            style: TextStyle(color: Colors.green),
                            overflow:
                                TextOverflow.ellipsis, // Handle text overflow
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem<String>(
                    value: 'block',
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Prevent overflow
                      children: [
                        Icon(Icons.block, color: Colors.red),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Bloquear usuario',
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
      color: Colors.red.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.block, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat bloqueado',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentUserBlockedOther
                      ? 'Has bloqueado a este usuario.'
                      : 'Este usuario te ha bloqueado.',
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
                color: isMe ? Colors.white.withAlpha(204) : Colors.black54,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ],
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
            title: Text('Bloquear a ${widget.username}'),
            content: const Text(
              'Si bloqueas a este usuario, no podrás recibir ni enviarle mensajes. ¿Estás seguro?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Bloquear'),
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
      NotificationService.showError(
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

          NotificationService.showSuccess(
            context,
            'Has bloqueado a ${widget.username}',
          );
        } else {
          NotificationService.showError(
            context,
            'No se pudo bloquear al usuario. Inténtalo de nuevo más tarde.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        NotificationService.showError(
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
            title: Text('Desbloquear a ${widget.username}'),
            content: const Text(
              'Si desbloqueas a este usuario, podrás volver a enviar y recibir mensajes. ¿Estás seguro?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: const Text('Desbloquear'),
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
      NotificationService.showError(
        context,
        'No se pudo identificar tu usuario. Por favor, inicia sesión nuevamente.',
      );
      return;
    }

    _showProgressSnackbar('Desbloqueando usuario...');
    print(
      '🔓 INICIO DEL PROCESO DE DESBLOQUEO: Tu usuario (${user.displayName}) va a desbloquear a ${widget.username}',
    );

    try {
      // Usar UserBlockService que ahora envía directamente por WebSocket
      final result = await _userBlockService.unblockUser(
        user.displayName!,
        widget.username,
      );
      print('🔓 Respuesta del desbloqueo: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (result) {
          // Actualizar el estado local
          setState(() => _currentUserBlockedOther = false);

          // Ya no es necesario enviar otra notificación por WebSocket aquí
          // porque UserBlockService ya lo hizo internamente

          NotificationService.showSuccess(
            context,
            'Has desbloqueado a ${widget.username}',
          );
        } else {
          NotificationService.showError(
            context,
            'No se pudo desbloquear al usuario. Inténtalo de nuevo más tarde.',
          );
        }
      }
    } catch (e) {
      print('❌ ERROR durante el proceso de desbloqueo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        NotificationService.showError(
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
