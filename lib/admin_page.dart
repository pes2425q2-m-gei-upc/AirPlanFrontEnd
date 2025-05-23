// admin_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:airplan/user_page.dart';
import 'services/websocket_service.dart';
import 'services/auth_service.dart'; // Import AuthService
import 'package:airplan/filtros_admin_content.dart'; // Import the new filters content page

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
    'admin_profile_title'.tr(),
    'admin_panel_title'.tr(),
    'content_filters_title'.tr(), // Updated title for the Filters tab
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
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "admin_panel_construction".tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Pestaña 3: Filtros (content of the new filters page)
          const FiltrosAdminContent(), // Use the new widget here
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'profile_tab_label'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.admin_panel_settings),
            label: 'admin_tab_label'.tr(),
          ),
          BottomNavigationBarItem(
            // Nueva pestaña Filtros
            icon: const Icon(Icons.filter_list),
            label: 'filters_tab_label'.tr(),
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
