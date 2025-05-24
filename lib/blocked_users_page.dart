import 'package:easy_localization/easy_localization.dart';
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
        _error = 'error_loading_blocked_users'.tr(args: [e.toString()]);
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String blockedUsername) async {
    // Verificamos si el widget todavía está montado
    if (!mounted) return;

    final user = _authService.getCurrentUser();
    if (user == null || user.displayName == null) {
      _notificationService.showError(
        context,
        'error_identifying_user_unblock'.tr(),
      );
      return;
    }

    // Almacenamos el contexto antes de la operación asíncrona
    final currentContext = context;

    // Mostramos el diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: currentContext,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              'unblock_user_dialog_title'.tr(args: [blockedUsername]),
            ),
            content: Text('unblock_user_dialog_content'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('cancel_button'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: Text('unblock_button'.tr()),
              ),
            ],
          ),
    );

    // Si el usuario cancela, salimos
    if (confirm != true) return;

    // Verificamos si el widget todavía está montado
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _blockService.unblockUser(
        user.displayName!,
        blockedUsername,
      );

      // Verificamos si el widget todavía está montado
      if (!mounted) return;

      if (success) {
        // Mostrar notificación de éxito
        // Usamos Future.microtask para asegurarnos de que la notificación se muestre después de que se actualice el estado
        Future.microtask(() {
          if (mounted) {
            _notificationService.showSuccess(
              context,
              'unblock_user_success_message'.tr(args: [blockedUsername]),
            );
          }
        });

        // Recargar la lista de usuarios bloqueados
        await _loadBlockedUsers();
      } else {
        // Mostrar notificación de error
        // Usamos Future.microtask para asegurarnos de que la notificación se muestre después de que se actualice el estado
        Future.microtask(() {
          if (mounted) {
            _notificationService.showError(
              context,
              'unblock_user_error_message'.tr(),
            );
          }
        });

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Verificamos si el widget todavía está montado
      if (!mounted) return;

      // Mostrar notificación de error
      // Usamos Future.microtask para asegurarnos de que la notificación se muestre después de que se actualice el estado
      Future.microtask(() {
        if (mounted) {
          _notificationService.showError(
            context,
            'unblock_user_exception_message'.tr(args: [e.toString()]),
          );
        }
      });

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('blocked_users_page_title'.tr())),
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
                        child: Text('retry_button'.tr()),
                      ),
                    ],
                  ),
                ),
              )
              : _blockedUsers.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'no_blocked_users_message'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'no_blocked_users_description'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : ListView.builder(
                itemCount: _blockedUsers.length,
                itemBuilder: (context, index) {
                  final user = _blockedUsers[index];
                  final blockedUsername =
                      user['blockedUsername'] as String? ?? 'unknown_user';
                  final profileImageUrl = user['profileImageUrl'] as String?;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            profileImageUrl != null &&
                                    profileImageUrl.isNotEmpty
                                ? NetworkImage(profileImageUrl)
                                : null,
                        child:
                            profileImageUrl == null || profileImageUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                      ),
                      title: Text(blockedUsername),
                      trailing: ElevatedButton(
                        onPressed: () => _unblockUser(blockedUsername),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('unblock_button'.tr()),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  // String _formatDate(DateTime date) {
  //   return '${date.day}/${date.month}/${date.year}';
  // }
}
