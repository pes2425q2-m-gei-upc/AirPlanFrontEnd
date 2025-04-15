// user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserService {
  static Future<bool> deleteUser(String email) async {
    try {
      // 1. Eliminar del backend
      final backendResponse = await http.delete(
        Uri.parse('http://localhost:8080/api/usuaris/eliminar/$email'),
      );

      if (backendResponse.statusCode != 200) {
        return false;
      }

      // 2. Eliminar de Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email == email) {
        await user.delete();
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rollbackUserCreation(String email) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:8080/api/usuaris/eliminar/$email'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> editUser(
    String currentEmail, // Current email of the user
    Map<String, dynamic> updatedData,
  ) async {
    try {
      final encodedEmail = Uri.encodeComponent(
        currentEmail,
      ); // Encode the email
      final response = await http.put(
        Uri.parse('http://localhost:8080/api/usuaris/editar/$encodedEmail'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(updatedData),
      );
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('User updated successfully');
        return {'success': true};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
