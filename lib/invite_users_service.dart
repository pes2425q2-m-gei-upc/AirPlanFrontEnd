import 'dart:convert';
import 'package:http/http.dart' as http;

class InviteUsersService {
  static const String baseUrl = 'http://127.0.0.1:8080/api/invitacions';

  // Buscar usuarios por nombre
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/search?query=$query'));

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return List<Map<String, dynamic>>.from(body);
    } else {
      throw Exception('Error fetching users');
    }
  }

  // Verificar si un usuario ya tiene una invitación
  static Future<bool> checkInvitation(String username, String activityId) async {
    final response = await http.get(Uri.parse('$baseUrl/check/$activityId/$username'));
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      // Directly return the value of 'hasInvitation' if it exists and is a boolean
      if (body is Map<String, dynamic> && body['hasInvitation'] is bool) {
        return body['hasInvitation'];
      } else {
        throw Exception('Unexpected server response format');
      }
    } else {
      throw Exception('Error checking invitation');
    }
  }

  // Invitar a un usuario
  static Future<void> inviteUser(String creator, String username, String activityId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invitar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'creator': creator, 'username': username, 'activityId': activityId}),
    );

    print('Response status code: ${response.statusCode}');

    if (response.statusCode != 201) {
      throw Exception('Error inviting user');
    }
  }
}