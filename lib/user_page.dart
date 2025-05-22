import 'package:airplan/trophies_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/user_services.dart';
import 'package:airplan/services/websocket_service.dart';
import 'package:airplan/services/auth_service.dart'; // Import the auth service
import 'dart:convert';
import 'activity_details_page.dart';
import 'invitations_page.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'dart:async';
import 'main.dart';
import 'rating_page.dart';
import 'package:airplan/solicituds_service.dart';
import 'blocked_users_page.dart'; // Import para la página de usuarios bloqueados

// Type definitions for function injection
typedef GetUserRealNameFunc = Future<String> Function(String username);
typedef GetUserTypeAndLevelFunc =
    Future<Map<String, dynamic>> Function(String username);

class UserRequestsPage extends StatefulWidget {
  final String username;

  const UserRequestsPage({super.key, required this.username});

  @override
  UserRequestsPageState createState() => UserRequestsPageState();
}

class UserRequestsPageState extends State<UserRequestsPage> {
  late Future<List<Map<String, dynamic>>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = SolicitudsService().fetchUserRequests(widget.username);
  }

  Future<void> _cancelSolicitud(String activityId) async {
    try {
      await SolicitudsService().cancelarSolicitud(
        int.parse(activityId),
        widget.username,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud eliminada correctamente.')),
      );
      setState(() {
        _requestsFuture = SolicitudsService().fetchUserRequests(
          widget.username,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar la solicitud: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Solicitudes")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No has realizado solicitudes.'));
          }

          final requests = snapshot.data!;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return ListTile(
                title: Text(request['nom'] ?? 'Actividad sin nombre'),
                subtitle: Text(
                  'Creador: ${request['creador'] ?? 'Desconocido'}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _cancelSolicitud(request['id'].toString()),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ActivityDetailsPage(
                            id: request['id'].toString(),
                            title: request['nom'] ?? '',
                            creator: request['creador'] ?? '',
                            description: request['descripcio'] ?? '',
                            startDate: request['dataInici'] ?? '',
                            endDate: request['dataFi'] ?? '',
                            airQualityData: [],
                            isEditable: false,
                            onEdit: () {},
                            onDelete: () {},
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget para mostrar la información del usuario
class UserInfoCard extends StatelessWidget {
  final String realName;
  final String username;
  final String email;
  final bool isClient;
  final int userLevel;
  final bool isLoading;

  // Added const constructor
  const UserInfoCard({
    super.key,
    required this.realName,
    required this.username,
    required this.email,
    required this.isClient,
    required this.userLevel,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoListTile(
              icon: Icons.person,
              title: 'Nombre',
              value: realName,
              isLoading: isLoading,
            ),
            const Divider(),
            _buildInfoListTile(
              icon: Icons.alternate_email,
              title: 'Username',
              value: username,
              isLoading:
                  false, // Username comes directly from Firebase Auth, not loaded async here
            ),
            const Divider(),
            _buildInfoListTile(
              icon: Icons.email,
              title: 'Correo',
              value: email,
              isLoading: false, // Email comes directly from Firebase Auth
            ),
            if (isClient) ...[
              const Divider(),
              _buildInfoListTile(
                icon: Icons.star,
                title: 'Nivel',
                value: '$userLevel',
                isLoading: isLoading,
                iconColor: Colors.amber,
                isBold: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoListTile({
    required IconData icon,
    required String title,
    required String value,
    bool isLoading = false,
    Color iconColor = Colors.blue,
    bool isBold = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle:
          isLoading
              ? const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
    );
  }
}

class UserPage extends StatefulWidget {
  final bool isEmbedded;
  final AuthService? authService; // Add AuthService injection
  // Add optional function parameters for dependency injection
  final GetUserRealNameFunc? getUserRealNameFunc;
  final GetUserTypeAndLevelFunc? getUserTypeAndLevelFunc;
  // Add optional WebSocketService parameter
  final WebSocketService? webSocketService;

  const UserPage({
    super.key,
    this.isEmbedded = false,
    this.authService, // Add optional authService parameter
    this.getUserRealNameFunc,
    this.getUserTypeAndLevelFunc,
    this.webSocketService, // Add to constructor
  });

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  bool _isLoading = true;
  String _realName = 'Cargando...';
  // Variables para nivel de usuario
  int _userLevel = 0;
  bool _isClient = false;
  // WebSocket subscription for real-time updates
  StreamSubscription<String>? _profileUpdateSubscription;
  // Suscripción para eventos de actualización global
  StreamSubscription<Map<String, dynamic>>? _globalUpdateSubscription;

  // Store user data locally to avoid relying solely on FirebaseAuth.instance.currentUser
  User? _currentUser;
  String _username = '';
  String _email = '';
  String? _photoURL;

  // AuthService instance
  late final AuthService _authService;
  // WebSocketService instance
  late final WebSocketService _webSocketService;

  @override
  void initState() {
    super.initState();
    // Initialize the AuthService with the provided one or create a new one
    _authService = widget.authService ?? AuthService();
    // Initialize the WebSocketService with the provided one or create a new one
    _webSocketService = widget.webSocketService ?? WebSocketService();

    _currentUser = _authService.getCurrentUser();
    _updateLocalUserInfo(); // Initialize local user info

    // Inicializar la conexión WebSocket antes de cargar datos
    _ensureWebSocketConnection();
    _loadUserData();
    // Suscribirse a eventos globales de actualización
    _subscribeToGlobalUpdates();
  }

  // Helper to update local user info from _currentUser
  void _updateLocalUserInfo() {
    if (_currentUser != null) {
      _username = _currentUser!.displayName ?? 'Username no disponible';
      _email = _currentUser!.email ?? 'UsuarioSinEmail';
      _photoURL = _currentUser!.photoURL;
    } else {
      _username = 'Username no disponible';
      _email = 'UsuarioSinEmail';
      _photoURL = null;
    }
  }

  // Método para suscribirse a eventos globales
  void _subscribeToGlobalUpdates() {
    _globalUpdateSubscription = profileUpdateStreamController.stream.listen((
      data,
    ) {
      // Verificar si es un evento de reanudación de la app O inicio de la app
      if (data['type'] == 'app_resumed' || data['type'] == 'app_launched') {
        // Recargar datos cuando la app se reanuda desde segundo plano o cuando se inicia desde cero
        if (mounted) {
          debugPrint('UserPage: Recargando datos por evento ${data['type']}');
          setState(() {
            _isLoading = true;
          });
          _loadUserData();
        }
      }
    });
  }

  // Asegurar que la conexión WebSocket está activa
  void _ensureWebSocketConnection() {
    // Use the injected or default WebSocketService instance
    final webSocketService = _webSocketService;

    // Verificar si ya está conectado
    if (!webSocketService.isConnected) {
      webSocketService.connect();
    }

    // Inicializar escucha de eventos WebSocket
    _initWebSocketListener();
  }

  // Initialize WebSocket connection and listen for profile updates
  void _initWebSocketListener() {
    // Cancelar suscripción anterior si existe
    _profileUpdateSubscription?.cancel();

    // Listen for profile update events using the instance
    _profileUpdateSubscription = _webSocketService.profileUpdates.listen(
      (message) {
        // Added mounted check at the beginning of the callback
        if (!mounted) return;

        try {
          // Parse incoming message
          final data = json.decode(message);

          // Check if this is a profile update notification
          if (data['type'] == 'PROFILE_UPDATE') {
            // Check if the update is relevant for the current user
            // Use local _currentUser for consistency
            if (_currentUser != null &&
                (data['username'] == _username || data['email'] == _email)) {
              final updatedFields =
                  data['updatedFields'] as List<dynamic>? ?? [];
              final isEmailUpdate = updatedFields.contains('email');
              final isPasswordUpdate = updatedFields.contains('password');
              final isNameUpdate =
                  updatedFields.contains('nom') ||
                  updatedFields.contains('username') ||
                  updatedFields.contains('displayName');
              final isPhotoUpdate = updatedFields.contains('photoURL');

              // Determine if it's a critical change requiring re-login
              final isSessionResetRequired = isEmailUpdate || isPasswordUpdate;

              if (isSessionResetRequired) {
                _handleCriticalUpdate(isEmailUpdate, isPasswordUpdate);
              } else if (isNameUpdate || isPhotoUpdate) {
                _handleNonCriticalUpdate(isNameUpdate, isPhotoUpdate);
              } else {
                // Other non-critical updates (e.g., language)
                _handleNonCriticalUpdate(false, false); // Still reload data
              }
            }
          } else if (data['type'] == 'ACCOUNT_DELETED') {
            // Handle account deletion initiated from another device
            if (_currentUser != null &&
                (data['username'] == _username || data['email'] == _email)) {
              _handleAccountDeletedRemotely();
            }
          }
        } catch (e) {
          debugPrint("Error procesando mensaje WebSocket en UserPage: $e");
        }
      },
      onError: (error) {
        debugPrint("WebSocket error en UserPage: $error");
        // Attempt to reconnect after a delay if mounted
        if (mounted) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _ensureWebSocketConnection(); // Re-establish connection and listener
            }
          });
        }
      },
      onDone: () {
        debugPrint("WebSocket connection closed en UserPage");
        // Attempt to reconnect after a delay if mounted
        if (mounted) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _ensureWebSocketConnection(); // Re-establish connection and listener
            }
          });
        }
      },
    );
  }

  // Handles critical updates (email/password change) from WebSocket
  void _handleCriticalUpdate(bool isEmailUpdate, bool isPasswordUpdate) {
    String message = '';
    if (isEmailUpdate && isPasswordUpdate) {
      message =
          'Se han detectado cambios en tu correo y contraseña en otro dispositivo. Es necesario volver a iniciar sesión.';
    } else if (isEmailUpdate) {
      message =
          'Se ha detectado un cambio de correo electrónico en otro dispositivo. Es necesario volver a iniciar sesión.';
    } else {
      // isPasswordUpdate
      message =
          'Se ha detectado un cambio de contraseña en otro dispositivo. Es necesario volver a iniciar sesión.';
    }

    // Show info message and trigger logout/redirect
    _showInfoAndLogout(message);
  }

  // Handles non-critical updates (name, photo, etc.) from WebSocket
  void _handleNonCriticalUpdate(bool isNameUpdate, bool isPhotoUpdate) {
    if (!mounted) return;

    String message = 'Tu perfil ha sido actualizado en otro dispositivo.';
    if (isNameUpdate && isPhotoUpdate) {
      message =
          'Tu nombre y foto de perfil han sido actualizados en otro dispositivo.';
    } else if (isNameUpdate) {
      message = 'Tu nombre ha sido actualizado en otro dispositivo.';
    } else if (isPhotoUpdate) {
      message = 'Tu foto de perfil ha sido actualizada en otro dispositivo.';
    }

    final currentContext = context;
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );

    // Reload user data to reflect changes
    setState(() {
      _isLoading = true;
    });
    _loadUserData();
  }

  // Handles account deletion initiated remotely via WebSocket
  void _handleAccountDeletedRemotely() {
    _showInfoAndLogout(
      'Tu cuenta ha sido eliminada desde otro dispositivo. Serás redirigido a la pantalla de inicio de sesión.',
      title: 'Cuenta Eliminada',
    );
  }

  // Shows an informational SnackBar and then initiates the logout process
  void _showInfoAndLogout(String message, {String title = 'Cambio Detectado'}) {
    if (!mounted) return;

    final currentContext = context;
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4), // Slightly longer duration
      ),
    );

    // Initiate logout after a delay
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        // Use _handleSessionClose for unified logout logic
        _handleSessionClose(
          title: title,
          message: message, // Reuse message for dialog
          redirectToLogin: true,
          isRemoteAction: true, // Indicate this is due to a remote action
        );
      }
    });
  }

  // --- Deprecated: _handleAccountChangeOnAnotherDevice --- (Replaced by WebSocket handlers and _showInfoAndLogout)
  /*
  Future<void> _handleAccountChangeOnAnotherDevice({
    required bool isPasswordChange,
    required bool isEmailChange,
    required bool isNameChange,
  }) async {
     // ... (Previous complex logic involving reload, signout, etc.)
     // This logic is now simplified and handled within the WebSocket listener
     // and the _showInfoAndLogout -> _handleSessionClose flow.
  }
  */

  // Método para cargar los datos de usuario
  Future<void> _loadUserData() async {
    // Refresh _currentUser instance
    _currentUser = _authService.getCurrentUser();
    _updateLocalUserInfo(); // Update local vars like _username, _email, _photoURL

    if (_currentUser != null &&
        _username.isNotEmpty &&
        _username != 'Username no disponible') {
      try {
        // Use injected function or default static method
        final realNameFunc =
            widget.getUserRealNameFunc ?? UserService.getUserRealName;
        final typeLevelFunc =
            widget.getUserTypeAndLevelFunc ?? UserService.getUserTypeAndLevel;

        // Cargar el nombre real del usuario
        final realName = await realNameFunc(_username);

        // Obtener el tipo de usuario y nivel si es cliente
        final tipoInfo = await typeLevelFunc(_username);

        // Added mounted check after awaits
        if (!mounted) return;

        final tipo = tipoInfo['tipo'] as String?;
        final isClient = tipo == 'cliente';
        final nivel = isClient ? (tipoInfo['nivell'] as int?) ?? 0 : 0;

        setState(() {
          _realName = realName;
          _isClient = isClient;
          _userLevel = nivel;
          _isLoading = false;
        });
      } catch (e) {
        // Added mounted check in catch block
        if (!mounted) return;
        setState(() {
          _realName = 'Error al cargar datos';
          _isLoading = false;
        });
        debugPrint("Error loading user data details: $e");
        // Optionally show a snackbar error
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text("Error al cargar detalles del perfil.")),
        // );
      }
    } else {
      // No hay usuario autenticado o falta el username
      if (mounted) {
        // Handle scenario where user becomes null unexpectedly
        _handleSessionClose(
          title: 'Sesión Expirada',
          message:
              'Tu sesión ha expirado o no se pudo verificar. Por favor, inicia sesión nuevamente.',
          redirectToLogin: true,
          isRemoteAction: false,
        );
      }
    }
  }

  // --- Removed redundant refresh logic (_needsRefresh, didChangeDependencies, markForRefresh) ---
  // Refreshing is handled by calling _loadUserData directly after returning from EditProfilePage
  // and via WebSocket updates.

  @override
  void dispose() {
    // Cancel profile update subscription when the page is disposed
    _profileUpdateSubscription?.cancel();
    _globalUpdateSubscription?.cancel();
    // Dispose the WebSocketService ONLY if it was created internally
    if (widget.webSocketService == null) {
      _webSocketService.dispose();
    }
    super.dispose();
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    // Capture context and check mounted status early
    if (!context.mounted) return;
    final contextCaptured = context;

    // Use local _currentUser
    if (_currentUser == null || _email.isEmpty || _email == 'UsuarioSinEmail') {
      ScaffoldMessenger.of(contextCaptured).showSnackBar(
        const SnackBar(content: Text("No hay un usuario autenticado válido.")),
      );
      return;
    }

    // Guardar una referencia al email para usarlo después del diálogo
    final userEmail = _email;

    // Mostrar el diálogo de confirmación
    final confirmacion = await showDialog<bool>(
      context: contextCaptured,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Eliminar cuenta"),
            content: const Text(
              "¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  "Eliminar",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    // Re-check mounted status after await
    if (!contextCaptured.mounted || confirmacion != true) return;

    // Show loading indicator
    ScaffoldMessenger.of(contextCaptured).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Eliminando cuenta..."),
          ],
        ),
        duration: Duration(seconds: 10), // Longer duration for deletion
      ),
    );

    // Desconecta el WebSocket antes de eliminar la cuenta
    _webSocketService.disconnect();

    // Eliminar la cuenta using UserService
    final success = await UserService.deleteUser(userEmail);

    // Re-check mounted status after await
    if (!contextCaptured.mounted) return;

    // Hide loading indicator
    ScaffoldMessenger.of(contextCaptured).hideCurrentSnackBar();

    if (success) {
      ScaffoldMessenger.of(contextCaptured).showSnackBar(
        const SnackBar(content: Text("Cuenta eliminada correctamente.")),
      );
      // Redirect to login page
      Navigator.of(contextCaptured).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(contextCaptured).showSnackBar(
        const SnackBar(
          content: Text(
            "Error al eliminar la cuenta. Es posible que necesites iniciar sesión de nuevo para completar la eliminación.",
          ),
        ),
      );
      // Attempt to sign out locally anyway, as the backend might have succeeded partially
      // or the Firebase user needs deletion.
      await _handleSessionClose(
        title: 'Error al Eliminar',
        message: 'Hubo un error al eliminar la cuenta. Se cerrará tu sesión.',
        redirectToLogin: true,
        isRemoteAction: false,
      );
    }
  }

  // Método unificado para manejar cierre de sesión
  Future<void> _handleSessionClose({
    String title = 'Sesión cerrada',
    String message = 'Tu sesión ha sido cerrada',
    bool redirectToLogin = true,
    bool isRemoteAction =
        false, // Flag to indicate if triggered by remote event
  }) async {
    // Capture context early
    final contextCaptured = context;
    if (!contextCaptured.mounted) return;

    try {
      // Use local email
      final email = _email;

      // 1. Cerrar sesión en el backend (best effort)
      if (email.isNotEmpty && email != 'UsuarioSinEmail') {
        try {
          await UserService.logoutUser(email);
        } catch (e) {
          debugPrint('Error during backend logout in _handleSessionClose: $e');
          // Continue with the process
        }
      }

      // 2. Desconectar WebSocket
      _webSocketService.disconnect();

      // 3. Cerrar sesión en Firebase (important!)
      try {
        await _authService
            .signOut(); // Using auth service instead of direct Firebase call
      } catch (e) {
        debugPrint('Error during Firebase signOut in _handleSessionClose: $e');
        // Continue with the process
      }

      // 4. Clear local user state
      _currentUser = null;
      _updateLocalUserInfo();
      if (mounted) {
        setState(() {
          // Trigger UI update if still mounted briefly
          _isLoading = false;
          _realName = '';
          _isClient = false;
          _userLevel = 0;
        });
      }

      // 5. Redireccionar si es necesario (check mounted again before navigation)
      if (redirectToLogin && contextCaptured.mounted) {
        // Show dialog only if it wasn't triggered by a remote action (which already showed a SnackBar)
        if (!isRemoteAction && title.isNotEmpty && message.isNotEmpty) {
          await showDialog(
            context: contextCaptured, // Use captured context
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Entendido'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ],
              );
            },
          );
        }

        // Re-check mounted before final navigation
        if (contextCaptured.mounted) {
          Navigator.of(contextCaptured).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint("Error in _handleSessionClose: $e");
      // Attempt to redirect anyway as a fallback
      if (redirectToLogin && contextCaptured.mounted) {
        ScaffoldMessenger.of(contextCaptured).showSnackBar(
          SnackBar(content: Text("Error crítico al cerrar sesión: $e")),
        );
        Navigator.of(contextCaptured).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Capturar el contexto para usarlo después de operaciones asíncronas
    final contextCaptured = context;
    if (!mounted) return;

    // Mostrar diálogo de confirmación antes de cerrar sesión
    final confirmacion = await showDialog<bool>(
      context: contextCaptured,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Cerrar Sesión"),
            content: const Text("¿Estás seguro de que quieres cerrar sesión?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  "Cerrar Sesión",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    // Re-check mounted status and confirmation
    if (!mounted || confirmacion != true) {
      return;
    }

    // Use the unified session close handler
    await _handleSessionClose(
      title: 'Sesión cerrada',
      message: 'Has cerrado sesión correctamente.',
      redirectToLogin: true,
      isRemoteAction: false, // Manual logout
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use local variables _username, _email, _photoURL for consistency

    // Contenido principal de la página de usuario
    Widget content = Stack(
      children: [
        // Envolver todo el contenido en SingleChildScrollView para permitir desplazamiento
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Foto de perfil
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  // Use local _photoURL
                  backgroundImage:
                      _photoURL != null ? NetworkImage(_photoURL!) : null,
                  child:
                      _photoURL == null
                          ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey,
                          )
                          : null,
                ),
                const SizedBox(height: 30),
                // Información del usuario
                UserInfoCard(
                  realName: _realName,
                  username: _username, // Use local _username
                  email: _email, // Use local _email
                  isClient: _isClient,
                  userLevel: _userLevel,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16), // Espaciado entre botones
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TrophiesPage(username: _username),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Ver Mis Trofeos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RatingsPage(username: _username),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star),
                  label: const Text('Ver Mis Valoraciones'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                // Add this button after the "Ver Mis Valoraciones" button
                const SizedBox(height: 16), // Espaciado entre botones
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => InvitationsPage(username: _username)),
                    );
                  },
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Ver Invitaciones'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => UserRequestsPage(username: _username),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Mis Solicitudes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                // Botón para ver usuarios bloqueados
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => BlockedUsersPage(username: _username),
                      ),
                    );
                  },
                  icon: const Icon(Icons.block),
                  label: const Text('Usuarios Bloqueados'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Capture context before await
                          final navContext = context;
                          // Navegar a la página de edición y esperar a que regrese
                          await Navigator.of(navContext).push(
                            MaterialPageRoute(
                              builder: (context) => const EditProfilePage(),
                            ),
                          );

                          // Re-check mounted status after navigation returns
                          if (!mounted) return;

                          // Reload data after returning from edit page
                          setState(() {
                            _isLoading = true;
                          });
                          await _loadUserData();
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar Perfil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _eliminarCuenta(context),
                        icon: const Icon(Icons.delete_forever),
                        label: const Text("Eliminar Cuenta"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Botón de logout
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text("Cerrar Sesión"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                // Añadimos un espacio extra al final para pantallas pequeñas
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );

    // Si la página está embebida dentro de otra (como en AdminPage), devuelve solo el contenido
    if (widget.isEmbedded) {
      return content;
    }

    // De lo contrario, envuelve el contenido en un Scaffold completo
    return Scaffold(
      appBar: AppBar(title: const Text("Perfil de Usuario")),
      body: content,
    );
  }
}
