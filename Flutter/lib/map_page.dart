// map_page.dart
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
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
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

  @override
  void initState() {
    super.initState();
    fetchAirQualityData();
    fetchActivities();
  }

  Future<void> fetchAirQualityData() async {
    final circles = await mapService.fetchAirQualityData(contaminantsPerLocation);
    setState(() {
      this.circles = circles;
    });
  }

  Future<void> fetchActivities() async {
    final activities = await activityService.fetchActivities();
    setState(() {
      this.activities = activities;
    });
  }

  void _onMapTapped(TapPosition tapPosition, LatLng position) {
    setState(() {
      selectedLocation = position;
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
    mapService.fetchPlaceDetails(position).then((details) {
      setState(() {
        placeDetails = details;
      });
      _showPlaceDetails();
    });
  }

  void _showPlaceDetails() {
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
                            _showFormWithLocation(selectedLocation);
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

  void _showFormWithLocation(LatLng location) async {
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
          airQuality: 'Excel·lent', // Placeholder
          airQualityColor: Colors.lightBlue, // Placeholder
          isEditable: true,
        ),
      ),
    );
  }

  void _showSavedLocationDetails(LatLng position, String details) {
    setState(() {
      selectedLocation = position;
      placeDetails = details;
    });
    _showPlaceDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OpenStreetMap Example")),
      body: map_ui.MapUI(
        mapController: mapController,
        currentPosition: currentPosition,
        circles: circles,
        onMapTapped: _onMapTapped,
        activities: activities,
        onActivityTap: _showActivityDetails, markers: markers,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (selectedLocation != LatLng(0, 0)) {
            _showFormWithLocation(selectedLocation);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selecciona una ubicación en el mapa antes de crear una actividad.')),
            );
          }
        },
        child: Icon(Icons.add_location),
      ),
    );
  }
}