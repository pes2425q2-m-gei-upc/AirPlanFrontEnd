import 'dart:async';
import 'package:flutter/material.dart';
import 'package:airplan/services/chat_service.dart';
import 'package:airplan/services/chat_websocket_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/user_services.dart';
import 'package:airplan/chat_detail_page.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/auth_service.dart'; // Importar AuthService
import 'package:intl/intl.dart';

class ChatListPage extends StatefulWidget {
  // Inyectamos los servicios para facilitar pruebas
  final ChatService? chatService;
  final ChatWebSocketService? chatWebSocketService;
  final AuthService? authService;

  const ChatListPage({
    super.key,
    this.chatService,
    this.chatWebSocketService,
    this.authService,
  });

  @override
  ChatListPageState createState() => ChatListPageState();
}

class ChatListPageState extends State<ChatListPage> {
  late final ChatService _chatService;
  late final ChatWebSocketService _chatWebSocketService;
  // Se elimina el campo _authService ya que no se está utilizando
  final NotificationService _notificationService = NotificationService();
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  bool _isLoading = true;
  final Map<String, String> _userNames = {};
  Timer? _refreshTimer;
  StreamSubscription? _chatMessageSubscription;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Inicializar servicios con inyección de dependencias o valores por defecto
    _chatService = widget.chatService ?? ChatService();
    _chatWebSocketService =
        widget.chatWebSocketService ?? ChatWebSocketService();
    // Se elimina la inicialización de _authService

    _loadChats();
    _setupMessageListener();

    // Configurar un timer para actualizar periódicamente la lista
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _loadChats();
      }
    });

    // Listener para el campo de búsqueda
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _chatMessageSubscription?.cancel();
    _searchController.removeListener(_filterChats);
    _searchController.dispose();
    super.dispose();
  }

  // Filtrar chats basado en el texto de búsqueda
  void _filterChats() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredChats = List.from(_chats);
      } else {
        _filteredChats =
            _chats.where((chat) {
              final displayName =
                  _getUserDisplayName(chat.otherUsername).toLowerCase();
              final username = chat.otherUsername.toLowerCase();
              return displayName.startsWith(query) ||
                  username.startsWith(query);
            }).toList();
      }
    });
  }

  // Configurar escucha de nuevos mensajes
  void _setupMessageListener() {
    _chatMessageSubscription = _chatWebSocketService.chatMessages.listen((
      messageData,
    ) {
      // Cuando llega un mensaje nuevo, actualizamos la lista de chats
      if (messageData.containsKey('usernameSender') &&
          messageData.containsKey('usernameReceiver')) {
        // Retraso pequeño para asegurar que el mensaje se guardó
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _loadChats();
          }
        });
      }
    });
  }

  // Cargar los chats del usuario
  Future<void> _loadChats() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final chats = await _chatService.getAllChats();

      // Ordenar chats por fecha del último mensaje (más reciente primero)
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      // Cargar los nombres reales de los usuarios
      await _loadUserNames(chats);

      if (mounted) {
        setState(() {
          _chats = chats;
          _filteredChats = List.from(chats); // Inicializar la lista filtrada
          _isLoading = false;
        });

        // Aplicar filtro actual si existe
        if (_searchController.text.isNotEmpty) {
          _filterChats();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _notificationService.showError(
          context,
          'Error al cargar los chats: ${e.toString()}',
        );
      }
    }
  }

  // Cargar nombres reales de los usuarios
  Future<void> _loadUserNames(List<Chat> chats) async {
    for (final chat in chats) {
      if (!_userNames.containsKey(chat.otherUsername)) {
        try {
          final name = await UserService.getUserRealName(chat.otherUsername);
          if (mounted) {
            _userNames[chat.otherUsername] = name;
          }
        } catch (e) {
          // Si no se puede obtener el nombre, usar el nombre de usuario
          _userNames[chat.otherUsername] = chat.otherUsername;
        }
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

  // Obtener nombre real o username como alternativa
  String _getUserDisplayName(String username) {
    return _userNames[username] ?? username;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                        : null,
              ),
            ),
          ),
          // Lista de chats
          Expanded(child: _buildChatsList()),
        ],
      ),
    );
  }

  Widget _buildChatsList() {
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

    if (_filteredChats.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No hay chats que coincidan con "${_searchController.text}"',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.builder(
        itemCount: _filteredChats.length,
        itemBuilder: (context, index) {
          final chat = _filteredChats[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor:
                    chat.isRead
                        ? Colors.blue.shade700
                        : Theme.of(context).primaryColor,
                // Usar la imagen de perfil si está disponible, de lo contrario mostrar la inicial
                backgroundImage:
                    chat.photoURL != null && chat.photoURL!.isNotEmpty
                        ? (chat.photoURL!.startsWith('http')
                            ? NetworkImage(
                              chat.photoURL!,
                            ) // URL completa (Cloudinary)
                            : NetworkImage(
                              ApiConfig().buildUrl(chat.photoURL!),
                            )) // URL relativa (backend)
                        : null,
                child:
                    chat.photoURL != null && chat.photoURL!.isNotEmpty
                        ? null // No mostrar texto si hay imagen
                        : Text(
                          _getUserDisplayName(
                            chat.otherUsername,
                          )[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
              title: Text(
                _getUserDisplayName(chat.otherUsername),
                style: TextStyle(
                  fontWeight: chat.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: chat.isRead ? Colors.grey.shade700 : Colors.black87,
                    fontWeight:
                        chat.isRead ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(chat.lastMessageTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: chat.isRead ? Colors.grey.shade600 : Colors.blue,
                      fontWeight:
                          chat.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Removido el indicador "1" y reemplazado por un círculo más sutil cuando hay mensajes no leídos
                  if (!chat.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ChatDetailPage(
                          username:
                              chat.otherUsername, // Use username for backend calls
                          name: _getUserDisplayName(
                            chat.otherUsername,
                          ), // Use real name for display
                        ),
                  ),
                ).then((_) => _loadChats());
              },
            ),
          );
        },
      ),
    );
  }
}
