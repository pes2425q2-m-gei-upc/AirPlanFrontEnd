// user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/websocket_service.dart';
import 'services/api_config.dart'; // Importar la configuración de API

class UserService {
  static Future<bool> deleteUser(String email) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final username = user?.displayName ?? "";

      // Obtener el clientId para identificar el dispositivo actual
      final clientId = WebSocketService().clientId;

      // 0. Enviar notificación de eliminación de cuenta a otros dispositivos antes de eliminarla
      await _sendAccountDeletedNotification(email, username, clientId);

      // 1. Eliminar del backend - Incluir clientId como parámetro de consulta
      final backendResponse = await http.delete(
        Uri.parse(
          ApiConfig().buildUrl(
            'api/usuaris/eliminar/$email?clientId=$clientId',
          ),
        ),
      );

      if (backendResponse.statusCode != 200) {
        return false;
      }

      // 2. Eliminar de Firebase Auth
      if (user != null && user.email == email) {
        await user.delete();
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Método para notificar a otros dispositivos sobre la eliminación de cuenta
  static Future<void> _sendAccountDeletedNotification(
    String email,
    String username,
    String clientId,
  ) async {
    try {
      // Enviar notificación al backend para que notifique a otros dispositivos
      await http.post(
        Uri.parse(ApiConfig().buildUrl('api/notifications/account-deleted')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': username,
          'clientId':
              clientId, // Identificar este dispositivo para no recibir la propia notificación
        }),
      );
      // No es necesario hacer nada con la respuesta, si falla simplemente continuará
    } catch (e) {
      // Capturamos la excepción pero no interrumpimos el flujo
    }
  }

  static Future<bool> rollbackUserCreation(String email) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/eliminar/$email')),
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
      // Filtrar valores nulos y convertir todos los valores a String
      final filteredData = <String, String>{};
      String? oldUsername; // Para guardar el nombre de usuario original

      updatedData.forEach((key, value) {
        if (value != null) {
          // Guardar el oldUsername si está presente pero no incluirlo en los datos a enviar
          if (key == 'oldUsername') {
            oldUsername = value.toString();
          } else {
            filteredData[key] = value.toString();
          }
        }
      });

      // No incluir campo 'correo' en la actualización
      // El correo debe cambiarse solo a través del flujo de verificación
      filteredData.remove('correo');

      // Asegurar que al menos un campo tiene valor para la actualización
      if (filteredData.isEmpty) {
        return {'success': false, 'error': 'No hay datos para actualizar'};
      }

      // Intentar realizar la actualización sin verificación previa
      final response = await http.put(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/editar/$currentEmail')),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(filteredData),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 404) {
        // Si el usuario no se encuentra, intentar obtenerlo por username como respaldo
        final user = FirebaseAuth.instance.currentUser;

        // Usar oldUsername si está disponible, de lo contrario usar el displayName actual
        final usernameToUse = oldUsername ?? user?.displayName;

        if (usernameToUse != null) {
          try {
            // Intentar obtener el usuario por username
            final usernameResponse = await http.get(
              Uri.parse(
                ApiConfig().buildUrl(
                  'api/usuaris/usuario-por-username/$usernameToUse',
                ),
              ),
            );

            if (usernameResponse.statusCode == 200) {
              final userData = jsonDecode(
                utf8.decode(usernameResponse.bodyBytes),
              );
              final databaseEmail = userData['email'] as String?;

              if (databaseEmail != null && databaseEmail != currentEmail) {
                // Intentar actualizar con el email que tenemos en la base de datos
                final secondResponse = await http.put(
                  Uri.parse(
                    ApiConfig().buildUrl('api/usuaris/editar/$databaseEmail'),
                  ),
                  headers: {'Content-Type': 'application/json; charset=UTF-8'},
                  body: jsonEncode(filteredData),
                );

                if (secondResponse.statusCode == 200) {
                  return {'success': true};
                }
              }
            }
          } catch (e) {
            // Si hay error, continuamos con el flujo normal
          }
        }

        return {'success': false, 'error': 'Usuario no encontrado'};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Método para obtener el nombre real del usuario desde el backend
  static Future<String> getUserRealName(String username) async {
    try {
      // Obtener el nombre completo del usuario desde el backend usando el nuevo endpoint
      final response = await http.get(
        Uri.parse(
          ApiConfig().buildUrl('api/usuaris/usuario-por-username/$username'),
        ),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        return userData['nom'] ?? 'Nombre no disponible';
      } else {
        return 'Nombre no disponible';
      }
    } catch (e) {
      return 'Nombre no disponible';
    }
  }

  // Método para obtener el tipo de usuario y nivel (si es cliente)
  static Future<Map<String, dynamic>> getUserTypeAndLevel(
    String username,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/tipo-usuario/$username')),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'No se pudo obtener el tipo de usuario'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Método para cerrar sesión en el backend
  static Future<bool> logoutUser(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/logout')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getUserData(String username) async {
    final response = await http.get(
      Uri.parse(
        ApiConfig().buildUrl('api/usuaris/usuario-por-username/$username'),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener los datos del usuario');
    }
  }
}
