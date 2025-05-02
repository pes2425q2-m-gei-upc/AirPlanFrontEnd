import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/auth_service.dart'; // Importamos el nuevo servicio

/// Service to manage the chat WebSocket connection.
class ChatWebSocketService {
  static final ChatWebSocketService _instance =
      ChatWebSocketService._internal();
  factory ChatWebSocketService() => _instance;

  WebSocketChannel? _chatChannel;
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isChatConnected = false;
  String _currentUsername = '';
  String? _currentChatPartner;
  Timer? _chatPingTimer;
  final AuthService _authService; // Usamos AuthService

  ChatWebSocketService._internal({AuthService? authService})
    : _authService = authService ?? AuthService() {
    _authService.authStateChanges.listen((User? user) {
      if (user == null) {
        disconnectChat();
      } else {
        _currentUsername = user.displayName ?? '';
      }
    });
    // Initialize username immediately if already logged in
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      _currentUsername = currentUser.displayName ?? '';
    }
  }

  Stream<Map<String, dynamic>> get chatMessages =>
      _chatMessageController.stream;
  bool get isChatConnected => _isChatConnected;
  String? get currentChatPartner => _currentChatPartner;

  void connectToChat(String otherUsername) {
    if (_currentUsername.isEmpty) {
      debugPrint('Cannot connect to chat: current username is unknown.');
      return;
    }

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
      final wsBaseUrl = ApiConfig().baseUrl.replaceFirst(
        RegExp(r'^http'),
        'ws',
      );
      final uri = Uri.parse(
        '$wsBaseUrl/ws/chat/$_currentUsername/$otherUsername',
      );
      debugPrint('Connecting to WebSocket: $uri');

      _chatChannel = WebSocketChannel.connect(uri);
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

  Future<bool> sendChatMessage(String receiverUsername, String content) async {
    if (!_ensureConnected(receiverUsername)) {
      debugPrint(
        'Cannot send message: WebSocket not connected or not connected to the correct user.',
      );
      return false;
    }

    try {
      final message = {
        'usernameSender': _currentUsername,
        'usernameReceiver': receiverUsername,
        'dataEnviament': DateTime.now().toIso8601String(),
        'missatge': content,
      };
      _chatChannel!.sink.add(jsonEncode(message));
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
