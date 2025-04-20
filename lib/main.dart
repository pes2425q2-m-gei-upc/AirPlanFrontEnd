// main.dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:airplan/user_page.dart';
import 'package:airplan/utils/web_utils_stub.dart';
import 'calendar_page.dart';
import 'login_page.dart';
import 'map_page.dart';
import 'admin_page.dart';
import 'services/websocket_service.dart'; // Import WebSocket service
import 'dart:async'; // Para StreamSubscription

// Stream controller para comunicar actualizaciones de perfil a toda la aplicación
final StreamController<Map<String, dynamic>> profileUpdateStreamController =
    StreamController<Map<String, dynamic>>.broadcast();

// Clave global para acceder al NavigatorState
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Clase para gestionar notificaciones de manera global
class GlobalNotificationService {
  // Instancia singleton
  static final GlobalNotificationService _instance =
      GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;
  GlobalNotificationService._internal();

  // Cola de notificaciones pendientes
  final List<Map<String, dynamic>> _pendingNotifications = [];
  bool _isShowingNotification = false;

  // Añadir una notificación a la cola
  void addNotification(String message, String type, {bool isUrgent = false}) {
    print("🔔 [GlobalNotificationService] Añadiendo notificación: $message");
    _pendingNotifications.add({
      'message': message,
      'type': type,
      'isUrgent': isUrgent,
    });

    // Intentar mostrar notificaciones pendientes
    _processPendingNotifications();
  }

  // Procesar la cola de notificaciones
  void _processPendingNotifications() {
    // Si no hay navigator key inicializado aún o ya estamos mostrando una notificación, salir
    if (navigatorKey.currentState == null ||
        _isShowingNotification ||
        _pendingNotifications.isEmpty) {
      print(
        "⏳ [GlobalNotificationService] No se pueden mostrar notificaciones ahora. navigatorKey disponible: ${navigatorKey.currentState != null}, mostrando: $_isShowingNotification, pendientes: ${_pendingNotifications.length}",
      );
      return;
    }

    // Marcar que estamos mostrando una notificación
    _isShowingNotification = true;

    // Tomar la primera notificación de la cola
    final notification = _pendingNotifications.removeAt(0);
    print(
      "📢 [GlobalNotificationService] Mostrando notificación: ${notification['message']}",
    );

    // Mostrar la notificación usando el context del navigator
    final context = navigatorKey.currentContext;
    if (context != null) {
      _showMaterialBanner(context, notification);
    } else {
      print(
        "⚠️ [GlobalNotificationService] Contexto no disponible, reintentando luego",
      );
      _isShowingNotification = false;
      // Volver a añadir la notificación a la cola
      _pendingNotifications.insert(0, notification);

      // Reintentar después de un breve retraso
      Future.delayed(
        const Duration(milliseconds: 500),
        _processPendingNotifications,
      );
    }
  }

  // Mostrar un MaterialBanner que es más robusto que SnackBar o Overlay
  void _showMaterialBanner(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    final String message = notification['message'];
    final String type = notification['type'];
    final bool isUrgent = notification['isUrgent'] ?? false;

    // Colores según tipo
    final Color backgroundColor = _getNotificationColor(type, isUrgent);
    final Color textColor = Colors.white;

    // Crear ScaffoldFeatureController para el banner
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // Limpiar banners anteriores
    messenger.clearMaterialBanners();

    // Crear y mostrar el banner
    final MaterialBanner banner = MaterialBanner(
      content: Text(message, style: TextStyle(color: textColor)),
      leading: Icon(_getNotificationIcon(type), color: textColor),
      backgroundColor: backgroundColor,
      actions: [
        IconButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            // Procesar siguiente notificación
            _isShowingNotification = false;
            _processPendingNotifications();
          },
          icon: Icon(Icons.close, color: textColor),
        ),
      ],
    );

    // Mostrar el banner
    messenger.showMaterialBanner(banner);

    // Para notificaciones no urgentes, configurar un temporizador para ocultarlas automáticamente
    if (!isUrgent) {
      Future.delayed(const Duration(seconds: 5), () {
        // Verificar si este banner sigue siendo el actual
        messenger.hideCurrentMaterialBanner();
        // Marcar que ya no estamos mostrando notificación
        _isShowingNotification = false;
        // Procesar siguiente notificación
        _processPendingNotifications();
      });
    }
  }

  // Refrescar la pantalla actual
  void _refreshCurrentScreen(BuildContext context) {
    print("🔄 [GlobalNotificationService] Refrescando pantalla");

    // Navegar a AuthWrapper para refrescar la UI
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
      (route) => false,
    );
  }

  // Determinar el color según el tipo de notificación
  Color _getNotificationColor(String type, bool isUrgent) {
    if (isUrgent) {
      return Colors.red;
    }

    switch (type) {
      case 'email_change':
        return Colors.orange;
      case 'profile_update':
        return Colors.blue;
      case 'session_expired':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  // Determinar el icono según el tipo de notificación
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'email_change':
        return Icons.email;
      case 'profile_update':
        return Icons.person;
      case 'session_expired':
        return Icons.lock_clock;
      default:
        return Icons.notifications;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyDjyHcnvD1JTfN7xpkRMD-S_qDMSnvbZII",
      authDomain: "airplan-f08be.firebaseapp.com",
      projectId: "airplan-f08be",
      storageBucket: "airplan-f08be.appspot.com",
      messagingSenderId: "952401482773",
      appId: "1:952401482773:web:9f9a3484c2cce60970ea1c",
      measurementId: "G-L70Y1N6J8Z",
    ),
  );

  runApp(const MiApp());
}

class MiApp extends StatefulWidget {
  const MiApp({super.key});

  @override
  State<MiApp> createState() => _MiAppState();
}

class _MiAppState extends State<MiApp> with WidgetsBindingObserver {
  bool _isWindowClosing = false;
  // Suscripción a eventos de WebSocket para escucha global
  StreamSubscription<String>? _globalWebSocketSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    } else {
      addUnloadListener(() async {
        _isWindowClosing = true;
        await _logoutUser();
      });
    }

    // Initialize WebSocket if user is already logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _initializeGlobalWebSocketListener();
    }

    // Escuchar cambios de autenticación para inicializar/destruir el WebSocket según corresponda
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _initializeGlobalWebSocketListener();
      } else {
        _disposeGlobalWebSocketListener();
        WebSocketService().disconnect();
      }
    });
  }

  // Inicializa la escucha global de WebSocket
  void _initializeGlobalWebSocketListener() {
    // Primero, asegurar que estamos conectados al WebSocket
    if (!WebSocketService().isConnected) {
      WebSocketService().connect();
    }

    // Cancelar cualquier suscripción anterior
    _globalWebSocketSubscription?.cancel();

    // Establecer una escucha global a los eventos del WebSocket
    _globalWebSocketSubscription = WebSocketService().profileUpdates.listen(
      (message) {
        _handleWebSocketMessage(message);
      },
      onError: (error) {
        print("❌ Error global en WebSocket: $error");
        // Intentar reconectar el WebSocket
        WebSocketService().reconnect();
      },
      onDone: () {
        print("⚠️ Conexión WebSocket global cerrada");
        // Intentar reconectar después de un breve retraso
        Future.delayed(const Duration(seconds: 2), () {
          if (FirebaseAuth.instance.currentUser != null) {
            WebSocketService().reconnect();
          }
        });
      },
    );

    print("🌐 Escucha global de WebSocket inicializada");
  }

  // Procesa los mensajes recibidos del WebSocket
  void _handleWebSocketMessage(String message) {
    try {
      print("📩 [Global] WebSocket mensaje recibido: $message");
      final data = json.decode(message);

      // Comprobar si es un mensaje de actualización de perfil
      if (data['type'] == 'PROFILE_UPDATE') {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null &&
            (data['username'] == currentUser.displayName ||
                data['email'] == currentUser.email)) {
          final updatedFields = data['updatedFields'] as List<dynamic>;
          final isEmailUpdate = updatedFields.contains('email');

          print(
            "💫 [Global] NOTIFICACIÓN RECIBIDA: Actualización de perfil detectada",
          );
          print("📋 [Global] Campos actualizados: ${updatedFields.join(', ')}");

          // Emitir el evento a través del StreamController para que otros widgets puedan reaccionar
          profileUpdateStreamController.add({
            'type': 'profile_update',
            'updatedFields': updatedFields,
            'data': data,
          });

          // Si es un cambio de correo, necesitamos manejar la sesión
          if (isEmailUpdate) {
            print("🚨 [Global] Cambio de correo electrónico detectado");
            _handleEmailChangeGlobally();
          } else {
            // Para otros cambios, actualizamos la información de usuario y mostramos notificación
            print(
              "ℹ️ [Global] Actualización detectada en: ${updatedFields.join(', ')}",
            );

            // Crear mensaje de notificación basado en campos actualizados
            String mensaje = _createProfileUpdateMessage(updatedFields);

            // Usar el servicio global de notificaciones
            GlobalNotificationService().addNotification(
              mensaje,
              'profile_update',
            );

            // Actualizar Firebase Auth si es necesario
            if (updatedFields.contains('username') ||
                updatedFields.contains('nom')) {
              _updateUserDisplayNameIfNeeded(data);
            }

            // Recargar datos de usuario en Firebase para mantener sincronización
            FirebaseAuth.instance.currentUser
                ?.reload()
                .then((_) {
                  print(
                    "✅ [Global] Usuario recargado después de actualización de perfil",
                  );
                })
                .catchError((error) {
                  print("⚠️ [Global] Error recargando usuario: $error");
                });
          }
        } else {
          print("⚠️ [Global] Notificación no relevante para este usuario");
          print(
            "Username actual: ${currentUser?.displayName}, recibido: ${data['username']}",
          );
          print(
            "Email actual: ${currentUser?.email}, recibido: ${data['email']}",
          );
        }
      }
    } catch (e) {
      print("❌ [Global] Error procesando mensaje WebSocket: $e");
    }
  }

  // Crea un mensaje descriptivo basado en los campos actualizados
  String _createProfileUpdateMessage(List<dynamic> updatedFields) {
    if (updatedFields.isEmpty) {
      return 'Tu perfil ha sido actualizado en otro dispositivo';
    }

    // Mapeo de campos a nombres amigables en español
    final fieldNames = {
      'username': 'nombre de usuario',
      'nom': 'nombre',
      'prenoms': 'apellidos',
      'telephone': 'teléfono',
      'adresse': 'dirección',
      'dateNaissance': 'fecha de nacimiento',
      'genre': 'género',
      'photo': 'foto de perfil',
      'paysOrigine': 'país de origen',
    };

    // Obtener nombres de campos legibles para el usuario
    final updatedFieldNames =
        updatedFields
            .map((field) => fieldNames[field] ?? field.toString())
            .toList();

    if (updatedFieldNames.length == 1) {
      return 'Tu ${updatedFieldNames[0]} ha sido actualizado en otro dispositivo';
    } else if (updatedFieldNames.length == 2) {
      return 'Tu ${updatedFieldNames[0]} y ${updatedFieldNames[1]} han sido actualizados en otro dispositivo';
    } else {
      // Para 3 o más campos
      final lastField = updatedFieldNames.removeLast();
      return 'Tu ${updatedFieldNames.join(", ")} y $lastField han sido actualizados en otro dispositivo';
    }
  }

  // Actualiza el displayName en Firebase Auth si es necesario
  void _updateUserDisplayNameIfNeeded(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        data['username'] != null &&
        data['username'] != user.displayName) {
      print("👤 [Global] Actualizando nombre de usuario en Firebase Auth");
      user
          .updateDisplayName(data['username'])
          .then((_) {
            print("✅ [Global] Nombre de usuario actualizado en Firebase Auth");
          })
          .catchError((error) {
            print("⚠️ [Global] Error actualizando nombre de usuario: $error");
          });
    }
  }

  // Maneja globalmente un cambio de correo electrónico
  void _handleEmailChangeGlobally() {
    try {
      print(
        "🔄 [Global] Forzando reload() del usuario Firebase por cambio de email",
      );

      // Hacer reload del usuario actual para que Firebase actualice su estado
      FirebaseAuth.instance.currentUser
          ?.reload()
          .then((_) {
            print("✅ [Global] Reload de Firebase completado");

            // Verificar el estado de autenticación
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              print(
                "⚠️ [Global] Usuario aún está autenticado después del cambio de email",
              );

              // Usar el servicio global de notificaciones
              GlobalNotificationService().addNotification(
                'Tu correo electrónico ha sido modificado en otro dispositivo. Necesitas volver a iniciar sesión.',
                'email_change',
                isUrgent: true,
              );

              // Cerrar sesión después de un breve retraso
              Future.delayed(const Duration(seconds: 3), () {
                _logoutAfterEmailChange();
              });
            } else {
              print("✅ [Global] Sesión ya invalidada por Firebase");
            }
          })
          .catchError((error) {
            print("❌ [Global] Error en reload Firebase: $error");
            // Si hay un error, forzar cierre de sesión
            _logoutAfterEmailChange();
          });
    } catch (e) {
      print("❌ [Global] Error general manejando cambio de email: $e");
      _logoutAfterEmailChange();
    }
  }

  // Cierra sesión después de un cambio de correo
  Future<void> _logoutAfterEmailChange() async {
    print("🚪 [Global] Cerrando sesión después de cambio de email");

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    // Cerrar sesión en el backend
    if (email != null) {
      try {
        final response = await http.post(
          Uri.parse('http://localhost:8080/api/usuaris/logout'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'email': email}),
        );
        print(
          "🔌 [Global] Logout en backend ${response.statusCode == 200 ? 'exitoso' : 'fallido'}",
        );
      } catch (e) {
        print("⚠️ [Global] Error en logout backend: $e");
      }
    }

    // Desconectar WebSocket
    WebSocketService().disconnect();

    // Cerrar sesión en Firebase
    try {
      await FirebaseAuth.instance.signOut();
      print("✅ [Global] Sesión cerrada en Firebase");

      // El listener de authStateChanges redirigirá automáticamente a LoginPage
    } catch (e) {
      print("❌ [Global] Error cerrando sesión en Firebase: $e");

      // Si hay un error, intentar forzar la navegación
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  // Libera la suscripción global al WebSocket
  void _disposeGlobalWebSocketListener() {
    _globalWebSocketSubscription?.cancel();
    _globalWebSocketSubscription = null;
    print("🛑 Escucha global de WebSocket finalizada");
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    // Close WebSocket connection when app is disposed
    _disposeGlobalWebSocketListener();
    WebSocketService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !kIsWeb) {
      // Disconnect WebSocket when app is paused
      WebSocketService().disconnect();
      _logoutUser();
    } else if (state == AppLifecycleState.resumed) {
      // Reconnect WebSocket when app is resumed, if user is logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        WebSocketService().connect();
        _initializeGlobalWebSocketListener();
      }
    }
  }

  Future<void> _logoutUser() async {
    if (!kIsWeb || _isWindowClosing) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final email = user.email;
        if (email != null) {
          // Disconnect WebSocket before logout
          WebSocketService().disconnect();

          // Realizar logout en el backend
          try {
            await http.post(
              Uri.parse('http://localhost:8080/api/usuaris/logout'),
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode({'email': email}),
            );
          } catch (e) {
            final actualContext = context;
            if (actualContext.mounted) {
              ScaffoldMessenger.of(actualContext).showSnackBar(
                SnackBar(content: Text("Error al conectar con el backend: $e")),
              );
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Usar la clave global para el navigator
      title: 'AirPlan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  AuthWrapperState createState() => AuthWrapperState();
}

class AuthWrapperState extends State<AuthWrapper> {
  // Flag para indicar si el usuario estaba previamente autenticado
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();

    // Verificar si hay un usuario actualmente autenticado
    final currentUser = FirebaseAuth.instance.currentUser;
    _wasAuthenticated = currentUser != null;
  }

  Future<bool> checkIfAdmin(String email) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/isAdmin/$email'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["isAdmin"] ?? false;
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text("Error al conectar con el backend: $e")),
        );
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;

          // Comprobar si la sesión ha caducado (estaba autenticado pero ahora no)
          if (_wasAuthenticated && user == null) {
            // La sesión ha caducado, mostrar notificación
            print("🚨 Sesión caducada detectada en AuthWrapper");

            // Usar el servicio global de notificaciones
            Future.delayed(Duration.zero, () {
              GlobalNotificationService().addNotification(
                'Tu sesión ha caducado. Por favor, inicia sesión nuevamente.',
                'session_expired',
                isUrgent: true,
              );
            });

            // Actualizar el estado
            _wasAuthenticated = false;
          } else if (user != null) {
            _wasAuthenticated = true;
          }

          if (user != null) {
            // El usuario está autenticado, verificar si es admin
            return FutureBuilder<bool>(
              future: checkIfAdmin(user.email!),
              builder: (context, adminSnapshot) {
                if (adminSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                } else {
                  final isAdmin = adminSnapshot.data ?? false;
                  // Ensure WebSocket is connected
                  WebSocketService().connect();
                  return isAdmin ? AdminPage() : MyHomePage();
                }
              },
            );
          }
          // Disconnect WebSocket if user is not authenticated
          WebSocketService().disconnect();
          return LoginPage();
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    MapPage(),
    CalendarPage(),
    UserPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'User'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
      bottomSheet: Container(height: 1, color: Colors.grey),
    );
  }
}
