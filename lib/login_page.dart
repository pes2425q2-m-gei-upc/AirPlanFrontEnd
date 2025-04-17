import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para usar jsonEncode
import 'register.dart'; // Importem la pantalla de registre
import 'reset_password.dart'; // Importem la pantalla de restabliment de contrasenya
import 'user_services.dart'; // Importamos el servicio de gestión de correos

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
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Si el login en Firebase es correcto, enviar un POST al backend
      final response = await http.post(
        Uri.parse(
          'http://localhost:8080/api/usuaris/login',
        ), // Cambia la URL por la de tu backend
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({"email": _emailController.text.trim()}),
      );

      // Verificar la respuesta del backend
      if (response.statusCode != 200) {
        // Si el backend responde con un error, mostrar el mensaje de error
        setState(() {
          _errorMessage = "Error en el backend: ${response.body}";
        });
      } else {
        // Login exitoso, ahora iniciamos el servicio de gestión de correos
        await EmailChangeManager().initialize();
        print('🔐 Login exitoso, EmailChangeManager inicializado');
      }
    } on FirebaseAuthException catch (e) {
      // Manejar errores de Firebase
      setState(() {
        _errorMessage = "Error: Credencials incorrectes: ${e.message}";
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
