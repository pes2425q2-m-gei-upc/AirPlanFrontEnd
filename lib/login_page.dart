import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para usar jsonEncode
import 'register.dart'; // Importem la pantalla de registre
import 'reset_password.dart'; // Importem la pantalla de restabliment de contrasenya
import 'main.dart'; // Importamos main.dart para acceder a AuthWrapper
import 'services/websocket_service.dart'; // Import WebSocket service

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
        Uri.parse('http://localhost:8080/api/usuaris/login'),
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

      // La sincronización del email ya se está manejando en el backend
      print('✅ Login exitoso');
      print('🔌 WebSocket connection initialized');
      print('🆔 ClientId: $clientId enviado en la solicitud de login');

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
