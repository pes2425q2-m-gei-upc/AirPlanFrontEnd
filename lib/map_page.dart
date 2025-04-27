// map_page.dart
import 'dart:async';

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
  Map<int, dynamic> savedRoutes = {};
  TransitRoute currentRoute = TransitRoute(
    fullRoute: [],
    steps: [],
    duration: 0,
    distance: 0,
    departure: DateTime.now(),
    arrival: DateTime.now(),
    origin: LatLng(0, 0),
    destination: LatLng(0, 0),
    option: 0
  );
  bool isNavigating = false;
  StreamSubscription<Position>? _positionStreamSubscription;

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
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
        _updateUserMarker(currentPosition); // Use the helper method
      });
      mapController.move(currentPosition, 15.0); // Move map initially
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
      for (Map<String, dynamic> route in routes) {
        List<TransitStep> steps = [];
        List<LatLng> fullRoute = [];
        LatLng origin = LatLng(route['origen']['latitud'], route['origen']['longitud']);
        LatLng destination = LatLng(route['desti']['latitud'], route['desti']['longitud']);
        int option;
        switch (route['tipusVehicle']) {
          case 'Cotxe':
            option = 1;
            break;
          case 'Moto':
            option = 2;
            break;
          case 'Bicicleta':
            option = 4;
            break;
          case 'TransportPublic':
            option = 10;
            break;
          default:
            option = 3;
            break;
        }
        TransitRoute temp = TransitRoute(
            fullRoute: fullRoute,
            steps: steps,
            duration: route['duracioMax'],
            distance: 0,
            departure: DateTime.parse(route['data']),
            arrival: DateTime.parse(route['data']),
            origin: origin,
            destination: destination,
            option: option
        );
        try {
          temp = await _calculateRoute(false, false, DateTime.now(), DateTime.now(), temp.option, temp.origin, temp.destination, mapService);
          savedRoutes[route['id']] = temp;
        } catch (e) {
          savedRoutes[route['id']] = temp;
        }
      }
      setState(() {
        savedRoutes = savedRoutes;
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
      // Remove previous tapped location marker if exists
      markers.removeWhere((m) => m.key == const Key('tapped_location'));

      markers = [
        // Add new tapped location marker
        Marker(
          key: const Key('tapped_location'), // Add a key
          width: 80.0,
          height: 80.0,
          point: position,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40.0,
          ),
        ),
        // Keep the user marker (it will be updated by the stream if navigating)
        ...markers.where((m) => m.key == const Key('user_location')),
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

    try {
      currentRoute = await _calculateRoute(false, false, DateTime.now(), DateTime.now(), selectedOption!, start, end, mapService);
      setState(() {
        currentRoute = currentRoute;
      });
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
            SnackBar(content: Text("Ruta calculada correctament."))
        );
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
            SnackBar(content: Text('Error al calcular la ruta: ${e.toString()}'))
        );
      }
    }
  }

  Future<TransitRoute> _calculateRoute(bool departure, bool arrival, DateTime departureTime, DateTime arrivalTime, int selectedOption, LatLng start, LatLng end, MapService mapService) async {
    try {
      final TransitRoute transitRoute;
      if (selectedOption == 10) {
        transitRoute = await mapService.getPublicTransportRoute(departure, arrival, departureTime, arrivalTime, start, end);
      } else {
        transitRoute = await mapService.getRoute(departure, arrival, departureTime, arrivalTime, selectedOption, start, end);
      }
      return transitRoute;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  void _showRouteDetails(TransitRoute transitRoute) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: [
          ListTile(
            title: Text('Total Journey'),
            subtitle: Text('Duració: ${transitRoute.duration} min - Distancia: ${transitRoute.distance} m - Sortida: ${DateFormat.Hm().format(transitRoute.departure)} - Arribada: ${DateFormat.Hm().format(transitRoute.arrival)}'),
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                          const SizedBox(width: 10),
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
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              showRouteOptions(context, currentPosition, selectedLocation, mapService);
                            },
                            child: const Text("Com Arribar"),
                          ),
                        ],
                      ),
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

  Future<int> _sendRouteToBackend(TransitRoute route) async {
    int id = 0;
    try {
      id = await mapService.sendRouteToBackend(route);
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('Ruta enviada correctament.')),
        );
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('Error al enviar la ruta: ${e.toString()}')),
        );
      }
    }
    return id;
  }

  void _showTimeSelectionDialog() async {
    final selectedOption = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecciona si vols arribar o sortir a una hora concreta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Hora de sortida'),
                onTap: () => Navigator.pop(context, 'departure'),
              ),
              ListTile(
                leading: const Icon(Icons.access_time_filled),
                title: const Text('Hora d\'arribada'),
                onTap: () => Navigator.pop(context, 'arrival'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedOption != null) {
      final actualContext = context;
      if (actualContext.mounted) {
        final selectedTime = await showTimePicker(
          context: actualContext,
          initialTime: TimeOfDay.now(),
        );
        if (selectedTime != null) {
          final selectedDateTime = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            selectedTime.hour,
            selectedTime.minute,
          );

          try {
            if (selectedOption == 'departure') {
              currentRoute = await _calculateRoute(true, false, selectedDateTime, selectedDateTime, currentRoute.option, currentRoute.origin, currentRoute.destination, mapService);
            } else if (selectedOption == 'arrival') {
              currentRoute = await _calculateRoute(false, true, selectedDateTime, selectedDateTime, currentRoute.option, currentRoute.origin, currentRoute.destination, mapService);
            }
            setState(() {
              currentRoute = currentRoute;
            });
            final actualContext = context;
            if (actualContext.mounted) {
              ScaffoldMessenger.of(actualContext).showSnackBar(
                  SnackBar(content: Text("Ruta calculada correctament."))
              );
            }
          } catch (e) {
            final actualContext = context;
            if (actualContext.mounted) {
              ScaffoldMessenger.of(actualContext).showSnackBar(
                SnackBar(
                    content: Text('Error al calcular la ruta: ${e.toString()}')),
              );
            }
          }
        }
      }
    }
  }

  void _showSavedRoutes() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (savedRoutes.isEmpty) {
          return Center(
            child: Text(
              'No tens cap ruta guardada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          );
        }
        return ListView.builder(
          itemCount: savedRoutes.length,
          itemBuilder: (context, index) {
            final route = savedRoutes.values.elementAt(index);
            return ListTile(
              title: Text('Ruta ${index + 1}'),
              subtitle: Text('Duració: ${route.duration} min - Distancia: ${route.distance} m'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.visibility, color: Colors.blue),
                    onPressed: () {
                      setState(() {
                        currentRoute = route;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Confirm Deletion'),
                            content: Text('Segur que vols eliminar la ruta seleccionada?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close the dialog
                                },
                                child: Text('Cancel·lar', style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _eliminarRuta(savedRoutes.keys.elementAt(index),index);
                                  });
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                child: Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _eliminarRuta(int id, int index) async {
    try {
      await mapService.deleteRouteInBackend(id);
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('Ruta eliminada correctament.')),
        );
      }
      savedRoutes.remove(id);
      setState(() {
        savedRoutes = savedRoutes;
      });
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('Error al eliminar la ruta: ${e.toString()}')),
        );
      }
    }
  }

  void _startNavigation() {
    if (currentRoute.fullRoute.isEmpty) return;

    setState(() {
      isNavigating = true;
    });

    // Start listening to location updates
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
          setState(() {
            currentPosition = LatLng(position.latitude, position.longitude);
            // Update the user marker (ensure it's handled correctly in your marker list logic)
            _updateUserMarker(currentPosition);
          });
          // Center map on user location
          mapController.move(currentPosition, 17.0); // Adjust zoom level as needed

          // --- Advanced Steps (To be implemented) ---
          // 1. Determine current step based on user location
          // 2. Display current/next instruction
          // 3. Check if user is off-route
          // 4. Optionally rotate map: mapController.rotate(position.heading);
          // ---
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error getting location: $error')),
            );
          }
          _stopNavigation();
        }
    );
  }

  void _stopNavigation() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    setState(() {
      isNavigating = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigation stopped.')),
      );
    }
  }

  // Helper to update or add the user marker
  void _updateUserMarker(LatLng position) {
    markers.removeWhere((m) => m.key == const Key('user_location')); // Remove old marker if exists
    markers.add(Marker(
      key: const Key('user_location'), // Use a key to easily find/remove it
      width: 80.0,
      height: 80.0,
      point: position,
      child: const Icon(
        Icons.navigation, // Use a navigation icon
        color: Colors.blue,
        size: 40.0,
      ),
    ));
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
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "toggleAirQuality",
                  onPressed: _toggleAirQualityCircles,
                  child: Icon(showAirQualityCircles ? Icons.visibility : Icons.visibility_off),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "showSavedRoutes",
                  onPressed: _showSavedRoutes,
                  child: Icon(Icons.route),
                ),
              ],
            )
          ),
          // Route action buttons - only show when route is active
          if (currentRoute.fullRoute.isNotEmpty) ...[
            Positioned(
              top: 160,
              right: 10,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: "startStopRoute", // Changed heroTag
                    backgroundColor: isNavigating ? Colors.red : Colors.green, // Change color
                    onPressed: () {
                      if (isNavigating) {
                        _stopNavigation();
                      } else {
                        _startNavigation();
                      }
                    },
                    child: Icon(isNavigating ? Icons.stop : Icons.play_arrow), // Change icon
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
                    heroTag: "changeDepartureArrival",
                    backgroundColor: Colors.cyan,
                    onPressed: () {
                      _showTimeSelectionDialog();
                    },
                    child: const Icon(Icons.access_time),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: "saveRoute",
                    backgroundColor: Colors.orange,
                    onPressed: () async {
                      int id = await _sendRouteToBackend(currentRoute);
                      if (id != 0) {
                        savedRoutes[id] = currentRoute;
                        setState(() {
                          savedRoutes = savedRoutes;
                        });
                      }
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
                          duration: 0,
                          distance: 0,
                          departure: DateTime.now(),
                          arrival: DateTime.now(),
                          origin: LatLng(0, 0),
                          destination: LatLng(0, 0),
                          option: 0
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

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}
