import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/user_services.dart';
import 'package:airplan/services/websocket_service.dart';
import 'dart:convert';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'dart:async';
import 'main.dart';

/// Widget para mostrar la información del usuario
class UserInfoCard extends StatelessWidget {
  final String realName;
  final String username;
  final String email;
  final bool isClient;
  final int userLevel;
  final bool isLoading;

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
              isLoading: false,
            ),
            const Divider(),
            _buildInfoListTile(
              icon: Icons.email,
              title: 'Correo',
              value: email,
              isLoading: false,
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

  const UserPage({super.key, this.isEmbedded = false});

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

  @override
  void initState() {
    super.initState();
    // Inicializar la conexión WebSocket antes de cargar datos
    _ensureWebSocketConnection();
    _loadUserData();
  }

  // Asegurar que la conexión WebSocket está activa
  void _ensureWebSocketConnection() {
    // Obtener la instancia del WebSocketService
    final webSocketService = WebSocketService();

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

    // Listen for profile update events
    _profileUpdateSubscription = WebSocketService().profileUpdates.listen(
      (message) {
        try {
          // Parse incoming message
          final data = json.decode(message);

          // Check if this is a profile update notification
          if (data['type'] == 'PROFILE_UPDATE') {
            // Check if the update is relevant for the current user
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null &&
                (data['username'] == currentUser.displayName ||
                    data['email'] == currentUser.email)) {
              final updatedFields = data['updatedFields'] as List<dynamic>;
              final isEmailUpdate = updatedFields.contains('email');
              final isPasswordUpdate = updatedFields.contains('password');
              final isNameUpdate =
                  updatedFields.contains('name') ||
                  updatedFields.contains('displayName');

              // Determinar si es un cambio crítico que requiere reinicio de sesión
              final isSessionResetRequired = isEmailUpdate || isPasswordUpdate;

              // Si la actualización incluye cambio de correo o contraseña, necesitamos una acción más drástica
              if (isSessionResetRequired) {
                // Realizar reload() de Firebase Auth para invalidar la sesión
                FirebaseAuth.instance.currentUser
                    ?.reload()
                    .then((_) {
                      // Forzar comprobación del estado de autenticación
                      FirebaseAuth.instance.authStateChanges().listen(
                        (User? user) {},
                      );
                    })
                    .catchError((error) {
                      // Si el reload falla, probablemente la sesión ya es inválida, cerrarla manualmente
                      _handleAccountChangeOnAnotherDevice(
                        isPasswordChange: isPasswordUpdate,
                        isEmailChange: isEmailUpdate,
                        isNameChange: isNameUpdate,
                      );
                    });

                // Notificar al usuario sobre el cambio detectado
                String message = '';
                Color backgroundColor = Colors.orange;

                if (isEmailUpdate && isPasswordUpdate) {
                  message =
                      'Se han detectado cambios en tu correo y contraseña. Es necesario volver a iniciar sesión.';
                } else if (isEmailUpdate) {
                  message =
                      'Se ha detectado un cambio de correo electrónico. Es necesario volver a iniciar sesión.';
                } else if (isPasswordUpdate) {
                  message =
                      'Se ha detectado un cambio de contraseña. Es necesario volver a iniciar sesión.';
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: backgroundColor,
                      duration: const Duration(seconds: 5),
                    ),
                  );

                  // Forzar cierre de sesión y redirigir a la página de login después de un breve retraso
                  // Movemos la verificación de mounted dentro del callback porque el widget podría
                  // ser desmontado durante los 3 segundos de espera
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) {
                      _handleAccountChangeOnAnotherDevice(
                        isPasswordChange: isPasswordUpdate,
                        isEmailChange: isEmailUpdate,
                        isNameChange: isNameUpdate,
                      );
                    }
                  });
                }
              } else if (isNameUpdate) {
                // Para cambios de nombre, recargamos los datos pero también mostramos un diálogo informativo

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tu nombre de usuario ha sido actualizado en otro dispositivo.',
                      ),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }

                // Reload user data
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadUserData();
                }
              } else {
                // Para otros cambios, solo recargamos los datos normalmente

                // Reload user data
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadUserData();
                }
              }
            }
          }
        } catch (e) {
          debugPrint("Error procesando mensaje WebSocket: $e");
        }
      },
      onError: (error) {
        // Intentar reconectar el WebSocket
        WebSocketService().reconnect();
      },
      onDone: () {
        // Intentar reconectar el WebSocket
        Future.delayed(const Duration(seconds: 2), () {
          WebSocketService().reconnect();
        });
      },
    );
  }

  // Método para manejar cambio de cuenta en otro dispositivo
  Future<void> _handleAccountChangeOnAnotherDevice({
    required bool isPasswordChange,
    required bool isEmailChange,
    required bool isNameChange,
  }) async {
    try {
      // Obtener el nombre de usuario actual para mostrar un mensaje personalizado
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = currentUser?.email;

      // Cerrar sesión en el backend
      if (email != null) {
        try {
          await UserService.logoutUser(email);
        } catch (e) {
          // Log error pero continuar con el proceso de cierre
          debugPrint('Error al cerrar sesión en el backend: $e');
        }
      }

      // IMPORTANTE: Intentar hacer signOut en Firebase para forzar la redirección
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Log error pero continuar con el proceso
        debugPrint('Error al cerrar sesión en Firebase: $e');
      }

      // Desconectar WebSocket
      WebSocketService().disconnect();

      // Redireccionar a la página de login después de un breve retraso
      // No mostramos diálogo adicional porque ya se mostró un SnackBar previamente
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      // En caso de error, intentar redireccionar de todos modos
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  // Método para cargar los datos de usuario
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.displayName != null) {
        final username = user.displayName!;

        // Cargar el nombre real del usuario
        final realName = await UserService.getUserRealName(username);

        // Obtener el tipo de usuario y nivel si es cliente
        final tipoInfo = await UserService.getUserTypeAndLevel(username);

        final tipo = tipoInfo['tipo'] as String?;
        final isClient = tipo == 'cliente';
        final nivel = isClient ? (tipoInfo['nivell'] as int?) ?? 0 : 0;

        if (mounted) {
          setState(() {
            _realName = realName;
            _isClient = isClient;
            _userLevel = nivel;
            _isLoading = false;
          });
        }
      } else {
        // No hay usuario autenticado
        if (mounted) {
          await _showSessionExpiredDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _realName = 'Error al cargar datos';
          _isLoading = false;
        });
      }
    }
  }

  // Método para manejar la sesión caducada sin mostrar diálogo (ahora usa GlobalNotificationService)
  Future<void> _showSessionExpiredDialog() async {
    // Ya no mostramos el diálogo aquí porque el GlobalNotificationService lo manejará

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // También necesitamos recargar cuando la página obtiene el foco nuevamente
  bool _needsRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Verificar si necesitamos recargar los datos (puede ser después de editar el perfil)
    if (_needsRefresh) {
      _loadUserData();
      _needsRefresh = false;
    }
  }

  void markForRefresh() {
    _needsRefresh = true;
  }

  @override
  void dispose() {
    // Cancel profile update subscription when the page is disposed
    _profileUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    // Guardar el contexto y verificar que el widget esté montado antes de continuar
    final contextCaptured = context;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(contextCaptured).showSnackBar(
          const SnackBar(content: Text("No hay un usuario autenticado.")),
        );
      }
      return;
    }

    // Guardar una referencia al email para usarlo después del diálogo
    final userEmail = user.email!;

    // Mostrar el diálogo de confirmación
    final confirmacion = await showDialog<bool>(
      context: contextCaptured,
      builder:
          (context) => AlertDialog(
            title: const Text("Eliminar cuenta"),
            content: const Text(
              "¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Eliminar",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    // Verificar que el widget aún esté montado después del await
    if (!mounted) return;

    if (confirmacion == true) {
      // Desconecta el WebSocket antes de eliminar la cuenta
      WebSocketService().disconnect();

      // Obtener una instancia de AuthWrapper para establecer la bandera de logout manual
      try {
        final authWrapperState =
            contextCaptured.findAncestorStateOfType<AuthWrapperState>();
        if (authWrapperState != null) {
          // Establecer bandera de logout manual para evitar la notificación
          authWrapperState.setManualLogout(true);
        }
      } catch (e) {
        debugPrint('Error al establecer bandera de logout manual: $e');
        // Continuamos con el flujo normal
      }

      // Eliminar la cuenta
      final success = await UserService.deleteUser(userEmail);

      // Verificar nuevamente que el widget esté montado después de otra llamada asincrónica
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(contextCaptured).showSnackBar(
          const SnackBar(content: Text("Cuenta eliminada correctamente.")),
        );
        Navigator.pushReplacement(
          contextCaptured,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        ScaffoldMessenger.of(contextCaptured).showSnackBar(
          const SnackBar(content: Text("Error al eliminar la cuenta")),
        );
      }
    }
  }

  // Método unificado para manejar cierre de sesión
  Future<void> _handleSessionClose({
    String title = 'Sesión cerrada',
    String message = 'Tu sesión ha sido cerrada',
    bool redirectToLogin = true,
  }) async {
    try {
      // Obtener el email del usuario actual
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;

      // Cerrar sesión en el backend
      if (email != null) {
        try {
          await UserService.logoutUser(email);
        } catch (e) {
          debugPrint('Error al cerrar sesión en el backend: $e');
          // Continuar con el proceso de cierre
        }
      }

      // Desconectar WebSocket
      WebSocketService().disconnect();

      // Cerrar sesión en Firebase
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Error al cerrar sesión en Firebase: $e');
        // Continuar con el proceso
      }

      // Redireccionar si es necesario
      if (redirectToLogin && mounted) {
        if (title.isNotEmpty && message.isNotEmpty) {
          // Mostrar diálogo informativo
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Entendido'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }

        // Redireccionar a página de login - Ya no necesitamos verificar mounted de nuevo
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al cerrar sesión: $e")));

        // En caso de error, intentar redireccionar de todos modos
        if (redirectToLogin) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Capturar el contexto para usarlo después de operaciones asíncronas
    final contextCaptured = context;

    // Mostrar diálogo de confirmación antes de cerrar sesión
    final confirmacion = await showDialog<bool>(
      context: contextCaptured,
      builder:
          (context) => AlertDialog(
            title: const Text("Cerrar Sesión"),
            content: const Text("¿Estás seguro de que quieres cerrar sesión?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Cerrar Sesión",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    // Verificar que el widget aún esté montado después del await
    if (!mounted) return;

    // Si el usuario no confirmó, salir del método
    if (confirmacion != true) {
      return;
    }

    await _handleSessionClose(
      title: 'Sesión cerrada',
      message: 'Has cerrado sesión correctamente.',
      redirectToLogin: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    var user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "UsuarioSinEmail";
    final username = user?.displayName ?? "Username no disponible";
    final photoURL = user?.photoURL;

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
                  backgroundImage:
                      photoURL != null ? NetworkImage(photoURL) : null,
                  child:
                      photoURL == null
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
                  username: username,
                  email: email,
                  isClient: _isClient,
                  userLevel: _userLevel,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 30),
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Navegar a la página de edición y esperar a que regrese
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const EditProfilePage(),
                            ),
                          );

                          // Verificar que el widget aún esté montado después de la navegación
                          if (!mounted) return;

                          // Marcar para refrescar datos cuando regresamos de la página de edición
                          setState(() {
                            _isLoading = true;
                          });
                          // Cargar datos inmediatamente
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
