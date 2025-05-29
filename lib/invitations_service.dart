import 'dart:convert';
import 'package:airplan/services/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

class InvitationsService {
  static String baseUrl = ApiConfig().buildUrl('api/invitacions');

  // Fetch invitations for a specific user
  static Future<List<Map<String, dynamic>>> fetchInvitations(
    String username,
  ) async {
    final response = await http.get(Uri.parse('$baseUrl/$username'));
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return List<Map<String, dynamic>>.from(body);
    } else {
      throw Exception('invitations_service_error_fetching'.tr());
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
      throw Exception('invitations_service_error_accepting'.tr());
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
      throw Exception('invitations_service_error_rejecting'.tr());
    }
  }
}
