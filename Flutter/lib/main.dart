import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:prueba_flutter/user_page.dart';
import 'dart:html' as html;

import 'calendar_page.dart';
import 'login_page.dart';
import 'map_page.dart'; // Solo para web
import 'admin_page.dart'; // Importa la vista de administrador

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyDjyHcnvD1JTfN7xpkRMD-S_qDMSnvbZII",
      authDomain: "airplan-f08be.firebaseapp.com",
      projectId: "airplan-f08be",
      storageBucket: "airplan-f08be.firebasestorage.app",
      messagingSenderId: "952401482773",
      appId: "1:952401482773:web:9f9a3484c2cce60970ea1c",
      measurementId: "G-L70Y1N6J8Z",
    ),
  );
  runApp(MiApp());
}

class MiApp extends StatefulWidget {
  const MiApp({super.key});

  @override
  State<MiApp> createState() => _MiAppState();
}

class _MiAppState extends State<MiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Registrar el observador del ciclo de vida (solo para móvil)
    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    } else {
      // Manejar el evento beforeunload en web
      html.window.addEventListener('beforeunload', (event) async {
        await _logoutUser();
      });
    }
  }

  @override
  void dispose() {
    // Eliminar el observador del ciclo de vida (solo para móvil)
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // La aplicación entró en segundo plano (móvil)
      _logoutUser();
    }
  }

  Future<void> _logoutUser() async {
    print("Cerrando sesión en el backend...");
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email;
      print("Sesión cerrada en Firebase para el usuario: $email");
      if (email != null) {
        print("se va a cerrar en el backend");
        // Enviar la solicitud POST al backend
        final response = await http.post(
          Uri.parse('http://localhost:8080/api/usuaris/logout'), // Cambia la URL por la de tu backend
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode({'email': email}),
        );
        print("se cerro en el backend");
        if (response.statusCode == 200) {
          print("Sesión cerrada en el backend para el usuario: $email");
        } else {
          print("Error al cerrar la sesión en el backend: ${response.body}");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LoginPage();
  }

}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    MapPage(),
    CalendarPage(),
    UserPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Corregido: se eliminó el paréntesis extra
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'User',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}