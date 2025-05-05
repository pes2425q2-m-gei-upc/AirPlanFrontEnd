// admin_page.dart
import 'package:flutter/material.dart';
import 'package:airplan/user_page.dart';
import 'services/websocket_service.dart';
import 'services/auth_service.dart'; // Import AuthService

class AdminPage extends StatefulWidget {
  // Add support for dependency injection
  final WebSocketService? webSocketService;
  final AuthService? authService;

  const AdminPage({super.key, this.webSocketService, this.authService});

  @override
  AdminPageState createState() => AdminPageState();
}

class AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;
  late final WebSocketService _webSocketService;
  late final AuthService _authService;

  // Títulos para la AppBar según la pestaña seleccionada
  static final List<String> _appBarTitles = [
    'Perfil de Administrador',
    'Panel de Administración',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize services with injected or default instances
    _webSocketService = widget.webSocketService ?? WebSocketService();
    _authService = widget.authService ?? AuthService();
  }

  @override
  Widget build(BuildContext context) {
    // Asegurar que WebSocket esté conectado
    if (!_webSocketService.isConnected) {
      _webSocketService.connect();
    }

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitles[_selectedIndex])),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Pestaña 1: Perfil de usuario (usando UserProfileContent en lugar del Scaffold completo)
          UserProfileContent(
            authService: _authService,
            webSocketService: _webSocketService,
          ),

          // Pestaña 2: Panel de administración
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Panel de administración\n(En construcción)",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Clase que contiene solo el contenido de UserPage sin el Scaffold
class UserProfileContent extends StatelessWidget {
  final AuthService? authService;
  final WebSocketService? webSocketService;

  const UserProfileContent({
    super.key,
    this.authService,
    this.webSocketService,
  });

  @override
  Widget build(BuildContext context) {
    return UserPage(
      isEmbedded: true,
      authService: authService,
      webSocketService: webSocketService,
    );
  }
}
