import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'home_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  LatLng selectedLocation = LatLng(0, 0);
  String placeDetails = "";
  List<CircleMarker> circles = [];
  LatLng currentPosition = LatLng(41.3851, 2.1734); // Default to Barcelona
  Map<LatLng,String> savedLocations = {};
  bool showAirQuality = true;

  @override
  void initState() {
    super.initState();
    fetchLocationUpdates();
    fetchAirQualityData();
  }

  Future<void> fetchPlaceDetails(LatLng position) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          placeDetails = data['display_name'] ?? "No address found";
        });
      } else {
        throw Exception('Failed to load place details');
      }
    } catch (e) {
      setState(() {
        placeDetails = "Error fetching place details";
      });
    }
  }

  Future<void> fetchAirQualityData() async {
    final url = Uri.parse('https://analisi.transparenciacatalunya.cat/resource/tasf-thgu.json');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          circles = createCirclesFromAirQualityData(data);
        });
      } else {
        throw Exception('Failed to load air quality data');
      }
    } catch (e) {
      print("Error fetching air quality data: $e");
    }
  }

  List<CircleMarker> createCirclesFromAirQualityData(dynamic data) {
    List<CircleMarker> circles = [];

    for (var entry in data) {
      LatLng position = LatLng(double.parse(entry['latitud']), double.parse(entry['longitud']));
      int aqi = getLastAirQualityIndex(entry);
      Color color = getColorForAirQuality(aqi);

      circles.add(CircleMarker(
        point: position,
        color: color,
        borderStrokeWidth: 2.0,
        borderColor: color,
        radius: 20, // Radius in pixels
      ));
    }

    return circles;
  }

  int getLastAirQualityIndex(Map<String, dynamic> entry) {
    int maxHour = 0;
    int aqi = 0;

    entry.forEach((key, value) {
      if (key.startsWith('h')) {
        int hour = int.tryParse(key.substring(1)) ?? 0;
        if (hour > maxHour) {
          maxHour = hour;
          aqi = int.tryParse(value) ?? 0;
        }
      }
    });

    return aqi;
  }

  Color getColorForAirQuality(int aqi) {
    if (aqi <= 50) {
      return Colors.green;
    } else if (aqi <= 100) {
      return Colors.yellow;
    } else if (aqi <= 150) {
      return Colors.orange;
    } else if (aqi <= 200) {
      return Colors.red;
    } else if (aqi <= 300) {
      return Colors.purple;
    } else {
      return Colors.brown;
    }
  }

  void _addMarker(LatLng position) async {
    setState(() {
      selectedLocation = position;
    });
    await fetchPlaceDetails(position);
    _showPlaceDetails();
  }

  void _onMapTapped(TapPosition p, LatLng position) {
    _addMarker(position);
  }

  void _showForm() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Details'),
          content: FormDialog(
            initialLocation: '',
            initialTitle: '',
            initialUser: '',
            initialDescription: '',
            initialStartDate: '',
            initialEndDate: '', savedLocations: savedLocations,
          ),
        );
      },
    );

    if (result != null) {
      // Handle the form submission result here
      print('Form submitted with data: $result');
    }
  }

  void _toggleAirQuality() {
    setState(() {
      showAirQuality = !showAirQuality;
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
                            savedLocations[selectedLocation] = placeDetails;
                            Navigator.pop(context); // Close the modal
                            _showFormWithLocation(selectedLocation);
                          },
                          child: const Text("Crea Activitat"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              savedLocations[selectedLocation] = placeDetails;
                            });
                            Navigator.pop(context); // Close the modal
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
      // Handle the form submission result here
      print('Form submitted with data: $result');
    }
  }

  Future<void> fetchLocationUpdates() async {
    // Simulate fetching current location
    setState(() {
      currentPosition = LatLng(41.3851, 2.1734); // Default to Barcelona
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OpenStreetMap Example")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentPosition,
              initialZoom: 15.0,
              onTap: _onMapTapped,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              if (showAirQuality) CircleLayer(circles: circles),
              MarkerLayer(
                markers: savedLocations.keys.map((location) {
                  return Marker(
                    point: location,
                    child: Icon(Icons.location_on, color: Colors.red, size: 40),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _toggleAirQuality,
              child: Icon(showAirQuality ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm, // Show the form on button press
        child: Icon(Icons.add_location),
      ),
    );
  }
}