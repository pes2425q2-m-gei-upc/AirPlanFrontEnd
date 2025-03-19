import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registre"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // Torna a la pantalla anterior (login)
        ),
      ),
      body: Center(
        child: isSmallScreen
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _Logo(),
            _FormContent(),
          ],
        )
            : Container(
          padding: const EdgeInsets.all(32.0),
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            children: const [
              Expanded(child: _Logo()),
              Expanded(
                child: Center(child: _FormContent()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo.png',
          width: isSmallScreen ? 100 : 200,
          height: isSmallScreen ? 100 : 200,
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Benvingut a Flutter!",
            textAlign: TextAlign.center,
            style: isSmallScreen
                ? Theme.of(context).textTheme.headlineMedium
                : Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.black),
          ),
        )
      ],
    );
  }
}

class _FormContent extends StatefulWidget {
  const _FormContent();

  @override
  State<_FormContent> createState() => __FormContentState();
}

class __FormContentState extends State<_FormContent> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  String _selectedLanguage = 'Castellano'; // Valor predeterminado para el idioma

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(); // Nuevo controlador para el username
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  Future<void> _registerUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Crear un objeto con los datos del usuario
        final usuario = {
          "username": _usernameController.text.trim(), // Usar el username introducido
          "nom": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "contrasenya": _passwordController.text.trim(),
          "idioma": _selectedLanguage, // Usar el idioma seleccionado
          "sesionIniciada": false,
          "isAdmin": false
        };

        // Convertir el objeto a JSON
        final usuarioJson = jsonEncode(usuario);

        // Enviar los datos al backend
        final response = await http.post(
          Uri.parse('http://localhost:8080/api/usuaris/crear'), // Cambia la URL por la de tu backend
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: usuarioJson,
        );

        // Verificar la respuesta del backend
        if (response.statusCode == 201) {
          // Si el backend responde con éxito, crear el usuario en Firebase
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registre complet i usuari creat al backend!")),
          );

          Navigator.pop(context); // Torna a la pantalla d'inici de sessió
        } else {
          // Si el backend responde con un error, mostrar el mensaje de error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al crear l'usuari al backend: ${response.body}")),
          );
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = "Error durant el registre";
        if (e.code == 'weak-password') {
          errorMessage = "La contrasenya és massa feble.";
        } else if (e.code == 'email-already-in-use') {
          errorMessage = "Aquest correu ja està en ús.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFormField(
              controller: _nameController,
              validator: (value) => value == null || value.isEmpty ? 'Introdueix el teu nom' : null,
              decoration: const InputDecoration(
                labelText: 'Nom',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            _gap(),
            TextFormField(
              controller: _usernameController, // Nuevo campo para el username
              validator: (value) => value == null || value.isEmpty ? 'Introdueix el teu nom d\'usuari' : null,
              decoration: const InputDecoration(
                labelText: 'Nom d\'usuari',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            _gap(),
            TextFormField(
              controller: _emailController,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Introdueix el teu correu electrònic';
                bool emailValid = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(value);
                return emailValid ? null : 'Introdueix un correu vàlid';
              },
              decoration: const InputDecoration(
                labelText: 'Correu electrònic',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            _gap(),
            TextFormField(
              controller: _passwordController,
              validator: (value) => value != null && value.length >= 6 ? null : 'Mínim 6 caràcters',
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Contrasenya',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            _gap(),
            TextFormField(
              controller: _confirmPasswordController,
              validator: (value) => value == _passwordController.text ? null : 'Les contrasenyes no coincideixen',
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Confirmar contrasenya',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
              ),
            ),
            _gap(),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
              items: ['Català', 'English', 'Castellano']
                  .map((language) => DropdownMenuItem(
                value: language,
                child: Text(language),
              ))
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Idioma',
                prefixIcon: Icon(Icons.language),
                border: OutlineInputBorder(),
              ),
            ),
            _gap(),
            CheckboxListTile(
              value: _agreeToTerms,
              onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
              title: const Text('Accepto els termes i condicions'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            _gap(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _registerUser,
                child: const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text('Registra\'t', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            _gap(),
            TextButton(
              onPressed: () => Navigator.pop(context), // Torna a la pantalla d'inici de sessió
              child: const Text("Ja tens un compte? Inicia sessió"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 16);
}