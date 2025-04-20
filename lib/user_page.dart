import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/user_services.dart';
import 'package:airplan/services/websocket_service.dart'; // Import WebSocket service
import 'dart:convert'; // For JSON processing
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'dart:async'; // Añade esta importación para StreamSubscription

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  bool _isLoading = true;
  String _realName = 'Cargando...';
  // WebSocket subscription for real-time updates
  StreamSubscription<String>? _profileUpdateSubscription;

  // Para mostrar mensajes de depuración en pantalla
  final List<String> _debugMessages = [];
  bool _showDebugMessages =
      false; // Cambiar a true para mostrar mensajes en la UI

  @override
  void initState() {
    super.initState();
    // Inicializar la conexión WebSocket antes de cargar datos
    _ensureWebSocketConnection();
    _loadUserData();
  }

  // Asegurar que la conexión WebSocket está activa
  void _ensureWebSocketConnection() {
    _addDebugMessage("🔌 Inicializando conexión WebSocket");

    // Obtener la instancia del WebSocketService
    final webSocketService = WebSocketService();

    // Verificar si ya está conectado
    if (!webSocketService.isConnected) {
      _addDebugMessage("🔄 Estableciendo conexión WebSocket");
      webSocketService.connect();
    } else {
      _addDebugMessage("✅ WebSocket ya está conectado");
    }

    // Inicializar escucha de eventos WebSocket
    _initWebSocketListener();
  }

  void _addDebugMessage(String message) {
    print("DEBUG: $message");
    setState(() {
      _debugMessages.add(
        "[${DateTime.now().toString().split('.').first}] $message",
      );
      // Mantener solo los últimos 20 mensajes
      if (_debugMessages.length > 20) {
        _debugMessages.removeAt(0);
      }
    });
  }

  // Initialize WebSocket connection and listen for profile updates
  void _initWebSocketListener() {
    _addDebugMessage("👂 Inicializando escucha de eventos WebSocket");

    // Cancelar suscripción anterior si existe
    _profileUpdateSubscription?.cancel();

    // Listen for profile update events
    _profileUpdateSubscription = WebSocketService().profileUpdates.listen(
      (message) {
        try {
          _addDebugMessage("📨 WebSocket mensaje recibido: $message");

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

              _addDebugMessage(
                "💫 NOTIFICACIÓN RECIBIDA: Actualización de perfil detectada",
              );
              _addDebugMessage("Campos actualizados: ${data['updatedFields']}");

              // Si la actualización incluye cambio de correo o contraseña, necesitamos una acción más drástica
              if (isSessionResetRequired) {
                _addDebugMessage(
                  "⚠️ CAMBIO CRÍTICO DETECTADO - Acción especial requerida",
                );

                // IMPORTANTE: Forzar una recarga del usuario de Firebase inmediatamente
                // Esto provocará que Firebase detecte que el token ya no es válido
                _addDebugMessage("🔄 Forzando reload() del usuario Firebase");

                // Realizar reload() de Firebase Auth para invalidar la sesión
                FirebaseAuth.instance.currentUser
                    ?.reload()
                    .then((_) {
                      _addDebugMessage("✅ Reload de Firebase completado");

                      // Forzar comprobación del estado de autenticación
                      FirebaseAuth.instance.authStateChanges().listen((
                        User? user,
                      ) {
                        _addDebugMessage(
                          "📊 Estado de autenticación actual: ${user != null ? 'Autenticado' : 'No autenticado'}",
                        );
                      });
                    })
                    .catchError((error) {
                      _addDebugMessage("❌ Error en reload de Firebase: $error");
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
                  Future.delayed(const Duration(seconds: 3), () {
                    _handleAccountChangeOnAnotherDevice(
                      isPasswordChange: isPasswordUpdate,
                      isEmailChange: isEmailUpdate,
                      isNameChange: isNameUpdate,
                    );
                  });
                }
              } else if (isNameUpdate) {
                // Para cambios de nombre, recargamos los datos pero también mostramos un diálogo informativo
                _addDebugMessage("👤 Cambio de nombre detectado");

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
                    _addDebugMessage(
                      "🔄 RECARGANDO DATOS del perfil desde Firebase y backend",
                    );
                  });
                  _loadUserData();
                }
              } else {
                // Para otros cambios, solo recargamos los datos normalmente
                _addDebugMessage(
                  "🔄 Actualización de perfil estándar detectada",
                );

                // Reload user data
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                    _addDebugMessage(
                      "🔄 RECARGANDO DATOS del perfil desde Firebase y backend",
                    );
                  });
                  _loadUserData();
                }
              }
            } else {
              _addDebugMessage(
                "⚠️ Notificación no relevante para este usuario",
              );
              _addDebugMessage(
                "Username actual: ${currentUser?.displayName}, recibido: ${data['username']}",
              );
              _addDebugMessage(
                "Email actual: ${currentUser?.email}, recibido: ${data['email']}",
              );
            }
          }
        } catch (e) {
          _addDebugMessage("❌ Error procesando mensaje WebSocket: $e");
        }
      },
      onError: (error) {
        _addDebugMessage("❌ Error en la conexión WebSocket: $error");
        // Intentar reconectar el WebSocket
        WebSocketService().reconnect();
      },
      onDone: () {
        _addDebugMessage("⚠️ Conexión WebSocket cerrada");
        // Intentar reconectar el WebSocket
        Future.delayed(const Duration(seconds: 2), () {
          WebSocketService().reconnect();
        });
      },
    );
  }

  // Método especial para manejar el cambio de correo en otro dispositivo
  Future<void> _handleEmailChangeOnAnotherDevice() async {
    _addDebugMessage(
      "🚨 Ejecutando cierre de sesión por cambio de correo en otro dispositivo",
    );

    try {
      // Obtener el nombre de usuario actual para mostrar un mensaje personalizado
      final currentUser = FirebaseAuth.instance.currentUser;
      final username = currentUser?.displayName ?? "usuario";
      final email = currentUser?.email;

      _addDebugMessage(
        "📝 Datos antes de cerrar sesión - Username: $username, Email: $email",
      );

      // Cerrar sesión en el backend
      if (email != null) {
        try {
          await UserService.logoutUser(email);
          _addDebugMessage("✅ Sesión cerrada correctamente en el backend");
        } catch (e) {
          _addDebugMessage("⚠️ Error al cerrar sesión en el backend: $e");
        }
      }

      // IMPORTANTE: Intentar hacer signOut en Firebase para forzar la redirección
      try {
        await FirebaseAuth.instance.signOut();
        _addDebugMessage("✅ Sesión cerrada correctamente en Firebase");
      } catch (e) {
        _addDebugMessage("⚠️ Error al cerrar sesión en Firebase: $e");
      }

      // Desconectar WebSocket
      WebSocketService().disconnect();

      // Mostrar diálogo informativo antes de redireccionar
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Cambio de correo detectado'),
              content: Text(
                'Hola $username, tu correo electrónico ha sido modificado en otro dispositivo. '
                'Por razones de seguridad, necesitas volver a iniciar sesión con tu nuevo correo.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Entendido'),
                  onPressed: () {
                    // Redireccionar a la página de login
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      _addDebugMessage("❌ Error manejando cambio de correo: $e");
      // En caso de error, intentar redireccionar de todos modos
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  // Método para manejar cambio de cuenta en otro dispositivo
  Future<void> _handleAccountChangeOnAnotherDevice({
    required bool isPasswordChange,
    required bool isEmailChange,
    required bool isNameChange,
  }) async {
    _addDebugMessage(
      "🚨 Ejecutando cierre de sesión por cambio de cuenta en otro dispositivo",
    );

    try {
      // Obtener el nombre de usuario actual para mostrar un mensaje personalizado
      final currentUser = FirebaseAuth.instance.currentUser;
      final username = currentUser?.displayName ?? "usuario";
      final email = currentUser?.email;

      _addDebugMessage(
        "📝 Datos antes de cerrar sesión - Username: $username, Email: $email",
      );

      // Cerrar sesión en el backend
      if (email != null) {
        try {
          await UserService.logoutUser(email);
          _addDebugMessage("✅ Sesión cerrada correctamente en el backend");
        } catch (e) {
          _addDebugMessage("⚠️ Error al cerrar sesión en el backend: $e");
        }
      }

      // IMPORTANTE: Intentar hacer signOut en Firebase para forzar la redirección
      try {
        await FirebaseAuth.instance.signOut();
        _addDebugMessage("✅ Sesión cerrada correctamente en Firebase");
      } catch (e) {
        _addDebugMessage("⚠️ Error al cerrar sesión en Firebase: $e");
      }

      // Desconectar WebSocket
      WebSocketService().disconnect();

      // Mostrar diálogo informativo antes de redireccionar
      if (mounted) {
        String title = 'Cambio de cuenta detectado';
        String message = '';

        if (isEmailChange && isPasswordChange) {
          title = 'Cambio de correo y contraseña';
          message =
              'Hola $username, tu correo electrónico y contraseña han sido modificados en otro dispositivo. '
              'Por razones de seguridad, necesitas volver a iniciar sesión.';
        } else if (isEmailChange) {
          title = 'Cambio de correo detectado';
          message =
              'Hola $username, tu correo electrónico ha sido modificado en otro dispositivo. '
              'Por razones de seguridad, necesitas volver a iniciar sesión con tu nuevo correo.';
        } else if (isPasswordChange) {
          title = 'Cambio de contraseña detectado';
          message =
              'Hola $username, tu contraseña ha sido modificada en otro dispositivo. '
              'Por razones de seguridad, necesitas volver a iniciar sesión.';
        } else if (isNameChange) {
          title = 'Cambio de nombre detectado';
          message =
              'Hola $username, tu nombre ha sido modificado en otro dispositivo. '
              'Por razones de seguridad, necesitas volver a iniciar sesión.';
        }

        showDialog(
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
                    // Redireccionar a la página de login
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      _addDebugMessage("❌ Error manejando cambio de cuenta: $e");
      // En caso de error, intentar redireccionar de todos modos
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      _addDebugMessage("Iniciando carga de datos de usuario");
      // Realizar un reload de la instancia de Firebase al entrar al perfil
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          _addDebugMessage("Recargando usuario actual desde Firebase");
          // Intentar recargar el usuario desde Firebase
          await user.reload();

          // Verificar si el correo en Firebase coincide con el de la base de datos
          await _checkAndSyncEmail();

          // Verificar si el usuario sigue autenticado después del reload
          final refreshedUser = FirebaseAuth.instance.currentUser;
          if (refreshedUser == null) {
            // La sesión ha caducado después del reload
            _addDebugMessage("❌ Sesión caducada tras recargar");
            if (mounted) {
              await _showSessionExpiredDialog();
              return;
            }
          }

          if (refreshedUser != null && refreshedUser.displayName != null) {
            final username = refreshedUser.displayName!;
            _addDebugMessage(
              "Obteniendo nombre real para el usuario: $username",
            );
            final realName = await UserService.getUserRealName(username);
            _addDebugMessage("✅ Datos cargados correctamente: $realName");

            if (mounted) {
              setState(() {
                _realName = realName;
                _isLoading = false;
              });
            }
          }
        } catch (e) {
          // Error al recargar el usuario, probablemente la sesión expiró
          _addDebugMessage("❌ Error al recargar usuario de Firebase: $e");
          if (mounted) {
            await _showSessionExpiredDialog();
          }
        }
      } else {
        // No hay usuario autenticado
        _addDebugMessage("⚠️ No hay usuario autenticado");
        if (mounted) {
          await _showSessionExpiredDialog();
        }
      }
    } catch (e) {
      _addDebugMessage("❌ Error general al cargar datos de usuario: $e");
      if (mounted) {
        setState(() {
          _realName = 'Error al cargar datos';
          _isLoading = false;
        });
      }
    }
  }

  // Método para verificar y sincronizar el correo electrónico
  Future<void> _checkAndSyncEmail() async {
    _addDebugMessage("Verificando sincronización de correo electrónico");
    try {
      final wasUpdated = await UserService.syncEmailOnProfileLoad();
      if (wasUpdated) {
        _addDebugMessage(
          "✅ Correo electrónico sincronizado entre Firebase y base de datos",
        );
      } else {
        _addDebugMessage("ℹ️ No fue necesario sincronizar el correo");
      }
    } catch (e) {
      _addDebugMessage("⚠️ Error al intentar sincronizar correo: $e");
    }
  }

  // Método para manejar la sesión caducada sin mostrar diálogo (ahora usa GlobalNotificationService)
  Future<void> _showSessionExpiredDialog() async {
    // Ya no mostramos el diálogo aquí porque el GlobalNotificationService lo manejará
    _addDebugMessage(
      "📤 Redireccionando a la página de login por sesión caducada",
    );

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // También necesitamos recargar cuando la página obtiene el foco nuevamente
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Esto captura cuando la página vuelve a estar visible, por ejemplo cuando el usuario
    // regresa a ella después de editar su perfil
    final route = ModalRoute.of(context);
    if (route != null) {
      route.addScopedWillPopCallback(() async {
        // Esta función se llamará cuando se regrese a esta página
        _loadUserData();
        return false; // Permitir que la navegación continúe
      });
    }
  }

  @override
  void dispose() {
    // Cancel profile update subscription when the page is disposed
    _profileUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay un usuario autenticado.")),
      );
      return;
    }

    final confirmacion = await showDialog<bool>(
      context: context,
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

    if (confirmacion == true) {
      final success = await UserService.deleteUser(user.email!);
      final actualContext = context;
      if (actualContext.mounted) {
        if (success) {
          ScaffoldMessenger.of(actualContext).showSnackBar(
            const SnackBar(content: Text("Cuenta eliminada correctamente.")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          ScaffoldMessenger.of(actualContext).showSnackBar(
            const SnackBar(content: Text("Error al eliminar la cuenta")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "UsuarioSinEmail";
    final username = user?.displayName ?? "Username no disponible";
    final photoURL = user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil de Usuario"),
        actions: [
          // Botón para activar/desactivar mensajes de depuración
          IconButton(
            icon: Icon(
              _showDebugMessages ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                _showDebugMessages = !_showDebugMessages;
              });
            },
            tooltip:
                _showDebugMessages
                    ? 'Ocultar depuración'
                    : 'Mostrar depuración',
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ...existing code...

                // Añadir el resto de los widgets existentes aquí
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
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person, color: Colors.blue),
                          title: const Text(
                            'Nombre',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              _isLoading
                                  ? const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    _realName,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(
                            Icons.alternate_email,
                            color: Colors.blue,
                          ),
                          title: const Text(
                            'Username',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            username,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.email, color: Colors.blue),
                          title: const Text(
                            'Correo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            email,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                              builder: (context) => EditProfilePage(),
                            ),
                          );

                          // Cuando regresamos de la página de edición, recargamos los datos
                          if (mounted) {
                            setState(() {
                              _isLoading = true;
                            });
                            await _loadUserData();
                          }
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
              ],
            ),
          ),

          // Mostrar panel de depuración si está activado
          if (_showDebugMessages)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                color: Colors.black.withOpacity(0.8),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Panel de Depuración',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            _addDebugMessage(
                              "Forzando recarga manual de datos",
                            );
                            setState(() {
                              _isLoading = true;
                            });
                            _loadUserData();
                          },
                          tooltip: 'Forzar recarga',
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _debugMessages.length,
                        itemBuilder: (context, index) {
                          return Text(
                            _debugMessages[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
