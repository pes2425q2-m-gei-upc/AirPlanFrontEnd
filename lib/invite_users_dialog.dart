import 'package:flutter/material.dart';
import 'invite_users_service.dart';
import 'package:easy_localization/easy_localization.dart';

class InviteUsersDialog extends StatefulWidget {
  final String activityId;
  final String creator;

  const InviteUsersDialog({
    super.key,
    required this.activityId,
    required this.creator,
  });

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
      final fetchedUsers = await InviteUsersService.searchUsers(
        query,
        widget.creator,
      );
      final usersWithInvitationStatus = await Future.wait(
        fetchedUsers.map((user) async {
          final hasInvitation = await InviteUsersService.checkInvitation(
            user['username'],
            widget.activityId,
          );
          return {...user, 'hasInvitation': hasInvitation};
        }),
      );

      setState(() {
        _users = usersWithInvitationStatus;
      });
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text('invite_error_search'.tr())));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteUser(String username) async {
    try {
      await InviteUsersService.inviteUser(
        widget.creator,
        username,
        widget.activityId,
      );
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text('invite_success'.tr())));
      }
      _fetchUsers(_searchQuery); // Refrescar la lista para actualizar el estado
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text('invite_error'.tr())));
      }
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
              decoration: InputDecoration(
                labelText: 'invite_search_label'.tr(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_users.isEmpty)
              Text('no_users_found'.tr())
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
                          user['hasInvitation']
                              ? Icons.check
                              : Icons.person_add,
                          color:
                              user['hasInvitation']
                                  ? Colors.green
                                  : Colors.blue,
                        ),
                        onPressed:
                            user['hasInvitation']
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
