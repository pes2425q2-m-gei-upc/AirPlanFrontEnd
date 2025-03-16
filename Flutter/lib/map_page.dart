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
  LatLng currentPosition = LatLng(41.3851, 2.1734); // Default to Barcelona

  @override
  void initState() {
    super.initState();
    fetchLocationUpdates();
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

  void _onMapTapped(TapPosition p, LatLng position) async {
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
              MarkerLayer(markers: markers),
            ],
          ),
        ],
      ),
    );
  }
}