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
  static WebSocketService? _instance;

  factory WebSocketService({
    FirebaseAuth? auth,
    SharedPreferences? preferences,
    ApiConfig? apiConfig,
    WebSocketChannelFactory? channelFactory,
  }) {
    if (_instance == null) {
      _instance = WebSocketService._internal(
        auth: auth,
        preferences: preferences,
        apiConfig: apiConfig,
        channelFactory: channelFactory,
      );
    } else {
      if (auth != null) _instance!._auth = auth;
      if (preferences != null) _instance!._prefs = preferences;
      if (apiConfig != null) _instance!._apiConfig = apiConfig;
      if (channelFactory != null) _instance!._channelFactory = channelFactory;
    }
    return _instance!;
  }

  // Private constructor with injectable dependencies
  WebSocketService._internal({
    FirebaseAuth? auth,
    SharedPreferences? preferences,
    ApiConfig? apiConfig,
    WebSocketChannelFactory? channelFactory,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _prefs = preferences,
       _apiConfig = apiConfig ?? ApiConfig(),
       _channelFactory = channelFactory ?? DefaultChannelFactory() {
    _initializeClientId();

    // Listen authentication changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _updateUserCredentials(user);
      } else {
        disconnect();
      }
    });

    // Check current user on init
    final user = _auth.currentUser;
    if (user != null) {
      _updateUserCredentials(user);
      connect();
    }
  }

  final StreamController<String> _profileUpdateController =
      StreamController<String>.broadcast();

  bool _isConnected = false;
  String _currentUsername = '';
  String _currentEmail = '';
  String _clientId = '';
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  FirebaseAuth _auth;
  SharedPreferences? _prefs;
  ApiConfig _apiConfig;
  WebSocketChannelFactory _channelFactory;
  WebSocketChannel? _channel;

  // Inicializar el ID de cliente único
  Future<void> _initializeClientId() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
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

  // Stream for profile updates that other widgets can listen to
  Stream<String> get profileUpdates => _profileUpdateController.stream;

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
    if (_isConnected && _channel != null) return;

    disconnect();

    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    _currentUsername = user.displayName ?? '';
    _currentEmail = user.email ?? '';

    if (_currentUsername.isEmpty || _currentEmail.isEmpty) {
      return;
    }

    try {
      final baseUrl = _apiConfig.baseUrl.replaceFirst('http://', 'ws://');
      _channel = _channelFactory.connect(
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

  // Iniciar timer para enviar pings periódicos al servidor principal
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
    // Filter out ping/pong messages
    if (message.contains('"type":"PING"') ||
        message.contains('"type":"PONG"')) {
      return;
    }
    try {
      // Try parsing JSON messages
      final data = json.decode(message) as Map<String, dynamic>;
      // Ignore messages from this client
      if (data.containsKey('clientId') && data['clientId'] == _clientId) {
        return;
      }
      // Handle account deletion separately
      if (data['type'] == 'ACCOUNT_DELETED') {
        _handleAccountDeletedMessage(data);
        return;
      }
      // Forward JSON message payload as raw string
      _profileUpdateController.add(message);
    } on FormatException {
      // Non-JSON message: forward as-is
      _profileUpdateController.add(message);
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  // Manejar mensaje de cuenta eliminada
  void _handleAccountDeletedMessage(Map<String, dynamic> data) {
    try {
      final String email = data['email'] ?? '';
      final String username = data['username'] ?? '';

      final currentUser = _auth.currentUser;
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
    if (context != null) {
      // Verificar si el widget está montado antes de mostrar el diálogo
      if (!context.mounted) return;

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
      await _auth.signOut();

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

  // Desconectar del servidor WebSocket principal
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

    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      _updateUserCredentials(user);
    }

    connect();
  }

  // Liberar recursos
  void dispose() {
    disconnect();
    _profileUpdateController.close();
  }
}

/// Factory interface to allow mocking WebSocketChannel connection in tests
abstract class WebSocketChannelFactory {
  WebSocketChannel connect(Uri uri);
}

/// Default implementation uses the real WebSocketChannel.connect
class DefaultChannelFactory implements WebSocketChannelFactory {
  @override
  WebSocketChannel connect(Uri uri) => WebSocketChannel.connect(uri);
}
