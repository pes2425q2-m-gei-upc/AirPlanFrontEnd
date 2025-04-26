import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:airplan/main.dart';
import 'api_config.dart';

/// Clase principal para gestionar la conexión WebSocket y distribuir mensajes
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  WebSocketChannel? _channel;

  // Controladores para diferentes tipos de mensajes
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _profileUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _accountDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Controller para todos los mensajes (para mantener compatibilidad)
  final StreamController<String> _allMessagesController =
      StreamController<String>.broadcast();

  bool _isConnected = false;
  String _currentUsername = '';
  String _currentEmail = '';
  String _clientId = '';
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  // Singleton factory
  factory WebSocketService() {
    return _instance;
  }

  // Streams específicos por tipo de mensaje
  Stream<Map<String, dynamic>> get chatMessages =>
      _chatMessageController.stream;
  Stream<Map<String, dynamic>> get profileUpdateEvents =>
      _profileUpdateController.stream;
  Stream<Map<String, dynamic>> get accountDeletedEvents =>
      _accountDeletedController.stream;

  // Stream de todos los mensajes (para compatibilidad con código existente)
  Stream<String> get profileUpdates => _allMessagesController.stream;

  WebSocketService._internal() {
    _initializeClientId();

    // Escuchar cambios de autenticación
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _updateUserCredentials(user);
      } else {
        disconnect();
      }
    });

    // Verificar si hay un usuario activo al iniciar
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _updateUserCredentials(user);
      connect();
    }
  }

  // Inicializar el ID de cliente único
  Future<void> _initializeClientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _clientId = prefs.getString('websocket_client_id') ?? '';

      if (_clientId.isEmpty) {
        _clientId = const Uuid().v4();
        await prefs.setString('websocket_client_id', _clientId);
      }
    } catch (e) {
      _clientId =
          'temp_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}';
    }
  }

  // Getter para el clientId
  String get clientId => _clientId;

  // Verificar si WebSocket está conectado
  bool get isConnected => _isConnected;

  // Actualiza credenciales del usuario y reconecta si es necesario
  void _updateUserCredentials(User user) {
    final newUsername = user.displayName ?? '';
    final newEmail = user.email ?? '';

    if (newUsername != _currentUsername || newEmail != _currentEmail) {
      _currentUsername = newUsername;
      _currentEmail = newEmail;

      if (_isConnected) {
        disconnect();
        connect();
      }
    }
  }

  // Conectar al servidor WebSocket
  void connect() {
    if (_isConnected && _channel != null) {
      return;
    }

    disconnect();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    _currentUsername = user.displayName ?? '';
    _currentEmail = user.email ?? '';

    if (_currentUsername.isEmpty || _currentEmail.isEmpty) {
      return;
    }

    try {
      final baseUrl = ApiConfig().baseUrl.replaceFirst('http://', 'ws://');

      _channel = WebSocketChannel.connect(
        Uri.parse(
          '$baseUrl/ws?username=$_currentUsername&email=$_currentEmail&clientId=$_clientId',
        ),
      );

      _isConnected = true;

      // Escuchar mensajes entrantes
      _channel!.stream.listen(
        (message) {
          _handleIncomingMessage(message.toString());
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _startPingTimer();
    } catch (e) {
      _isConnected = false;
      debugPrint('Error al conectar WebSocket: $e');
      _scheduleReconnect();
    }
  }

  // Iniciar timer para enviar pings periódicos
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('{"type":"PING"}');
        } catch (e) {
          _isConnected = false;
          _scheduleReconnect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Programar un intento de reconexión
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  // Manejar mensajes entrantes del WebSocket
  void _handleIncomingMessage(String message) {
    try {
      // Enviamos el mensaje crudo al stream general (compatibilidad)
      _allMessagesController.add(message);

      // No procesamos mensajes de ping/pong
      if (message.contains('"type":"PING"') ||
          message.contains('"type":"PONG"')) {
        return;
      }

      // Deserializar el mensaje
      final Map<String, dynamic> data = json.decode(message);

      // Distribuir el mensaje según su tipo
      final String type = data['type'] ?? '';

      switch (type) {
        case 'CHAT_MESSAGE':
          _chatMessageController.add(data);
          break;

        case 'PROFILE_UPDATE':
          _profileUpdateController.add(data);
          break;

        case 'ACCOUNT_DELETED':
          _accountDeletedController.add(data);
          _handleAccountDeletedMessage(data);
          break;

        default:
          // Para tipos desconocidos, no hacemos nada especial
          break;
      }
    } catch (e) {
      debugPrint('Error al procesar mensaje WebSocket: $e');
    }
  }

  // Manejar mensaje de cuenta eliminada
  void _handleAccountDeletedMessage(Map<String, dynamic> data) {
    try {
      final String email = data['email'] ?? '';
      final String username = data['username'] ?? '';

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          (currentUser.email == email || currentUser.displayName == username)) {
        _showAccountDeletedDialog();

        Future.delayed(const Duration(seconds: 2), () {
          _forceLogout();
        });
      }
    } catch (e) {
      // Ignorar errores
    }
  }

  // Mostrar diálogo de cuenta eliminada
  void _showAccountDeletedDialog() {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      final safeContext = context;

      showDialog(
        context: safeContext,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Cuenta eliminada'),
            content: const Text(
              'Tu cuenta ha sido eliminada desde otro dispositivo. '
              'Esta sesión se cerrará automáticamente.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Entendido'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _forceLogout();
                },
              ),
            ],
          );
        },
      );
    }
  }

  // Forzar cierre de sesión
  Future<void> _forceLogout() async {
    try {
      disconnect();
      await FirebaseAuth.instance.signOut();

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      // Ignorar errores
    }
  }

  // Forzar reconexión
  void reconnect() {
    disconnect();
    Future.delayed(const Duration(milliseconds: 500), () {
      connect();
    });
  }

  // Desconectar del servidor WebSocket
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      try {
        _channel!.sink.close();
      } catch (e) {
        debugPrint('Error al cerrar WebSocket: $e');
      } finally {
        _isConnected = false;
        _channel = null;
      }
    }
  }

  // Actualizar conexión con credenciales actuales
  Future<void> refreshConnection() async {
    disconnect();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      _updateUserCredentials(user);
    }

    connect();
  }

  // Enviar mensaje a través del WebSocket
  bool sendMessage(String message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(message);
        return true;
      } catch (e) {
        debugPrint('Error al enviar mensaje por WebSocket: $e');
        return false;
      }
    }
    return false;
  }

  // Liberar recursos
  void dispose() {
    disconnect();
    _chatMessageController.close();
    _profileUpdateController.close();
    _accountDeletedController.close();
    _allMessagesController.close();
  }
}
