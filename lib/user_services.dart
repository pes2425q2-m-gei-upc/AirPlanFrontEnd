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
      print('⏳ Iniciando actualización de usuario con email: $currentEmail');

      // Filtrar valores nulos y convertir todos los valores a String
      final filteredData = <String, String>{};
      updatedData.forEach((key, value) {
        if (value != null) {
          filteredData[key] = value.toString();
        }
      });

      // ⚠️ Importante: No incluir campo 'correo' en la actualización
      // El correo debe cambiarse solo a través del flujo de verificación
      filteredData.remove('correo');

      // Asegurar que al menos un campo tiene valor para la actualización
      if (filteredData.isEmpty) {
        return {'success': false, 'error': 'No hay datos para actualizar'};
      }

      // Imprimir datos para depuración
      print('📤 Enviando actualización para: $currentEmail');
      print('📋 Datos filtrados: $filteredData');

      // Intentar realizar la actualización sin verificación previa
      final response = await http.put(
        Uri.parse('http://localhost:8080/api/usuaris/editar/$currentEmail'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(filteredData),
      );

      print('📩 Response status code: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Usuario actualizado exitosamente');
        return {'success': true};
      } else if (response.statusCode == 404) {
        // Si el usuario no se encuentra, intentar obtenerlo por username como respaldo
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.displayName != null) {
          print(
            '🔍 Intentando localizar usuario por username: ${user.displayName}',
          );

          try {
            // Intentar obtener el usuario por username
            final usernameResponse = await http.get(
              Uri.parse(
                'http://localhost:8080/api/usuaris/usuario-por-username/${user.displayName}',
              ),
            );

            if (usernameResponse.statusCode == 200) {
              final userData = jsonDecode(usernameResponse.body);
              final databaseEmail = userData['email'] as String?;

              if (databaseEmail != null && databaseEmail != currentEmail) {
                print('⚠️ Correo en base de datos diferente al de Firebase:');
                print('   - Firebase: $currentEmail');
                print('   - Base de datos: $databaseEmail');

                // Intentar actualizar con el email que tenemos en la base de datos
                final secondResponse = await http.put(
                  Uri.parse(
                    'http://localhost:8080/api/usuaris/editar/$databaseEmail',
                  ),
                  headers: {'Content-Type': 'application/json; charset=UTF-8'},
                  body: jsonEncode(filteredData),
                );

                if (secondResponse.statusCode == 200) {
                  print(
                    '✅ Usuario actualizado exitosamente (usando email de DB)',
                  );
                  return {'success': true};
                }
              }
            }
          } catch (e) {
            print('❌ Error al intentar obtener usuario por username: $e');
          }
        }

        return {'success': false, 'error': 'Usuario no encontrado'};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      print('❌ Error en editUser: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Añadir método para obtener el nombre real del usuario desde el backend
  static Future<String> getUserRealName(String username) async {
    try {
      // Obtener el nombre completo del usuario desde el backend usando el nuevo endpoint
      final response = await http.get(
        Uri.parse(
          'http://localhost:8080/api/usuaris/usuario-por-username/$username',
        ),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        return userData['nom'] ?? 'Nombre no disponible';
      } else {
        print('Error al obtener el nombre del usuario: ${response.statusCode}');
        return 'Nombre no disponible';
      }
    } catch (e) {
      print('Error obteniendo el nombre del usuario: $e');
      return 'Nombre no disponible';
    }
  }

  // Método para sincronizar el email de Firebase con la base de datos (para usar en la página de usuario)
  static Future<bool> syncEmailOnProfileLoad() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Forzar una recarga del usuario desde Firebase para obtener datos actualizados
      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) return false;

      final username = refreshedUser.displayName;
      final firebaseEmail = refreshedUser.email;

      if (username == null || firebaseEmail == null) {
        print('⚠️ Usuario sin username o correo en Firebase');
        return false;
      }

      print('🔄 Sincronizando correo al cargar perfil:');
      print('   Username: $username');
      print('   Email en Firebase: $firebaseEmail');

      // Obtener datos del usuario desde la base de datos
      final response = await http.get(
        Uri.parse(
          'http://localhost:8080/api/usuaris/usuario-por-username/$username',
        ),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final databaseEmail = userData['email'] as String?;

        // Si el correo en Firebase es diferente al de la base de datos, actualizar la base de datos
        if (databaseEmail != null && databaseEmail != firebaseEmail) {
          print('⚠️ Correo en Firebase diferente al de la base de datos:');
          print('   - Firebase: $firebaseEmail');
          print('   - Base de datos: $databaseEmail');

          // Actualizar directamente el email en la base de datos
          final updateResponse = await http.post(
            Uri.parse('http://localhost:8080/api/usuaris/directUpdateEmail'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'oldEmail': databaseEmail,
              'newEmail': firebaseEmail,
            }),
          );

          if (updateResponse.statusCode == 200) {
            print('✅ Correo actualizado correctamente en la base de datos');
            // Retornar true para indicar que se detectó un cambio de correo
            return true;
          } else {
            print('❌ Error actualizando correo: ${updateResponse.statusCode}');
          }
        } else {
          print('✅ Los correos ya están sincronizados');
        }
      }
      return false;
    } catch (e) {
      print('❌ Error sincronizando correo: $e');
      return false;
    }
  }
}
