// admin_page.dart
import 'package:flutter/material.dart';
import 'package:airplan/user_page.dart';
import 'services/websocket_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  AdminPageState createState() => AdminPageState();
}

class AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;

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
  Widget build(BuildContext context) {
    // Asegurar que WebSocket esté conectado
    if (!WebSocketService().isConnected) {
      WebSocketService().connect();
    }

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitles[_selectedIndex])),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Pestaña 1: Perfil de usuario (usando UserProfileContent en lugar del Scaffold completo)
          UserProfileContent(),

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
  const UserProfileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserPage(isEmbedded: true);
  }
}
