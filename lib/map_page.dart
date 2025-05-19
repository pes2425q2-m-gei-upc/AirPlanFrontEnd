// map_page.dart
import 'package:airplan/solicituds_service.dart';
import 'dart:async';
import 'package:airplan/transit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'air_quality.dart';
import 'form_dialog.dart';
import 'map_service.dart';
import 'activity_service.dart';
import 'map_ui.dart' as map_ui;
import 'activity_details_page.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import 'dart:math' show log, ln2, min;
import 'package:easy_localization/easy_localization.dart';

class MapPage extends StatefulWidget {
  final AuthService authService;
  final ActivityService activityService;

  MapPage({
    super.key,
    AuthService? authService,
    ActivityService? activityService,
  }) : authService = authService ?? AuthService(),
       activityService = activityService ?? ActivityService();

  @override
  MapPageState createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  final MapService mapService = MapService();
  final ActivityService activityService = ActivityService();
  final SolicitudsService solicitudsService = SolicitudsService();
  LatLng selectedLocation = LatLng(0, 0);
  Map<LatLng, String> savedLocations = {};
  String placeDetails = "";
  List<CircleMarker> circles = [];
  Map<LatLng, Map<Contaminant, AirQualityData>> contaminantsPerLocation = {};
  LatLng currentPosition = LatLng(41.3851, 2.1734); // Default to Barcelona
  List<Map<String, dynamic>> activities = [];
  List<Marker> markers = [];
  bool showAirQualityCircles = true;
  bool loadingRoutes = false;
  bool loadingActivities = false;
  Map<int, TransitRoute> savedRoutes = {};
  MapEntry<int, TransitRoute> currentRoute = MapEntry(
    0,
    TransitRoute(
      fullRoute: [],
      steps: [],
      duration: 0,
      distance: 0,
      departure: DateTime.now(),
      arrival: DateTime.now(),
      origin: LatLng(0, 0),
      destination: LatLng(0, 0),
      option: 0,
    ),
  );
  bool isNavigating = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  double _deviceHeading = 0.0;
  bool _showCompass = false;
  OverlayEntry? _currentInstructionOverlay;

  @override
  void initState() {
    super.initState();
    _startCompassListener();
    fetchAirQualityData();
    fetchActivities();
    fetchUserLocation();
    fetchRoutes();
  }

  void _startCompassListener() {
    _magnetometerSubscription = magnetometerEventStream().listen((
      MagnetometerEvent event,
    ) {
      if (mounted) {
        // Calculate base heading from magnetometer data
        double heading = math.atan2(event.y, event.x) * (180 / math.pi);

        heading -= 90;

        // Normalize to 0-360 degrees
        if (heading < 0) {
          heading += 360;
        }

        // Update the state only if significant change to prevent too many rebuilds
        if ((heading - _deviceHeading).abs() > 2.0) {
          setState(() {
            _deviceHeading = heading;
          });
        }
      }
    });
  }

  Future<void> fetchAirQualityData() async {
    try {
      final circles = await mapService.fetchAirQualityData(
        contaminantsPerLocation,
      );

      // Verificar que el widget esté montado antes de actualizar el estado
      if (mounted) {
        setState(() {
          this.circles = circles;
        });
      }
    } catch (e) {
      // Ya tiene comprobación mounted
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(
            content: Text(tr('error_fetch_air_quality', args: [e.toString()])),
          ),
        );
      }
    }
  }

  Future<void> fetchActivities() async {
    setState(() {
      loadingActivities = true;
    });
    final activities = await widget.activityService.fetchActivities();

    for (Map<String, dynamic> activity in activities) {
      final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
      final lat = ubicacio['latitud'] as double;
      final lon = ubicacio['longitud'] as double;
      String details;
      try {
        details = await mapService.fetchPlaceDetails(LatLng(lat, lon));
      } catch (e) {
        details = '';
      }
      savedLocations[LatLng(lat, lon)] = details;
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(lat, lon),
          child: GestureDetector(
            onTap: () => _showSavedLocationDetails(LatLng(lat, lon), details),
            child: const Icon(Icons.push_pin, color: Colors.red, size: 40.0),
          ),
        ),
      );
    }

    // Verificar que el widget esté montado antes de actualizar el estado
    if (mounted) {
      setState(() {
        this.activities = activities;
        loadingActivities = false;
      });
    }
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
          SnackBar(content: Text(tr('location_services_disabled'))),
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
            SnackBar(content: Text(tr('location_permissions_denied'))),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(
            content: Text(tr('location_permissions_permanently_denied')),
          ),
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
          SnackBar(
            content: Text(tr('failed_fetch_location', args: [e.toString()])),
          ),
        );
      }
    }
  }

  Future<void> fetchRoutes() async {
    setState(() {
      loadingRoutes = true;
    });
    try {
      final routes = await mapService.fetchRoutes();
      for (Map<String, dynamic> route in routes) {
        List<TransitStep> steps = [];
        List<LatLng> fullRoute = [];
        LatLng origin = LatLng(
          route['origen']['latitud'],
          route['origen']['longitud'],
        );
        LatLng destination = LatLng(
          route['desti']['latitud'],
          route['desti']['longitud'],
        );
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
          option: option,
        );
        try {
          temp = await _calculateRoute(
            false,
            false,
            DateTime.now(),
            DateTime.now(),
            temp.option,
            temp.origin,
            temp.destination,
            mapService,
          );
          savedRoutes[route['id']] = temp;
        } catch (e) {
          savedRoutes[route['id']] = temp;
        }
      }
      setState(() {
        savedRoutes = savedRoutes;
        loadingRoutes = false;
      });
    } catch (e) {
      setState(() {
        loadingRoutes = false;
      });
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(
            content: Text('${'error_fetch_user_routes'.tr()}: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _onMapTapped(TapPosition tapPosition, LatLng position) async {
    if (isNavigating) return;
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
          child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
        ),
        // Keep the user marker (it will be updated by the stream if navigating)
        ...markers.where((m) => m.key == const Key('user_location')),
        // Saved locations markers
        ...savedLocations.entries.map(
          (entry) => Marker(
            width: 80.0,
            height: 80.0,
            point: entry.key,
            child: GestureDetector(
              onTap: () => _showSavedLocationDetails(entry.key, entry.value),
              child: const Icon(Icons.push_pin, color: Colors.red, size: 40.0),
            ),
          ),
        ),
      ];
    });

    String details;
    try {
      details = await mapService.fetchPlaceDetails(position);
      _showPlaceDetails(position, details);
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(
            content: Text(
              '${'error_fetch_place_details'.tr()} ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  Future<void> showRouteOptions(
    BuildContext context,
    LatLng start,
    LatLng end,
    MapService mapService,
  ) async {
    final selectedOption = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('select_transport_mode'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.directions_walk),
                title: Text('walking'.tr()),
                onTap: () => Navigator.pop(context, 3),
              ),
              ListTile(
                leading: const Icon(Icons.pedal_bike),
                title: Text('bicycle'.tr()),
                onTap: () => Navigator.pop(context, 4),
              ),
              ListTile(
                leading: const Icon(Icons.directions_bus),
                title: Text('public_transport'.tr()),
                onTap: () => Navigator.pop(context, 10),
              ),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text('car'.tr()),
                onTap: () => Navigator.pop(context, 1),
              ),
              ListTile(
                leading: const Icon(Icons.directions_bike),
                title: Text('motorcycle'.tr()),
                onTap: () => Navigator.pop(context, 2),
              ),
            ],
          ),
        );
      },
    );

    try {
      currentRoute = MapEntry(
        0,
        await _calculateRoute(
          false,
          false,
          DateTime.now(),
          DateTime.now(),
          selectedOption!,
          start,
          end,
          mapService,
        ),
      );
      setState(() {
        currentRoute = currentRoute;
        if (currentRoute.value.fullRoute.isNotEmpty) {
          // Schedule the bounds fitting for after the setState completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitMapToBounds(
              _calculateRouteBounds(currentRoute.value.fullRoute),
            );
          });
        }
      });
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text(tr('route_calculated_success'))));
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(
            content: Text(tr('route_calculation_error', args: [e.toString()])),
          ),
        );
      }
    }
  }

  Future<TransitRoute> _calculateRoute(
    bool departure,
    bool arrival,
    DateTime departureTime,
    DateTime arrivalTime,
    int selectedOption,
    LatLng start,
    LatLng end,
    MapService mapService,
  ) async {
    try {
      final TransitRoute transitRoute;
      if (selectedOption == 10) {
        transitRoute = await mapService.getPublicTransportRoute(
          departure,
          arrival,
          departureTime,
          arrivalTime,
          start,
          end,
        );
      } else {
        transitRoute = await mapService.getRoute(
          departure,
          arrival,
          departureTime,
          arrivalTime,
          selectedOption,
          start,
          end,
        );
      }
      return transitRoute;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  void _showRouteDetails(TransitRoute transitRoute) {
    // Remove the current instruction overlay temporarily
    _currentInstructionOverlay?.remove();

    showModalBottomSheet(
      context: context,
      builder:
          (context) => ListView(
            children: [
              ListTile(
                title: Text('route_details'.tr()),
                subtitle: Text(
                  '${'route_duration'.tr()} ${transitRoute.duration} min - ${'route_distance'.tr()} ${transitRoute.distance} m - ${'route_departure'.tr()} ${DateFormat.Hm().format(transitRoute.departure)} - ${'route_arrival'.tr()} ${DateFormat.Hm().format(transitRoute.arrival)}',
                ),
              ),
              const Divider(),
              ...groupSteps(transitRoute.steps).map(
                (group) => Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        group.first.mode == TipusVehicle.cap
                            ? Icons.directions_walk
                            : group.first.mode == TipusVehicle.cotxe
                            ? Icons.directions_car
                            : group.first.mode == TipusVehicle.autobus
                            ? Icons.directions_bus
                            : group.first.mode == TipusVehicle.tren
                            ? Icons.train
                            : group.first.mode == TipusVehicle.bicicleta
                            ? Icons.pedal_bike
                            : group.first.mode == TipusVehicle.moto
                            ? Icons.directions_bike
                            : Icons.directions_transit,
                        color: group.first.color,
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...group.map(
                            (step) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(step.instruction),
                                Text(
                                  '${DateFormat.Hm().format(step.departure)} - ${DateFormat.Hm().format(step.arrival)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (step != group.last)
                                  const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              ),
            ],
          ),
    ).whenComplete(() {
      // Reinsert the current instruction overlay after the modal is dismissed
      if (_currentInstructionOverlay != null && mounted) {
        Overlay.of(context).insert(_currentInstructionOverlay!);
      }
    });
  }

  List<List<TransitStep>> groupSteps(List<TransitStep> steps) {
    List<List<TransitStep>> groups = [];
    List<TransitStep> currentGroup = [];

    for (var step in steps) {
      if (currentGroup.isEmpty || currentGroup.first.mode == step.mode) {
        currentGroup.add(step);
      } else {
        groups.add(List.from(currentGroup));
        currentGroup = [step];
      }
    }

    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  void _showPlaceDetails(LatLng selectedLocation, String placeDetails) {
    if (isNavigating) return;
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
                    Text(
                      'selected_location'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                              _showFormWithLocation(
                                selectedLocation,
                                placeDetails,
                              );
                              savedLocations[selectedLocation] = placeDetails;
                            },
                            child: Text('create_activity'.tr()),
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
                                  ...savedLocations.entries.map(
                                    (entry) => Marker(
                                      width: 80.0,
                                      height: 80.0,
                                      point: entry.key,
                                      child: GestureDetector(
                                        onTap:
                                            () => _showSavedLocationDetails(
                                              entry.key,
                                              entry.value,
                                            ),
                                        child: const Icon(
                                          Icons.push_pin,
                                          color: Colors.red,
                                          size: 40.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ];
                              });
                              Navigator.pop(context);
                            },
                            child: Text('save_marker'.tr()),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              showRouteOptions(
                                context,
                                currentPosition,
                                selectedLocation,
                                mapService,
                              );
                            },
                            child: Text('get_directions'.tr()),
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
          title: Text(tr('enter_details')),
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
      try {
        await widget.activityService.sendActivityToBackend(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('activity_created_success'))),
          );
        }
        fetchActivities();
      } catch (e) {
        String errorMessage = e.toString();
        if (errorMessage.contains("inapropiats")) {
          errorMessage = "inappropiat_message".tr();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('${'error_creating_activity'.tr()} $errorMessage'),
              ),
            ),
          );
        }
      }
    }
  }

  void _showActivityDetails(Map<String, dynamic> activity) async {
    if (isNavigating) return;
    final String? currentUser = widget.authService.getCurrentUsername();
    final bool isCurrentUserCreator =
        currentUser != null && activity['creador'] == currentUser;

    bool isFavorite = false;

    try {
      isFavorite = await isActivityFavorite(activity['id']);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking favorite status: $error')),
        );
      }
    }

    if (!mounted) return;

    bool solicitudExistente = false;

    // Verificar si ya existe una solicitud para esta actividad
    if (!isCurrentUserCreator && currentUser != null) {
      solicitudExistente = await solicitudsService.jaExisteixSolicitud(
        activity['id'],
        currentUser,
        activity['creador'],
      );
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${'creador'.tr()}: ${activity['creador'] ?? ''}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              // Botones a la derecha
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final ubicacio =
                          activity['ubicacio'] as Map<String, dynamic>;
                      final lat = ubicacio['latitud'] as double;
                      final lon = ubicacio['longitud'] as double;
                      showRouteOptions(
                        context,
                        currentPosition,
                        LatLng(lat, lon),
                        mapService,
                      );
                    },
                    child: Text('get_directions'.tr()),
                  ),
                  // Favorite button
                  if (currentUser != null) // Only show if user is logged in
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                      ),
                      onPressed: () async {
                        if (isFavorite) {
                          await removeActivityFromFavorites(activity['id']);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tr('removed_from_favorites')),
                              ),
                            );
                          }
                        } else {
                          await addActivityToFavorites(activity['id']);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('added_to_favorites'))),
                            );
                          }
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                    ),

                  if (isCurrentUserCreator) // Botones de edición y eliminación
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditActivityForm(activity);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(activity);
                          },
                        ),
                      ],
                    )
                  else if (currentUser !=
                      null) // Botón "+" o tick azul para otros usuarios
                    IconButton(
                      icon: Icon(
                        solicitudExistente ? Icons.check_circle : Icons.add,
                        color: solicitudExistente ? Colors.blue : Colors.blue,
                      ),
                      onPressed: () {
                        if (solicitudExistente) {
                          // Mostrar botón para cancelar solicitud
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('cancel_request'.tr()),
                                content: Text('cancel_request_message'.tr()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('cancel'.tr()),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      Navigator.pop(context);
                                      await solicitudsService.cancelarSolicitud(
                                        activity['id'],
                                        currentUser,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'request_canceled_success'.tr(),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      'confirm'.tr(),
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          // Enviar solicitud
                          Navigator.pop(context);
                          _sendSolicitud(
                            activity['id'],
                            currentUser,
                            activity['creador'],
                          );
                        }
                      },
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
        showRouteOptions(
          context,
          currentPosition,
          selectedLocation,
          mapService,
        );
      },
      child: Text('get_directions'.tr()),
    );
  }

  // Función para mostrar el formulario de edición
  void _showEditActivityForm(Map<String, dynamic> activity) {
    final parentContext = context; // capture scaffold context
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: activity['nom']);
    final descriptionController = TextEditingController(
      text: activity['descripcio'],
    );
    final startDateController = TextEditingController(
      text: activity['dataInici'],
    );
    final endDateController = TextEditingController(text: activity['dataFi']);
    final creatorController = TextEditingController(text: activity['creador']);
    final locationController = TextEditingController(
      text:
          activity['ubicacio'] != null
              ? '${activity['ubicacio']['latitud']},${activity['ubicacio']['longitud']}'
              : '',
    );

    LatLng selectedLocation = LatLng(
      activity['ubicacio']['latitud'] as double,
      activity['ubicacio']['longitud'] as double,
    );

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('edit_activity'.tr()),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'title'.tr()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_title'.tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: 'description'.tr()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_description'.tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: startDateController,
                    decoration: InputDecoration(labelText: 'start_date'.tr()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_start_date'.tr();
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: endDateController,
                    decoration: InputDecoration(labelText: 'end_date'.tr()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_end_date'.tr();
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<LatLng>(
                    value: selectedLocation,
                    items:
                        savedLocations.entries.map((entry) {
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
                    decoration: InputDecoration(
                      labelText: 'select_location'.tr(),
                    ),
                    validator: (value) {
                      if (value == null) {
                        return 'please_select_location'.tr();
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
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop();

                  final updatedActivityData = {
                    'title': titleController.text,
                    'description': descriptionController.text,
                    'startDate': startDateController.text,
                    'endDate': endDateController.text,
                    'location': locationController.text,
                    'user': creatorController.text,
                  };

                  try {
                    final activityService = ActivityService();
                    await activityService.updateActivityInBackend(
                      activity['id'].toString(),
                      updatedActivityData,
                    );
                    if (mounted) {
                      if (!parentContext.mounted) return;
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text('activity_updated_success'.tr()),
                        ),
                      );
                    }
                    fetchActivities();
                  } catch (e) {
                    if (mounted) {
                      // Get only the part after the last ': '
                      final parts = e.toString().split(': ');
                      String msg = parts.isNotEmpty ? parts.last : e.toString();
                      if (msg.contains("inapropiats")) {
                        msg = "inappropiat_message".tr();
                      }
                      if (!parentContext.mounted) return;
                      ScaffoldMessenger.of(
                        parentContext,
                      ).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  }
                }
              },
              child: Text('save'.tr()),
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
          title: Text(tr('confirm_delete_activity_title')),
          content: Text(tr('confirm_delete_activity_content')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
              },
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Cierra el diálogo

                // Llama al servicio para eliminar la actividad
                try {
                  final activityService = ActivityService();
                  await activityService.deleteActivityFromBackend(
                    activity['id'].toString(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('activity_deleted_success'))),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr('activity_delete_error', args: [e.toString()]),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(tr('delete'), style: TextStyle(color: Colors.red)),
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

  // Función para navegar a la página de detalles (código original)
  void _navigateToActivityDetails(Map<String, dynamic> activity) {
    final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
    final lat = ubicacio['latitud'] as double;
    final lon = ubicacio['longitud'] as double;
    List<AirQualityData> airQualityData = findClosestAirQualityData(
      LatLng(lat, lon),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ActivityDetailsPage(
              id: activity['id'].toString(),
              title: activity['nom'] ?? '',
              creator: activity['creador'] ?? '',
              description: activity['descripcio'] ?? '',
              startDate: activity['dataInici'] ?? '',
              endDate: activity['dataFi'] ?? '',
              airQualityData: airQualityData,
              isEditable: true,
              onEdit:
                  () => _showEditActivityForm(
                    activity,
                  ), // Pasamos la función de editar
              onDelete:
                  () => _showDeleteConfirmation(
                    activity,
                  ), // Pasamos la función de eliminar
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
    final String? username = widget.authService.getCurrentUsername();
    if (username == null) {
      throw Exception('user_not_logged_in'.tr());
    }
    return await widget.activityService.isActivityFavorite(
      activityId,
      username,
    );
  }

  Future<void> addActivityToFavorites(int activityId) async {
    final String? username = widget.authService.getCurrentUsername();
    if (username == null) {
      throw Exception('user_not_logged_in'.tr());
    }
    await widget.activityService.addActivityToFavorites(activityId, username);
  }

  Future<void> removeActivityFromFavorites(int activityId) async {
    final String? username = widget.authService.getCurrentUsername();
    if (username == null) {
      throw Exception('user_not_logged_in'.tr());
    }
    await widget.activityService.removeActivityFromFavorites(
      activityId,
      username,
    );
  }

  Future<void> _showFavoriteActivities() async {
    try {
      final String? username = widget.authService.getCurrentUsername();
      if (username == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login_required_to_view_favorites'.tr())),
        );
        return;
      }

      final favoriteActivities = await widget.activityService
          .fetchFavoriteActivities(username);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('favorite_activities'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child:
                      favoriteActivities.isEmpty
                          ? Center(child: Text('no_favorites_found'.tr()))
                          : ListView.builder(
                            itemCount: favoriteActivities.length,
                            itemBuilder: (context, index) {
                              final activity = favoriteActivities[index];
                              return ListTile(
                                title: Text(activity['nom'] ?? 'Sin nombre'),
                                subtitle: Text(
                                  '${'creador'.tr()}: ${activity['creador'] ?? 'Unknown'}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await removeActivityFromFavorites(
                                      activity['id'],
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            tr('removed_from_favorites'),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showActivityDetails(activity);
                                },
                              );
                            },
                          ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('error_loading_favorites', args: [e.toString()])),
          ),
        );
      }
    }
  }

  Future<void> _sendSolicitud(
    int activityId,
    String requester,
    String host,
  ) async {
    try {
      await solicitudsService.sendSolicitud(activityId, requester, host);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('request_send_success'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('request_send_error', args: [e.toString()])),
          ),
        );
      }
    }
  }

  Future<int> _sendRouteToBackend(TransitRoute route) async {
    int id = 0;
    try {
      id = await mapService.sendRouteToBackend(route);
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text(tr('route_sent_success'))));
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text(tr('route_sent_error', args: [e.toString()]))),
        );
      }
    }
    return id;
  }

  Future<void> _updateRouteInBackend(MapEntry<int, TransitRoute> route) async {
    try {
      await mapService.updateRouteInBackend(route);
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text(tr('route_updated_success'))));
      }
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(
            content: Text(tr('route_updated_error', args: [e.toString()])),
          ),
        );
      }
    }
  }

  void _fitMapToBounds(LatLngBounds bounds) {
    // Add 15% padding around the route bounds
    final centerPoint = bounds.center;
    final double paddingFactor = 0.15;

    final heightDifference =
        (bounds.northEast.latitude - bounds.southWest.latitude) *
        (1 + paddingFactor);
    final widthDifference =
        (bounds.northEast.longitude - bounds.southWest.longitude) *
        (1 + paddingFactor);

    final newBounds = LatLngBounds(
      LatLng(
        centerPoint.latitude - heightDifference / 2,
        centerPoint.longitude - widthDifference / 2,
      ),
      LatLng(
        centerPoint.latitude + heightDifference / 2,
        centerPoint.longitude + widthDifference / 2,
      ),
    );

    mapController.move(newBounds.center, _getBoundsZoom(newBounds));
  }

  double _getBoundsZoom(LatLngBounds bounds) {
    final worldLatDiff = 180.0;
    final worldLngDiff = 360.0;

    final latDiff =
        (bounds.northEast.latitude - bounds.southWest.latitude).abs();
    final lngDiff =
        (bounds.northEast.longitude - bounds.southWest.longitude).abs();

    final latZoom = (log(worldLatDiff / latDiff) / ln2).floor();
    final lngZoom = (log(worldLngDiff / lngDiff) / ln2).floor();

    return min(latZoom, lngZoom).toDouble() + 1;
  }

  LatLngBounds _calculateRouteBounds(List<LatLng> routePoints) {
    if (routePoints.isEmpty) {
      return LatLngBounds(currentPosition, currentPosition);
    }

    double minLat = routePoints[0].latitude;
    double maxLat = routePoints[0].latitude;
    double minLng = routePoints[0].longitude;
    double maxLng = routePoints[0].longitude;

    for (var point in routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Add padding to include current position
    minLat = math.min(minLat, currentPosition.latitude);
    maxLat = math.max(maxLat, currentPosition.latitude);
    minLng = math.min(minLng, currentPosition.longitude);
    maxLng = math.max(maxLng, currentPosition.longitude);

    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  void _showTimeSelectionDialog() async {
    final selectedOption = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('select_time_option'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text('departure_time'.tr()),
                onTap: () => Navigator.pop(context, 'departure'),
              ),
              ListTile(
                leading: const Icon(Icons.access_time_filled),
                title: Text("arrival_time".tr()),
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
              currentRoute = MapEntry(
                currentRoute.key,
                await _calculateRoute(
                  true,
                  false,
                  selectedDateTime,
                  selectedDateTime,
                  currentRoute.value.option,
                  currentRoute.value.origin,
                  currentRoute.value.destination,
                  mapService,
                ),
              );
            } else if (selectedOption == 'arrival') {
              currentRoute = MapEntry(
                currentRoute.key,
                await _calculateRoute(
                  false,
                  true,
                  selectedDateTime,
                  selectedDateTime,
                  currentRoute.value.option,
                  currentRoute.value.origin,
                  currentRoute.value.destination,
                  mapService,
                ),
              );
            }
            setState(() {
              currentRoute = currentRoute;
            });
            final actualContext = context;
            if (actualContext.mounted) {
              ScaffoldMessenger.of(actualContext).showSnackBar(
                SnackBar(content: Text("route_calculated_success".tr())),
              );
            }
          } catch (e) {
            final actualContext = context;
            if (actualContext.mounted) {
              ScaffoldMessenger.of(actualContext).showSnackBar(
                SnackBar(
                  content: Text(
                    '${'route_calculation_error'.tr()} ${e.toString()}',
                  ),
                ),
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
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.25,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            if (loadingRoutes || loadingActivities) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('loading_routes', style: TextStyle(fontSize: 18)),
                  ],
                ),
              );
            }
            if (savedRoutes.isEmpty) {
              return Center(
                child: Text(
                  'no_routes_saved'.tr(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              );
            }

            // Group routes by destination type
            final List<MapEntry<int, TransitRoute>> activityRoutes = [];
            final List<MapEntry<int, TransitRoute>> otherRoutes = [];

            // Categorize routes
            savedRoutes.forEach((id, route) {
              bool isActivityDestination = false;

              // Check if this route is going to an activity
              for (var activity in activities) {
                final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
                final lat = ubicacio['latitud'] as double;
                final lon = ubicacio['longitud'] as double;
                final activityLocation = LatLng(lat, lon);

                final distance = Distance().as(
                  LengthUnit.Meter,
                  route.destination,
                  activityLocation,
                );
                if (distance < 20) {
                  activityRoutes.add(MapEntry(id, route));
                  isActivityDestination = true;
                  break;
                }
              }

              if (!isActivityDestination) {
                otherRoutes.add(MapEntry(id, route));
              }
            });

            // Build combined list with entries and divider
            return ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                if (activityRoutes.isNotEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'routes_activity'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ...activityRoutes.map((entry) => _buildRouteListTile(entry)),
                ],

                if (activityRoutes.isNotEmpty && otherRoutes.isNotEmpty)
                  Divider(thickness: 2, height: 32),

                if (otherRoutes.isNotEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'other_routes'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ...otherRoutes.map((entry) => _buildRouteListTile(entry)),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRouteListTile(MapEntry<int, TransitRoute> entry) {
    final route = entry.value;
    final routeId = entry.key;
    final destinationLatLng = route.destination;

    // Generate route title based on destination
    String title = 'Ruta';

    // Check for activity match
    for (var activity in activities) {
      final ubicacio = activity['ubicacio'] as Map<String, dynamic>;
      final lat = ubicacio['latitud'] as double;
      final lon = ubicacio['longitud'] as double;
      final activityLocation = LatLng(lat, lon);

      final distance = Distance().as(
        LengthUnit.Meter,
        destinationLatLng,
        activityLocation,
      );
      if (distance < 20) {
        title = 'Ruta a ${activity['nom']}';
        break;
      }
    }

    // If no activity match, check saved locations
    if (title == 'Ruta') {
      for (var entry in savedLocations.entries) {
        final savedLocation = entry.key;
        final distance = Distance().as(
          LengthUnit.Meter,
          destinationLatLng,
          savedLocation,
        );
        if (distance < 20) {
          // Extract a meaningful part from the place details
          final placeName = entry.value.split(',').first;
          title = 'Ruta a $placeName';
          break;
        }
      }
    }

    if (title == 'Ruta') {
      // If no match found, use the destination coordinates
      title =
          'Ruta a ${destinationLatLng.latitude}, ${destinationLatLng.longitude}';
    }

    // Find route index in the savedRoutes map
    final index = savedRoutes.keys.toList().indexOf(routeId);

    return ListTile(
      title: Text(title),
      subtitle: Text(
        '${'route_duration_distance'.tr()} ${route.duration} min - ${'route_distance'.tr()} ${route.distance} m',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.visibility, color: Colors.blue),
            onPressed: () {
              setState(() {
                currentRoute = MapEntry(routeId, route);
                // Schedule the bounds fitting for after the setState completes
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (currentRoute.value.fullRoute.isNotEmpty) {
                    _fitMapToBounds(
                      _calculateRouteBounds(currentRoute.value.fullRoute),
                    );
                  }
                });
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
                    title: Text('confirm_deletion'.tr()),
                    content: Text('sure_delete_route'.tr()),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the dialog
                        },
                        child: Text(
                          'Cancel·lar',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _eliminarRuta(routeId, index);
                          });
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
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
  }

  Future<void> _eliminarRuta(int id, int index) async {
    try {
      await mapService.deleteRouteInBackend(id);
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(
          actualContext,
        ).showSnackBar(SnackBar(content: Text('route_deleted_success'.tr())));
      }
      savedRoutes.remove(id);
      setState(() {
        savedRoutes = savedRoutes;
      });
    } catch (e) {
      final actualContext = context;
      if (actualContext.mounted) {
        ScaffoldMessenger.of(actualContext).showSnackBar(
          SnackBar(content: Text('${'route_delete_error'.tr()} $e')),
        );
      }
    }
  }

  void _toggleCompass() {
    setState(() {
      _showCompass = !_showCompass;
      if (_showCompass) {
        markers.removeWhere((m) => m.key == const Key('user_location'));
      } else {
        _updateUserMarker(currentPosition);
      }
    });
  }

  void _startNavigation() {
    if (currentRoute.value.fullRoute.isEmpty) return;

    setState(() {
      isNavigating = true;
      _showCompass = true;
    });

    // Start listening to location updates
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        setState(() {
          currentPosition = LatLng(position.latitude, position.longitude);
          // Update the user marker (ensure it's handled correctly in your marker list logic)
          if (_showCompass) {
            markers.removeWhere((m) => m.key == const Key('user_location'));
          } else {
            _updateUserMarker(currentPosition);
          }
        });
        // Center map on user location
        mapController.move(
          currentPosition,
          17.0,
        ); // Adjust zoom level as needed

        // --- Advanced Steps (To be implemented) ---
        // 1. Determine current step based on user location
        int currentStepIndex = _determineCurrentStepIndex(
          currentPosition,
          currentRoute,
        );
        // 2. Display current/next instruction
        if (currentStepIndex >= 0) {
          // User is on a valid step
          final currentStep = currentRoute.value.steps[currentStepIndex];

          // Show instruction for current step
          _showCurrentInstruction(currentStep, currentStepIndex);
        } else {
          // User is off route
          _showOffRouteWarning();
        }
        // 3. Check if user is off-route
        mapController.rotate(-_deviceHeading);
        // ---
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'error_getting_location'.tr()}$error')),
          );
        }
        _stopNavigation();
      },
    );
  }

  void _stopNavigation() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _currentInstructionOverlay?.remove();
    _currentInstructionOverlay = null;
    setState(() {
      isNavigating = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('navigation_stopped'.tr())));
    }
  }

  int _determineCurrentStepIndex(
    LatLng userPosition,
    MapEntry<int, TransitRoute> route,
  ) {
    if (route.value.steps.isEmpty) return -1;

    // Find the step with the closest point to the user's current position
    int closestStepIndex = 0;
    double closestDistance = double.infinity;

    for (int i = 0; i < route.value.steps.length; i++) {
      final step = route.value.steps[i];

      // For each step, find the closest point in that step's points
      for (int j = 0; j < step.points.length; j++) {
        final point = step.points[j];
        final distance = Distance().as(LengthUnit.Meter, userPosition, point);

        if (distance < closestDistance) {
          closestDistance = distance;
          closestStepIndex = i;
        }
      }
    }

    // If we're too far from any point (e.g., 50 meters), we might be off route
    if (closestDistance > 50) {
      return -1; // Indicates off-route
    }

    return closestStepIndex;
  }

  void _updateUserMarker(LatLng position) {
    if (isNavigating && currentRoute.value.fullRoute.isNotEmpty) {
      // Get the current step and its points
      int currentStepIndex = _determineCurrentStepIndex(position, currentRoute);
      if (currentStepIndex >= 0) {
        TransitStep currentStep = currentRoute.value.steps[currentStepIndex];

        double minDistance = double.infinity;
        LatLng nextWaypoint = currentStep.points[0];

        for (int i = 0; i < currentStep.points.length; i++) {
          double distance = Distance().as(
            LengthUnit.Meter,
            position,
            currentStep.points[i],
          );
          if (distance < minDistance) {
            minDistance = distance;
            // Use the point after the closest one as the next waypoint
            if (i + 1 < currentStep.points.length) {
              nextWaypoint = currentStep.points[i + 1];
            } else if (currentStepIndex + 1 < currentRoute.value.steps.length) {
              // If we're at the last point of the step, use the first point of the next step
              nextWaypoint =
                  currentRoute.value.steps[currentStepIndex + 1].points[0];
            }
          }
        }

        // Calculate bearing between current position and next waypoint
        final bearing = _calculateBearing(position, nextWaypoint);

        markers.removeWhere((m) => m.key == const Key('user_location'));
        markers.add(
          Marker(
            key: const Key('user_location'),
            width: 80.0,
            height: 80.0,
            point: position,
            child: Transform.rotate(
              angle: bearing * (math.pi / 180),
              child: const Icon(
                Icons.navigation,
                color: Colors.blue,
                size: 40.0,
              ),
            ),
          ),
        );
      }
    } else {
      // Default marker when not navigating
      markers.removeWhere((m) => m.key == const Key('user_location'));
      markers.add(
        Marker(
          key: const Key('user_location'),
          width: 80.0,
          height: 80.0,
          point: position,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40.0),
        ),
      );
    }
    setState(() {
      markers = List.from(markers);
    });
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * math.pi / 180;
    final startLng = start.longitude * math.pi / 180;
    final endLat = end.latitude * math.pi / 180;
    final endLng = end.longitude * math.pi / 180;

    final dLng = endLng - startLng;

    final y = math.sin(dLng) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return bearing;
  }

  void _showCurrentInstruction(TransitStep step, int stepIndex) {
    _currentInstructionOverlay?.remove();
    _currentInstructionOverlay = OverlayEntry(
      builder:
          (context) => Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 8,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Transport mode icon
                          Icon(
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
                            color: Theme.of(context).primaryColor,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          // Step instruction with movement icon
                          Expanded(
                            child: Row(
                              children: [
                                if (step.mode != TipusVehicle.autobus &&
                                    step.mode != TipusVehicle.tren &&
                                    step.mode != TipusVehicle.metro)
                                  Icon(
                                    mapService.getDirectionTypeIcon(step.type),
                                    color: Theme.of(context).primaryColor,
                                    size: 24,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    step.instruction.isNotEmpty
                                        ? step.instruction
                                        : "Follow the route",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Time and distance information
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${DateFormat.Hm().format(step.departure)} - ${DateFormat.Hm().format(step.arrival)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${step.distance} m',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    if (mounted) {
      Overlay.of(context).insert(_currentInstructionOverlay!);
    }
  }

  void _showOffRouteWarning() {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.yellow),
              SizedBox(width: 8),
              Text('recalculating_route'.tr(), style: TextStyle(fontSize: 16)),
            ],
          ),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );

      // Optional: You could trigger route recalculation here
      _recalculateRoute(currentPosition);
    }
  }

  void _recalculateRoute(LatLng currentPosition) async {
    try {
      TransitRoute newRoute = await _calculateRoute(
        true,
        false,
        DateTime.now(),
        DateTime.now(),
        currentRoute.value.option,
        currentPosition,
        currentRoute.value.destination,
        mapService,
      );
      setState(() {
        currentRoute = MapEntry(currentRoute.key, newRoute);
        savedRoutes[currentRoute.key] = newRoute;
      });
      _updateRouteInBackend(currentRoute);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error_recalculating_route'.tr()} $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AirPlan")),
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
            route: currentRoute.value.fullRoute,
            steps: currentRoute.value.steps,
            userHeading: _showCompass ? _deviceHeading : null,
            isNavigationMode: isNavigating,
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "toggleAirQuality",
                  onPressed: _toggleAirQualityCircles,
                  child: Icon(
                    showAirQualityCircles
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
                const SizedBox(height: 10),
                if (!isNavigating) ...[
                  FloatingActionButton(
                    heroTag: "showSavedRoutes",
                    onPressed: isNavigating ? null : _showSavedRoutes,
                    child: Icon(Icons.route),
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton(
                  heroTag: "toggleCompass",
                  onPressed: _toggleCompass,
                  child: Icon(
                    _showCompass ? Icons.compass_calibration : Icons.explore,
                  ),
                ),
              ],
            ),
          ),
          // Route action buttons - only show when route is active
          if (currentRoute.value.fullRoute.isNotEmpty) ...[
            Positioned(
              top: 210,
              right: 10,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: "startStopRoute", // Changed heroTag
                    backgroundColor:
                        isNavigating
                            ? Colors.red
                            : Colors.green, // Change color
                    onPressed: () {
                      if (isNavigating) {
                        _stopNavigation();
                      } else {
                        _startNavigation();
                      }
                    },
                    child: Icon(
                      isNavigating ? Icons.stop : Icons.play_arrow,
                    ), // Change icon
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: "showInstructions",
                    backgroundColor: Colors.blue,
                    onPressed: () {
                      if (currentRoute.value.steps.isNotEmpty) {
                        _showRouteDetails(currentRoute.value);
                      }
                    },
                    child: const Icon(Icons.list),
                  ),
                  if (!isNavigating) ...[
                    if (currentRoute.value.option == 10) ...[
                      const SizedBox(height: 10),
                      FloatingActionButton(
                        heroTag: "changeDepartureArrival",
                        backgroundColor: Colors.cyan,
                        onPressed: () {
                          _showTimeSelectionDialog();
                        },
                        child: const Icon(Icons.access_time),
                      ),
                    ],
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "saveRoute",
                      backgroundColor: Colors.orange,
                      onPressed: () async {
                        int id = await _sendRouteToBackend(currentRoute.value);
                        if (id != 0) {
                          savedRoutes[id] = currentRoute.value;
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
                          currentRoute = MapEntry(
                            0,
                            TransitRoute(
                              fullRoute: [],
                              steps: [],
                              duration: 0,
                              distance: 0,
                              departure: DateTime.now(),
                              arrival: DateTime.now(),
                              origin: LatLng(0, 0),
                              destination: LatLng(0, 0),
                              option: 0,
                            ),
                          );
                        });
                      },
                      child: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (!isNavigating)
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
        heroTag: "addLocation",
        onPressed: () {
          if (savedLocations.entries.isNotEmpty) {
            _showFormWithLocation(savedLocations.keys.first, placeDetails);
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('no_ubication_saved'.tr())));
          }
        },
        child: const Icon(Icons.add_location),
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    super.dispose();
  }
}
