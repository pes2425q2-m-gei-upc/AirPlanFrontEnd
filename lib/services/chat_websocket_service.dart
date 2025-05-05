import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/auth_service.dart';

/// Service to manage the chat WebSocket connection.
class ChatWebSocketService {
  static ChatWebSocketService? _instance;

  factory ChatWebSocketService({
    AuthService? authService,
    ApiConfig? apiConfig,
    WebSocketChannelFactory? webSocketChannelFactory,
  }) {
    // Create a fresh instance if none exists, or when injecting AuthService to re-run initialization
    if (_instance == null || authService != null) {
      _instance = ChatWebSocketService._internal(
        authService: authService,
        apiConfig: apiConfig,
        webSocketChannelFactory: webSocketChannelFactory,
      );
    } else {
      if (authService != null) {
        _instance!._authService = authService;
      }
      if (apiConfig != null) {
        _instance!._apiConfig = apiConfig;
      }
      if (webSocketChannelFactory != null) {
        _instance!._webSocketChannelFactory = webSocketChannelFactory;
      }
    }
    return _instance!;
  }

  WebSocketChannel? _chatChannel;
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isChatConnected = false;
  String _currentUsername = '';
  String? _currentChatPartner;
  Timer? _chatPingTimer;
  late AuthService _authService;
  late ApiConfig _apiConfig;
  late WebSocketChannelFactory _webSocketChannelFactory;

  ChatWebSocketService._internal({
    AuthService? authService,
    ApiConfig? apiConfig,
    WebSocketChannelFactory? webSocketChannelFactory,
  }) : _authService = authService ?? AuthService(),
       _apiConfig = apiConfig ?? ApiConfig(),
       _webSocketChannelFactory =
           webSocketChannelFactory ?? DefaultWebSocketChannelFactory() {
    // No auth subscription at init; connectToChat will fetch current username
  }

  Stream<Map<String, dynamic>> get chatMessages =>
      _chatMessageController.stream;
  bool get isChatConnected => _isChatConnected;
  String? get currentChatPartner => _currentChatPartner;

  void connectToChat(String otherUsername) {
    // Always get the latest username from AuthService
    final user = _authService.getCurrentUser();
    final username = user?.displayName ?? '';
    if (username.isEmpty) {
      debugPrint('Cannot connect to chat: current username is unknown.');
      return;
    }
    _currentUsername = username;

    // Avoid redundant connections or connecting to self
    if (otherUsername == _currentUsername) {
      debugPrint('Cannot connect to chat with oneself.');
      return;
    }

    if (_isChatConnected && _currentChatPartner == otherUsername) {
      debugPrint('Already connected to chat with $otherUsername.');
      return; // Already connected to the same chat
    }

    disconnectChat(); // Close any existing chat connection

    _currentChatPartner = otherUsername;

    try {
      // Use ApiConfig to build the WebSocket URL correctly
      final wsBaseUrl = _apiConfig.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final uri = Uri.parse(
        '$wsBaseUrl/ws/chat/$_currentUsername/$otherUsername',
      );
      debugPrint('Connecting to WebSocket: $uri');

      _chatChannel = _webSocketChannelFactory.connect(uri);
      _isChatConnected = true;

      _chatChannel!.stream.listen(
        _handleIncomingMessage,
        onDone: () {
          debugPrint('WebSocket chat connection closed.');
          _handleDisconnection();
        },
        onError: (error) {
          debugPrint('WebSocket chat error: $error');
          _handleDisconnection();
        },
        cancelOnError: true,
      );

      _startChatPingTimer();
      debugPrint('WebSocket chat connection established with $otherUsername.');
    } catch (e) {
      debugPrint('Error connecting to chat WebSocket: $e');
      _handleDisconnection();
    }
  }

  Future<bool> sendEditMessage(
      String receiverUsername,
      String originalTimestamp,
      String newContent
      ) async {
    if (!_isChatConnected || _chatChannel == null) {
      // If no active connection, try to connect first
      connectToChat(receiverUsername);
      // Wait a bit for the connection to establish
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isChatConnected || _chatChannel == null) {
        debugPrint('No se pudo establecer conexión WebSocket para editar el mensaje');
        return false;
      }
    }

    try {
      final message = {
        'type': 'EDIT',
        'usernameSender': _currentUsername,
        'usernameReceiver': receiverUsername,
        'originalTimestamp': originalTimestamp,
        'newContent': newContent,
        'editTimestamp': DateTime.now().toIso8601String(),
      };

      _chatChannel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      debugPrint('Error al enviar edición por WebSocket: $e');
      return false;
    }
  }

  Future<bool> sendChatMessage(String receiverUsername, String content, DateTime timestamp) async {
    if (!_ensureConnected(receiverUsername)) {
      debugPrint(
        'Cannot send message: WebSocket not connected or not connected to the correct user.',
      );
      return false;
    }

    try {
      final msgMap = {
        'usernameSender': _currentUsername,
        'usernameReceiver': receiverUsername,
        'dataEnviament': timestamp.toIso8601String(),
        'missatge': content,
      };
      // Send message immediately
      _chatChannel!.sink.add(jsonEncode(msgMap));
      debugPrint('Sent chat message to $receiverUsername');
      return true;
    } catch (e) {
      debugPrint('Error sending chat message via WebSocket: $e');
      // Consider attempting a reconnect or notifying the user
      _handleDisconnection(); // Assume connection is lost on error
      return false;
    }
  }

  Future<bool> sendBlockNotification(
    String blockedUsername,
    bool isBlocking,
  ) async {
    // Ensure connection is established with the correct partner before sending block/unblock
    if (!_ensureConnected(blockedUsername)) {
      debugPrint(
        'Cannot send block notification: WebSocket not connected or not connected to the correct user.',
      );
      return false;
    }

    try {
      final notification = {
        'type': isBlocking ? 'BLOCK' : 'UNBLOCK',
        'blockerUsername': _currentUsername,
        'blockedUsername': blockedUsername,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final notificationJson = jsonEncode(notification);
      _chatChannel!.sink.add(notificationJson);
      debugPrint(
        'Sent ${isBlocking ? "block" : "unblock"} notification for $blockedUsername.',
      );

      // No explicit reconnect needed here, rely on server sending status updates.
      // The UI should update based on incoming 'blockStatusUpdate' messages.
      return true;
    } catch (e) {
      debugPrint(
        'Error sending ${isBlocking ? "block" : "unblock"} notification: $e',
      );
      _handleDisconnection(); // Assume connection is lost on error
      return false;
    }
  }

  // Ensures connection exists for the target user. Does NOT attempt reconnect.
  bool _ensureConnected(String targetUsername) {
    return _isChatConnected &&
        _chatChannel != null &&
        _currentChatPartner == targetUsername;
  }

  void _handleIncomingMessage(dynamic message) {
    try {
      final String messageText = message.toString();
      debugPrint('WebSocket message received: $messageText');
      final dynamic messageData = jsonDecode(messageText);

      if (messageData is! Map<String, dynamic>) {
        debugPrint('Received non-map message: $messageData');
        return;
      }

      final String? messageType = messageData['type'] as String?;

      // Handle Block Status Updates (Preferred Method)
      if (messageType == 'blockStatusUpdate' &&
          messageData.containsKey('blockStatus')) {
        final blockStatus = messageData['blockStatus'];
        if (blockStatus is Map<String, dynamic>) {
          _chatMessageController.add({
            'type': 'blockStatusUpdate',
            'blockStatus': blockStatus,
          });
          debugPrint('Processed blockStatusUpdate: $blockStatus');
        } else {
          debugPrint('Invalid blockStatus format received.');
        }
        return;
      }

      // Handle explicit Block/Unblock Notifications (Fallback/Alternative)
      // These might be sent by the server in addition to blockStatusUpdate
      if (messageType == 'BLOCK_NOTIFICATION' ||
          messageType == 'UNBLOCK_NOTIFICATION') {
        // Forward directly, let the UI decide how to interpret
        _chatMessageController.add(messageData);
        debugPrint('Processed $messageType notification.');
        return;
      }

      // Handle Chat History
      if (messageType == 'history' && messageData['messages'] is List) {
        final List<dynamic> messages = messageData['messages'];
        debugPrint('Processing history with ${messages.length} messages.');

        // Process each message from history exactly once, preserving isEdited flag
        // Send block status first if available in the history payload
        if (messageData.containsKey('blockStatus')) {
          final blockStatus = messageData['blockStatus'];
          if (blockStatus is Map<String, dynamic>) {
            _chatMessageController.add({
              'type': 'blockStatusUpdate',
              'blockStatus': blockStatus,
            });
            debugPrint('Sent blockStatus from history: $blockStatus');
          }
        }

        // Send history messages individually for processing by the UI
        for (var msg in messages) {
          if (msg is Map<String, dynamic> && _isValidChatMessage(msg)) {
            _chatMessageController.add({
              ...msg, // Spread operator to include all fields
              'fromHistory': true, // Mark as historical message
            });
          } else {
            debugPrint('Skipping invalid message in history: $msg');
          }
        }
        debugPrint('Finished processing history.');
        return;
      }

      // Handle real-time edit notifications
      if (messageData['type'] == 'EDIT') {
        debugPrint('Received edit notification');

        final editData = {
          'type': 'EDIT',
          'usernameSender': messageData['usernameSender'],
          'originalTimestamp': messageData['originalTimestamp'],
          'newContent': messageData['newContent'],
          'isEdited': messageData['isEdited'] ?? true
        };

        _chatMessageController.add(editData);
        return;
      }

      // Handle Regular Chat Messages
      if (_isValidChatMessage(messageData)) {
        _chatMessageController.add(messageData);
        debugPrint('Processed regular chat message.');
        return;
      }

      // Handle Server Errors explicitly sent
      if (messageData.containsKey('error')) {
        debugPrint('Error received from server: ${messageData['error']}');
        // Optionally forward the error to the UI if needed
        _chatMessageController.add({
          'type': 'error',
          'message': messageData['error'],
        });
        return;
      }

      // If none of the above, log as unprocessed
      debugPrint('Could not process message format: $messageData');
    } catch (e, stackTrace) {
      // Corrected debugPrint statements
      debugPrint('Error processing incoming WebSocket message: $e');
      debugPrint('Stack trace: $stackTrace');
      // Avoid processing potentially malformed legacy formats
    }
  }

  // Helper to validate the structure of a chat message map
  bool _isValidChatMessage(Map<String, dynamic> data) {
    return data.containsKey('usernameSender') &&
        data.containsKey('usernameReceiver') &&
        data.containsKey('dataEnviament') &&
        data.containsKey('missatge');
  }

  void _startChatPingTimer() {
    _chatPingTimer?.cancel();
    _chatPingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isChatConnected && _chatChannel != null) {
        try {
          _chatChannel!.sink.add('{"type":"PING"}');
          // debugPrint('Sent PING'); // Optional: uncomment for debugging
        } catch (e) {
          debugPrint('Error sending PING: $e. Disconnecting.');
          _handleDisconnection(); // Disconnect if ping fails
        }
      } else {
        timer.cancel(); // Stop timer if not connected
      }
    });
  }

  void _handleDisconnection() {
    if (_isChatConnected) {
      // Only trigger updates if it was previously connected
      _isChatConnected = false;
      _chatPingTimer?.cancel();
      _chatChannel = null; // Ensure channel is nullified
      _currentChatPartner = null;
      // Notify listeners about the disconnection, perhaps with a specific event type
      _chatMessageController.add({'type': 'disconnected'});
      debugPrint('WebSocket chat state reset due to disconnection.');
    }
  }

  void disconnectChat() {
    _chatPingTimer?.cancel();
    if (_chatChannel != null) {
      try {
        debugPrint('Closing WebSocket chat connection.');
        // Use the current chat partner value before nullifying it
        final partner = _currentChatPartner;
        _chatChannel!.sink.close();
        debugPrint('WebSocket sink closed for chat with $partner.');
      } catch (e) {
        // Log potential errors during close, but proceed with cleanup
        debugPrint('Error closing chat WebSocket sink: $e');
      } finally {
        _handleDisconnection(); // Ensure state is reset regardless of close errors
      }
    } else {
      // Ensure state is consistent even if channel was already null
      _handleDisconnection();
    }
  }

  void dispose() {
    disconnectChat(); // Ensure connection is closed
    _chatMessageController.close(); // Close the stream controller
    debugPrint('ChatWebSocketService disposed.');
  }
}

/// Factory interface for creating WebSocketChannel instances
/// This facilitates mocking in tests
abstract class WebSocketChannelFactory {
  WebSocketChannel connect(Uri uri);
}

/// Default implementation of WebSocketChannelFactory
/// Uses the actual WebSocketChannel.connect method
class DefaultWebSocketChannelFactory implements WebSocketChannelFactory {
  @override
  WebSocketChannel connect(Uri uri) {
    return WebSocketChannel.connect(uri);
  }
}
