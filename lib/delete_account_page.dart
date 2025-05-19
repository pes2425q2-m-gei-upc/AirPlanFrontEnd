import 'package:flutter/material.dart';
import 'package:airplan/services/auth_service.dart';
import 'login_page.dart';
import 'package:easy_localization/easy_localization.dart';

class DeleteAccountPage extends StatefulWidget {
  // Add support for dependency injection
  final AuthService? authService;

  const DeleteAccountPage({super.key, this.authService});

  @override
  DeleteAccountPageState createState() => DeleteAccountPageState();
}

class DeleteAccountPageState extends State<DeleteAccountPage> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    // Initialize auth service with injected or default instance
    _authService = widget.authService ?? AuthService();
  }

  Future<void> _deleteAccount() async {
    try {
      // Use AuthService instead of direct Firebase call
      await _authService.deleteCurrentUser();

      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text(tr('delete_account_success'))));

        // Tornar a la pantalla d'inici de sessió
        Navigator.pushAndRemoveUntil(
          actualContext,
          MaterialPageRoute(
            builder: (context) => LoginPage(authService: _authService),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        // Check for requires-recent-login error
        String errorMessage = e.toString();
        if (errorMessage.contains('requires-recent-login')) {
          ScaffoldMessenger.of(actualContext).showSnackBar(
            SnackBar(content: Text(tr('delete_account_requires_relogin'))),
          );
        } else {
          ScaffoldMessenger.of(actualContext).showSnackBar(
            SnackBar(
              content: Text(tr('delete_account_error', args: [errorMessage])),
            ),
          );
        }
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(tr('confirm_delete_account_title')),
            content: Text(tr('confirm_delete_account_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAccount();
                },
                child: Text(tr('delete')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('confirm_delete_account_title'))),
      body: Center(
        child: ElevatedButton(
          onPressed: _confirmDelete,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text(
            tr('confirm_delete_account_title'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
