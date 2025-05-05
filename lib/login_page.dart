import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para usar jsonEncode
import 'register.dart'; // Importem la pantalla de registre
import 'reset_password.dart'; // Importem la pantalla de restabliment de contrasenya
import 'main.dart'; // Importamos main.dart para acceder a AuthWrapper
import 'services/websocket_service.dart'; // Import WebSocket service
import 'services/api_config.dart'; // Importar la configuración de API
import 'services/auth_service.dart'; // Importamos AuthService

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
      // Manejar errores (tanto de FirebaseAuth como otros)
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
              onSubmitted: (_) => _signIn(), // Añadir esta línea
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Contrasenya",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _signIn(), // Añadir esta línea
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _signIn,
              child: const Text("Iniciar Sessió"),
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
