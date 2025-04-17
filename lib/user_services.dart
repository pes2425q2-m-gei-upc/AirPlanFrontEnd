// user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Necesario para Timer

// Servicio global para gestionar los correos electrónicos
class EmailChangeManager {
  // Singleton
  static final EmailChangeManager _instance = EmailChangeManager._internal();
  factory EmailChangeManager() => _instance;
  EmailChangeManager._internal();

  // Estado del servicio
  bool _isInitialized = false;
  Timer? _periodicCheckTimer;
  bool _isLoading = false;
  String? _lastEmailInDb;

  // Inicializar el servicio una sola vez
  Future<void> initialize() async {
    if (_isInitialized) return;

    print(
      '📧 Inicializando EmailChangeManager - Servicio global de gestión de correos',
    );

    // Configurar una verificación periódica cada 5 segundos
    _periodicCheckTimer = Timer.periodic(Duration(seconds: 5), (_) {
      _periodicEmailCheck();
    });

    _isInitialized = true;
  }

  // Verificación periódica (único método para sincronizar correos)
  void _periodicEmailCheck() {
    print(
      '🔄 Verificación periódica ejecutándose... (comprobación cada 5 segundos)',
    );

    if (_isLoading) {
      print('⏸️ Verificación en pausa - hay una operación en curso');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('👤 No hay usuario actualmente en sesión');
      return;
    }

    // Forzar una recarga del usuario desde Firebase para obtener cambios externos
    user
        .reload()
        .then((_) {
          // Importante: Obtenemos de nuevo el usuario después de recargar para tener datos actualizados
          final refreshedUser = FirebaseAuth.instance.currentUser;
          if (refreshedUser == null) return;

          final username = refreshedUser.displayName;
          final firebaseEmail = refreshedUser.email;

          print('🔄 Datos actualizados después de reload():');
          print('   Username: $username');
          print('   Email: $firebaseEmail');
          print('   Email verificado: ${refreshedUser.emailVerified}');

          if (username == null ||
              firebaseEmail == null ||
              firebaseEmail.isEmpty) {
            print('⚠️ Usuario sin username o correo en Firebase');
            return;
          }

          // Verificar si el correo en Firebase coincide con el de la base de datos para el mismo username
          _checkEmailForUsernameInDatabase(username, firebaseEmail);
        })
        .catchError((error) {
          print('❌ Error al recargar usuario: $error');
        });
  }

  // Comprueba si el correo en la base de datos coincide con el de Firebase para el mismo username
  Future<void> _checkEmailForUsernameInDatabase(
    String username,
    String firebaseEmail,
  ) async {
    _isLoading = true;
    try {
      print('🔍 Verificando correo para username: $username');
      print('   Correo en Firebase: $firebaseEmail');

      // Obtener datos del usuario desde la base de datos usando el username
      final response = await http.get(
        Uri.parse(
          'http://localhost:8080/api/usuaris/usuario-por-username/$username',
        ),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        final databaseEmail = userData['email'] as String?;
        final pendingEmail = userData['pendingEmail'] as String?;

        _lastEmailInDb = databaseEmail;

        print('📋 Usuario en base de datos:');
        print('   Username: $username');
        print('   Email en Firebase: $firebaseEmail');
        print('   Email en DB: $databaseEmail');
        print('   Email pendiente: $pendingEmail');

        // Caso 1: El correo en Firebase es diferente al de la base de datos
        if (databaseEmail != null && databaseEmail != firebaseEmail) {
          print('⚠️ Diferencia detectada entre correos:');
          print('   Firebase: $firebaseEmail');
          print('   Base de datos: $databaseEmail');

          // Actualizar el correo en la base de datos para que coincida con Firebase
          await _updateEmailInDatabase(databaseEmail, firebaseEmail);
        }
        // Caso 2: El correo en Firebase coincide con pendingEmail
        else if (pendingEmail != null && pendingEmail == firebaseEmail) {
          print('🔄 El correo en Firebase coincide con el pendingEmail:');
          print('   Firebase: $firebaseEmail');
          print('   PendingEmail en DB: $pendingEmail');
          print('   Actualizando email principal en la base de datos...');

          // Actualizar el correo principal en la base de datos ya que se ha verificado en Firebase
          await _confirmPendingEmail(databaseEmail!, firebaseEmail);
        }
      } else {
        print(
          '❌ Error al obtener usuario por username: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error verificando correo por username: $e');
    } finally {
      _isLoading = false;
    }
  }

  // Actualiza el correo en la base de datos directamente (cuando Firebase y DB son diferentes)
  Future<void> _updateEmailInDatabase(String oldEmail, String newEmail) async {
    try {
      print(
        '✏️ Actualizando correo en la base de datos: $oldEmail → $newEmail',
      );

      final response = await http.post(
        Uri.parse('http://localhost:8080/api/usuaris/directUpdateEmail'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'oldEmail': oldEmail, 'newEmail': newEmail}),
      );

      if (response.statusCode == 200) {
        print('✅ Correo actualizado correctamente en la base de datos');
        _lastEmailInDb = newEmail;
      } else {
        print(
          '❌ Error actualizando correo: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error en actualización directa de correo: $e');
    }
  }

  // Confirma un correo pendiente (cuando Firebase coincide con pendingEmail)
  Future<void> _confirmPendingEmail(
    String currentEmail,
    String pendingEmail,
  ) async {
    try {
      print(
        '✅ Confirmando cambio de correo pendiente: $currentEmail → $pendingEmail',
      );

      final response = await http.post(
        Uri.parse('http://localhost:8080/api/usuaris/confirmEmail'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'currentEmail': pendingEmail,
          'oldEmail': currentEmail,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Correo pendiente confirmado en la base de datos');
        _lastEmailInDb = pendingEmail;
      } else {
        print(
          '❌ Error confirmando correo pendiente: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error confirmando correo pendiente: $e');
    }
  }

  // Método para limpiar recursos cuando se destruye la instancia
  void dispose() {
    _periodicCheckTimer?.cancel();
  }
}

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
}
