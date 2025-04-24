import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services/api_config.dart'; // Importar la configuración de API
import 'package:airplan/terms_page.dart';
import 'package:airplan/user_services.dart';
import 'rive_controller.dart';

class FormContentRegister extends StatefulWidget {
  final RiveAnimationControllerHelper riveHelper;

  const FormContentRegister({super.key, required this.riveHelper});

  @override
  State<FormContentRegister> createState() => _FormContentRegisterState();
}

class _FormContentRegisterState extends State<FormContentRegister> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _isAdmin = false;
  String _selectedLanguage = 'Castellano';
  String? _emailError;
  String? _usernameError;
  final TextEditingController _verificationCodeController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  Widget _gap() => const SizedBox(height: 16);

  @override
  void initState() {
    super.initState();
    _setupPasswordFocusListeners();
  }

  void _setupPasswordFocusListeners() {
    // Solo para campos de contraseña
    _passwordFocusNode.addListener(_handlePasswordFocusChange);
    _confirmPasswordFocusNode.addListener(_handlePasswordFocusChange);
  }

  void _handlePasswordFocusChange() {
    if (_passwordFocusNode.hasFocus || _confirmPasswordFocusNode.hasFocus) {
      widget.riveHelper.setHandsUp();
    } else {
      widget.riveHelper.setHandsDown();
    }
  }

  void _handleTapOutside() {
    // Baja manos solo si ningún campo de contraseña tiene foco
    if (!_passwordFocusNode.hasFocus && !_confirmPasswordFocusNode.hasFocus) {
      widget.riveHelper.setHandsDown();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _registerUser() async {
    // 1. Validación inicial forzada
    _formKey.currentState?.validate();
    await Future.delayed(Duration.zero); // Pequeña pausa para la UI

    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      // 2. Resetear errores previos
      setState(() {
        _emailError = null;
        _usernameError = null;
      });
      _formKey.currentState?.validate(); // Actualizar UI inmediatamente

      // 3. Preparar datos del usuario
      final usuario = {
        "username": _usernameController.text.trim(),
        "nom": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "idioma": _selectedLanguage,
        "sesionIniciada": true,
        "isAdmin":
            _isAdmin && _verificationCodeController.text.trim() == 'ab123',
      };

      // 4. Enviar petición al backend
      final response = await http.post(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/crear')),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(usuario),
      );

      // 5. Manejar respuesta
      if (response.statusCode == 201) {
        _handleRegistrationSuccess();
      } else {
        _handleBackendError(response.body);
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
    } on PlatformException catch (e) {
      _handlePlatformError(e);
    } catch (e) {
      _handleGenericError();
    }
  }

  void _handleRegistrationSuccess() async {
    widget.riveHelper.addSuccessController();
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      await userCredential.user?.updateProfile(
        displayName: _usernameController.text.trim(),
      );
      await userCredential.user?.sendEmailVerification();
      if (!mounted) return;

      // Regresar a la pantalla anterior
      Navigator.of(context).pop();
    } catch (e) {
      _handleGenericError();
    }
  }

  void _handleBackendError(String errorMessage) {
    widget.riveHelper.addFailController();
    setState(() {
      if (errorMessage.contains("El nom d'usuari ja està en ús")) {
        _usernameError = errorMessage;
      } else if (errorMessage.contains("El correu electrònic ja està en ús")) {
        _emailError = errorMessage;
      } else {
        _emailError = _usernameError = errorMessage;
      }
    });
    _formKey.currentState?.validate();
  }

  // En el método _handleFirebaseError
  void _handleFirebaseError(FirebaseAuthException e) async {
    widget.riveHelper.addFailController();

    // Eliminar usuario del backend si Firebase falla
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      await UserService.rollbackUserCreation(email);
    }

    setState(() {
      if (e.code == 'weak-password') {
        _passwordController.clear();
        _confirmPasswordController.clear();
      } else if (e.code == 'email-already-in-use') {
        _emailError = "Aquest correu ja està en ús a Firebase";
      } else {
        _emailError = "Error de Firebase: ${e.message}";
      }
    });

    _formKey.currentState?.validate();
  }

  void _handlePlatformError(PlatformException e) {
    widget.riveHelper.addFailController();
    setState(() {
      _emailError = _usernameError = "Error de plataforma: ${e.message}";
    });
    _formKey.currentState?.validate();
  }

  void _handleGenericError() {
    widget.riveHelper.addFailController();
    setState(() {
      _emailError = _usernameError = "Error en connectar amb el servidor";
    });
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTapOutside,
      behavior:
          HitTestBehavior
              .opaque, // Importante para que funcione en áreas vacías
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Campo Nombre
                TextFormField(
                  onTap: () => RiveAnimationControllerHelper().setLookRight(),
                  onTapOutside:
                      (_) => RiveAnimationControllerHelper().setIdle(),
                  controller: _nameController,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Introdueix el teu nom'
                              : null,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    errorMaxLines: 2,
                  ),
                ),
                _gap(),

                // Campo Nombre de Usuario
                TextFormField(
                  onTap: () => RiveAnimationControllerHelper().setLookRight(),
                  onTapOutside:
                      (_) => RiveAnimationControllerHelper().setIdle(),
                  controller: _usernameController,
                  validator: (value) {
                    if (_usernameError != null) return _usernameError;
                    if (value == null || value.isEmpty) {
                      return 'Introdueix el teu nom d\'usuari';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nom d\'usuari',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() => _usernameError = null),
                ),
                _gap(),

                // Campo Email
                TextFormField(
                  controller: _emailController,
                  validator: (value) {
                    if (_emailError != null) return _emailError;
                    if (value == null || value.isEmpty) {
                      return 'Introdueix el teu correu electrònic';
                    }
                    bool emailValid = RegExp(
                      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                    ).hasMatch(value);
                    return emailValid ? null : 'Introdueix un correu vàlid';
                  },
                  decoration: const InputDecoration(
                    labelText: 'Correu electrònic',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() => _emailError = null),
                ),
                _gap(),

                // Campo Contraseña
                TextFormField(
                  focusNode: _passwordFocusNode,
                  controller: _passwordController,
                  validator:
                      (value) =>
                          value != null && value.length >= 8
                              ? null
                              : 'Mínim 8 caràcters',
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Contrasenya',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed:
                          () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                    ),
                  ),
                ),
                _gap(),

                // Campo Confirmar Contraseña
                TextFormField(
                  focusNode: _confirmPasswordFocusNode,
                  controller: _confirmPasswordController,
                  validator:
                      (value) =>
                          value == _passwordController.text
                              ? null
                              : 'Les contrasenyes no coincideixen',
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contrasenya',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed:
                          () => setState(
                            () =>
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible,
                          ),
                    ),
                  ),
                ),
                _gap(),

                // Selector de Idioma
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  onChanged:
                      (value) => setState(() => _selectedLanguage = value!),
                  items:
                      ['Català', 'English', 'Castellano']
                          .map(
                            (language) => DropdownMenuItem(
                              value: language,
                              child: Text(language),
                            ),
                          )
                          .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Idioma',
                    prefixIcon: Icon(Icons.language),
                    border: OutlineInputBorder(),
                  ),
                ),
                _gap(),

                // Checkbox Administrador
                CheckboxListTile(
                  value: _isAdmin,
                  onChanged:
                      (value) => setState(() => _isAdmin = value ?? false),
                  title: const Text('¿Eres administrador?'),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),

                // Campo Código de Verificación (solo para admins)
                if (_isAdmin) ...[
                  _gap(),
                  TextFormField(
                    controller: _verificationCodeController,
                    validator: (value) {
                      if (_isAdmin && (value == null || value.isEmpty)) {
                        return 'Introdueix el codi de verificació';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Codi de verificació',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                _gap(),

                // Checkbox Términos y Condiciones
                CheckboxListTile(
                  value: _agreeToTerms,
                  onChanged:
                      (value) => setState(() => _agreeToTerms = value ?? false),
                  title: const Text('Accepto els termes i condicions'),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                _gap(),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Ja tens un compte? Inicia sessió",
                    style: TextStyle(fontSize: 14),
                  ),
                ),

                // Botón de Registro
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _registerUser,
                    child: const Text(
                      'Registra\'t',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _gap(),

                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TermsPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "Veure termes i condicions",
                    style: TextStyle(
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      color: Colors.blue, // Opcional: color de enlace
                    ),
                  ),
                ),

                // Enlace a Login
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Ja tens un compte? Inicia sessió",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }
}
