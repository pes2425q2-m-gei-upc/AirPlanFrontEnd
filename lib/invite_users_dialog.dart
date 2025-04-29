import 'package:flutter/material.dart';
import 'invite_users_service.dart';

class InviteUsersDialog extends StatefulWidget {
  final String activityId;
  final String creator;

  const InviteUsersDialog({super.key, required this.activityId, required this.creator});

  @override
  State<InviteUsersDialog> createState() => _InviteUsersDialogState();
}

class _InviteUsersDialogState extends State<InviteUsersDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
      _fetchUsers(_searchQuery);
    });
  }

  Future<void> _fetchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _users = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fetchedUsers = await InviteUsersService.searchUsers(query);
      final usersWithInvitationStatus = await Future.wait(fetchedUsers.map((user) async {
        final hasInvitation = await InviteUsersService.checkInvitation(user['username'], widget.activityId);
        return {
          ...user,
          'hasInvitation': hasInvitation,
        };
      }));

      setState(() {
        _users = usersWithInvitationStatus;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al buscar usuarios')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteUser(String username) async {
    try {
      await InviteUsersService.inviteUser(widget.creator, username, widget.activityId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario invitado con éxito')),
      );
      _fetchUsers(_searchQuery); // Refrescar la lista para actualizar el estado
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al invitar al usuario')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar usuario',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_users.isEmpty)
              const Text('No se encontraron usuarios')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      title: Text(user['username']),
                      trailing: IconButton(
                        icon: Icon(
                          user['hasInvitation'] ? Icons.check : Icons.person_add,
                          color: user['hasInvitation'] ? Colors.green : Colors.blue,
                        ),
                        onPressed: user['hasInvitation']
                            ? null
                            : () => _inviteUser(user['username']),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}