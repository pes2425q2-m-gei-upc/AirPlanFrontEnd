import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:airplan/user_services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'activity_service.dart';
import 'login_page.dart'; // Para redirigir al usuario después de eliminar la cuenta


class Valoracio {
  final String username;
  final int idActivitat;
  final double valoracion;
  final String? comentario;
  final DateTime fecha;

  Valoracio({
    required this.username,
    required this.idActivitat,
    required this.valoracion,
    this.comentario,
    required this.fecha,
  });

  factory Valoracio.fromJson(Map<String, dynamic> json) {
    return Valoracio(
      username: json['username'],
      idActivitat: json['idActivitat'],
      valoracion: json['valoracion'].toDouble(),
      comentario: json['comentario'],
      fecha: DateTime.parse(json['fechaValoracion']),
    );
  }
}

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late Future<List<Valoracio>> _userRatingsFuture;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ActivityService activityService = ActivityService();
  List<Map<String, dynamic>> activities = [];

  @override
  void initState() {
    super.initState();
    _loadUserRatings();
    fetchActivities();
  }

  Future<void> _loadUserRatings() async {
    if (_currentUser == null) return;

    setState(() {
      _userRatingsFuture = _fetchUserRatings(_currentUser.displayName ?? _currentUser.email!.split('@')[0]);
    });
  }
  Future<void> fetchActivities() async {
    activities = await activityService.fetchActivities();
  }

  String? findActivityTitleById(List<Map<String, dynamic>> activities, int id) {
    final activity = activities.firstWhere(
        (activity) => activity['id'] == id,
        orElse: () => {},
    );
    return activity.isNotEmpty ? activity['nom'] as String? : null;
  }

  Future<List<Valoracio>> _fetchUserRatings(String username) async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8080/valoracions/usuari/$username'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Valoracio.fromJson(json)).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Error al cargar valoraciones: $e');
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
  Widget _buildUserRatings(List<Valoracio> valoracions) {
    if (valoracions.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No has realizado ninguna valoración aún',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Tus valoraciones (${valoracions.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: valoracions.length,
          itemBuilder: (context, index) {
            final valoracio = valoracions[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      findActivityTitleById(activities, valoracio.idActivitat) ?? "Actividad no encontrada",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    RatingBarIndicator(
                      rating: valoracio.valoracion,
                      itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                      itemCount: 5,
                      itemSize: 20,
                    ),
                    if (valoracio.comentario?.isNotEmpty ?? false) ...[
                      SizedBox(height: 8),
                      Text(
                        '"${valoracio.comentario!}"',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                    SizedBox(height: 4),
                    Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(valoracio.fecha)}',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Perfil")),
        body: Center(child: Text("No hay usuario autenticado")),
      );
    }

    final username = _currentUser.displayName ?? _currentUser.email!.split('@')[0];
    final email = _currentUser.email ?? "UsuarioSinEmail";

    return Scaffold(
      appBar: AppBar(
        title: Text("Perfil de $username"),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserRatings,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Text(
                  username[0].toUpperCase(),
                  style: TextStyle(fontSize: 40, color: Colors.white),
                ),
              ),
              SizedBox(height: 16),
              Text(
                username,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                email,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 24),

              // Sección de valoraciones
              FutureBuilder<List<Valoracio>>(
                future: _userRatingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Error al cargar valoraciones',
                            style: TextStyle(color: Colors.red),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadUserRatings,
                            child: Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }
                  return _buildUserRatings(snapshot.data ?? []);
                },
              ),

              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.delete, color: Colors.white),
                  label: Text("Eliminar Cuenta", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: Size(double.infinity, 50),
                  ),
                  onPressed: () => _eliminarCuenta(context),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}