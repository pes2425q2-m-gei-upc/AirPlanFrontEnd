// Puedes añadir esto en un nuevo archivo lib/models/real_time_notification.dart
class RealTimeEventNotification {
  final String type;
  final String message;
  final String username;
  final int timestamp;

  RealTimeEventNotification({
    required this.type,
    required this.message,
    required this.username,
    required this.timestamp,
  });

  factory RealTimeEventNotification.fromJson(Map<String, dynamic> json) {
    return RealTimeEventNotification(
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      username: json['username'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message,
      'username': username,
      'timestamp': timestamp,
    };
  }
}