import 'package:flutter/material.dart';
import 'package:airplan/user_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert'; // Añadido para usar jsonEncode
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedLanguage = 'Castellano'; // Default language
  File? _selectedImage;
  Uint8List? _webImage; // Para almacenar la imagen en formato web

  final List<String> _languages = [
    'Castellano',
    'Catalan',
    'English',
  ]; // Example languages

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      // Intentar cargar los datos actuales del usuario
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    // TODO: Aquí podrías hacer una solicitud al backend para obtener los datos actuales
    // Por ahora, solo cargamos lo que tenemos en Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _nameController.text = user.displayName ?? '';
        // Otros campos se podrían cargar si estuvieran disponibles
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        // Para web, leemos los bytes de la imagen
        _webImage = await pickedFile.readAsBytes();
        setState(() {});
      } else {
        // Para aplicaciones móviles, usamos File
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (kIsWeb) {
      if (_webImage == null) return null;

      // Para web, enviamos los bytes de la imagen
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8080/api/uploadImage'),
      );

      // Crear un archivo temporal desde los bytes
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        _webImage!,
        filename: 'web_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      request.files.add(multipartFile);
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return responseBody;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${response.statusCode}'),
          ),
        );
        return null;
      }
    } else {
      // Para móvil, usamos el método existente
      if (_selectedImage == null) return null;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8080/api/uploadImage'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return responseBody;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${response.statusCode}'),
          ),
        );
        return null;
      }
    }
  }

  void _saveProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is currently logged in.')),
      );
      return;
    }

    String? imageUrl;
    // Upload image if selected
    if (_selectedImage != null || _webImage != null) {
      imageUrl = await _uploadImage();
      if (imageUrl != null) {
        try {
          await currentUser.updatePhotoURL(imageUrl);
          print('Firebase profile image URL updated: $imageUrl');
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating profile image in Firebase: $e'),
            ),
          );
          return;
        }
      }
    }

    final currentEmail = currentUser.email ?? '';
    final newEmail = _emailController.text.trim();

    // Preparar datos actualizados sin incluir el correo si ha cambiado
    final updatedData = {
      'nom': _nameController.text.trim(),
      'username': _usernameController.text.trim(),
      'idioma': _selectedLanguage,
      'photoURL': imageUrl,
    };

    // Comprobar si el email ha cambiado
    if (newEmail != currentEmail) {
      await _handleEmailChange(currentEmail, newEmail, updatedData);
    } else {
      // Si el correo no cambió, actualizar normalmente el perfil
      final result = await UserService.editUser(currentEmail, updatedData);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Perfil actualizado correctamente!')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${result['error']}')));
      }
    }
  }

  // Método para mostrar diálogo de re-autenticación
  Future<bool> _reauthenticateUser(String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Crear credenciales con el email actual y la contraseña proporcionada
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      // Re-autenticar al usuario
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en la re-autenticación: $e')),
      );
      return false;
    }
  }

  // Diálogo para solicitar contraseña para re-autenticación
  Future<String?> _showReauthDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Verificación necesaria'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Esta operación requiere verificación reciente. Por favor, ingresa tu contraseña para continuar.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.of(context).pop(passwordController.text),
                  child: const Text('Verificar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para manejar el cambio de correo electrónico con re-autenticación
  Future<void> _handleEmailChange(
    String currentEmail,
    String newEmail,
    Map<String, dynamic> updatedData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // 1. Guardar el nuevo correo como pendiente en el backend
      final pendingResponse = await http.post(
        Uri.parse('http://localhost:8080/api/usuaris/pendingEmail'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'currentEmail': currentEmail,
          'pendingEmail': newEmail,
        }),
      );

      if (pendingResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar correo pendiente: ${pendingResponse.body}',
            ),
          ),
        );
        return;
      }

      try {
        // 2. Enviar correo de verificación a través de Firebase
        await currentUser.verifyBeforeUpdateEmail(newEmail);

        // No necesitamos configurar un listener aquí, ya que el servicio global
        // EmailChangeManager se encargará de detectar y sincronizar el cambio

        // 3. Actualizar el resto de datos del perfil (sin cambiar el correo aún)
        final profileResult = await UserService.editUser(
          currentEmail,
          updatedData,
        );

        if (profileResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Perfil actualizado. Verifica tu nuevo correo para completar el cambio.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al actualizar perfil: ${profileResult['error']}',
              ),
            ),
          );
        }
      } catch (e) {
        // Detectar el error específico de re-autenticación
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
          // Mostrar diálogo para re-autenticación
          final password = await _showReauthDialog();

          if (password != null && password.isNotEmpty) {
            // Intentar re-autenticar al usuario
            final reauthSuccess = await _reauthenticateUser(password);

            if (reauthSuccess) {
              // Intentar nuevamente la operación después de la re-autenticación
              try {
                await currentUser.verifyBeforeUpdateEmail(newEmail);

                // El servicio global detectará el cambio cuando ocurra

                // Actualizar el resto de datos del perfil
                final profileResult = await UserService.editUser(
                  currentEmail,
                  updatedData,
                );

                if (profileResult['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Perfil actualizado. Verifica tu nuevo correo para completar el cambio.',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al actualizar perfil: ${profileResult['error']}',
                      ),
                    ),
                  );
                }
              } catch (finalError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error después de re-autenticación: $finalError',
                    ),
                  ),
                );
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Re-autenticación cancelada')),
            );
          }
        } else {
          // Otro tipo de error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar cambio de correo: $e')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar cambio de correo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Mostrar la imagen previa elegida
            if (_selectedImage != null && !kIsWeb)
              Image.file(
                _selectedImage!,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            if (_webImage != null && kIsWeb)
              Image.memory(
                _webImage!,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            TextButton(
              onPressed: _pickImage,
              child: Text('Select Profile Image'),
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              items:
                  _languages.map((language) {
                    return DropdownMenuItem(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value ?? 'Castellano';
                });
              },
              decoration: InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
