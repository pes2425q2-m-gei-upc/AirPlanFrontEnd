import 'package:flutter/material.dart';
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
import 'services/api_config.dart'; // Importar la configuración de API
import 'main.dart'; // Importamos main.dart para acceder a profileUpdateStreamController

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
  StreamSubscription<Map<String, dynamic>>?
  _globalUpdateSubscription; // Para eventos globales

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
      // Added mounted check
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

    // Suscribirse a eventos globales
    _subscribeToGlobalEvents();
  }

  // Método para suscribirse a eventos globales
  void _subscribeToGlobalEvents() {
    _globalUpdateSubscription = profileUpdateStreamController.stream.listen((
      data,
    ) {
      // Si la app acaba de iniciarse o volver de segundo plano, recargar datos
      if (data['type'] == 'app_resumed' || data['type'] == 'app_launched') {
        if (mounted) {
          _loadUserData();
        }
      }
    });
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
              // Added mounted check
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
            ApiConfig().buildUrl('api/usuaris/usuario-por-username/$username'),
          ),
        );

        // Added mounted check
        if (!mounted) return;

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
        // Added mounted check
        if (!mounted) return;
        // En caso de error, configuramos el username desde Firebase
        setState(() {
          _usernameController.text = username;
        });
        // Optionally show an error message
        // NotificationService.showError(context, 'Error al cargar datos del perfil.');
      }
    }
  }

  @override
  void dispose() {
    // Cancelar todas las suscripciones
    _authStateSubscription?.cancel();
    _profileUpdateSubscription?.cancel();
    _globalUpdateSubscription?.cancel();

    // Liberar los controladores de texto
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
    String? imageUrl;
    http.MultipartRequest request;

    // Store current BuildContext before async operations
    final currentContext = context;

    if (kIsWeb) {
      if (_webImage == null) return null;
      request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig().buildUrl('api/uploadImage')),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          _webImage!,
          filename: 'web_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
    } else {
      if (_selectedImage == null) return null;
      request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig().buildUrl('api/uploadImage')),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );
    }

    try {
      final response = await request.send();
      // Verify that context is still valid after await
      if (!currentContext.mounted) return null;

      if (response.statusCode == 200) {
        // Parse the JSON response to extract the actual URL
        final responseString = await response.stream.bytesToString();
        // Verify that context is still valid after await
        if (!currentContext.mounted) return null;

        try {
          final jsonResponse = json.decode(responseString);
          if (jsonResponse.containsKey('imageUrl')) {
            // Get the base URL from ApiConfig
            final baseUrl = ApiConfig().buildUrl('').replaceAll('/api/', '');
            // Combine base URL with the relative path
            imageUrl = baseUrl + jsonResponse['imageUrl'];
          } else {
            // Verify context is mounted before using it
            if (!currentContext.mounted) return null;
            NotificationService.showError(
              currentContext,
              'Error: La respuesta del servidor no contiene una URL de imagen',
            );
          }
        } catch (e) {
          // Verify context is mounted before using it
          if (!currentContext.mounted) return null;
          NotificationService.showError(
            currentContext,
            'Error al procesar la respuesta del servidor: ${e.toString()}',
          );
        }
      } else {
        // Verify context is mounted before using it
        if (!currentContext.mounted) return null;
        NotificationService.showError(
          currentContext,
          'Error al subir la imagen: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Verify context is mounted before using it
      if (!currentContext.mounted) return null;
      NotificationService.showError(
        currentContext,
        'Error de red al subir la imagen: ${_getFriendlyErrorMessage(e.toString())}',
      );
    }
    return imageUrl;
  }

  // --- Refactored _saveProfile ---

  void _saveProfile() async {
    if (!_validateInputFields()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      NotificationService.showError(
        context,
        'No hay ningún usuario con sesión iniciada.',
      );
      return;
    }

    final currentEmail = currentUser.email ?? '';
    final newEmail = _emailController.text.trim();
    final currentUsername = currentUser.displayName ?? '';
    final newUsername = _usernameController.text.trim();
    bool emailChanged = newEmail != currentEmail;
    String? password;

    // 1. Handle Email Change and Re-authentication if necessary
    if (emailChanged) {
      password = await _handleEmailChangeReauth();
      if (password == null) return; // Re-authentication failed or cancelled
      // Added mounted check
      if (!mounted) return;
    }

    // 2. Show Loading Indicator
    _showLoadingIndicator("Actualizando perfil...");
    // Added mounted check
    if (!mounted) return;

    // 3. Upload Image if selected
    String? imageUrl = await _uploadImageIfNeeded();
    // Added mounted check after potential async gap
    if (!mounted) return;

    // 4. Prepare Update Data
    final updateData = _prepareUpdateData(
      currentEmail,
      newEmail,
      currentUsername,
      newUsername,
      imageUrl,
      password,
    );

    // 5. Perform Backend Update
    await _performBackendUpdate(
      updateData,
      currentEmail,
      newEmail,
      currentUsername,
      newUsername,
      imageUrl,
      emailChanged,
    );

    // 6. Hide Loading Indicator (regardless of success/failure)
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  bool _validateInputFields() {
    if (_nameController.text.trim().isEmpty) {
      NotificationService.showError(context, 'El nombre no puede estar vacío.');
      return false;
    }
    if (_usernameController.text.trim().isEmpty) {
      NotificationService.showError(
        context,
        'El nombre de usuario no puede estar vacío.',
      );
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      NotificationService.showError(
        context,
        'El correo electrónico no puede estar vacío.',
      );
      return false;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      NotificationService.showError(
        context,
        'Por favor, introduce un correo electrónico válido.',
      );
      return false;
    }
    return true;
  }

  Future<String?> _handleEmailChangeReauth() async {
    final password = await _showReauthDialog();
    // Added mounted check
    if (!mounted) return null;
    if (password == null || password.isEmpty) {
      NotificationService.showInfo(context, 'Cambio de perfil cancelado.');
      return null;
    }
    final reauthSuccess = await _reauthenticateUser(password);
    // Added mounted check
    if (!mounted) return null;
    return reauthSuccess ? password : null;
  }

  void _showLoadingIndicator(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImageIfNeeded() async {
    if (_selectedImage != null || _webImage != null) {
      return await _uploadImage();
    }
    return null;
  }

  Map<String, dynamic> _prepareUpdateData(
    String currentEmail,
    String newEmail,
    String currentUsername,
    String newUsername,
    String? imageUrl,
    String? password,
  ) {
    final clientId = WebSocketService().clientId;
    final updateData = {
      'currentEmail': currentEmail,
      'clientId': clientId,
      'username': newUsername,
      'oldUsername': currentUsername,
      'nom': _nameController.text.trim(),
      'idioma': _selectedLanguage,
    };

    if (newEmail != currentEmail) {
      updateData['newEmail'] = newEmail;
      if (password != null) {
        updateData['password'] = password; // Password for re-authentication
      }
    }
    if (imageUrl != null) {
      updateData['photoURL'] = imageUrl;
    }
    return updateData;
  }

  Future<void> _performBackendUpdate(
    Map<String, dynamic> updateData,
    String currentEmail,
    String newEmail,
    String currentUsername,
    String newUsername,
    String? imageUrl,
    bool emailChanged,
  ) async {
    final currentUser =
        FirebaseAuth.instance.currentUser; // Re-get current user just in case
    if (currentUser == null) {
      return; // Should not happen if initial check passed
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/updateFullProfile')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      // Added mounted check
      if (!mounted) return;

      // Hide loading indicator here before processing response
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bool success = responseData['success'] ?? false;
        final String message =
            responseData['message'] ?? 'Perfil actualizado correctamente';
        final String? customToken = responseData['customToken'] as String?;

        if (success) {
          // Pass necessary variables to _handleSuccessfulUpdate
          await _handleSuccessfulUpdate(
            currentUser,
            message,
            customToken,
            emailChanged,
            imageUrl,
            newUsername,
            currentUsername,
            updateData,
            newEmail,
          );
        } else {
          NotificationService.showError(
            context,
            responseData['error'] ?? 'Error al actualizar el perfil',
          );
        }
      } else {
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['error'] ??
              'Error desconocido (${response.statusCode})';
          errorMessage = _getFriendlyErrorMessage(errorMessage);
        } catch (e) {
          errorMessage =
              'Error de comunicación con el servidor (${response.statusCode})';
        }
        NotificationService.showError(context, errorMessage);
      }
    } catch (e) {
      // Added mounted check
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).hideCurrentSnackBar(); // Ensure hidden on exception
      NotificationService.showError(
        context,
        _getFriendlyErrorMessage(e.toString()),
      );
    }
  }

  // Update signature to include newEmail
  Future<void> _handleSuccessfulUpdate(
    User currentUser,
    String message,
    String? customToken,
    bool emailChanged,
    String? imageUrl,
    String newUsername,
    String currentUsername,
    Map<String, dynamic> updateData,
    String newEmail,
  ) async {
    if (emailChanged && customToken != null && customToken.isNotEmpty) {
      await _handleEmailChangeWithToken(
        message,
        customToken,
        imageUrl,
        newUsername,
        currentUsername,
      );
    } else if (emailChanged) {
      _handleEmailChangeWithoutToken(message);
    } else {
      await _handleProfileUpdateWithoutEmailChange(
        currentUser,
        message,
        imageUrl,
        newUsername,
        currentUsername,
      );
    }

    // Added mounted check before notification call
    if (!mounted) return;

    // Notify other devices (moved here to ensure it runs after local updates)
    // Use passed variables
    await _notifyOtherDevices(
      updateData,
      currentEmail: emailChanged ? newEmail : currentUser.email ?? '',
      currentUsername: currentUsername,
      newUsername: newUsername,
      emailChanged: emailChanged,
    );

    // Reload data after successful update and notifications
    if (mounted) {
      _loadUserData(); // Reload data to reflect changes locally
    }
  }

  Future<void> _handleEmailChangeWithToken(
    String message,
    String customToken,
    String? imageUrl,
    String newUsername,
    String currentUsername,
  ) async {
    try {
      await FirebaseAuth.instance.signInWithCustomToken(customToken);
      // Added mounted check
      if (!mounted) return;

      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser != null) {
        if (imageUrl != null) await updatedUser.updatePhotoURL(imageUrl);
        if (newUsername != currentUsername) {
          await updatedUser.updateDisplayName(newUsername);
        }
      }
      // Added mounted check
      if (!mounted) return;
      NotificationService.showSuccess(context, message);
      // _loadUserData(); // Moved to the end of _handleSuccessfulUpdate
    } catch (e) {
      // Added mounted check
      if (!mounted) return;
      NotificationService.showInfo(
        context,
        '$message\nPero hubo un problema con tu sesión. Puede que tengas que iniciar sesión nuevamente.',
      );
    }
  }

  void _handleEmailChangeWithoutToken(String message) {
    NotificationService.showInfo(
      context,
      '$message\nPor favor, inicia sesión nuevamente con tu nuevo correo.',
    );
    // _authStateSubscription should handle redirection automatically
  }

  Future<void> _handleProfileUpdateWithoutEmailChange(
    User currentUser,
    String message,
    String? imageUrl,
    String newUsername,
    String currentUsername,
  ) async {
    try {
      if (imageUrl != null) await currentUser.updatePhotoURL(imageUrl);
      if (newUsername != currentUsername) {
        await currentUser.updateDisplayName(newUsername);
      }
      // Added mounted check
      if (!mounted) return;
      NotificationService.showSuccess(context, message);
      // _loadUserData(); // Moved to the end of _handleSuccessfulUpdate
    } catch (e) {
      // Added mounted check
      if (!mounted) return;
      NotificationService.showInfo(
        context,
        '$message\nAlgunos cambios podrían no verse reflejados inmediatamente.',
      );
      // _loadUserData(); // Moved to the end of _handleSuccessfulUpdate
    }
  }

  Future<void> _notifyOtherDevices(
    Map<String, dynamic> updateData, {
    required String currentEmail,
    required String currentUsername,
    required String newUsername,
    required bool emailChanged,
  }) async {
    try {
      await http.post(
        Uri.parse(ApiConfig().buildUrl('api/notifications/profile-updated')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username':
              currentUsername, // Send original username for identification
          'newUsername': newUsername,
          'email':
              currentEmail, // Send the final email associated with the account
          'updatedFields': updateData.keys.toList(),
          'clientId': WebSocketService().clientId, // Exclude current device
        }),
      );
    } catch (e) {
      // Ignore errors here, main update was successful
    }
  }

  // Método para mostrar diálogo de re-autenticación
  Future<bool> _reauthenticateUser(String password) async {
    // Added mounted check at the beginning
    if (!mounted) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        return false; // Ensure user and email exist
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      // Added mounted check
      if (!mounted) return false;
      // ... (existing error handling)
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
      NotificationService.showError(context, errorMessage);
      return false;
    } catch (e) {
      // Added mounted check
      if (!mounted) return false;
      NotificationService.showError(
        context,
        _getFriendlyErrorMessage(e.toString()),
      );
      return false;
    }
  }

  // Diálogo para solicitar contraseña para re-autenticación
  Future<String?> _showReauthDialog() async {
    // Added mounted check at the beginning
    if (!mounted) return null;

    final passwordController = TextEditingController();
    bool obscurePassword = true;

    // Use context captured before the async gap
    final currentContext = context;

    return showDialog<String>(
      context: currentContext, // Use captured context
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Use dialogContext inside builder
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Use context from StatefulBuilder
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
                            // Use setStateDialog from StatefulBuilder
                            setStateDialog(() {
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
                  // Use dialogContext to pop
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed:
                      () =>
                      // Use dialogContext to pop
                      Navigator.of(dialogContext).pop(passwordController.text),
                  child: const Text('Verificar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para cambiar la contraseña
  Future<void> _changePassword() async {
    // Added mounted check at the beginning
    if (!mounted) return;

    // ... (validations for passwords)
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
    if (_newPasswordController.text.length < 8) {
      NotificationService.showError(
        context,
        'La nueva contraseña debe tener al menos 8 caracteres',
      );
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      NotificationService.showError(context, 'Las contraseñas no coinciden');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      NotificationService.showError(
        context,
        'No hay usuario autenticado o falta el email.',
      );
      return;
    }

    // Show loading indicator
    _showLoadingIndicator("Actualizando contraseña...");
    // Added mounted check
    if (!mounted) return;

    try {
      // 1. Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Added mounted check after await
      if (!mounted) return;

      // 2. Change password
      await user.updatePassword(_newPasswordController.text);

      // Added mounted check after await
      if (!mounted) return;

      // 3. Notify other devices
      await _notifyPasswordChange(user);

      // Added mounted check after await
      if (!mounted) return;

      // 4. Success feedback and cleanup
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      NotificationService.showSuccess(
        context,
        'Contraseña actualizada correctamente',
      );
    } on FirebaseAuthException catch (e) {
      // Added mounted check
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // ... (existing FirebaseAuthException handling)
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
      NotificationService.showError(context, errorMessage);
    } catch (e) {
      // Added mounted check
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      NotificationService.showError(
        context,
        'Error al cambiar la contraseña: ${_getFriendlyErrorMessage(e.toString())}',
      );
    }
  }

  // Helper to notify other devices about password change
  Future<void> _notifyPasswordChange(User user) async {
    final clientId = WebSocketService().clientId;
    try {
      await http.post(
        Uri.parse(ApiConfig().buildUrl('api/notifications/profile-updated')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': user.displayName ?? '',
          'email': user.email ?? '',
          'updatedFields': ['password'],
          'clientId': clientId,
        }),
      );
    } catch (e) {
      // Ignore notification errors
    }
  }

  // ... (rest of the file, including build method and _getFriendlyErrorMessage)
  // Ensure _getFriendlyErrorMessage is robust
  String _getFriendlyErrorMessage(String errorMessage) {
    // Existing checks...
    if (errorMessage.contains('duplicate key') ||
        errorMessage.contains(
          'já está em ús',
        ) || // Portuguese? Check backend consistency
        errorMessage.contains('already in use')) {
      // Add English check
      if (errorMessage.contains('username')) {
        return 'El nombre de usuario ya está en uso. Por favor, elige otro nombre de usuario.';
      }
      if (errorMessage.contains('email')) {
        return 'El correo electrónico ya está registrado. Por favor, usa otro correo electrónico o inicia sesión con esa cuenta.';
      }
    }
    if (errorMessage.contains('invalid-email') ||
        (errorMessage.contains('email') && errorMessage.contains('formato'))) {
      return 'El formato del correo electrónico no es válido.';
    }
    if (errorMessage.contains('wrong-password') ||
        errorMessage.contains('incorrecta')) {
      return 'La contraseña proporcionada es incorrecta. Por favor, verifica tus credenciales.';
    }
    if (errorMessage.contains('network error') || // Generic network error
        errorMessage.contains('refused') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('SocketException')) {
      // Common Dart network error
      return 'No se pudo conectar con el servidor. Por favor, verifica tu conexión a internet e inténtalo de nuevo.';
    }
    if (errorMessage.contains('requires-recent-login')) {
      return 'Esta operación requiere una autenticación reciente. Por favor, cierra sesión y vuelve a iniciarla.';
    }
    if (errorMessage.contains('weak-password')) {
      return 'La nueva contraseña es débil. Usa una contraseña más segura.';
    }
    if (errorMessage.contains('user-not-found')) {
      return 'Usuario no encontrado.';
    }
    if (errorMessage.contains('invalid-credential')) {
      return 'Credenciales inválidas.';
    }

    // Default fallback
    // Avoid showing overly technical details if possible
    if (errorMessage.length > 150 || errorMessage.contains('Exception')) {
      return 'Ocurrió un error inesperado. Por favor, inténtalo de nuevo más tarde.';
    }

    return errorMessage; // Return original if it's somewhat readable
  }

  @override
  Widget build(BuildContext context) {
    // ... (build method remains largely the same, ensure const where possible)
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ... (Image preview)
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
            const SizedBox(height: 16), // Added space before first field
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
              keyboardType: TextInputType.emailAddress, // Added keyboard type
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
                helperText: 'Mínimo 8 caracteres', // Added helper text
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
                backgroundColor: Colors.blue, // Consider using Theme colors
                foregroundColor: Colors.white,
              ),
              child: const Text('Actualizar Contraseña'),
            ),
            const SizedBox(height: 20), // Added space at the bottom
          ],
        ),
      ),
    );
  }
}
