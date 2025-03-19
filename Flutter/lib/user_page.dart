import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart'; // Para redirigir al usuario después de eliminar la cuenta

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  Future<void> _eliminarCuenta(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay un usuario autenticado.")),
      );
      return;
    }

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar cuenta"),
        content: const Text("¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        final response = await http.delete(
          Uri.parse('http://localhost:8080/api/usuaris/eliminar/${user.email}'),
        );

        if (response.statusCode == 200) {
          await user.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cuenta eliminada correctamente.")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al eliminar la cuenta: ${response.body}")),
          );
        }
      } catch (e) {
        print("Error en la solicitud HTTP: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil de Usuario"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('User\nPróximamente', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _eliminarCuenta(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Color rojo para el botón de eliminar
                foregroundColor: Colors.white, // Texto blanco
              ),
              child: const Text("Eliminar Cuenta"),
            ),
          ],
        ),
      ),
    );
  }
}