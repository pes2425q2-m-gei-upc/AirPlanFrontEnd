import 'package:flutter/material.dart';
import 'package:airplan/user_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
// Añadido para usar jsonEncode
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:async'; // Para StreamSubscription
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login_page.dart'; // Para la página de login
import 'dart:convert'; // Para json.decode
import 'services/websocket_service.dart'; // Add WebSocket service
import 'services/notification_service.dart'; // Importar nuestro nuevo servicio

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
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

  final List<String> _languages = [
    'Castellano',
    'Catalan',
    'English',
  ]; // Example languages

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
            print('💫 Received profile update notification, reloading data...');

            // Reload user data from Firebase
            currentUser.reload().then((_) {
              // Then reload the updated user data from backend
              _loadUserData();
            });
          }
        }
      } catch (e) {
        print('Error processing WebSocket message: $e');
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

        if (response.statusCode == 200) {
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
        } else {
          // Si no se puede obtener datos del backend, al menos configuramos el username
          setState(() {
            _usernameController.text = username;
          });
        }
      } catch (e) {
        print('Error al cargar datos de usuario: $e');
        // En caso de error, configuramos el username desde Firebase
        setState(() {
          _usernameController.text = username;
        });
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

    if (pickedFile != null) {
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
      } else {
        // Reemplazar SnackBar con notificación de error
        NotificationService.showError(
          context,
          'Error al subir la imagen: ${response.statusCode}',
        );
        return null;
      }
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
      } else {
        // Reemplazar SnackBar con notificación de error
        NotificationService.showError(
          context,
          'Error al subir la imagen: ${response.statusCode}',
        );
        return null;
      }
    }
  }

  void _saveProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(
        context,
        'No hay ningún usuario con sesión iniciada.',
      );
      return;
    }

    String? imageUrl;
    // Upload image if selected
    if (_selectedImage != null || _webImage != null) {
      imageUrl = await _uploadImage();
      if (imageUrl != null) {
        try {
          await currentUser.updatePhotoURL(imageUrl);
          print('Firebase profile image URL updated: $imageUrl');
        } catch (e) {
          // Reemplazar SnackBar con notificación de error
          NotificationService.showError(
            context,
            'Error al actualizar la imagen de perfil en Firebase: $e',
          );
          return;
        }
      }
    }

    final currentEmail = currentUser.email ?? '';
    final newEmail = _emailController.text.trim();
    final currentUsername =
        currentUser.displayName ?? ''; // Nombre de usuario actual
    final newUsername = _usernameController.text.trim();

    // Actualizar el displayName en Firebase Auth si el username ha cambiado
    if (newUsername != currentUsername) {
      try {
        await currentUser.updateDisplayName(newUsername);
        print('Firebase displayName updated to: $newUsername');
      } catch (e) {
        // Reemplazar SnackBar con notificación de error
        NotificationService.showError(
          context,
          'Error al actualizar el nombre de usuario en Firebase Auth: $e',
        );
        return;
      }
    }

    // Preparar datos actualizados sin incluir el correo si ha cambiado
    final updatedData = {
      'nom': _nameController.text.trim(),
      'username': newUsername,
      'oldUsername': currentUsername, // Añadir el nombre de usuario original
      'idioma': _selectedLanguage,
      'photoURL': imageUrl,
    };

    // Comprobar si el email ha cambiado
    if (newEmail != currentEmail) {
      await _handleEmailChange(currentEmail, newEmail, updatedData);
    } else {
      // Si el correo no cambió, actualizar normalmente el perfil
      final result = await UserService.editUser(currentEmail, updatedData);

      if (result['success']) {
        // Reemplazar SnackBar con notificación de éxito
        NotificationService.showSuccess(
          context,
          '¡Perfil actualizado correctamente!',
        );

        // Notify backend of profile update for WebSocket notification to other devices
        try {
          final clientId = WebSocketService().clientId;
          await http.post(
            Uri.parse(
              'http://localhost:8080/api/notifications/profile-updated',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username':
                  currentUsername, // Usar el username anterior para la notificación
              'newUsername': newUsername, // Añadir el nuevo username
              'email': currentEmail,
              'updatedFields': updatedData.keys.toList(),
              'clientId': clientId, // Incluir el clientId en la notificación
            }),
          );
          print('✅ Profile update notification sent with clientId: $clientId');
        } catch (e) {
          print('❌ Error sending profile update notification: $e');
        }
      } else {
        // Reemplazar SnackBar con notificación de error
        NotificationService.showError(context, 'Error: ${result['error']}');
      }
    }
  }

  // Método para mostrar diálogo de re-autenticación
  Future<bool> _reauthenticateUser(String password) async {
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
    } catch (e) {
      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(
        context,
        'Error en la re-autenticación: $e',
      );
      return false;
    }
  }

  // Diálogo para solicitar contraseña para re-autenticación
  Future<String?> _showReauthDialog() async {
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

  // Método para manejar el cambio de correo electrónico con re-autenticación
  Future<void> _handleEmailChange(
    String currentEmail,
    String newEmail,
    Map<String, dynamic> updatedData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Intentar enviar correo de verificación a través de Firebase
      await currentUser.verifyBeforeUpdateEmail(newEmail);

      // Actualizar el resto de datos del perfil (sin cambiar el correo aún)
      final profileResult = await UserService.editUser(
        currentEmail,
        updatedData,
      );

      if (profileResult['success']) {
        // Reemplazar SnackBar con notificación de información
        NotificationService.showInfo(
          context,
          'Perfil actualizado. Verifica tu nuevo correo para completar el cambio.',
        );
      } else {
        // Reemplazar SnackBar con notificación de error
        NotificationService.showError(
          context,
          'Error al actualizar perfil: ${profileResult['error']}',
        );
      }
    } catch (e) {
      // Manejar el error específicamente
      String errorMessage;
      if (e.toString().contains('requires-recent-login')) {
        // Si se requiere re-autenticación, mostrar diálogo
        final password = await _showReauthDialog();
        if (password != null && password.isNotEmpty) {
          // Intentar re-autenticar al usuario
          final success = await _reauthenticateUser(password);
          if (success) {
            // Si la re-autenticación fue exitosa, intentar nuevamente
            _handleEmailChange(currentEmail, newEmail, updatedData);
            return;
          }
        } else {
          // El usuario canceló la re-autenticación
          NotificationService.showInfo(context, 'Cambio de correo cancelado.');
          return;
        }
        errorMessage =
            'Se requiere iniciar sesión nuevamente para cambiar el correo.';
      } else {
        errorMessage = 'Error al cambiar el correo electrónico: $e';
      }
      // Mostrar mensaje de error
      NotificationService.showError(context, errorMessage);
    }
  }

  // Método para cambiar la contraseña
  Future<void> _changePassword() async {
    // Obtener el usuario actual
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(context, 'No hay usuario autenticado');
      return;
    }

    // Validar contraseñas
    if (_currentPasswordController.text.isEmpty) {
      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(
        context,
        'Debes introducir tu contraseña actual',
      );
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(
        context,
        'La nueva contraseña no puede estar vacía',
      );
      return;
    }

    // Validar que la nueva contraseña tenga al menos 8 caracteres (requisito de Firebase)
    if (_newPasswordController.text.length < 8) {
      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(
        context,
        'La nueva contraseña debe tener al menos 8 caracteres',
      );
      return;
    }

    // Validar que las contraseñas coincidan
    if (_newPasswordController.text != _confirmPasswordController.text) {
      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(context, 'Las contraseñas no coinciden');
      return;
    }

    try {
      // Crear credenciales para reautenticar
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      // Reautenticar usuario
      await user.reauthenticateWithCredential(credential);

      // Cambiar contraseña
      await user.updatePassword(_newPasswordController.text);

      // Limpiar los campos de contraseña
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Reemplazar SnackBar con notificación de éxito
      NotificationService.showSuccess(
        context,
        'Contraseña actualizada correctamente',
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'La contraseña actual es incorrecta';
          break;
        case 'requires-recent-login':
          errorMessage =
              'Esta operación es sensible y requiere autenticación reciente. Inicia sesión de nuevo.';
          break;
        case 'weak-password':
          errorMessage =
              'La contraseña es débil. Usa una contraseña más fuerte.';
          break;
        default:
          errorMessage = 'Error: ${e.message}';
      }

      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(context, errorMessage);
    } catch (e) {
      // Reemplazar SnackBar con notificación de error
      NotificationService.showError(
        context,
        'Error al cambiar la contraseña: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile')),
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
              child: Text('Select Profile Image'),
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
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
              decoration: InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              child: Text('Save Changes'),
            ),

            // Sección de cambio de contraseña
            SizedBox(height: 40),
            Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                border: OutlineInputBorder(),
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
            SizedBox(height: 16),

            // Nueva contraseña
            TextField(
              controller: _newPasswordController,
              obscureText: !_isNewPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Nueva Contraseña',
                border: OutlineInputBorder(),
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
            SizedBox(height: 16),

            // Confirmar nueva contraseña
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Confirmar Nueva Contraseña',
                border: OutlineInputBorder(),
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
            SizedBox(height: 24),

            ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Actualizar Contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}
