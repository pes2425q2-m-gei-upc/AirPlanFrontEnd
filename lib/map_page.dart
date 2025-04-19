// map_page.dart
import 'package:airplan/transit_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
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
  List<dynamic> savedRoutes = [];
  TransitRoute currentRoute = TransitRoute(
    fullRoute: [],
    steps: [],
    duration: '',
    distance: '',
    departure: DateTime.now(),
    arrival: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    fetchAirQualityData();
    fetchActivities();
    fetchUserLocation();
    fetchRoutes();
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
      markers.add(Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(lat, lon),
        child: GestureDetector(
          onTap: () => _showSavedLocationDetails(LatLng(lat, lon), details),
          child: const Icon(
            Icons.push_pin,
            color: Colors.red,
            size: 40.0,
          ),
        ),
      ));
    }

    setState(() {
      this.activities = activities;
    });
  }

  Future<void> fetchUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('Location services are disabled. Please enable them.')),
        );
      }
      return;
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        final actualContext = context;
        if (actualContext.mounted) {
          ScaffoldMessenger.of(actualContext).showSnackBar(
            SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return;
    }

    // Fetch the current location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
        markers.add(Marker(
          width: 80.0,
          height: 80.0,
          point: currentPosition,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 40.0,
          ),
        ));
      });
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('Failed to fetch location: $e')),
        );
      }
    }
  }

  Future<void> fetchRoutes() async {
    try {
      final routes = await mapService.fetchRoutes();
      setState(() {
        savedRoutes = routes;
      });
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(SnackBar(
          content: Text("Error al obtenir les rutes de l'usuari: ${e.toString()}"),
        ));
      }
    }
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
        Marker(
          width: 80.0,
          height: 80.0,
          point: currentPosition,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
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

  Future<void> showRouteOptions(BuildContext context, LatLng start, LatLng end, MapService mapService) async {
    final selectedOption = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecciona el mode de transport'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.directions_walk),
                title: const Text('A peu'),
                onTap: () => Navigator.pop(context, 3),
              ),
              ListTile(
                leading: const Icon(Icons.pedal_bike),
                title: const Text('Bicicleta'),
                onTap: () => Navigator.pop(context, 4),
              ),
              ListTile(
                leading: const Icon(Icons.directions_bus),
                title: const Text('Transport públic'),
                onTap: () => Navigator.pop(context, 10),
              ),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: const Text('Cotxe'),
                onTap: () => Navigator.pop(context, 1),
              ),
              ListTile(
                leading: const Icon(Icons.directions_bike),
                title: const Text('Moto'),
                onTap: () => Navigator.pop(context, 2),
              ),
            ],
          ),
        );
      },
    );

    if (selectedOption != null) {
      try {
        final transitRoute;
        if (selectedOption == 10) {
          transitRoute = await mapService.getPublicTransportRoute(start, end);
        } else {
          transitRoute = await mapService.getRoute(selectedOption, start, end);
        }
        setState(() {
          currentRoute = transitRoute;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Ruta calculada correctament."))
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al calcular la ruta: ${e.toString()}'))
          );
        }
      }
    }
  }

  void _showRouteDetails(TransitRoute transitRoute) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: [
          ListTile(
            title: Text('Total Journey'),
            subtitle: Text('Duració: ${transitRoute.duration} - Distancia: ${transitRoute.distance} - Sortida: ${DateFormat.Hm().format(transitRoute.departure)} - Arribada: ${DateFormat.Hm().format(transitRoute.arrival)}'),
          ),
          const Divider(),
          ...transitRoute.steps.map((step) => Column(
            children: [
              ListTile(
                leading: Icon(
                    step.mode == TipusVehicle.cap
                        ? Icons.directions_walk
                        : step.mode == TipusVehicle.cotxe
                        ? Icons.directions_car
                        : step.mode == TipusVehicle.autobus
                        ? Icons.directions_bus
                        : step.mode == TipusVehicle.tren
                        ? Icons.train
                        : step.mode == TipusVehicle.bicicleta
                        ? Icons.pedal_bike
                        : step.mode == TipusVehicle.moto
                        ? Icons.directions_bike
                        : Icons.directions_transit,
                    color: step.color
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: step.instructions
                      .map((instruction) => Column(
                    children: [
                      Text(instruction),
                      const Divider(), // Add a separator after each instruction
                    ],
                  ))
                      .toList(),
                ),
                subtitle: Text('${DateFormat.Hm().format(step.departure)} - ${DateFormat.Hm().format(step.arrival)}'),
              ),
              const Divider(), // Add a separator after each instruction
            ],
          )),
        ],
      ),
    );
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
                            _showFormWithLocation(selectedLocation, placeDetails);
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
                                Marker(
                                  width: 80.0,
                                  height: 80.0,
                                  point: currentPosition,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
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
                        ElevatedButton(
                          onPressed: () {
                            showRouteOptions(context, currentPosition, selectedLocation, mapService);
                          },
                          child: const Text("Com Arribar"),
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

  void _showActivityDetails(Map<String, dynamic> activity) {
    // Obtener el usuario actual
    final String? currentUser = FirebaseAuth.instance.currentUser?.displayName;
    final bool isCurrentUserCreator = currentUser != null &&
        activity['creador'] == currentUser;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Contenido a la izquierda (título y creador)
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
              // Botones a la derecha (solo si el usuario es el creador)
              Row(
                children: [
                  if (isCurrentUserCreator) // <-- Condición para mostrar los botones
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditActivityForm(activity);
                      },
                    ),
                  if (isCurrentUserCreator) // <-- Condición para mostrar los botones
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(activity);
                      },
                    ),
                  ElevatedButton(
                    onPressed: () {
                      final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
                      final lat = ubicacio['latitud'] as double;
                      final lon = ubicacio['longitud'] as double;
                      showRouteOptions(context, currentPosition, LatLng(lat, lon), mapService);
                    },
                    child: const Text("Com Arribar"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    ElevatedButton(
      onPressed: () {
        showRouteOptions(context, currentPosition, selectedLocation, mapService);
      },
      child: const Text("Com Arribar"),
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
            route: currentRoute.fullRoute,
            steps: currentRoute.steps,
          ),
          // Air quality toggle button
          Positioned(
            top: 10,
            right: 10,
            child: FloatingActionButton(
              heroTag: "toggleAirQuality",
              onPressed: _toggleAirQualityCircles,
              child: Icon(showAirQualityCircles ? Icons.visibility : Icons.visibility_off),
            ),
          ),
          // Route action buttons - only show when route is active
          if (currentRoute.fullRoute.isNotEmpty) ...[
            Positioned(
              top: 80,
              right: 10,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: "startRoute",
                    backgroundColor: Colors.green,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Start route functionality coming soon')),
                      );
                    },
                    child: const Icon(Icons.play_arrow),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: "showInstructions",
                    backgroundColor: Colors.blue,
                    onPressed: () {
                      if (currentRoute.steps.isNotEmpty) {
                        _showRouteDetails(currentRoute);
                      }
                    },
                    child: const Icon(Icons.list),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: "saveRoute",
                    backgroundColor: Colors.orange,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Save route functionality coming soon')),
                      );
                    },
                    child: const Icon(Icons.save),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: "unwatchRoute",
                    backgroundColor: Colors.grey,
                    onPressed: () {
                      setState(() {
                        currentRoute = TransitRoute(
                          fullRoute: [],
                          steps: [],
                          duration: '',
                          distance: '',
                          departure: DateTime.now(),
                          arrival: DateTime.now(),
                        );
                      });
                    },
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "addLocation",
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
