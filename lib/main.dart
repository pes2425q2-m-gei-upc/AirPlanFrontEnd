// main.dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:airplan/user_page.dart';
import 'package:airplan/utils/web_utils_stub.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'calendar_page.dart';
import 'login_page.dart';
import 'map_page.dart';
import 'admin_page.dart';
import 'chat_list_page.dart'; // Import the new ChatListPage
import 'services/websocket_service.dart'; // Import WebSocket service
import 'services/api_config.dart'; // Importar la configuración de API
import 'dart:async'; // Para StreamSubscription
import 'package:easy_localization/easy_localization.dart';

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
      return;
    }

    // Marcar que estamos mostrando una notificación
    _isShowingNotification = true;

    // Tomar la primera notificación de la cola
    final notification = _pendingNotifications.removeAt(0);

    // Mostrar la notificación usando el context del navigator
    final context = navigatorKey.currentContext;
    if (context != null) {
      _showMaterialBanner(context, notification);
    } else {
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
  await EasyLocalization.ensureInitialized();

  // Inicializar datos de formateo para español y otros idiomas que puedas necesitar
  await initializeDateFormatting('es', null);

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

  // Inicializar la configuración de API
  ApiConfig().initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('es'), Locale('ca'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MiApp(),
    ),
  );
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
  // Flag para rastrear si la app estuvo en segundo plano
  bool _wasInBackground = false;
  // Tiempo de la última vez que la app estuvo activa
  int _lastActiveTimestamp = 0;

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

    // Guardar timestamp de inicio
    _lastActiveTimestamp = DateTime.now().millisecondsSinceEpoch;

    // Initialize WebSocket if user is already logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _initializeGlobalWebSocketListener();

      // Si el usuario ya está autenticado al iniciar la app,
      // forzar una recarga para sincronizar cambios que pudieron
      // haber ocurrido mientras la app estaba cerrada
      _checkForUpdatesOnLaunch(currentUser);
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

  // Verificar actualizaciones al iniciar la app
  Future<void> _checkForUpdatesOnLaunch(User user) async {
    try {
      // Registrar en log que estamos verificando actualizaciones

      // Recargar el usuario para obtener los datos más recientes
      await user.reload();

      // Notificar a toda la app que debe actualizar sus datos
      // después de un pequeño retraso para asegurar que todos los widgets están montados
      Future.delayed(const Duration(milliseconds: 500), () {
        profileUpdateStreamController.add({
          'type': 'app_launched',
          'updatedFields': ['all'],
          'data': {'timestamp': DateTime.now().millisecondsSinceEpoch},
        });
      });

      // Asegurarnos que la conexión WebSocket está activa
      WebSocketService().refreshConnection();
    } catch (e) {
      // Log error instead of having an empty catch block
      debugPrint('Error checking for updates on launch: $e');
    }
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
        // Intentar reconectar el WebSocket
        WebSocketService().reconnect();
      },
      onDone: () {
        // Intentar reconectar después de un breve retraso
        Future.delayed(const Duration(seconds: 2), () {
          if (FirebaseAuth.instance.currentUser != null) {
            WebSocketService().reconnect();
          }
        });
      },
    );
  }

  // Procesa los mensajes recibidos del WebSocket
  void _handleWebSocketMessage(String message) {
    try {
      final data = json.decode(message);

      // Comprobar si es un mensaje de actualización de perfil
      if (data['type'] == 'PROFILE_UPDATE') {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null &&
            (data['username'] == currentUser.displayName ||
                data['email'] == currentUser.email)) {
          final updatedFields = data['updatedFields'] as List<dynamic>;
          final isEmailUpdate = updatedFields.contains('email');

          // Emitir el evento a través del StreamController para que otros widgets puedan reaccionar
          profileUpdateStreamController.add({
            'type': 'profile_update',
            'updatedFields': updatedFields,
            'data': data,
          });

          // Si es un cambio de correo, necesitamos manejar la sesión
          if (isEmailUpdate) {
            _handleEmailChangeGlobally();
          } else {
            // Para otros cambios, actualizamos la información de usuario y mostramos notificación
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
            FirebaseAuth.instance.currentUser?.reload();
          }
        }
      }
    } catch (e) {
      // Error silencioso - el manejo de errores ya está implementado en los listeners
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
      user.updateDisplayName(data['username']);
    }
  }

  // Maneja globalmente un cambio de correo electrónico
  void _handleEmailChangeGlobally() {
    try {
      // Hacer reload del usuario actual para que Firebase actualice su estado
      FirebaseAuth.instance.currentUser
          ?.reload()
          .then((_) {
            // Verificar el estado de autenticación
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
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
            }
          })
          .catchError((_) {
            // Si hay un error, forzar cierre de sesión
            _logoutAfterEmailChange();
          });
    } catch (e) {
      _logoutAfterEmailChange();
    }
  }

  // Cierra sesión después de un cambio de correo
  Future<void> _logoutAfterEmailChange() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    // Cerrar sesión en el backend
    if (email != null) {
      try {
        await http.post(
          Uri.parse(ApiConfig().buildUrl('api/usuaris/logout')),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'email': email}),
        );
      } catch (e) {
        // Error silencioso
      }
    }

    // Desconectar WebSocket
    WebSocketService().disconnect();

    // Cerrar sesión en Firebase
    try {
      await FirebaseAuth.instance.signOut();
      // El listener de authStateChanges redirigirá automáticamente a LoginPage
    } catch (e) {
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
      // La app está entrando en segundo plano
      _wasInBackground = true;
      _lastActiveTimestamp = DateTime.now().millisecondsSinceEpoch;
      // Disconnect WebSocket when app is paused
      WebSocketService().disconnect();
    } else if (state == AppLifecycleState.resumed) {
      // La app está volviendo al primer plano
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Reconectar WebSocket
        WebSocketService().connect();
        _initializeGlobalWebSocketListener();

        // Calcular cuánto tiempo ha pasado desde la última vez activa
        final now = DateTime.now().millisecondsSinceEpoch;
        final timeDiff = now - _lastActiveTimestamp;

        // Si han pasado más de 5 segundos en segundo plano o fue cerrada completamente (_wasInBackground)
        if (_wasInBackground || timeDiff > 5000) {
          _wasInBackground = false;
          _lastActiveTimestamp = now;

          // Forzar recarga de datos de Firebase para sincronizar cambios
          currentUser
              .reload()
              .then((_) {
                // Notificar a toda la app que los datos pueden haber cambiado
                profileUpdateStreamController.add({
                  'type': 'app_resumed',
                  'updatedFields': ['all'],
                  'data': {'timestamp': now},
                });
              })
              .catchError((error) {
                // Manejar error de recarga silenciosamente
                debugPrint('Error al recargar datos de Firebase: $error');
              });
        }
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
              Uri.parse(ApiConfig().buildUrl('api/usuaris/logout')),
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
      navigatorKey: navigatorKey,
      title: tr('app_title'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      locale: EasyLocalization.of(context)!.locale,
      supportedLocales: EasyLocalization.of(context)!.supportedLocales,
      localizationsDelegates: EasyLocalization.of(context)!.delegates,
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
  bool _langLoaded = false;
  // Flag para indicar si el usuario estaba previamente autenticado
  bool _wasAuthenticated = false;
  // Flag para indicar si el logout fue manual
  bool _isManualLogout = false;

  @override
  void initState() {
    super.initState();

    // Verificar si hay un usuario actualmente autenticado
    final currentUser = FirebaseAuth.instance.currentUser;
    _wasAuthenticated = currentUser != null;
  }

  // Método para establecer que el logout es manual
  void setManualLogout(bool isManual) {
    setState(() {
      _isManualLogout = isManual;
    });
  }

  Future<bool> checkIfAdmin(String email) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig().buildUrl('isAdmin/$email')),
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

          // Cargar idioma del usuario según configuración del backend
          if (user != null && !_langLoaded) {
            print('Cargando idioma del usuario: ${user.email}');
            _langLoaded = true;
            _fetchUserLanguage(user);
          }
          // Comprobar si la sesión ha caducado (estaba autenticado pero ahora no)
          if (_wasAuthenticated && user == null && !_isManualLogout) {
            // La sesión ha caducado, mostrar notificación solo si NO es logout manual
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
            // Resetear la bandera de logout manual cuando hay un nuevo login
            _isManualLogout = false;
          } else if (user == null && _isManualLogout) {
            // Si es un logout manual, simplemente actualizamos el estado sin mostrar notificación
            _wasAuthenticated = false;
            // Resetear la bandera después de procesarla
            _isManualLogout = false;
          }

          if (user != null) {
            // El usuario está autenticado, verificar si es admin
            return FutureBuilder<bool>(
              future: checkIfAdmin(user.email!),
              builder: (context, adminSnapshot) {
                if (adminSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                } else {
                  final isAdmin = adminSnapshot.data ?? false;
                  // Ensure WebSocket is connected
                  WebSocketService().connect();
                  return isAdmin ? AdminPage() : const MyHomePage();
                }
              },
            );
          }
          // Disconnect WebSocket if user is not authenticated
          WebSocketService().disconnect();
          return const LoginPage();
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  // Obtener y aplicar el idioma del usuario desde el backend
  Future<void> _fetchUserLanguage(User user) async {
    try {
      print('Fetching user language for: ${user.email}');
      // Obtener idioma de usuario usando el endpoint correcto por username
      final username = user.displayName ?? user.email ?? '';
      final url = ApiConfig().buildUrl(
        'api/usuaris/usuario-por-username/$username',
      );
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print('User language response: ${response.body}');
        final data = jsonDecode(response.body);
        final rawLang = (data['idioma'] as String? ?? 'en').toLowerCase();
        print('Raw language: $rawLang');
        // Mapear nombres de idioma desde backend a códigos de locale
        final localeCode =
            rawLang.contains('eng')
                ? 'en'
                : rawLang.contains('castellano')
                ? 'es'
                : rawLang.contains('ca')
                ? 'ca'
                : 'en';
        // Aplicar locale con la extensión de easy_localization
        print('Setting locale to: $localeCode');
        await context.setLocale(Locale(localeCode));
      }
    } catch (e) {
      debugPrint('Error fetching user language: $e');
    }
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
    const ChatListPage(), // Add the Chat tab
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
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ), // New chat tab
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'User'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
        type:
            BottomNavigationBarType
                .fixed, // Add this to support more than 3 items
      ),
      bottomSheet: Container(height: 1, color: Colors.grey),
    );
  }
}
