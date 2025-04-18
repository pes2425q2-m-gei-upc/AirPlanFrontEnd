import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/user_services.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  bool _isLoading = true;
  String _realName = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Realizar un reload de la instancia de Firebase al entrar al perfil
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Intentar recargar el usuario desde Firebase
          await user.reload();

          // Verificar si el usuario sigue autenticado después del reload
          final refreshedUser = FirebaseAuth.instance.currentUser;
          if (refreshedUser == null) {
            // La sesión ha caducado después del reload
            if (mounted) {
              await _showSessionExpiredDialog();
              return;
            }
          }

          if (refreshedUser != null && refreshedUser.displayName != null) {
            final username = refreshedUser.displayName!;
            final realName = await UserService.getUserRealName(username);

            if (mounted) {
              setState(() {
                _realName = realName;
                _isLoading = false;
              });
            }
          }
        } catch (e) {
          // Error al recargar el usuario, probablemente la sesión expiró
          print('Error al recargar usuario de Firebase: $e');
          if (mounted) {
            await _showSessionExpiredDialog();
          }
        }
      } else {
        // No hay usuario autenticado
        if (mounted) {
          await _showSessionExpiredDialog();
        }
      }
    } catch (e) {
      print('Error general al cargar datos de usuario: $e');
      if (mounted) {
        setState(() {
          _realName = 'Error al cargar datos';
          _isLoading = false;
        });
      }
    }
  }

  // Método para mostrar el diálogo de sesión caducada
  Future<void> _showSessionExpiredDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sesión caducada'),
          content: const Text(
            'La sesión ha caducado, vuelve a iniciar sesión por favor.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Aceptar'),
              onPressed: () {
                // Cerrar el diálogo y navegar a la página de login
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  // También necesitamos recargar cuando la página obtiene el foco nuevamente
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Esto captura cuando la página vuelve a estar visible, por ejemplo cuando el usuario
    // regresa a ella después de editar su perfil
    final route = ModalRoute.of(context);
    if (route != null) {
      route.addScopedWillPopCallback(() async {
        // Esta función se llamará cuando se regrese a esta página
        _loadUserData();
        return false; // Permitir que la navegación continúe
      });
    }
  }

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
      builder:
          (context) => AlertDialog(
            title: const Text("Eliminar cuenta"),
            content: const Text(
              "¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Eliminar",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmacion == true) {
      final success = await UserService.deleteUser(user.email!);
      final actualContext = context;
      if (actualContext.mounted) {
        if (success) {
          ScaffoldMessenger.of(actualContext).showSnackBar(
            const SnackBar(content: Text("Cuenta eliminada correctamente.")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          ScaffoldMessenger.of(actualContext).showSnackBar(
            const SnackBar(content: Text("Error al eliminar la cuenta")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "UsuarioSinEmail";
    final username = user?.displayName ?? "Username no disponible";
    final photoURL = user?.photoURL;

    return Scaffold(
      appBar: AppBar(title: const Text("Perfil de Usuario")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Foto de perfil
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[300],
              backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
              child:
                  photoURL == null
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
            ),
            const SizedBox(height: 30),
            // Información del usuario
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.blue),
                      title: const Text(
                        'Nombre',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          _isLoading
                              ? const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                              : Text(
                                _realName,
                                style: const TextStyle(fontSize: 16),
                              ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.alternate_email,
                        color: Colors.blue,
                      ),
                      title: const Text(
                        'Username',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        username,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.blue),
                      title: const Text(
                        'Correo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        email,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar Perfil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _eliminarCuenta(context),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Eliminar Cuenta"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
