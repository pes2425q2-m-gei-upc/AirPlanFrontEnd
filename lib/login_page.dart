import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sign_button/sign_button.dart';
import 'package:oauth2_client/github_oauth2_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _sendLoginToBackend(_emailController.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = "Error: Credenciales incorrectas: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
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
        print("Usuario autenticado con Firebase (web): ${userCredential.user?.uid}");
        print("Usuario autenticado con Firebase (web): ${userCredential.user?.displayName}");
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
              await user.updateDisplayName(username + "_" + githubId.toString());
              await user.reload();
              print("DisplayName actualizado en móvil: ${user.displayName}");
            }

            // Login
            await _sendLoginToBackend(email);
          }
        }
      } else {
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
        print("mamahuevo");
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
            await user.updateDisplayName(username + "_" + githubId.toString());
            await user.reload();
          }
          print("bien mas o menos, creo que bien");
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
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '952401482773-7hevpa2fa1ru3jnggq3cbvucqnka06oh.apps.googleusercontent.com',
      );
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
        Uri.parse('http://nattech.fib.upc.edu:40350/api/usuaris/usuarios/$email'),
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
      print ("Creando usuario en el backend con email: $email");
      print ("Creando usuario en el backend con displayName: $displayName");
      print ("Creando usuario en el backend con githubId: $githubId");
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/usuaris/crear'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          "username": displayName + "_" + githubId,
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
    print ("Creado usuario en el backend con email: $displayName");
  }




// Función para generar estado aleatorio
String _generateRandomString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
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
      appBar: AppBar(title: const Text("Iniciar Sesión")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Correo electrónico",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                ),
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
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}