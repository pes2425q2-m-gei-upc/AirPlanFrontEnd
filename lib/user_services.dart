// user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class UserService {
  static Future<bool> deleteUser(String email) async {
    try {
      // 1. Eliminar del backend
      final backendResponse = await http.delete(
        Uri.parse('http://nattech.fib.upc.edu:40350/api/usuaris/eliminar/$email'),
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
        Uri.parse('http://nattech.fib.upc.edu:40350/api/usuaris/eliminar/$email'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}