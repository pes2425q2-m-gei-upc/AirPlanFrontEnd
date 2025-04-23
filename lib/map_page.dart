// map_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'air_quality.dart';
import 'form_dialog.dart';
import 'map_service.dart';
import 'activity_service.dart';
import 'map_ui.dart' as map_ui;
import 'activity_details_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  MapPageState createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  final MapService mapService = MapService();
  final ActivityService activityService = ActivityService();
  LatLng selectedLocation = LatLng(0, 0);
  Map<LatLng, String> savedLocations = {};
  String placeDetails = "";
  List<CircleMarker> circles = [];
  Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation = {};
  LatLng currentPosition = LatLng(41.3851, 2.1734); // Default to Barcelona
  List<Map<String, dynamic>> activities = [];
  List<Marker> markers = [];
  bool showAirQualityCircles = true;

  @override
  void initState() {
    super.initState();
    fetchAirQualityData();
    fetchActivities();
  }

  Future<void> fetchAirQualityData() async {
    try {
    final circles = await mapService.fetchAirQualityData(
        contaminantsPerLocation);
    setState(() {
      this.circles = circles;
    });
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(SnackBar(
          content: Text('Error al obtenir dades de qualitat de l\'aire: ${e.toString()}'),
        ));
      }
    }
  }

  Future<void> fetchActivities() async {
    final activities = await activityService.fetchActivities();

    for (Map<String,dynamic> activity in activities) {
      final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
      final lat = ubicacio['latitud'] as double;
      final lon = ubicacio['longitud'] as double;
      String details = await mapService.fetchPlaceDetails(LatLng(lat, lon));
      savedLocations[LatLng(lat, lon)] = details;
    }

    setState(() {
      this.activities = activities;
    });
  }

  Future<void> _onMapTapped(TapPosition tapPosition, LatLng position) async {
    setState(() {
      markers = [
        // Current selected location marker
        Marker(
          width: 80.0,
          height: 80.0,
          point: position,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40.0,
          ),
        ),
        // Saved locations markers
        ...savedLocations.entries.map((entry) => Marker(
          width: 80.0,
          height: 80.0,
          point: entry.key,
          child: GestureDetector(
            onTap: () => _showSavedLocationDetails(entry.key, entry.value),
            child: const Icon(
              Icons.push_pin,
              color: Colors.red,
              size: 40.0,
            ),
          ),
        )),
      ];
    });

    String details;
    try {
      details = await mapService.fetchPlaceDetails(position);
      _showPlaceDetails(position,details);
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(SnackBar(
          content: Text('Error al obtenir detalls del lloc: ${e.toString()}'),
        ));
      }
    }
  }

  void _showPlaceDetails(LatLng selectedLocation, String placeDetails) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.3,
          minChildSize: 0.1,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Selected Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(placeDetails),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showFormWithLocation(selectedLocation,placeDetails);
                            savedLocations[selectedLocation] = placeDetails;
                          },
                          child: const Text("Crea Activitat"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              savedLocations[selectedLocation] = placeDetails;
                              markers = [
                                // Current selected location marker
                                Marker(
                                  width: 80.0,
                                  height: 80.0,
                                  point: selectedLocation,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40.0,
                                  ),
                                ),
                                // Saved locations markers
                                ...savedLocations.entries.map((entry) => Marker(
                                  width: 80.0,
                                  height: 80.0,
                                  point: entry.key,
                                  child: GestureDetector(
                                    onTap: () => _showSavedLocationDetails(entry.key, entry.value),
                                    child: const Icon(
                                      Icons.push_pin,
                                      color: Colors.red,
                                      size: 40.0,
                                    ),
                                  ),
                                )),
                              ];
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("Guardar marcador"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFormWithLocation(LatLng location, String placeDetails) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Details'),
          content: FormDialog(
            initialLocation: '${location.latitude},${location.longitude}',
            initialPlaceDetails: placeDetails,
            initialTitle: '',
            initialUser: '',
            initialDescription: '',
            initialStartDate: '',
            initialEndDate: '',
            savedLocations: savedLocations,
          ),
        );
      },
    );

    if (result != null) {
      await activityService.sendActivityToBackend(result);
      fetchActivities();
    }
  }

  void _showActivityDetails(Map<String, dynamic> activity) async {
    final String? currentUser = FirebaseAuth.instance.currentUser?.displayName;
    final bool isCurrentUserCreator = currentUser != null &&
        activity['creador'] == currentUser;

    bool isFavorite = false;

    try {
      isFavorite = await isActivityFavorite(activity['id']);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error checking favorite status: $error'),
        ));
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToActivityDetails(activity);
                          },
                          child: Text(
                            activity['nom'] ?? '',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Creador: ${activity['creador'] ?? ''}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () async {
                      try {
                        if (isFavorite) {
                          await removeActivityFromFavorites(activity['id']);
                        } else {
                          await addActivityToFavorites(activity['id']);
                        }
                        setState(() {
                          isFavorite = !isFavorite;
                        });
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error updating favorite status: $error'),
                          ));
                        }
                      }
                    },
                  ),
                  if (isCurrentUserCreator)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditActivityForm(activity);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(activity);
                          },
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// Función para mostrar el formulario de edición
  void _showEditActivityForm(Map<String, dynamic> activity) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: activity['nom']);
    final descriptionController = TextEditingController(text: activity['descripcio']);
    final startDateController = TextEditingController(text: activity['dataInici']);
    final endDateController = TextEditingController(text: activity['dataFi']);
    final creatorController = TextEditingController(text: activity['creador']);
    final locationController = TextEditingController(
      text: activity['ubicacio'] != null
          ? '${activity['ubicacio']['latitud']},${activity['ubicacio']['longitud']}'
          : '',
    );

    LatLng selectedLocation = LatLng(activity['ubicacio']['latitud'] as double, activity['ubicacio']['longitud'] as double);

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
                    items: savedLocations.entries.map((entry) {
                      String displayText = entry.value.isNotEmpty
                          ? entry.value
                          : '${entry.key.latitude}, ${entry.key.longitude}';
                      return DropdownMenuItem<LatLng>(
                        value: entry.key,
                        child: Text(displayText, overflow: TextOverflow.ellipsis),
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
                    'location': locationController.text, // Ubicación ingresada por el usuario
                    'user': creatorController.text,
                  };

                  // Llama al servicio para actualizar la actividad
                  try {
                    final activityService = ActivityService();
                    await activityService.updateActivityInBackend(
                      activity['id'].toString(),
                      updatedActivityData,
                    );
                    fetchActivities(); // Actualiza la lista de actividades
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error al actualizar la actividad: ${e.toString()}'),
                      ));
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

// Función para mostrar el aviso de confirmación de eliminación
  void _showDeleteConfirmation(Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar actividad'),
          content: Text('¿Estás seguro de que quieres eliminar esta actividad?'),
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
                  await activityService.deleteActivityFromBackend(activity['id'].toString());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Actividad eliminada correctament."))
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Error al eliminar l'activitat: ${e.toString()}"))
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

  List<AirQualityData> findClosestAirQualityData(LatLng activityLocation) {
    double closestDistance = double.infinity;
    LatLng closestLocation = LatLng(0, 0);
    List<AirQualityData> listAQD = [];

    contaminantsPerLocation.forEach((location, dataMap) {
      final distance = Distance().as(LengthUnit.Meter, activityLocation, location);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestLocation = location;
      }
    });

    contaminantsPerLocation[closestLocation]?.forEach((contaminant, airQualityData) {
      listAQD.add(airQualityData);
    });

    return listAQD;
  }

// Función para navegar a la página de detalles (código original)
  void _navigateToActivityDetails(Map<String, dynamic> activity) {
    final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
    final lat = ubicacio['latitud'] as double;
    final lon = ubicacio['longitud'] as double;
    List<AirQualityData> airQualityData = findClosestAirQualityData(LatLng(lat, lon));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailsPage(
          id: activity['id'].toString(),
          title: activity['nom'] ?? '',
          creator: activity['creador'] ?? '',
          description: activity['descripcio'] ?? '',
          startDate: activity['dataInici'] ?? '',
          endDate: activity['dataFi'] ?? '',
          airQualityData: airQualityData,
          isEditable: true,
          onEdit: () => _showEditActivityForm(activity), // Pasamos la función de editar
          onDelete: () => _showDeleteConfirmation(activity), // Pasamos la función de eliminar
        ),
      ),
    );
  }

  void _showSavedLocationDetails(LatLng position, String details) {
    _showPlaceDetails(position, details);
  }

  void _toggleAirQualityCircles() {
    setState(() {
      showAirQualityCircles = !showAirQualityCircles;
    });
  }
  //Puentes entre boton de favorita y activityService
  Future<bool> isActivityFavorite(int activityId) async {
    final String? username = FirebaseAuth.instance.currentUser?.displayName;
    if (username == null) {
      throw Exception('User not logged in');
    }
    bool isFavorite = await activityService.isActivityFavorite(activityId, username);
    print("isFavorite: $isFavorite");
    return await activityService.isActivityFavorite(activityId, username);
  }

  Future<void> addActivityToFavorites(int activityId) async {
    final String? username = FirebaseAuth.instance.currentUser?.displayName;
    if (username == null) {
      throw Exception('User not logged in');
    }
    await activityService.addActivityToFavorites(activityId, username);
  }

  Future<void> removeActivityFromFavorites(int activityId) async {
    final String? username = FirebaseAuth.instance.currentUser?.displayName;
    if (username == null) {
      throw Exception('User not logged in');
    }
    await activityService.removeActivityFromFavorites(activityId, username);
  }

  Future<void> _showFavoriteActivities() async {
    try {
      final String? username = FirebaseAuth.instance.currentUser?.displayName;
      if (username == null) {
        throw Exception('User not logged in');
      }

      final favoriteActivities = await activityService.fetchFavoriteActivities(username);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) {
          if (favoriteActivities.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No tienes actividades favoritas.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: favoriteActivities.length,
            itemBuilder: (context, index) {
              final activity = favoriteActivities[index];
              return ListTile(
                title: Text(activity['nom'] ?? 'Sin título'),
                subtitle: Text(activity['descripcio'] ?? 'Sin descripción'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToActivityDetails(activity);
                },
              );
            },
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al obtener actividades favoritas: ${e.toString()}'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AirPlan"),
      ),
      body: Stack(
        children: [
          map_ui.MapUI(
            mapController: mapController,
            currentPosition: currentPosition,
            circles: showAirQualityCircles ? circles : [],
            onMapTapped: _onMapTapped,
            activities: activities,
            onActivityTap: _showActivityDetails,
            markers: markers,
          ),
          Positioned(
            top: 10,
            right: 10,
            child: FloatingActionButton(
              onPressed: _toggleAirQualityCircles,
              child: Icon(showAirQualityCircles ? Icons.visibility : Icons.visibility_off),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: FloatingActionButton(
              onPressed: _showFavoriteActivities,
              child: const Icon(Icons.favorite),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (savedLocations.entries.isNotEmpty) {
            _showFormWithLocation(savedLocations.keys.first, placeDetails);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No tens ubicacions guardades. Selecciona una ubicació abans de crear una activitat.')),
            );
          }
        },
        child: Icon(Icons.add_location),
      ),
    );
  }
}
