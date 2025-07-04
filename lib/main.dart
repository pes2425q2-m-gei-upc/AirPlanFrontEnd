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
import 'services/registration_state_service.dart'; // Import registration state service
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
      Future.delayed(const Duration(seconds: 12), () {
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
      case 'message':
        return Colors.green;
      case 'activity_reminder':
        return Colors.yellow;
      case 'invitacions':
        return Colors.purple;
      case 'note_reminder':
        return Colors.teal;
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
      case 'activity_reminder':
        return Icons.access_alarm;
      case 'message':
        return Icons.message;
      case 'invitacions':
        return Icons.group_add;
      case 'note_reminder':
        return Icons.note;
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
        debugPrint('User logged in: ${user.email}');
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
              'profile_update'.tr(),
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
      return 'your_profile_updated'.tr();
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
      return '${'profile_field_updated'.tr()} ${updatedFieldNames[0]}';
    } else if (updatedFieldNames.length == 2) {
      return '${'profile_fields_updated_two'.tr()} ${updatedFieldNames[0]} y ${updatedFieldNames[1]}';
    } else {
      // Para 3 o más campos
      final lastField = updatedFieldNames.removeLast();
      return '${'profile_fields_updated_many'.tr()} ${updatedFieldNames.join(", ")} y $lastField';
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
                'email_change_verify_again'.tr(),
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
                SnackBar(
                  content: Text("${"error_connecting_backend".tr()} $e"),
                ),
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
      title: "Airplan",
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
  String? _lastUserId; // Para evitar recargas innecesarias
  StreamSubscription<RegistrationState>? _registrationSubscription;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios en el estado de registro
    _registrationSubscription = RegistrationStateService().stateStream.listen((
      state,
    ) {
      if (state == RegistrationState.completed && mounted) {
        // Si el registro se completó, forzar una reconstrucción después de un breve delay
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _registrationSubscription?.cancel();
    super.dispose();
  }

  Future<bool> checkIfAdmin(String email) async {
    // Construir URL y log para depuración
    final url = ApiConfig().buildUrl('isAdmin/$email');
    debugPrint('>>> checkIfAdmin: GET $url');
    try {
      final response = await http.get(Uri.parse(url));
      debugPrint(
        '>>> checkIfAdmin response: ${response.statusCode} ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["isAdmin"] ?? false;
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text("${"error_connecting_backend".tr()} $e")),
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
        // Mostrar loading mientras se establece la conexión
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;

          // Si no hay usuario, mostrar login
          if (user == null) {
            _langLoaded = false;
            _lastUserId = null;
            WebSocketService().disconnect();
            // Resetear el estado de registro si no hay usuario
            RegistrationStateService().reset();
            return const LoginPage();
          }

          // Verificar si estamos en proceso de registro para este usuario
          final registrationService = RegistrationStateService();
          if (registrationService.isRegistering(user.email)) {
            // Mostrar pantalla de loading mientras se completa el registro
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Completando registro...'),
                  ],
                ),
              ),
            );
          }

          // Verificar si es un nuevo usuario o si cambió el usuario
          final currentUserId = user.uid;
          if (_lastUserId != currentUserId) {
            _langLoaded = false;
            _lastUserId = currentUserId;
          }

          // Asegurar que el usuario esté completamente cargado antes de proceder
          return FutureBuilder<void>(
            future: _ensureUserReady(user),
            builder: (context, readySnapshot) {
              if (readySnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Cargar idioma del usuario según configuración del backend
              if (!_langLoaded) {
                _langLoaded = true;
                _fetchUserLanguage(user);
              }

              // El usuario está autenticado, verificar si es admin
              return FutureBuilder<bool>(
                future: checkIfAdmin(user.email!),
                builder: (context, adminSnapshot) {
                  if (adminSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Manejar errores en la verificación de admin
                  if (adminSnapshot.hasError) {
                    debugPrint(
                      'Error checking admin status: ${adminSnapshot.error}',
                    );
                    // En caso de error, asumir que no es admin
                    WebSocketService().connect();
                    return const MyHomePage();
                  }

                  final isAdmin = adminSnapshot.data ?? false;
                  // Ensure WebSocket is connected
                  WebSocketService().connect();
                  debugPrint(
                    'User is authenticated: ${user.email}, Admin: $isAdmin',
                  );
                  return isAdmin ? AdminPage() : const MyHomePage();
                },
              );
            },
          );
        }

        // Fallback para otros estados de conexión
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  // Asegurar que el usuario esté completamente configurado
  Future<void> _ensureUserReady(User user) async {
    try {
      // Recargar el usuario para obtener la información más reciente
      await user.reload();

      // Verificar que el usuario sigue autenticado después del reload
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != user.uid) {
        throw Exception('Usuario no válido después del reload');
      }

      // Pequeña pausa para asegurar que todos los procesos estén completos
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('Error ensuring user ready: $e');
      // Si hay un error, cerrar sesión para evitar estados inconsistentes
      await FirebaseAuth.instance.signOut();
      rethrow;
    }
  }

  // Obtener y aplicar el idioma del usuario desde el backend
  Future<void> _fetchUserLanguage(User user) async {
    try {
      // Obtener idioma de usuario usando el endpoint correcto por username
      final username = user.displayName ?? user.email ?? '';
      final url = ApiConfig().buildUrl(
        'api/usuaris/usuario-por-username/$username',
      );
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawLang = (data['idioma'] as String? ?? 'en').toLowerCase();
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
        if (!mounted) return;
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
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'.tr()),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat'.tr(),
          ), // New chat tab
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'User'.tr()),
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
