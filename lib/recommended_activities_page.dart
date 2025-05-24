import 'dart:convert';

import 'package:airplan/air_quality.dart';
import 'package:airplan/air_quality_service.dart';
import 'package:airplan/map_service.dart';
import 'package:airplan/services/api_config.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:airplan/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:airplan/transit_service.dart';
import 'package:intl/intl.dart';

import 'activity_details_page.dart';
import 'activity_service.dart';

class Activity {
  int id;
  String creador;
  String name;
  String description;
  DateTime dataInici;
  DateTime dataFi;
  LatLng location;
  double distance;
  bool isFavorite;
  List<AirQualityData> airQuality;

  Activity({
    required this.id,
    required this.creador,
    required this.name,
    required this.description,
    required this.dataInici,
    required this.dataFi,
    required this.location,
    required this.distance,
    required this.isFavorite,
    required this.airQuality,
  });
}

class RecommendedActivitiesPage extends StatefulWidget {
  final LatLng userLocation;
  final Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation;
  final Map<LatLng, String> savedLocations;

  const RecommendedActivitiesPage({
    super.key,
    required this.userLocation,
    required this.contaminantsPerLocation,
    required this.savedLocations,
  });

  @override
  RecommendedActivitiesPageState createState() => RecommendedActivitiesPageState();
}

class RecommendedActivitiesPageState extends State<RecommendedActivitiesPage> {
  List<Activity> _activities = [];
  bool _isLoading = true;
  int _totalActivities = 0;
  int _loadedActivities = 0;
  final activityService = ActivityService();
  final authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchRecommendedActivities().then((_) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _fetchRecommendedActivities() async {
    final url = Uri.parse(ApiConfig().buildUrl("api/activitats/recomanades"));
    final response = await http.get(url.replace(queryParameters: {
      'latitud': widget.userLocation.latitude.toString(),
      'longitud': widget.userLocation.longitude.toString(),
    }));
    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final activitats = jsonDecode(body);
      setState(() {
        _totalActivities = activitats.length;
        _loadedActivities = 0;
      });
      for (var activitat in activitats) {
        LatLng localitzacioActivitat = LatLng(activitat['ubicacio']['latitud'], activitat['ubicacio']['longitud']);
        List<AirQualityData> aqd = AirQualityService.findClosestAirQualityData(localitzacioActivitat, widget.contaminantsPerLocation);
        if (AirQualityService.isAcceptable(aqd)) {
          TransitRoute dist = await calculateRoute(false,false,DateTime.now(),DateTime.now(),3,widget.userLocation,localitzacioActivitat);
          Activity temp = Activity(
              id: activitat['id'],
              creador: activitat['creador'],
              name: activitat['nom'],
              description: activitat['descripcio'],
              dataInici: DateTime.parse(activitat['dataInici']),
              dataFi: DateTime.parse(activitat['dataFi']),
              location: localitzacioActivitat,
              distance: dist.distance.toDouble(),
              isFavorite: await activityService.isActivityFavorite(activitat['id'], authService.getCurrentUsername()!),
              airQuality: aqd
          );
          try {
            widget.savedLocations[localitzacioActivitat] = await MapService().fetchPlaceDetails(localitzacioActivitat);
          } catch (e) {
            widget.savedLocations[localitzacioActivitat] = "";
          }
          _activities.add(temp);
        }
        setState(() {
          _loadedActivities++;
        });
      }
      setState(() {
        _activities = _activities;
      });
    } else {
      throw Exception("${response.statusCode}: ${response.reasonPhrase}");
    }
  }

  void _showEditActivityForm(Activity activity) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: activity.name);
    final descriptionController = TextEditingController(
      text: activity.description,
    );
    final startDateController = TextEditingController(
      text: activity.dataInici.toString(),
    );
    final endDateController = TextEditingController(text: activity.dataFi.toString());
    final creatorController = TextEditingController(text: activity.creador);
    final locationController = TextEditingController(
      text: '${activity.location.latitude},${activity.location.longitude}'
    );

    LatLng selectedLocation = activity.location;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar actividad'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'Título'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa un título';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: 'Descripción'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa una descripción';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: startDateController,
                    decoration: InputDecoration(labelText: 'Fecha de inicio'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa una fecha de inicio';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: endDateController,
                    decoration: InputDecoration(labelText: 'Fecha de fin'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa una fecha de fin';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<LatLng>(
                    value: selectedLocation,
                    items:
                    widget.savedLocations.entries.map((entry) {
                      String displayText =
                      entry.value.isNotEmpty
                          ? entry.value
                          : '${entry.key.latitude}, ${entry.key.longitude}';
                      return DropdownMenuItem<LatLng>(
                        value: entry.key,
                        child: Text(
                          displayText,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLocation = value!;
                      });
                    },
                    decoration: InputDecoration(labelText: 'Selected Location'),
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a location';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Cierra el diálogo
                  Navigator.pop(context);

                  // Prepara los datos actualizados
                  final updatedActivityData = {
                    'title': titleController.text,
                    'description': descriptionController.text,
                    'startDate': startDateController.text,
                    'endDate': endDateController.text,
                    'location':
                    locationController
                        .text, // Ubicación ingresada por el usuario
                    'user': creatorController.text,
                  };

                  // Llama al servicio para actualizar la actividad
                  try {
                    final activityService = ActivityService();
                    await activityService.updateActivityInBackend(
                      activity.id.toString(),
                      updatedActivityData,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error al actualizar la actividad: ${e.toString()}',
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(Activity activity) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar actividad'),
          content: Text(
            '¿Estás seguro de que quieres eliminar esta actividad?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Cierra el diálogo

                // Llama al servicio para eliminar la actividad
                try {
                  final activityService = ActivityService();
                  await activityService.deleteActivityFromBackend(
                    activity.id.toString(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Actividad eliminada correctament."),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Error al eliminar l'activitat: ${e.toString()}",
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activitats Recomanades'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Center(child: CircularProgressIndicator()),
                if (_totalActivities > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _totalActivities > 0 ? _loadedActivities / _totalActivities : null,
                        ),
                        const SizedBox(height: 8),
                        Text('Carregant activitats: $_loadedActivities / $_totalActivities'),
                      ],
                    ),
                  ),
              ],
            )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Activitats recomanades a prop teu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[900],
                    fontSize: 18,
                  ) ?? TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[900],
                    fontSize: 18,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(
            thickness: 1.2,
            indent: 24,
            endIndent: 24,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final activity = _activities[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActivityDetailsPage(
                          id: activity.id.toString(),
                          title: activity.name,
                          creator: activity.creador,
                          description: activity.description,
                          startDate: activity.dataInici.toString(),
                          endDate: activity.dataFi.toString(),
                          airQualityData: activity.airQuality,
                          isEditable: true,
                          onEdit:
                              () => _showEditActivityForm(activity), // Pasamos la función de editar
                          onDelete:
                              () => _showDeleteConfirmation(activity), // Pasamos la función de eliminar
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ActivityDetailsPage(
                                              id: activity.id.toString(),
                                              title: activity.name,
                                              creator: activity.creador,
                                              description: activity.description,
                                              startDate: activity.dataInici.toString(),
                                              endDate: activity.dataFi.toString(),
                                              airQualityData: activity.airQuality,
                                              isEditable: true,
                                              onEdit:
                                                  () => _showEditActivityForm(activity), // Pasamos la función de editar
                                              onDelete:
                                                  () => _showDeleteConfirmation(activity), // Pasamos la función de eliminar
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        activity.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    backgroundColor: Colors.teal[100],
                                    label: Text(
                                      activity.distance < 1000
                                          ? '${activity.distance.toStringAsFixed(0)} m'
                                          : '${NumberFormat("#,##0.0", "es_ES").format(activity.distance / 1000)} km',
                                      style: TextStyle(color: Colors.teal[800]),
                                    ),
                                    avatar: Icon(Icons.directions_walk, color: Colors.teal[800], size: 18),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                activity.description,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.teal[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Inici: ${DateFormat('dd/MM/yyyy HH:mm').format(activity.dataInici)}',
                                    style: TextStyle(fontSize: 13, color: Colors.teal[900]),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.event, size: 16, color: Colors.teal[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Fi: ${DateFormat('dd/MM/yyyy HH:mm').format(activity.dataFi)}',
                                    style: TextStyle(fontSize: 13, color: Colors.teal[900]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Qualitat de l'aire:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.teal[800],
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                    const SizedBox(width: 8),
                                    ...activity.airQuality.map((aq) => Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            color: getColorForAirQuality(aq.aqi),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${aq.contaminant.name}: ${aq.value.toStringAsFixed(1)} ${aq.units}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: activity.isFavorite ?
                                          Icon(Icons.favorite, color: Colors.red)
                                        : Icon(Icons.favorite_border, color: Colors.red),
                                    label: activity.isFavorite ? Text('Desada') : Text('Desar'),
                                    onPressed: () async {
                                      if (!activity.isFavorite) {
                                        try {
                                          await activityService.addActivityToFavorites(activity.id, authService.getCurrentUsername()!);
                                          setState(() {
                                            activity.isFavorite = true;
                                          });
                                          if (context.mounted) NotificationService().showInfo(context, 'Has afegit ${activity.name} a la teva llista de favorits.');
                                        } catch (e) {
                                          if (context.mounted) NotificationService().showError(context, 'Error afegint ${activity.name} a la teva llista de favorits.');
                                        }
                                      } else {
                                        try {
                                          await activityService.removeActivityFromFavorites(activity.id, authService.getCurrentUsername()!);
                                          setState(() {
                                            activity.isFavorite = false;
                                          });
                                          if (context.mounted) NotificationService().showInfo(context, 'Has eliminat ${activity.name} de la teva llista de favorits.');
                                        } catch (e) {
                                          if (context.mounted) NotificationService().showError(context,'Error eliminant ${activity.name} de la teva llista de favorits.');
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.directions),
                                    label: const Text('Com Arribar'),
                                    onPressed: () {
                                      Navigator.pop(context, activity.location);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

