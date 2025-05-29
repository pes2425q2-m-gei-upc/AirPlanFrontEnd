import 'package:airplan/services/google_calendar_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para usar jsonEncode
import 'register.dart'; // Importem la pantalla de registre
import 'reset_password.dart'; // Importem la pantalla de restabliment de contrasenya
import 'main.dart'; // Importamos main.dart para acceder a AuthWrapper
import 'services/websocket_service.dart'; // Import WebSocket service
import 'services/api_config.dart'; // Importar la configuración de API
import 'services/auth_service.dart'; // Importamos AuthService
import 'package:sign_button/sign_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io' show Platform;

class LoginPage extends StatefulWidget {
  // Añadimos la posibilidad de inyectar el AuthService
  final AuthService? authService;
  final WebSocketService? webSocketService;
  final http.Client? httpClient;
  final Widget? signUpPage;

  const LoginPage({
    super.key,
    this.authService,
    this.webSocketService,
    this.httpClient,
    this.signUpPage,
  });

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  // Usamos late para inicializar en initState
  late final AuthService _authService;
  late final WebSocketService _webSocketService;
  late final http.Client _httpClient;
  late final GoogleCalendarService _googleCalendarService;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    try {
      // Inicializamos los servicios usando los proporcionados o creando nuevos
      _authService = widget.authService ?? AuthService();
      _webSocketService = widget.webSocketService ?? WebSocketService();
      _httpClient = widget.httpClient ?? http.Client();

      // Configuramos Google Calendar Service
      final googleSignIn = GoogleSignIn(
        scopes: [
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/userinfo.email',
        ],
        clientId: kIsWeb
            ? '751649023508-e62rslll2c8n864juq95j1rd7a8t26d0.apps.googleusercontent.com'
            : Platform.isAndroid
            ? '751649023508-e62rslll2c8n864juq95j1rd7a8t26d0.apps.googleusercontent.com' // Usa el mismo ID que web para pruebas
            : null,
      );

      _googleCalendarService = GoogleCalendarService(googleSignIn: googleSignIn);
    } catch (e) {
      // Manejo de errores más específico
      debugPrint('Error inicializando servicios: $e');
      _authService = AuthService();
      _webSocketService = WebSocketService();
      _httpClient = http.Client();

      // Configuración básica para tests
      _googleCalendarService = GoogleCalendarService(
        googleSignIn: GoogleSignIn(
          scopes: [
            'https://www.googleapis.com/auth/calendar',
            'https://www.googleapis.com/auth/userinfo.email',
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    // Si creamos un cliente HTTP, lo cerramos al finalizar
    if (widget.httpClient == null) {
      _httpClient.close();
    }
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Usar AuthService en lugar de Firebase directamente
      final userCredential = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) {
        setState(() {
          _errorMessage = "login_error_user_info_null".tr();
        });
        return;
      }

      final firebaseEmail = user.email;
      final username = user.displayName;

      if (username == null || firebaseEmail == null) {
        setState(() {
          _errorMessage = "login_error_user_info_missing".tr();
        });
        return;
      }

      // Obtener el clientId del WebSocketService
      final clientId = _webSocketService.clientId;

      // Enviar un POST al backend para el login, incluyendo ahora username y clientId
      final response = await _httpClient.post(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/login')),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          "email": firebaseEmail,
          "username": username,
          "clientId":
              clientId, // Incluir el clientId para filtrar notificaciones WebSocket
        }),
      );

      // Verificar la respuesta del backend
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = "login_error_backend_status".tr(
            args: [response.body],
          );
        });
        return;
      }

      // Initialize WebSocket connection after successful login
      _webSocketService.connect();

      // Forzar la navegación a la página principal usando AuthWrapper
      if (mounted) {
        // Usando Navigator.pushAndRemoveUntil para limpiar la pila de navegación
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => AuthWrapper()),
          (route) => false, // Esto elimina todas las rutas anteriores
        );
      }
    } catch (e) {
      // Manejar otros errores
      setState(() {
        _errorMessage = "login_error_incorrect_credentials".tr();
        _isLoading = false;
      });
    }
  }

  /*Future<void> _signInWithGitHub() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (kIsWeb) {
        // 🌐 FLUJO PARA WEB
        final githubProvider = GithubAuthProvider();
        githubProvider.addScope('read:user');
        githubProvider.addScope('user:email');

        final userCredential = await _authService.signInWithPopup(
          githubProvider,
        );
        final email = userCredential.user?.email;

        final OAuthCredential githubAuthCredential =
            userCredential.credential as OAuthCredential;
        final String? githubAccessToken = githubAuthCredential.accessToken;

        if (email != null && githubAccessToken != null) {
          // Obtener datos del usuario de GitHub
          final response = await http.get(
            Uri.parse('https://api.github.com/user'),
            headers: {
              'Authorization': 'token $githubAccessToken',
              'Accept': 'application/vnd.github.v3+json',
            },
          );

          if (response.statusCode == 200) {
            final userData = jsonDecode(response.body);
            String username = userData['login'];
            final int githubId = userData['id'];

            // Verificar si el usuario existe
            final userExists = await _checkUserExists(email);
            if (!userExists) {
              // Crear el usuario
              await _createUserInBackend(email, username, githubId.toString());
            }

            //preguntar MARWAN, AYUDA
            if ((_authService.getCurrentUsername() == null ||
                _authService.getCurrentUsername()!.isEmpty)) {
              await _authService.updateDisplayName("${username}_$githubId");
              await _authService.reloadCurrentUser();
            }

            // Login
            await _sendLoginToBackend(email);
          }
        }
      } else {
        // 📱 FLUJO PARA MÓVIL
        final githubProvider = GithubAuthProvider();
        githubProvider.addScope('read:user,user:email');

        final UserCredential userCredential = await _authService
            .signInWithProvider(githubProvider);

        // 1. Obtener el access_token de GitHub
        final OAuthCredential? credential =
            userCredential.credential as OAuthCredential?;
        final String? githubAccessToken = credential?.accessToken;

        if (githubAccessToken == null) {
          throw Exception("login_error_github_token_null".tr());
        }

        // 2. Obtener datos del usuario de GitHub
        final response = await http.get(
          Uri.parse('https://api.github.com/user'),
          headers: {
            'Authorization': 'token $githubAccessToken',
            'Accept': 'application/vnd.github.v3+json',
          },
        );

        if (response.statusCode != 200) {
          throw Exception(
            "login_error_github_data_fetch".tr(args: [response.body]),
          );
        }
        final userData = jsonDecode(response.body);
        String username = userData['login'];
        final int githubId = userData['id'];

        // 3. Verificar/crear usuario en backend usando GITHUB_ID (no UID de Firebase)
        final email = userCredential.user?.email;

        if (email != null) {
          final userExists = await _checkUserExists(email);
          if (!userExists) {
            await _createUserInBackend(
              email,
              username,
              githubId.toString(), // Usar ID de GitHub, no UID de Firebase
            );
          }

          // 4. Actualizar displayName en Firebase si es necesario
          if ((_authService.getCurrentUsername() == null ||
              _authService.getCurrentUsername()!.isEmpty)) {
            await _authService.updateDisplayName("${username}_$githubId");
            await _authService.reloadCurrentUser();
          }

          await _sendLoginToBackend(email);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "login_error_auth_exception".tr(args: [e.toString()]);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }*/

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final GoogleSignIn googleSignIn;
      if (kIsWeb) {
        googleSignIn = GoogleSignIn(
          clientId: '751649023508-e62rslll2c8n864juq95j1rd7a8t26d0.apps.googleusercontent.com',
          scopes: [
            'email',
            'https://www.googleapis.com/auth/calendar',
          ],
        );
      } else {
        googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/calendar',
          ],
        );
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _errorMessage = "login_error_google_cancelled".tr();
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final email = firebaseUser.email;
        final displayName = firebaseUser.displayName ?? "google_user";
        final uid = firebaseUser.uid;

        if (email != null) {
          // Verificar acceso al calendario
          try {
            final googleSignIn = _googleCalendarService.getGoogleSignIn();
            final hasAccess = await googleSignIn.canAccessScopes([
              'https://www.googleapis.com/auth/calendar'
            ]);
            if (!hasAccess) {
              throw Exception('No hay acceso al calendario de Google');
            }
          } catch (calendarError) {
            debugPrint('Error al verificar acceso al calendario: $calendarError');
          }

          final userExists = await _checkUserExists(email);
          if (!userExists) {
            await _createUserInBackend(email, displayName, uid);
            await _authService.updateDisplayName("${displayName}_$uid");
            await _authService.reloadCurrentUser();
          }

          await _sendLoginToBackend(email);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "login_error_auth_google_exception".tr(
          args: [e.toString()],
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Función para verificar si el usuario existe en el backend
  Future<bool> _checkUserExists(String email) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/usuarios/$email')),
      );

      if (response.statusCode == 200) {
        // Si el backend responde con 200, el usuario existe
        return true;
      } else if (response.statusCode == 404) {
        // Si el backend responde con 404, el usuario no existe
        return false;
      } else {
        throw Exception(
          'login_error_verifying_user_backend'.tr(args: [response.body]),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'login_error_contacting_backend_exception'.tr(
          args: [e.toString()],
        );
      });
      return false;
    }
  }

  // Función para crear un nuevo usuario en el backend
  Future<void> _createUserInBackend(
    String email,
    String displayName,
    String githubId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/crear')),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          "username": "${displayName}_$githubId",
          "nom": displayName,
          "email": email,
          "sesionIniciada": true,
          "idioma": 'Castellano', // Puedes modificar el idioma si lo necesitas
          "isAdmin": false,
          "esExtern": false,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception(
          'login_error_creating_user_backend'.tr(args: [response.body]),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'login_error_creating_user_exception'.tr(
          args: [e.toString()],
        );
      });
    }
  }

  // Función para generar estado aleatorio

  Future<void> _sendLoginToBackend(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/login')),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'login_error_backend_detail_exception'.tr(args: [response.body]),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      await _authService.signOut();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('login_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'email_label'.tr(),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'password_label'.tr(),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _signIn(),
            ),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : Text('login_button'.tr()),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: SizedBox(
                        width: 200,
                        child: SignInButton(
                          buttonType: ButtonType.google,
                          buttonSize: ButtonSize.small,
                          btnText: "Google",
                          onPressed: _isLoading ? null : _signInWithGoogle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            widget.signUpPage ??
                            SignUpPage(authService: _authService),
                  ),
                );
              },
              child: Text('signup_prompt'.tr()),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            ResetPasswordPage(authService: _authService),
                  ),
                );
              },
              child: Text('reset_password'.tr()),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
