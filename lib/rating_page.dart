import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:airplan/activity_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:airplan/activity_details_page.dart';
import 'package:airplan/air_quality.dart'; // Add this import for AirQualityData
import 'package:airplan/services/api_config.dart';
import 'package:latlong2/latlong.dart';
import 'package:airplan/map_service.dart';

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

class RatingsPage extends StatefulWidget {
  final String username;

  const RatingsPage({super.key, required this.username});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  late Future<List<Valoracio>> _userRatingsFuture;
  List<Map<String, dynamic>> _activities = [];
  final ActivityService _activityService = ActivityService();
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation = {};
  final MapService mapService = MapService();

  @override
  void initState() {
    super.initState();
    _loadUserRatings();
    fetchAirQualityData();
  }

  void _loadUserRatings() {
    setState(() {
      _isLoading = true;
      _userRatingsFuture = _fetchUserRatings(widget.username);
    });
    _fetchActivities();
  }

  Future<List<Valoracio>> _fetchUserRatings(String username) async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig().buildUrl('valoracions/usuari/$username')),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _isLoading = false;
        });
        return data.map((json) => Valoracio.fromJson(json)).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
      }
      throw Exception('Error ${response.statusCode}');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error al cargar valoraciones: $e');
      return [];
    }
  }

  Future<void> _fetchActivities() async {
    try {
      _activities = await _activityService.fetchActivities();
    } catch (e) {
      final String message = 'Error al cargar actividades';
      if (!mounted) return;
      _notificationService.showError(context, message);
    }
  }

  String? _findActivityTitleById(int id) {
    final activity = _activities.firstWhere(
      (activity) => activity['id'] == id,
      orElse: () => {},
    );
    return activity.isNotEmpty ? activity['nom'] as String? : null;
  }

  // New method to navigate to activity details
  Future<void> _navigateToActivityDetails(int activityId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Find the activity details from your fetched activities
      final activity = _activities.firstWhere(
        (activity) => activity['id'] == activityId,
        orElse: () => {},
      );

      if (activity.isEmpty) {
        if (context.mounted) {
          // Close loading dialog
          Navigator.of(context).pop();
          _notificationService.showError(
            context,
            'No se encontró la actividad',
          );
        }
        return;
      }

      // Get activity details based on your data structure
      final String id = activity['id'].toString();
      final String title = activity['nom'] ?? 'Actividad sin título';
      final String creator = activity['creador'] ?? 'Usuario desconocido';
      final String description = activity['descripcio'] ?? 'Sin descripción';
      final String startDate =
          activity['dataInici'] ?? DateTime.now().toString();
      final String endDate = activity['dataFi'] ?? DateTime.now().toString();
      final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
      final lat = ubicacio['latitud'] as double;
      final lon = ubicacio['longitud'] as double;

      // Create empty air quality data or fetch it if available
      List<AirQualityData> airQualityData = findClosestAirQualityData(LatLng(lat,lon));

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Navigate to activity details page
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => ActivityDetailsPage(
                  id: id,
                  title: title,
                  creator: creator,
                  description: description,
                  airQualityData: airQualityData,
                  startDate: startDate,
                  endDate: endDate,
                  isEditable:
                      false, // Assuming the user can't edit from ratings page
                  onEdit: () {}, // Empty function since not editable
                  onDelete: () {}, // Empty function since not deletable
                ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog if open
        Navigator.of(context, rootNavigator: true).pop();
        _notificationService.showError(
          context,
          'Error al cargar los detalles: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Valoraciones')),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadUserRatings();
        },
        child: FutureBuilder<List<Valoracio>>(
          future: _userRatingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                _isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Error al cargar valoraciones',
                      style: TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadUserRatings,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final valoracions = snapshot.data ?? [];

            if (valoracions.isEmpty) {
              return const Center(
                child: Text(
                  'No has realizado ninguna valoración aún',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: valoracions.length,
              itemBuilder: (context, index) {
                final valoracio = valoracions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clickable activity title with navigation
                        InkWell(
                          onTap:
                              () => _navigateToActivityDetails(
                                valoracio.idActivitat,
                              ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _findActivityTitleById(
                                        valoracio.idActivitat,
                                      ) ??
                                      "Actividad no encontrada",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        RatingBarIndicator(
                          rating: valoracio.valoracion,
                          itemBuilder:
                              (context, _) =>
                                  const Icon(Icons.star, color: Colors.amber),
                          itemCount: 5,
                          itemSize: 24,
                        ),
                        if (valoracio.comentario?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 12),
                          Text(
                            '"${valoracio.comentario!}"',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Fecha: ${DateFormat('dd/MM/yyyy').format(valoracio.fecha)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> fetchAirQualityData() async {
    try{
      await mapService.fetchAirQualityData(contaminantsPerLocation);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading air quality data: $e')),
      );
    }
  }

  List<AirQualityData> findClosestAirQualityData(LatLng activityLocation) {
    double closestDistance = double.infinity;
    LatLng closestLocation = LatLng(0, 0);
    List<AirQualityData> listAQD = [];

    contaminantsPerLocation.forEach((location, dataMap) {
      final distance = Distance().as(
        LengthUnit.Meter,
        activityLocation,
        location,
      );
      if (distance < closestDistance) {
        closestDistance = distance;
        closestLocation = location;
      }
    });

    contaminantsPerLocation[closestLocation]?.forEach((
        contaminant,
        airQualityData,
        ) {
      listAQD.add(airQualityData);
    });

    return listAQD;
  }
}
