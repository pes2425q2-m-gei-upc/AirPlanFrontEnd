import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importación necesaria para FirebaseAuthException
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services/api_config.dart';
import 'package:airplan/terms_page.dart';
import 'package:airplan/user_services.dart';
import 'rive_controller.dart';
import 'services/auth_service.dart';
import 'services/registration_state_service.dart';
import 'package:airplan/main.dart';
import 'package:easy_localization/easy_localization.dart';

class FormContentRegister extends StatefulWidget {
  final RiveAnimationControllerHelper riveHelper;
  final AuthService? authService;

  const FormContentRegister({
    super.key,
    required this.riveHelper,
    this.authService,
  });

  @override
  State<FormContentRegister> createState() => _FormContentRegisterState();
}

class _FormContentRegisterState extends State<FormContentRegister> {
  // Usamos late para inicializar en initState
  late final AuthService _authService;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _isAdmin = false;
  String _selectedLanguage = 'Castellano'; // Will be updated in initState
  String? _emailError;
  String? _usernameError;
  String? _nameError; // Add name error variable

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
    // Inicializamos el servicio auth usando el proporcionado o creando uno nuevo
    _authService = widget.authService ?? AuthService();
    _setupPasswordFocusListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Establecer el idioma seleccionado basado en el locale actual de EasyLocalization
    // Se hace aquí porque context.locale necesita que el widget tree esté completamente construido
    _setInitialLanguage();
  }

  void _setInitialLanguage() {
    final currentLocale = context.locale;
    switch (currentLocale.languageCode) {
      case 'ca':
        _selectedLanguage = 'Català';
        break;
      case 'en':
        _selectedLanguage = 'English';
        break;
      case 'es':
      default:
        _selectedLanguage = 'Castellano';
        break;
    }
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
        _nameError = null; // Reset name error
      });
      _formKey.currentState?.validate(); // Actualizar UI inmediatamente

      // 3. Preparar datos del usuario
      final bool isActuallyAdmin =
          _isAdmin && _verificationCodeController.text.trim() == 'ab123';
      final usuario = {
        "username": _usernameController.text.trim(),
        "nom": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "idioma": _selectedLanguage,
        "sesionIniciada": false, // Consistent for all new user registrations
        "isAdmin": isActuallyAdmin,
        "esExtern": false, // Default to false for new users
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
      } else if (response.statusCode == 400) {
        // Backend indicates inappropriate content, parse field-specific error
        final Map<String, dynamic> body = jsonDecode(response.body);
        final field = body['field'] as String?;
        widget.riveHelper.addFailController();
        setState(() {
          if (field == 'nom') {
            _nameError = 'Contenido inapropiado en el nombre';
          } else if (field == 'username') {
            _usernameError = 'Contenido inapropiado en el nombre de usuario';
          } else if (field == 'email') {
            _emailError = 'Contenido inapropiado en el correo electrónico';
          } else {
            // Fallback error
            _usernameError = _emailError = _nameError = 'Contenido inapropiado';
          }
        });
        _formKey.currentState?.validate();
      } else {
        _handleBackendError(response.body);
      }
    } catch (e) {
      debugPrint('Error en _registerUser: $e');
      if (e is FirebaseAuthException) {
        _handleFirebaseError(e);
      } else if (e is PlatformException) {
        _handlePlatformError(e);
      } else {
        _handleGenericError();
      }
    }
  }

  void _handleRegistrationSuccess() async {
    widget.riveHelper.addSuccessController();

    // Marcar el inicio del proceso de registro
    final registrationService = RegistrationStateService();
    registrationService.startRegistration(_emailController.text.trim());

    try {
      debugPrint('Iniciando registro de usuario con AuthService');

      // Crear usuario en Firebase
      final userCredential = await _authService.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      debugPrint(
        'Usuario registrado exitosamente: ${userCredential.user?.email}',
      );

      // Verificar que el usuario se creó correctamente
      if (userCredential.user == null) {
        throw Exception('No se pudo crear el usuario en Firebase');
      }

      final user = userCredential.user!;

      // Actualizar displayName y enviar verificación de email de forma secuencial
      // para evitar problemas de concurrencia
      debugPrint('Actualizando displayName...');
      await _authService.updateDisplayName(_usernameController.text.trim());

      debugPrint('Enviando verificación de email...');
      await _authService.sendEmailVerification();

      debugPrint('Recargando usuario...');
      await _authService.reloadCurrentUser();

      // Verificar que el usuario sigue autenticado antes de continuar
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != user.uid) {
        throw Exception(
          'El usuario se desautenticó durante el proceso de registro',
        );
      }

      debugPrint('Actualizando estado de sesión en el backend...');
      await _updateUserSessionStatus(_emailController.text.trim());

      // Verificar una vez más que el usuario sigue autenticado
      final finalUser = FirebaseAuth.instance.currentUser;
      if (finalUser == null) {
        throw Exception('El usuario se desautenticó antes de la navegación');
      }

      // Marcar el registro como completado ANTES de navegar
      registrationService.markRegistrationComplete();

      if (!mounted) return;

      debugPrint('Usuario completamente configurado, navegando al AuthWrapper');

      // Usar un delay mínimo antes de navegar
      await Future.delayed(const Duration(milliseconds: 100));

      // Navegar al AuthWrapper
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );

      debugPrint('Navegación completada');
    } catch (e) {
      debugPrint('Error en _handleRegistrationSuccess: $e');
      // Marcar el registro como fallido
      registrationService.markRegistrationFailed();

      // Si hay error, intentar limpiar el estado de Firebase
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _authService.signOut();
          // También intentar eliminar el usuario del backend
          await UserService.rollbackUserCreation(_emailController.text.trim());
        }
      } catch (signOutError) {
        debugPrint('Error al hacer rollback después del fallo: $signOutError');
      }
      _handleGenericError();
    }
  }

  // Método auxiliar para actualizar el estado de sesión en el backend
  Future<void> _updateUserSessionStatus(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig().buildUrl('api/usuaris/login')),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        debugPrint('Estado de sesión actualizado en el backend');
      } else {
        debugPrint(
          'Warning: No se pudo actualizar el estado de sesión en el backend',
        );
      }
    } catch (e) {
      debugPrint('Error al actualizar estado de sesión: $e');
      // No lanzamos error aquí porque el registro ya fue exitoso
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
      // Debug print
    });
    _formKey.currentState?.validate();
  }

  void _handleFirebaseError(FirebaseAuthException e) async {
    widget.riveHelper.addFailController();

    debugPrint('Firebase error: ${e.code} - ${e.message}');

    // Eliminar usuario del backend si Firebase falla
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      try {
        await UserService.rollbackUserCreation(email);
        debugPrint('Rollback de usuario completado');
      } catch (rollbackError) {
        debugPrint('Error en rollback: $rollbackError');
      }
    }

    setState(() {
      if (e.code == 'weak-password') {
        _passwordController.clear();
        _confirmPasswordController.clear();
      } else if (e.code == 'email-already-in-use') {
        _emailError = "Aquest correu ja està en ús a Firebase";
      } else if (e.code == 'invalid-email') {
        _emailError = "El format del correu electrònic no és vàlid";
      } else if (e.code == 'operation-not-allowed') {
        _emailError = "Operació no permesa";
      } else if (e.code == 'network-request-failed') {
        _emailError = "Error de connexió de xarxa";
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
      // Debug print
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
                  validator: (value) {
                    if (_nameError != null) return _nameError;
                    if (value == null || value.isEmpty) {
                      return tr('register_enter_name');
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: tr('register_name_label'),
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() => _nameError = null),
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
                      final result = tr('register_enter_username');
                      return result;
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: tr('register_username_label'),
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
                    if (_emailError != null) {
                      return _emailError;
                    }
                    if (value == null || value.isEmpty) {
                      final result = tr('register_enter_email');
                      return result;
                    }
                    bool emailValid = RegExp(
                      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                    ).hasMatch(value);
                    final result =
                        emailValid ? null : tr('register_invalid_email');
                    return result;
                  },
                  decoration: InputDecoration(
                    labelText: tr('register_email_label'),
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
                  validator: (value) {
                    final result =
                        value != null && value.length >= 8
                            ? null
                            : tr('register_password_min_chars');
                    return result;
                  },
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: tr('register_password_label'),
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
                  validator: (value) {
                    final result =
                        value == _passwordController.text
                            ? null
                            : tr('register_password_mismatch');
                    return result;
                  },
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: tr('register_confirm_password_label'),
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
                  onChanged: (value) {
                    if (value == null) return;
                    Locale locale;
                    switch (value) {
                      case 'Català':
                        locale = const Locale('ca');
                        break;
                      case 'English':
                        locale = const Locale('en');
                        break;
                      case 'Castellano':
                      default:
                        locale = const Locale('es');
                    }
                    context.setLocale(locale);
                    setState(() {
                      _selectedLanguage = value;
                    });
                  },
                  items:
                      ['Català', 'English', 'Castellano']
                          .map(
                            (language) => DropdownMenuItem(
                              value: language,
                              child: Text(language),
                            ),
                          )
                          .toList(),
                  decoration: InputDecoration(
                    labelText: tr('register_language_label'),
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
                  title: Text(tr('register_admin_title')),
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
                        return tr('register_verification_code_enter');
                      }
                      if (_isAdmin &&
                          value != null &&
                          value.trim() != 'ab123') {
                        return tr('register_verification_code_invalid');
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: tr('register_verification_code_label'),
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
                  title: Text(tr('register_agree_terms')),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                _gap(),

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
                    child: Text(
                      tr('register_button'),
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
                  child: Text(
                    tr('register_view_terms'),
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
                  child: Text(
                    tr('register_have_account_login'),
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
