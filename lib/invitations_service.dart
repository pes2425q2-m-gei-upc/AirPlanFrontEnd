import 'dart:convert';
import 'package:airplan/services/api_config.dart';
import 'package:http/http.dart' as http;

class InvitationsService {
  static String baseUrl = ApiConfig().buildUrl('api/invitacions');

  // Fetch invitations for a specific user
  static Future<List<Map<String, dynamic>>> fetchInvitations(String username) async {
    final response = await http.get(Uri.parse('$baseUrl/$username'));
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return List<Map<String, dynamic>>.from(body);
    } else {
      throw Exception('Error fetching invitations');
    }
  }

  // Acceptar una invitació
  static Future<void> acceptInvitation(int activityId, String username) async {

      final response = await http.post(
      Uri.parse('$baseUrl/acceptar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'activityId': activityId, 'username': username}),
    );
    if (response.statusCode != 200) {
      throw Exception('Error accepting invitation');
    }
  }

  // Rebutjar una invitació
  static Future<void> rejectInvitation(int activityId, String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rebutjar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'activityId': activityId, 'username': username}),
    );
    if (response.statusCode != 200) {
      throw Exception('Error rejecting invitation');
    }
  }
}