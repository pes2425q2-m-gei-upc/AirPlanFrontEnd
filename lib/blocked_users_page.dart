import 'package:flutter/material.dart';
import 'package:airplan/services/user_block_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/services/auth_service.dart';

class BlockedUsersPage extends StatefulWidget {
  final String username;
  final AuthService? authService;
  final UserBlockService? blockService;
  final NotificationService?
  notificationService; // Add NotificationService as a dependency

  const BlockedUsersPage({
    super.key,
    required this.username,
    this.authService,
    this.blockService,
    this.notificationService, // Initialize NotificationService
  });

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  late final UserBlockService _blockService;
  late final AuthService _authService;
  late final NotificationService
  _notificationService; // Add NotificationService
  bool _isLoading = true;
  List<dynamic> _blockedUsers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _blockService = widget.blockService ?? UserBlockService();
    _authService = widget.authService ?? AuthService();
    _notificationService =
        widget.notificationService ??
        NotificationService(); // Initialize NotificationService
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final blockedUsers = await _blockService.getBlockedUsers(widget.username);

      setState(() {
        _blockedUsers = blockedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar los usuarios bloqueados: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String blockedUsername) async {
    final user = _authService.getCurrentUser();
    if (user == null || user.displayName == null) {
      _notificationService.showError(
        context,
        'No se pudo identificar tu usuario. Por favor, inicia sesión nuevamente.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Desbloquear a $blockedUsername'),
            content: Text(
              '¿Estás seguro de que quieres desbloquear a este usuario? Podrás volver a ver sus mensajes y actividades.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: const Text('Desbloquear'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _blockService.unblockUser(
        user.displayName!,
        blockedUsername,
      );

      if (success) {
        _notificationService.showSuccess(
          context,
          'Has desbloqueado a $blockedUsername',
        );
        await _loadBlockedUsers();
      } else {
        _notificationService.showError(
          context,
          'No se pudo desbloquear al usuario. Inténtalo de nuevo.',
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _notificationService.showError(
        context,
        'Error al desbloquear usuario: ${e.toString()}',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios Bloqueados')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadBlockedUsers,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
              : _blockedUsers.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Colors.green.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No tienes usuarios bloqueados',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Cuando bloqueas a un usuario, aparecerá en esta lista y podrás desbloquearlo desde aquí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadBlockedUsers,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final blockedUser = _blockedUsers[index];
                    final blockedUsername =
                        blockedUser['blockedUsername'] ?? 'Usuario desconocido';
                    final blockDate =
                        blockedUser['blockDate'] != null
                            ? DateTime.parse(blockedUser['blockDate'])
                            : null;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.block, color: Colors.white),
                        ),
                        title: Text(
                          blockedUsername,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                            blockDate != null
                                ? Text('Bloqueado el ${_formatDate(blockDate)}')
                                : null,
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.lock_open, size: 18),
                          label: const Text('Desbloquear'),
                          onPressed: () => _unblockUser(blockedUsername),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
