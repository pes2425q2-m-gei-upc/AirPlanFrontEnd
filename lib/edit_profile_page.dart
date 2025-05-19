import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io'; // Keep for File type
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
import 'services/auth_service.dart'; // Import AuthService
import 'main.dart'; // Importamos main.dart para acceder a profileUpdateStreamController
import 'package:easy_localization/easy_localization.dart';

class EditProfilePage extends StatefulWidget {
  final AuthService?
  authService; // Add AuthService parameter for dependency injection
  final WebSocketService?
  webSocketService; // Add WebSocketService parameter for testing

  const EditProfilePage({super.key, this.authService, this.webSocketService});

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
  late final String _initialLanguage;
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

  // Auth service instance
  late final AuthService _authService;

  final List<String> _languages = ['Castellano', 'Catalan', 'English'];

  // Notification service instance
  final NotificationService _notificationService = NotificationService();

  String? _nameError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    // Initialize the AuthService with the provided one or create a new one
    _authService = widget.authService ?? AuthService();

    final user = _authService.getCurrentUser();
    if (user != null) {
      _emailController.text = user.email ?? '';
      // Intentar cargar los datos actuales del usuario
      _loadUserData();
    }

    _initialLanguage = _selectedLanguage;

    // Añadir listener para los cambios de autenticación
    _authStateSubscription = _authService.authStateChanges.listen((User? user) {
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
    // Use injected webSocketService or create a new one
    final webSocketService = widget.webSocketService ?? WebSocketService();

    // Connect to WebSocket for real-time updates
    webSocketService.connect();

    // Subscribe to profile update events
    _profileUpdateSubscription = webSocketService.profileUpdates.listen((
      message,
    ) {
      try {
        // Parse WebSocket message
        final data = json.decode(message);

        // Check if this is a profile update notification
        if (data['type'] == 'PROFILE_UPDATE') {
          // Check if this update is relevant for the current user
          final currentUser = _authService.getCurrentUser();
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
    // Obtener usuario actual a través del servicio de autenticación
    final user = _authService.getCurrentUser();
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
              _initialLanguage = _selectedLanguage;
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
        // _notificationService.showError(context, 'Error al cargar datos del perfil.');
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
    // Configurar para seleccionar una sola imagen con opciones de calidad y tamaño
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // Calidad de imagen (0-100)
      maxHeight: 800, // Limitar altura máxima
      maxWidth: 800, // Limitar anchura máxima
    );

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

  // --- Refactored _saveProfile ---

  void _saveProfile() async {
    if (!_validateInputFields()) return;

    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
      _notificationService.showError(
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

    // 3. Prepare Update Data, incluyendo la imagen directamente en la petición
    final updateData = await _prepareUpdateDataWithImage(
      currentEmail,
      newEmail,
      currentUsername,
      newUsername,
      password,
    );

    if (!mounted) return;

    // 4. Perform Backend Update
    await _performBackendUpdate(
      updateData,
      currentEmail,
      newEmail,
      currentUsername,
      newUsername,
      updateData['photoURL'] as String?,
      emailChanged,
    );

    // 5. Si el usuario cambió idioma y la actualización fue exitosa, aplicar nuevo locale
    if (_selectedLanguage != _initialLanguage) {
      final raw = _selectedLanguage.toLowerCase();
      final code =
          raw.contains('eng')
              ? 'en'
              : raw.contains('castellano')
              ? 'es'
              : raw.contains('ca')
              ? 'ca'
              : 'en';
      await context.setLocale(Locale(code));
      _initialLanguage = _selectedLanguage;
    }

    // 6. Hide Loading Indicator (regardless of success/failure)
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  // Helper to display error messages in dialogs
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _validateInputFields() {
    if (_nameController.text.trim().isEmpty) {
      _showErrorDialog('El nombre no puede estar vacío.');
      return false;
    }
    if (_usernameController.text.trim().isEmpty) {
      _showErrorDialog('El nombre de usuario no puede estar vacío.');
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('El correo electrónico no puede estar vacío.');
      return false;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showErrorDialog('Por favor, introduce un correo electrónico válido.');
      return false;
    }
    return true;
  }

  Future<String?> _handleEmailChangeReauth() async {
    final password = await _showReauthDialog();
    // Added mounted check
    if (!mounted) return null;
    if (password == null || password.isEmpty) {
      _notificationService.showInfo(context, 'Cambio de perfil cancelado.');
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

  Future<Map<String, dynamic>> _prepareUpdateDataWithImage(
    String currentEmail,
    String newEmail,
    String currentUsername,
    String newUsername,
    String? password,
  ) async {
    // Usar el webSocketService inyectado si está disponible
    final webSocketService = widget.webSocketService ?? WebSocketService();

    final updateData = {
      'currentEmail': currentEmail,
      'clientId': webSocketService.clientId,
      'username':
          currentUsername, // Solo enviar el username actual para identificar al usuario
      'nom': _nameController.text.trim(),
      'idioma': _selectedLanguage,
    };

    if (newEmail != currentEmail) {
      updateData['newEmail'] = newEmail;
      if (password != null) {
        updateData['password'] = password; // Password for re-authentication
      }
    }

    // Incluir la imagen si se ha seleccionado una
    if (_selectedImage != null || _webImage != null) {
      // Convertir la imagen a base64 para incluirla en la petición JSON
      String base64Image;

      if (kIsWeb && _webImage != null) {
        // Para web, ya tenemos los bytes
        base64Image = base64Encode(_webImage!);
      } else if (_selectedImage != null) {
        // Para móvil, leemos los bytes del archivo
        List<int> imageBytes = await _selectedImage!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      } else {
        return updateData; // No hay imagen para incluir
      }

      String fileName =
          kIsWeb
              ? 'web_image_${DateTime.now().millisecondsSinceEpoch}.jpg'
              : _selectedImage!.path.split('/').last;

      updateData['imageData'] = base64Image;
      updateData['fileName'] = fileName;
    }

    return updateData;
  }

  Future<void> _performBackendUpdate(
    Map<String, dynamic> updateData,
    String currentEmail,
    String newEmail,
    String currentUsername,
    String newUsername,
    String?
    imageUrl, // This imageUrl is from the potential separate upload, now unused here
    bool emailChanged,
  ) async {
    final currentUser =
        _authService
            .getCurrentUser(); // Use _authService instead of direct Firebase call
    if (currentUser == null) {
      return; // Should not happen if initial check passed
    }

    try {
      // Reset inline errors
      setState(() {
        _nameError = null;
        _emailError = null;
      });
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
        // Obtener la URL de la imagen desde la respuesta si se subió una imagen
        final String? imageUrlFromResponse =
            responseData['imageUrl'] as String?;
        // Use the URL from the response if available
        final String? photoURL = imageUrlFromResponse;

        if (success) {
          // Pass necessary variables to _handleSuccessfulUpdate
          await _handleSuccessfulUpdate(
            currentUser,
            message,
            customToken,
            emailChanged,
            photoURL, // Usar la URL de la imagen devuelta por el servidor
            newUsername,
            currentUsername,
            updateData,
            newEmail,
          );
        } else {
          _notificationService.showError(
            context,
            responseData['error'] ?? 'Error al actualizar el perfil',
          );
        }
      } else if (response.statusCode == 400) {
        // Inappropriate content error
        final errorData = json.decode(response.body);
        final field = errorData['field'] as String?;
        final message =
            errorData['error'] as String? ?? 'Contenido inapropiado';
        setState(() {
          if (field == 'nom') {
            _nameError = message;
          } else if (field == 'email') {
            _emailError = message;
          }
        });
        return;
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
        _notificationService.showError(context, errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _notificationService.showError(
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
    String? imageUrl, // This is the URL from the backend response
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
    String? imageUrl, // This is the URL from the backend response
    String newUsername,
    String currentUsername,
  ) async {
    try {
      await _authService.signInWithCustomToken(customToken);
      // Added mounted check
      if (!mounted) return;

      final updatedUser = _authService.getCurrentUser();
      if (updatedUser != null) {
        // Solo actualizar la foto de perfil si se proporciona una URL de imagen
        if (imageUrl != null) await updatedUser.updatePhotoURL(imageUrl);

        // Ya no actualizamos el nombre de usuario
        // Se ha eliminado: await updatedUser.updateDisplayName(newUsername);
      }
      // Added mounted check
      if (!mounted) return;
      _notificationService.showSuccess(context, message);
      // _loadUserData(); // Moved to the end of _handleSuccessfulUpdate
    } catch (e) {
      // Added mounted check
      if (!mounted) return;
      _notificationService.showInfo(
        context,
        '$message\nPero hubo un problema con tu sesión. Puede que tengas que iniciar sesión nuevamente.',
      );
    }
  }

  void _handleEmailChangeWithoutToken(String message) {
    _notificationService.showInfo(
      context,
      '$message\nPor favor, inicia sesión nuevamente con tu nuevo correo.',
    );
    // _authStateSubscription should handle redirection automatically
  }

  Future<void> _handleProfileUpdateWithoutEmailChange(
    User currentUser,
    String message,
    String? imageUrl, // This is the URL from the backend response
    String newUsername,
    String currentUsername,
  ) async {
    try {
      // Update Firebase profile picture if a new image URL was provided by the backend
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Assume imageUrl from backend is the correct one to use
        await currentUser.updatePhotoURL(imageUrl);
      }

      // Ya no actualizamos el username en Firebase Auth
      // Se ha eliminado: await currentUser.updateDisplayName(newUsername);

      // Added mounted check
      if (!mounted) return;
      _notificationService.showSuccess(context, message);
    } catch (e) {
      // Added mounted check
      if (!mounted) return;
      _notificationService.showInfo(
        context,
        '$message\nAlgunos cambios podrían no verse reflejados inmediatamente.',
      );
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
      // Usar el webSocketService inyectado si está disponible
      final webSocketService = widget.webSocketService ?? WebSocketService();

      // Filtrar 'username' y 'oldUsername' de updatedFields para no notificar cambios de username
      List<String> updatedFields = updateData.keys.toList();
      updatedFields.removeWhere(
        (field) => field == 'username' || field == 'oldUsername',
      );

      // Solo enviar notificación si hay campos actualizados o si cambió el email
      if (updatedFields.isNotEmpty || emailChanged) {
        await http.post(
          Uri.parse(ApiConfig().buildUrl('api/notifications/profile-updated')),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username':
                currentUsername, // Solo usar el username actual para identificar al usuario
            // Ya no enviamos 'newUsername' para evitar notificaciones de cambio de username
            'email': currentEmail,
            'updatedFields':
                updatedFields, // Lista filtrada sin 'username' ni 'oldUsername'
            'clientId': webSocketService.clientId, // Exclude current device
          }),
        );
      }
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
      _notificationService.showError(context, errorMessage);
      return false;
    } catch (e) {
      // Added mounted check
      if (!mounted) return false;
      _notificationService.showError(
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

    // Validations for passwords
    if (_currentPasswordController.text.isEmpty) {
      _showErrorDialog('Debes introducir tu contraseña actual');
      return;
    }
    if (_newPasswordController.text.isEmpty) {
      _showErrorDialog('La nueva contraseña no puede estar vacía');
      return;
    }
    if (_newPasswordController.text.length < 8) {
      _showErrorDialog('La nueva contraseña debe tener al menos 8 caracteres');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Las contraseñas no coinciden');
      return;
    }

    final user = _authService.getCurrentUser();
    if (user == null || user.email == null) {
      _showErrorDialog('No hay usuario autenticado o falta el email.');
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
      _notificationService.showSuccess(
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
      _notificationService.showError(context, errorMessage);
    } catch (e) {
      // Added mounted check
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _notificationService.showError(
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

  // Método para construir la imagen de perfil con mejor manejo para tests
  Widget _buildProfileImage(User? user) {
    // Si estamos en un test, user.photoURL podría ser null o una cadena vacía
    if (user?.photoURL == null || user!.photoURL!.isEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, size: 50, color: Colors.grey[700]),
      );
    } else {
      // Para uso normal, intentar cargar la imagen de red
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(user.photoURL!),
        // Fallback icon en caso de error de carga
        onBackgroundImageError: (_, __) {
          // Silenciosamente mostrar un icono en caso de error
          return;
        },
        child:
            user.photoURL == null ? const Icon(Icons.person, size: 50) : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();

    return Scaffold(
      appBar: AppBar(title: Text('edit_profile_title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview section
            Center(
              // Center the image preview and button
              child: Column(
                children: [
                  const SizedBox(height: 20), // Add some top spacing
                  // Display existing profile picture if available and no new one selected
                  if (_selectedImage == null && _webImage == null)
                    _buildProfileImage(currentUser),
                  // Display selected image preview
                  if (_selectedImage != null && !kIsWeb)
                    ClipOval(
                      // Make preview circular
                      child: Image.file(
                        _selectedImage!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (_webImage != null && kIsWeb)
                    ClipOval(
                      // Make preview circular
                      child: Image.memory(
                        _webImage!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    // Use icon button for better UX
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: Text('change_profile_picture'.tr()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24), // Increased space after image section
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'name_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline), // Add icon
                errorText: _nameError,
              ),
              onChanged: (_) => setState(() => _nameError = null),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'username_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.account_circle_outlined),
                hintText: 'username_not_modifiable'.tr(),
                helperText: 'username_helper'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'email_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined), // Add icon
                errorText: _emailError,
              ),
              onChanged: (_) => setState(() => _emailError = null),
              keyboardType: TextInputType.emailAddress,
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
              decoration: InputDecoration(
                labelText: 'language_label'.tr(),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.language), // Add icon
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              // Add icon to save button
              onPressed: _saveProfile,
              icon: const Icon(Icons.save),
              label: Text('save_changes'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ), // Adjust padding
              ),
            ),

            // Sección de cambio de contraseña
            const SizedBox(height: 40),
            const Divider(),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'change_password'.tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center, // Center title
              ),
            ),

            // Contraseña actual
            TextField(
              controller: _currentPasswordController,
              obscureText: !_isCurrentPasswordVisible,
              decoration: InputDecoration(
                labelText: 'current_password_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline), // Add icon
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
                labelText: 'new_password_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline), // Add icon
                helperText: 'helper_min_8_chars'.tr(),
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
                labelText: 'confirm_password_label'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline), // Add icon
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

            ElevatedButton.icon(
              // Add icon to change password button
              onPressed: _changePassword,
              icon: const Icon(Icons.sync_lock),
              label: Text('update_password'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Consider using Theme colors
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ), // Adjust padding
              ),
            ),
            const SizedBox(height: 40), // Increased space at the bottom
          ],
        ),
      ),
    );
  }
}
