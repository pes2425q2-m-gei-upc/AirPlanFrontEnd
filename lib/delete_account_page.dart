import 'package:flutter/material.dart';
import 'package:airplan/services/auth_service.dart';
import 'login_page.dart';

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
        ScaffoldMessenger.of(actualContext).showSnackBar(
          const SnackBar(content: Text('Compte eliminat correctament')),
        );

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
            const SnackBar(
              content: Text(
                'Has de tornar a iniciar sessió per esborrar el compte',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            actualContext,
          ).showSnackBar(SnackBar(content: Text('Error: $errorMessage')));
        }
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmació'),
            content: const Text(
              'Segur que vols esborrar el teu compte? Aquesta acció és irreversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel·lar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAccount();
                },
                child: const Text('Esborrar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar compte')),
      body: Center(
        child: ElevatedButton(
          onPressed: _confirmDelete,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text(
            'Esborrar el meu compte',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
