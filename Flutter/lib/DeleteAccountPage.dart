import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  _DeleteAccountPageState createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _deleteAccount() async {
    User? user = _auth.currentUser;

    if (user != null) {
      try {
        await user.delete(); // Elimina l'usuari de Firebase Authentication
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte eliminat correctament')),
        );

        // Tornar a la pantalla d'inici de sessió
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (Route<dynamic> route) => false,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Has de tornar a iniciar sessió per esborrar el compte',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
        }
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmació'),
        content: const Text('Segur que vols esborrar el teu compte? Aquesta acció és irreversible.'),
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
