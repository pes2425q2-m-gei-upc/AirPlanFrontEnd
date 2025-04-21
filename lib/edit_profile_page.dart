import 'package:flutter/material.dart';
import 'package:airplan/user_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login_page.dart';
import 'dart:convert';
import 'services/websocket_service.dart';
import 'services/notification_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => EditProfilePageState();
}

class EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String _selectedLanguage = 'Castellano'; // Default language
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  File? _selectedImage;
  Uint8List? _webImage; // Para almacenar la imagen en formato web
  // Añadir un listener para los cambios de autenticación
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<String>?
  _profileUpdateSubscription; // For WebSocket updates

  final List<String> _languages = ['Castellano', 'Catalan', 'English'];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      // Intentar cargar los datos actuales del usuario
      _loadUserData();
    }

    // Añadir listener para los cambios de autenticación
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user == null && mounted) {
        // Usuario ha cerrado sesión o ha cambiado su autenticación
        // Navegar a la pantalla de inicio de sesión
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    });

    // Initialize and connect to WebSocket service
    _initWebSocketService();
  }

  // Initialize WebSocket service and subscribe to updates
  void _initWebSocketService() {
    // Connect to WebSocket for real-time updates
    WebSocketService().connect();

    // Subscribe to profile update events
    _profileUpdateSubscription = WebSocketService().profileUpdates.listen((
      message,
    ) {
      try {
        // Parse WebSocket message
        final data = json.decode(message);

        // Check if this is a profile update notification
        if (data['type'] == 'PROFILE_UPDATE') {
          // Check if this update is relevant for the current user
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null &&
              (data['username'] == currentUser.displayName ||
                  data['email'] == currentUser.email)) {
            // Reload user data from Firebase
            currentUser.reload().then((_) {
              // Then reload the updated user data from backend
              if (mounted) {
                _loadUserData();
              }
            });
          }
        }
      } catch (e) {
        // Ignoramos errores de procesamiento
      }
    });
  }

  Future<void> _loadUserData() async {
    // Obtener usuario actual de Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // El displayName en Firebase contiene el username
      final username = user.displayName ?? '';

      try {
        // Obtener datos completos del usuario desde el backend
        final response = await http.get(
          Uri.parse(
            'http://localhost:8080/api/usuaris/usuario-por-username/$username',
          ),
        );

        if (response.statusCode == 200 && mounted) {
          final userData = json.decode(response.body);

          // Actualizar los campos del formulario
          setState(() {
            // Nombre real desde la base de datos
            _nameController.text = userData['nom'] ?? '';
            // Username desde Firebase
            _usernameController.text = username;
            // Email desde Firebase (ya asignado en initState, pero lo mantenemos por completitud)
            _emailController.text = user.email ?? '';
            // Idioma si está disponible
            if (userData['idioma'] != null) {
              _selectedLanguage = userData['idioma'];
            }
          });
        } else if (mounted) {
          // Si no se puede obtener datos del backend, al menos configuramos el username
          setState(() {
            _usernameController.text = username;
          });
        }
      } catch (e) {
        if (mounted) {
          // En caso de error, configuramos el username desde Firebase
          setState(() {
            _usernameController.text = username;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    // Cancelar la suscripción al listener cuando se destruye la página
    _authStateSubscription?.cancel();
    // Cancel WebSocket subscription
    _profileUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && mounted) {
      if (kIsWeb) {
        // Para web, leemos los bytes de la imagen
        _webImage = await pickedFile.readAsBytes();
        setState(() {});
      } else {
        // Para aplicaciones móviles, usamos File
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (kIsWeb) {
      if (_webImage == null) return null;

      // Para web, enviamos los bytes de la imagen
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8080/api/uploadImage'),
      );

      // Crear un archivo temporal desde los bytes
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        _webImage!,
        filename: 'web_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      request.files.add(multipartFile);
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return responseBody;
      } else if (mounted) {
        // Reemplazar SnackBar con notificación de error
        NotificationService.showError(
          context,
          'Error al subir la imagen: ${response.statusCode}',
        );
        return null;
      }
      return null;
    } else {
      // Para móvil, usamos el método existente
      if (_selectedImage == null) return null;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8080/api/uploadImage'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return responseBody;
      } else if (mounted) {
        // Reemplazar SnackBar con notificación de error
        NotificationService.showError(
          context,
          'Error al subir la imagen: ${response.statusCode}',
        );
        return null;
      }
      return null;
    }
  }

  // Método para verificar si un nombre de usuario ya existe
  Future<bool> _checkUsernameExists(String username) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/usuaris/check-username/$username'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _saveProfile() async {
    if (!mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      NotificationService.showError(
        context,
        'No hay ningún usuario con sesión iniciada.',
      );
      return;
    }

    // Validar que los campos obligatorios no estén vacíos
    if (_nameController.text.trim().isEmpty) {
      NotificationService.showError(context, 'El nombre no puede estar vacío.');
      return;
    }

    if (_usernameController.text.trim().isEmpty) {
      NotificationService.showError(
        context,
        'El nombre de usuario no puede estar vacío.',
      );
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      NotificationService.showError(
        context,
        'El correo electrónico no puede estar vacío.',
      );
      return;
    }

    // Validar formato de correo electrónico
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      NotificationService.showError(
        context,
        'Por favor, introduce un correo electrónico válido.',
      );
      return;
    }

    final currentEmail = currentUser.email ?? '';
    final newEmail = _emailController.text.trim();
    final currentUsername = currentUser.displayName ?? '';
    final newUsername = _usernameController.text.trim();
    String? password;

    // Si el correo cambia, necesitamos reautenticar al usuario
    if (newEmail != currentEmail) {
      // Re-autenticar al usuario antes de proceder con el cambio de correo
      password = await _showReauthDialog();
      if (password == null || password.isEmpty) {
        if (mounted) {
          NotificationService.showInfo(context, 'Cambio de perfil cancelado.');
        }
        return;
      }

      final reauthSuccess = await _reauthenticateUser(password);
      if (!reauthSuccess) {
        return; // El método _reauthenticateUser ya muestra el mensaje de error
      }
    }

    String? imageUrl;
    // Subir imagen si se seleccionó
    if (_selectedImage != null || _webImage != null) {
      imageUrl = await _uploadImage();
    }

    if (!mounted) return;

    // Mostrar indicador de carga
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Actualizando perfil..."),
          ],
        ),
      ),
    );

    // Obtenemos el clientId para evitar notificaciones duplicadas
    final clientId = WebSocketService().clientId;

    // Preparar todos los datos para la petición unificada
    final updateData = {
      'currentEmail': currentEmail,
      'clientId': clientId,
      'username': newUsername,
      'oldUsername': currentUsername,
      'nom': _nameController.text.trim(),
      'idioma': _selectedLanguage,
    };

    // Añadir campos opcionales solo si existen
    if (newEmail != currentEmail && password != null) {
      updateData['newEmail'] = newEmail;
      updateData['password'] = password; // La contraseña para reautenticación
    } else if (newEmail != currentEmail) {
      updateData['newEmail'] = newEmail;
    }

    if (imageUrl != null) {
      updateData['photoURL'] = imageUrl;
    }

    try {
      // Realizar petición unificada al backend
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/usuaris/updateFullProfile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      // Cerrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bool success = responseData['success'] ?? false;
        final String message =
            responseData['message'] ?? 'Perfil actualizado correctamente';
        final String? customToken = responseData['customToken'] as String?;
        final bool emailChanged = newEmail != currentEmail;

        if (success) {
          // Si se cambió el correo y hay un token, lo utilizamos para mantener la sesión
          if (emailChanged && customToken != null && customToken.isNotEmpty) {
            try {
              // Iniciar sesión con el token personalizado para mantener la sesión activa
              await FirebaseAuth.instance.signInWithCustomToken(customToken);

              // Actualizar otros campos de Firebase Auth
              final updatedUser = FirebaseAuth.instance.currentUser;
              if (updatedUser != null) {
                if (imageUrl != null) {
                  await updatedUser.updatePhotoURL(imageUrl);
                }

                if (newUsername != currentUsername) {
                  await updatedUser.updateDisplayName(newUsername);
                }
              }

              // Notificar éxito y recargar datos
              if (mounted) {
                NotificationService.showSuccess(context, message);
                _loadUserData();
              }
            } catch (e) {
              if (mounted) {
                NotificationService.showInfo(
                  context,
                  '$message\nPero hubo un problema con tu sesión. Puede que tengas que iniciar sesión nuevamente.',
                );
              }
            }
          } else if (emailChanged) {
            // Si se cambió el correo pero no hay token, la sesión probablemente se cerrará
            if (mounted) {
              NotificationService.showInfo(
                context,
                '$message\nPor favor, inicia sesión nuevamente con tu nuevo correo.',
              );
              // _authStateSubscription redirigirá automáticamente al usuario
            }
          } else {
            // No se cambió el correo, actualizar solo los otros campos en Firebase
            try {
              if (imageUrl != null) {
                await currentUser.updatePhotoURL(imageUrl);
              }

              if (newUsername != currentUsername) {
                await currentUser.updateDisplayName(newUsername);
              }

              // Notificar éxito
              if (mounted) {
                NotificationService.showSuccess(context, message);
                _loadUserData();
              }
            } catch (e) {
              if (mounted) {
                NotificationService.showInfo(
                  context,
                  '$message\nAlgunos cambios podrían no verse reflejados inmediatamente.',
                );
                _loadUserData();
              }
            }
          }

          // Notificar a otros dispositivos sobre la actualización
          try {
            await http.post(
              Uri.parse(
                'http://localhost:8080/api/notifications/profile-updated',
              ),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'username': currentUsername,
                'newUsername': newUsername,
                'email': emailChanged ? newEmail : currentEmail,
                'updatedFields': updateData.keys.toList(),
                'clientId': clientId,
              }),
            );
          } catch (e) {
            // Ignorar errores al enviar notificaciones
          }
        } else {
          // Si success es false, mostrar el error
          if (mounted) {
            NotificationService.showError(
              context,
              responseData['error'] ?? 'Error al actualizar el perfil',
            );
          }
        }
      } else {
        // Error en la petición
        if (mounted) {
          String errorMessage;
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['error'] ?? 'Error desconocido';
            // Convertir a un mensaje más amigable
            errorMessage = _getFriendlyErrorMessage(errorMessage);
          } catch (e) {
            errorMessage = 'Error de comunicación con el servidor';
          }

          NotificationService.showError(context, errorMessage);
        }
      }
    } catch (e) {
      // Error en la comunicación o procesamiento
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        NotificationService.showError(
          context,
          _getFriendlyErrorMessage(e.toString()),
        );
      }
    }
  }

  // Método para mostrar diálogo de re-autenticación
  Future<bool> _reauthenticateUser(String password) async {
    if (!mounted) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Crear credenciales con el email actual y la contraseña proporcionada
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      // Re-autenticar al usuario
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      // Mensajes de error específicos para problemas de autenticación
      String errorMessage;

      switch (e.code) {
        case 'wrong-password':
          errorMessage =
              'La contraseña introducida es incorrecta. Por favor, verifica e intenta nuevamente.';
          break;
        case 'user-mismatch':
          errorMessage = 'Las credenciales no corresponden al usuario actual.';
          break;
        case 'user-not-found':
          errorMessage = 'No se encontró el usuario en el sistema.';
          break;
        case 'invalid-credential':
          errorMessage =
              'Las credenciales de autenticación proporcionadas no son válidas.';
          break;
        case 'invalid-email':
          errorMessage = 'El formato del correo electrónico no es válido.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Demasiados intentos fallidos. Por favor, espera un momento antes de volver a intentarlo.';
          break;
        default:
          errorMessage = 'Error en la autenticación: ${e.message}';
          break;
      }

      if (mounted) {
        NotificationService.showError(context, errorMessage);
      }
      return false;
    } catch (e) {
      // Para otros tipos de errores
      if (mounted) {
        NotificationService.showError(
          context,
          _getFriendlyErrorMessage(e.toString()),
        );
      }
      return false;
    }
  }

  // Diálogo para solicitar contraseña para re-autenticación
  Future<String?> _showReauthDialog() async {
    if (!mounted) return null;

    final passwordController = TextEditingController();
    bool obscurePassword = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Verificación necesaria'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Esta operación requiere verificación reciente. Por favor, ingresa tu contraseña para continuar.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.of(context).pop(passwordController.text),
                  child: const Text('Verificar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para manejar el cambio de correo electrónico con actualización directa
  Future<void> _handleEmailChange(
    String currentEmail,
    String newEmail,
    Map<String, dynamic> updatedData,
  ) async {
    if (!mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Verificamos si el correo electrónico ya está en uso
      bool emailInUse = false;
      try {
        final authMethods = await FirebaseAuth.instance
            .fetchSignInMethodsForEmail(newEmail);
        if (authMethods.isNotEmpty) {
          emailInUse = true;
        }
      } catch (e) {
        // Si hay un error al verificar, continuamos con el proceso
      }

      if (emailInUse) {
        // Si detectamos que el correo ya está en uso, mostramos el error directamente
        if (mounted) {
          NotificationService.showError(
            context,
            'El correo electrónico ya está siendo utilizado por otra cuenta.',
          );
        }
        return;
      }

      // Re-autenticar al usuario antes de proceder con el cambio de correo
      final password = await _showReauthDialog();
      if (password == null || password.isEmpty) {
        if (mounted) {
          NotificationService.showInfo(context, 'Cambio de correo cancelado.');
        }
        return;
      }

      final reauthSuccess = await _reauthenticateUser(password);
      if (!reauthSuccess) {
        return; // El método _reauthenticateUser ya muestra el mensaje de error
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Actualizando correo electrónico..."),
              ],
            ),
          ),
        );
      }

      // Obtenemos el clientId para evitar notificaciones duplicadas
      final clientId = WebSocketService().clientId;

      // Paso 1: Llamamos al backend para actualizar el correo en la base de datos
      // y en Firebase y notificar a otros dispositivos
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/usuaris/directUpdateEmail'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'oldEmail': currentEmail,
          'newEmail': newEmail,
          'clientId':
              clientId, // Para que este dispositivo no reciba la notificación
        }),
      );

      // Cerrar el indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (response.statusCode == 200) {
        // Decodificar la respuesta del servidor
        final responseData = json.decode(response.body);
        final bool success = responseData['success'] ?? false;
        final String message =
            responseData['message'] ?? 'Correo actualizado correctamente';
        final String? customToken = responseData['customToken'] as String?;

        if (success) {
          // Si tenemos un token personalizado, lo usamos para iniciar sesión
          if (customToken != null && customToken.isNotEmpty) {
            try {
              // Iniciar sesión con el token personalizado para mantener la sesión activa
              await FirebaseAuth.instance.signInWithCustomToken(customToken);

              // Paso 2: Actualizamos el resto del perfil
              final profileResult = await UserService.editUser(
                newEmail, // Usamos el nuevo correo como identificador
                updatedData,
              );

              if (mounted) {
                if (profileResult['success']) {
                  try {
                    // Paso 3: Actualizamos otros campos locales en Firebase si es necesario
                    final updatedUser = FirebaseAuth.instance.currentUser;
                    if (updatedUser != null) {
                      if (updatedData['photoURL'] != null) {
                        await updatedUser.updatePhotoURL(
                          updatedData['photoURL'],
                        );
                      }

                      final String newUsername = updatedData['username'] ?? '';
                      final String currentUsername =
                          updatedUser.displayName ?? '';
                      if (newUsername.isNotEmpty &&
                          newUsername != currentUsername) {
                        await updatedUser.updateDisplayName(newUsername);
                      }
                    }

                    // Mostrar notificación de éxito
                    NotificationService.showSuccess(context, message);

                    // Recargar la página para reflejar los cambios
                    _loadUserData();
                  } catch (e) {
                    NotificationService.showInfo(
                      context,
                      '$message\nAlgunos detalles del perfil pueden no haberse actualizado completamente.',
                    );
                    _loadUserData();
                  }
                } else {
                  // Error al actualizar el perfil
                  NotificationService.showError(
                    context,
                    'El correo se actualizó pero hubo un error al actualizar el perfil: ${profileResult['error']}',
                  );
                }
              }
            } catch (e) {
              // Si falla la autenticación con token personalizado
              if (mounted) {
                NotificationService.showInfo(
                  context,
                  '$message\nPero tu sesión se ha desconectado. Inicia sesión nuevamente con el nuevo correo.',
                );
                // La sesión se cerró automáticamente y _authStateSubscription llevará al usuario a la pantalla de login
              }
            }
          } else {
            // No hay token personalizado, el proceso fue exitoso pero la sesión se cerrará
            if (mounted) {
              NotificationService.showInfo(
                context,
                '$message\nPor favor, inicia sesión nuevamente con tu nuevo correo.',
              );
              // La sesión se cerrará automáticamente y _authStateSubscription llevará al usuario a la pantalla de login
            }
          }
        } else {
          // Si success es false, mostrar el mensaje de error del servidor
          if (mounted) {
            NotificationService.showError(
              context,
              responseData['error'] ?? 'Error al actualizar el correo',
            );
          }
        }
      } else {
        // Error al actualizar el correo
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? 'Error desconocido';
        } catch (e) {
          errorMessage = 'Error de comunicación con el servidor';
        }

        if (mounted) {
          NotificationService.showError(
            context,
            'Error al actualizar el correo: $errorMessage',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Manejar errores específicos de Firebase Auth
      String errorMessage;

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage =
              'El correo electrónico ya está siendo utilizado por otra cuenta.';
          break;
        case 'invalid-email':
          errorMessage = 'El formato del correo electrónico no es válido.';
          break;
        case 'requires-recent-login':
          errorMessage =
              'Esta operación es sensible. Por favor, intenta iniciar sesión nuevamente antes de cambiar el correo.';
          break;
        default:
          errorMessage = 'Error al cambiar el correo electrónico: ${e.message}';
      }

      // Mostrar mensaje de error
      if (mounted) {
        NotificationService.showError(context, errorMessage);
      }
    } catch (e) {
      // Capturar cualquier otro tipo de error
      if (mounted) {
        NotificationService.showError(
          context,
          'Error al cambiar el correo electrónico: $e',
        );
      }
    }
  }

  // Método para cambiar la contraseña
  Future<void> _changePassword() async {
    if (!mounted) return;

    // Obtener el usuario actual
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      NotificationService.showError(context, 'No hay usuario autenticado');
      return;
    }

    // Validar contraseñas
    if (_currentPasswordController.text.isEmpty) {
      NotificationService.showError(
        context,
        'Debes introducir tu contraseña actual',
      );
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      NotificationService.showError(
        context,
        'La nueva contraseña no puede estar vacía',
      );
      return;
    }

    // Validar que la nueva contraseña tenga al menos 8 caracteres (requisito de Firebase)
    if (_newPasswordController.text.length < 8) {
      NotificationService.showError(
        context,
        'La nueva contraseña debe tener al menos 8 caracteres',
      );
      return;
    }

    // Validar que las contraseñas coincidan
    if (_newPasswordController.text != _confirmPasswordController.text) {
      NotificationService.showError(context, 'Las contraseñas no coinciden');
      return;
    }

    // Mostrar indicador de carga
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Actualizando contraseña..."),
            ],
          ),
        ),
      );
    }

    try {
      // 1. Crear credenciales para reautenticar
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      // 2. Reautenticar al usuario (necesario para operaciones sensibles)
      await user.reauthenticateWithCredential(credential);

      // 3. Cambiar contraseña
      await user.updatePassword(_newPasswordController.text);

      // 4. Notificar a otros dispositivos sobre el cambio de contraseña
      // Obtenemos el clientId para evitar notificaciones duplicadas
      final clientId = WebSocketService().clientId;
      try {
        await http.post(
          Uri.parse('http://localhost:8080/api/notifications/profile-updated'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': user.displayName ?? '',
            'email': user.email ?? '',
            'updatedFields': [
              'password',
            ], // Marcamos explícitamente que se actualizó la contraseña
            'clientId': clientId, // Evitar notificación al dispositivo actual
          }),
        );
      } catch (e) {
        // Ignoramos errores al enviar notificaciones
        // Ya cambiamos la contraseña exitosamente
      }

      // Ocultar indicador de carga

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Limpiar los campos de contraseña
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        // Mostrar notificación de éxito
        NotificationService.showSuccess(
          context,
          'Contraseña actualizada correctamente',
        );
      }
    } on FirebaseAuthException catch (e) {
      // Ocultar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      String errorMessage;

      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'La contraseña actual es incorrecta';
          break;
        case 'requires-recent-login':
          errorMessage =
              'Esta operación es sensible y requiere una autenticación reciente. Por favor, cierra sesión y vuelve a iniciarla.';
          break;
        case 'weak-password':
          errorMessage =
              'La nueva contraseña es débil. Usa una contraseña más segura que incluya letras, números y símbolos.';
          break;
        case 'invalid-credential':
          errorMessage =
              'Las credenciales proporcionadas no son válidas. Verifica tu contraseña actual.';
          break;
        case 'user-token-expired':
          errorMessage =
              'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.';
          break;
        default:
          errorMessage = 'Error al cambiar la contraseña: ${e.message}';
      }

      if (mounted) {
        NotificationService.showError(context, errorMessage);
      }
    } catch (e) {
      // Ocultar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        NotificationService.showError(
          context,
          'Error al cambiar la contraseña: ${_getFriendlyErrorMessage(e.toString())}',
        );
      }
    }
  }

  // Método para interpretar los mensajes de error del backend y presentarlos de forma amigable
  String _getFriendlyErrorMessage(String errorMessage) {
    // Detectar mensajes de error comunes y convertirlos a mensajes amigables
    if (errorMessage.contains('duplicate key') ||
        errorMessage.contains('já está em ús')) {
      if (errorMessage.contains('username')) {
        return 'El nombre de usuario ya está en uso. Por favor, elige otro nombre de usuario.';
      }
      if (errorMessage.contains('email')) {
        return 'El correo electrónico ya está registrado. Por favor, usa otro correo electrónico o inicia sesión con esa cuenta.';
      }
    }

    // Mensajes específicos del formulario
    if (errorMessage.contains('email') && errorMessage.contains('formato')) {
      return 'El formato del correo electrónico no es válido.';
    }

    // Errores de autenticación
    if (errorMessage.contains('wrong-password') ||
        errorMessage.contains('incorrecta')) {
      return 'La contraseña proporcionada es incorrecta. Por favor, verifica tus credenciales.';
    }

    // Errores de disponibilidad del servidor
    if (errorMessage.contains('refused') || errorMessage.contains('timeout')) {
      return 'No se pudo conectar con el servidor. Por favor, verifica tu conexión a internet e inténtalo de nuevo.';
    }

    // Para cualquier otro error, devolver un mensaje genérico o el error original si es descriptivo
    if (errorMessage.length > 100) {
      return 'Ocurrió un error al procesar tu solicitud. Por favor, inténtalo de nuevo más tarde.';
    }

    return errorMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mostrar la imagen previa elegida
            if (_selectedImage != null && !kIsWeb)
              Image.file(
                _selectedImage!,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            if (_webImage != null && kIsWeb)
              Image.memory(
                _webImage!,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            TextButton(
              onPressed: _pickImage,
              child: const Text('Select Profile Image'),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              items:
                  _languages.map((language) {
                    return DropdownMenuItem(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value ?? 'Castellano';
                });
              },
              decoration: const InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Save Changes'),
            ),

            // Sección de cambio de contraseña
            const SizedBox(height: 40),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Cambiar Contraseña',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // Contraseña actual
            TextField(
              controller: _currentPasswordController,
              obscureText: !_isCurrentPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Contraseña Actual',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isCurrentPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nueva contraseña
            TextField(
              controller: _newPasswordController,
              obscureText: !_isNewPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Nueva Contraseña',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isNewPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isNewPasswordVisible = !_isNewPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirmar nueva contraseña
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Confirmar Nueva Contraseña',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Actualizar Contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}
