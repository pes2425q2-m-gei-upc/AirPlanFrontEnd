// user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class UserService {
  static Future<bool> deleteUser(String email) async {
    try {

      print("Eliminando usuario $email");
      // 1. Eliminar del backend
      final backendResponse = await http.delete(
        Uri.parse('http://localhost:8080/api/usuaris/eliminar/$email'),
      );
      print("Eliminando usuario $email");

      if (backendResponse.statusCode != 200) {
        return false;
      }
      print("Eliminando usuario $email");

      // 2. Eliminar de Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email == email) {
        await user.delete();
      }
      print("Eliminando usuario $email");

      return true;
    } catch (e) {
      print("Error al eliminar usuario: $e");
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
      print("Error en rollback: $e");
      return false;
    }
  }
}