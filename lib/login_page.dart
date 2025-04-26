import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para usar jsonEncode
import 'register.dart'; // Importem la pantalla de registre
import 'reset_password.dart'; // Importem la pantalla de restabliment de contrasenya
import 'main.dart'; // Importamos main.dart para acceder a AuthWrapper
import 'services/websocket_service.dart'; // Import WebSocket service
import 'services/api_config.dart'; // Importar la configuración de API
import 'package:sign_button/sign_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;

  Future<void> _signIn() async {
    try {
      // Iniciar sesión en Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
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
      final clientId = WebSocketService().clientId;

      // Enviar un POST al backend para el login, incluyendo ahora username y clientId
      final response = await http.post(
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
      WebSocketService().connect();

      // Forzar la navegación a la página principal usando AuthWrapper
      if (mounted) {
        // Usando Navigator.pushAndRemoveUntil para limpiar la pila de navegación
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => AuthWrapper()),
          (route) => false, // Esto elimina todas las rutas anteriores
        );
      }
    } on FirebaseAuthException {
      // Manejar errores de Firebase
      setState(() {
        _errorMessage = "Error: Credencials incorrectes";
      });
    } catch (e) {
      // Manejar otros errores
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
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

        final userCredential = await _auth.signInWithPopup(githubProvider);
        //print("Usuario autenticado con Firebase (web): ${userCredential.user?.uid}");
        //print("Usuario autenticado con Firebase (web): ${userCredential.user?.displayName}");
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
            final user = _auth.currentUser;
            if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
              await user.updateDisplayName("${username}_${githubId.toString()}");
              await user.reload();
              //print("DisplayName actualizado en móvil: ${user.displayName}");
            }

            // Login
            await _sendLoginToBackend(email);
          }
        }
      } else { // no funciona ni para atras, 15 horas en esto y sigue sin redirigir si no se ha conectado a githú o eso creo :(
        // 📱 FLUJO PARA MÓVIL
        final githubProvider = GithubAuthProvider();
        githubProvider.addScope('read:user,user:email');

        final UserCredential userCredential = await _auth.signInWithProvider(githubProvider);

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
        //print("mamahuevo");
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
          final user = _auth.currentUser;
          if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
            await user.updateDisplayName("${username}_${githubId.toString()}");
            await user.reload();
          }
          //print("bien mas o menos, creo que bien");
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

  Future<bool> _checkUserExists(String email) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/usuaris/usuarios/$email'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
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
      //print ("Creando usuario en el backend con email: $email");
      //print ("Creando usuario en el backend con displayName: $displayName");
      //print ("Creando usuario en el backend con githubId: $githubId");
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/usuaris/crear'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          "username": "${displayName}_${githubId.toString()}",
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
    //print ("Creado usuario en el backend con email: $displayName");
  }

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
      await _auth.signOut();
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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Contrasenya",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _signIn,
              child: const Text("Iniciar Sessió"),
            ),
            if (kIsWeb) ...[
              SizedBox(height: 12),
              SignInButton(
                buttonType: ButtonType.github,
                buttonSize: ButtonSize.large,
                onPressed: _isLoading ? null : _signInWithGitHub,
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpPage()),
                );
              },
              child: const Text("No tens compte? Registra't aquí"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ResetPasswordPage(),
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
