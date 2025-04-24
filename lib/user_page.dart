import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/user_services.dart';
import 'package:airplan/solicituds_service.dart';
import 'login_page.dart';
import 'activity_details_page.dart';

class UserRequestsPage extends StatefulWidget {
  final String username;

  const UserRequestsPage({super.key, required this.username});

  @override
  _UserRequestsPageState createState() => _UserRequestsPageState();
}

class _UserRequestsPageState extends State<UserRequestsPage> {
  late Future<List<Map<String, dynamic>>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = SolicitudsService().fetchUserRequests(widget.username);
  }

  Future<void> _cancelSolicitud(String activityId) async {
    try {
      await SolicitudsService().cancelarSolicitud(int.parse(activityId), widget.username);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud eliminada correctamente.')),
      );
      setState(() {
        _requestsFuture = SolicitudsService().fetchUserRequests(widget.username);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la solicitud: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Solicitudes"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No has realizado solicitudes.'));
          }

          final requests = snapshot.data!;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return ListTile(
                title: Text(request['nom'] ?? 'Actividad sin nombre'),
                subtitle: Text('Creador: ${request['creador'] ?? 'Desconocido'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _cancelSolicitud(request['id'].toString()),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActivityDetailsPage(
                        id: request['id'].toString(),
                        title: request['nom'] ?? '',
                        creator: request['creador'] ?? '',
                        description: request['descripcio'] ?? '',
                        startDate: request['dataInici'] ?? '',
                        endDate: request['dataFi'] ?? '',
                        airQualityData: [],
                        isEditable: false,
                        onEdit: () {},
                        onDelete: () {},
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

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
    final username = user?.displayName ?? "UsuarioSinNombre";
    final em = user?.email ?? "UsuarioSinEmail";

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
            Text(em, textAlign: TextAlign.center),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserRequestsPage(username: username),
                  ),
                );
              },
              child: const Text("Ver Mis Solicitudes"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _eliminarCuenta(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Eliminar Cuenta"),
            ),
          ],
        ),
      ),
    );
  }
}