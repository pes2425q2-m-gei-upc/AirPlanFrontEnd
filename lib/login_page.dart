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
    } catch (_) {
      // Tests may instantiate state directly without widget
      _authService = AuthService();
      _webSocketService = WebSocketService();
      _httpClient = http.Client();
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
          _errorMessage =
              "Error: No se pudo obtener la información del usuario";
        });
        return;
      }

      final firebaseEmail = user.email;
      final username = user.displayName;

      if (username == null || firebaseEmail == null) {
        setState(() {
          _errorMessage = "Error: Falta información del usuario";
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
          _errorMessage = "Error en el backend: ${response.body}";
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
        _errorMessage = "Error: Credencials incorrectes";
        if (e.toString().contains("invalid-credential") ||
            e.toString().contains("wrong-password") ||
            e.toString().contains("user-not-found")) {
          _errorMessage = "Error: Credencials incorrectes";
        } else {
          _errorMessage = "Error: ${e.toString()}";
        }
      });
    }
  }

  Future<void> _signInWithGitHub() async {
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

        final userCredential = await _authService.signInWithPopup(githubProvider);
        final email = userCredential.user?.email;

        final OAuthCredential githubAuthCredential = userCredential.credential as OAuthCredential;
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
            if ( (_authService.getCurrentUsername() == null || _authService.getCurrentUsername()!.isEmpty)) {
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

        final UserCredential userCredential = await _authService.signInWithProvider(githubProvider);

// 1. Obtener el access_token de GitHub
        final OAuthCredential? credential = userCredential.credential as OAuthCredential?;
        final String? githubAccessToken = credential?.accessToken;

        if (githubAccessToken == null) {
          throw Exception("No se pudo obtener el token de GitHub");
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
          throw Exception("Error al obtener datos de GitHub: ${response.body}");
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
          if ((_authService.getCurrentUsername() == null || _authService.getCurrentUsername()!.isEmpty)) {
            await _authService.updateDisplayName("${username}_$githubId");
            await _authService.reloadCurrentUser();
          }

          await _sendLoginToBackend(email);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error de autenticación: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final GoogleSignIn googleSignIn;
      if (kIsWeb) {
        googleSignIn = GoogleSignIn(
          clientId: '751649023508-rji7074men2mm1198oq93pvqc1nklip1.apps.googleusercontent.com',
        );
      } else {
        googleSignIn = GoogleSignIn();
      }
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _errorMessage = "Inicio de sesión cancelado";
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final email = firebaseUser.email;
        final displayName = firebaseUser.displayName ?? "google_user";
        final uid = firebaseUser.uid;

        if (email != null) {
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
        _errorMessage = "Error de autenticación con Google: $e";
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
        Uri.parse(
            'https://nattech.fib.upc.edu:40350/api/usuaris/usuarios/$email'),
      );

      if (response.statusCode == 200) {
        // Si el backend responde con 200, el usuario existe
        return true;
      } else if (response.statusCode == 404) {
        // Si el backend responde con 404, el usuario no existe
        return false;
      } else {
        throw Exception('Error al verificar usuario: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al contactar con el backend: ${e.toString()}';
      });
      return false;
    }
  }


// Función para crear un nuevo usuario en el backend
  Future<void> _createUserInBackend(String email, String displayName, String githubId) async {
    try {
      final response = await http.post(
        Uri.parse('https://nattech.fib.upc.edu:40350/api/usuaris/crear'),
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
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Error al crear el usuario: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al crear el usuario: ${e.toString()}';
      });
    }
  }




// Función para generar estado aleatorio


  Future<void> _sendLoginToBackend(String email) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/usuaris/login'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode != 200) {
        throw Exception('Error del backend: ${response.body}');
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
      appBar: AppBar(title: const Text("Iniciar Sessió")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Correu electrònic",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Contrasenya",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _signIn(),
            ),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Iniciar Sesión"),
            ),
            const SizedBox(height: 12),
            // Botón de GitHub con sign_button
            SignInButton(
              buttonType: ButtonType.github,
              buttonSize: ButtonSize.large,
              onPressed: _isLoading ? null : _signInWithGitHub,
            ),
            const SizedBox(height: 12),
            SignInButton(
              buttonType: ButtonType.google,
              buttonSize: ButtonSize.large,
              onPressed: _isLoading ? null : _signInWithGoogle,
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
              child: const Text("No tens compte? Registra't aquí"),
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
              child: const Text("Has oblidat la contrasenya?"),
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