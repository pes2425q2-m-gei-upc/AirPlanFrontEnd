import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  LatLng? selectedLocation;
  String? placeDetails;
  List<Marker> markers = [];
  List<Polygon> polygons = [];
  LatLng currentPosition = LatLng(41.3851, 2.1734); // Default to Barcelona
  bool showAirQuality = false;

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
    /*
    final url = Uri.parse('https://api.example.com/air_quality');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          polygons = createPolygonsFromAirQualityData(data);
        });
      } else {
        throw Exception('Failed to load air quality data');
      }
    } catch (e) {
      print("Error fetching air quality data: $e");
    }
    */
  }

  List<Polygon> createPolygonsFromAirQualityData(dynamic data) {
    // Example function to create polygons based on air quality data
    // This should be adapted to your specific data structure
    List<Polygon> polygons = [];
    for (var area in data['areas']) {
      List<LatLng> points = [];
      for (var point in area['points']) {
        points.add(LatLng(point['lat'], point['lng']));
      }
      Color color = getColorForAirQuality(area['aqi']);
      polygons.add(Polygon(
        points: points,
        color: color.withOpacity(0.5),
        borderColor: color,
        borderStrokeWidth: 2.0,
      ));
    }
    return polygons;
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
      markers = [
        Marker(
          point: position,
          child: Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      ];
    });
    await fetchPlaceDetails(position);
    _showPlaceDetails();
  }

  void _onMapTapped(TapPosition p, LatLng position) {
    _addMarker(position);
  }

  void _onButtonPressed() {
    _addMarker(currentPosition);
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
                    Text(placeDetails ?? "No address available"),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              if (showAirQuality) PolygonLayer(polygons: polygons),
              MarkerLayer(markers: markers),
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
        onPressed: _onButtonPressed,
        child: Icon(Icons.add_location),
      ),
    );
  }
}