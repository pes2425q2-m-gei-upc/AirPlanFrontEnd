import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:airplan/main.dart'; // Importar para acceder a navigatorKey

/// WebSocketService manages real-time communication for profile updates across devices
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  WebSocketChannel? _channel;
  final StreamController<String> _profileUpdateController =
      StreamController<String>.broadcast();
  bool _isConnected = false;

  // Datos actuales del usuario
  String _currentUsername = '';
  String _currentEmail = '';

  // ID único para este cliente/dispositivo
  String _clientId = '';

  // Timer para ping/pong y reconexión automática
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  // Singleton instance
  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal() {
    // Inicializar clientId
    _initializeClientId();

    // Escuchar cambios de autenticación para mantener la conexión actualizada
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // Usuario logueado - conectar o actualizar conexión
        _updateUserCredentials(user);
      } else {
        // Usuario desconectado - cerrar WebSocket
        disconnect();
      }
    });

    // Inicializar conexión si ya hay un usuario
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

      // Si no hay ID guardado, generar uno nuevo
      if (_clientId.isEmpty) {
        _clientId = const Uuid().v4();
        await prefs.setString('websocket_client_id', _clientId);
      }

      print('🆔 Cliente WebSocket ID: $_clientId');
    } catch (e) {
      print('❌ Error inicializando clientId: $e');
      // Generar un ID temporal si hay error con SharedPreferences
      _clientId =
          'temp_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}';
    }
  }

  // Getter para el clientId
  String get clientId => _clientId;

  // Stream for profile updates that other widgets can listen to
  Stream<String> get profileUpdates => _profileUpdateController.stream;

  // Check if WebSocket is connected
  bool get isConnected => _isConnected;

  // Actualiza las credenciales del usuario y reconecta si es necesario
  void _updateUserCredentials(User user) {
    final newUsername = user.displayName ?? '';
    final newEmail = user.email ?? '';

    // Verificar si cambiaron las credenciales
    if (newUsername != _currentUsername || newEmail != _currentEmail) {
      print('🔄 Credenciales de usuario actualizadas:');
      print('   - Username anterior: $_currentUsername → Nuevo: $newUsername');
      print('   - Email anterior: $_currentEmail → Nuevo: $newEmail');

      _currentUsername = newUsername;
      _currentEmail = newEmail;

      // Si ya estábamos conectados, reconectar con las nuevas credenciales
      if (_isConnected) {
        disconnect();
        connect();
      }
    }
  }

  // Connect to WebSocket server with current user credentials
  void connect() {
    if (_isConnected) {
      print('⚠️ WebSocket ya está conectado. No es necesario reconectar.');
      return;
    }

    // Actualizar las credenciales del usuario antes de conectar
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No se puede conectar WebSocket: No hay usuario autenticado');
      return;
    }

    _currentUsername = user.displayName ?? '';
    _currentEmail = user.email ?? '';

    try {
      print(
        '🔌 Conectando WebSocket con: Username=$_currentUsername, Email=$_currentEmail',
      );

      // Connect to WebSocket server with user credentials as query parameters
      _channel = WebSocketChannel.connect(
        Uri.parse(
          'ws://localhost:8080/ws?username=$_currentUsername&email=$_currentEmail&clientId=$_clientId',
        ),
      );

      _isConnected = true;

      // Listen for incoming messages
      _channel!.stream.listen(
        (message) {
          // Process incoming message
          _handleIncomingMessage(message.toString());
        },
        onDone: () {
          _isConnected = false;
          print('WebSocket connection closed');
          // Attempt to reconnect after a delay
          _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          print('❌ WebSocket error: $error');
          // Attempt to reconnect after a delay
          _scheduleReconnect();
        },
      );

      print('✅ WebSocket connected successfully');

      // Iniciar el ping periódico para mantener la conexión activa
      _startPingTimer();
    } catch (e) {
      _isConnected = false;
      print('❌ Failed to connect to WebSocket: $e');
      // Attempt to reconnect after a delay
      _scheduleReconnect();
    }
  }

  // Iniciar timer para enviar pings periódicos al servidor
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('{"type":"PING"}');
          print('📡 Ping enviado al servidor WebSocket');
        } catch (e) {
          print('❌ Error enviando ping: $e');
          _isConnected = false;
          _scheduleReconnect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Schedule a reconnection attempt
  void _scheduleReconnect() {
    // Cancelar cualquier timer de reconexión existente
    _reconnectTimer?.cancel();

    print('⏱️ Programando reconexión WebSocket en 5 segundos...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        print('🔄 Intentando reconectar WebSocket...');
        connect();
      }
    });
  }

  // Handle incoming WebSocket messages
  void _handleIncomingMessage(String message) {
    try {
      print('📩 Received WebSocket message: $message');

      // No procesar mensajes ping-pong
      if (message.contains('"type":"PING"') ||
          message.contains('"type":"PONG"')) {
        print('📡 Mensaje de ping/pong recibido');
        return;
      }

      // Deserializar el mensaje para verificar el clientId
      final Map<String, dynamic> data = json.decode(message);

      // Comprobar si el mensaje proviene del mismo dispositivo (mismo clientId)
      if (data.containsKey('clientId') && data['clientId'] == _clientId) {
        print(
          '🔄 Ignorando mensaje de mi propio dispositivo (clientId: $_clientId)',
        );
        return; // No procesamos mensajes de nuestro propio dispositivo
      }

      // Comprobar si es un mensaje de cuenta eliminada
      if (data['type'] == 'ACCOUNT_DELETED') {
        _handleAccountDeletedMessage(data);
        return;
      }

      // Emit the message to all listeners
      _profileUpdateController.add(message);
    } catch (e) {
      print('❌ Error processing WebSocket message: $e');
    }
  }

  // Maneja mensajes de eliminación de cuenta
  void _handleAccountDeletedMessage(Map<String, dynamic> data) {
    try {
      final String email = data['email'] ?? '';
      final String username = data['username'] ?? '';

      print('⚠️ Cuenta eliminada detectada: $username ($email)');

      // Verificar si el mensaje es relevante para este usuario
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          (currentUser.email == email || currentUser.displayName == username)) {
        print('🚨 Esta cuenta ha sido eliminada desde otro dispositivo');

        // Mostrar alerta al usuario y cerrar sesión
        _showAccountDeletedDialog();

        // Cerrar sesión después de un breve retraso
        Future.delayed(const Duration(seconds: 2), () {
          _forceLogout();
        });
      }
    } catch (e) {
      print('❌ Error procesando mensaje de cuenta eliminada: $e');
    }
  }

  // Muestra un diálogo de cuenta eliminada si hay contexto disponible
  void _showAccountDeletedDialog() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
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
                  // Cerrar el diálogo
                  Navigator.of(dialogContext).pop();
                  // Forzar cierre de sesión
                  _forceLogout();
                },
              ),
            ],
          );
        },
      );
    }
  }

  // Fuerza el cierre de sesión cuando la cuenta se elimina
  Future<void> _forceLogout() async {
    try {
      print('🚪 Forzando cierre de sesión por eliminación de cuenta');

      // Desconectar WebSocket
      disconnect();

      // Cerrar sesión en Firebase
      await FirebaseAuth.instance.signOut();

      // Redirigir a la página de login
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      print('❌ Error durante el cierre de sesión forzado: $e');
    }
  }

  // Método público para forzar una reconexión
  void reconnect() {
    print('🔄 Forzando reconexión del WebSocket');
    disconnect();
    connect();
  }

  // Disconnect from WebSocket server
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      try {
        _channel!.sink.close();
        print('🔌 WebSocket disconnected');
      } catch (e) {
        print('⚠️ Error closing WebSocket: $e');
      } finally {
        _isConnected = false;
        _channel = null;
      }
    }
  }

  // Dispose resources
  void dispose() {
    disconnect();
    _profileUpdateController.close();
  }
}
