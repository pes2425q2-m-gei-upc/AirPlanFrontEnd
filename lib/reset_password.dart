import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';

class ResetPasswordPage extends StatefulWidget {
  // Añadimos la posibilidad de inyectar el AuthService
  final AuthService? authService;

  const ResetPasswordPage({super.key, this.authService});

  @override
  ResetPasswordPageState createState() => ResetPasswordPageState();
}

class ResetPasswordPageState extends State<ResetPasswordPage> {
  // Usamos late para inicializar en initState
  late final AuthService _authService;
  final TextEditingController _emailController = TextEditingController();
  String _message = '';

  @override
  void initState() {
    super.initState();
    // Inicializamos el servicio usando el proporcionado o creando uno nuevo
    _authService = widget.authService ?? AuthService();
  }

  Future<void> _resetPassword() async {
    try {
      // Usamos el servicio AuthService en lugar de Firebase directamente
      await _authService.resetPassword(_emailController.text.trim());
      setState(() {
        _message =
            "Correu de restabliment enviat! Revisa la teva safata d'entrada.";
      });
    } catch (e) {
      setState(() {
        _message = "Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('reset_password_title'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('reset_instruction'), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: tr('email_label'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _resetPassword,
              child: Text(tr('reset_button')),
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr(_message), style: const TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }
}
