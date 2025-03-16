import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:location/location.dart' as loc;

const String googleApiKey = 'AIzaSyCm6JS3aQjDdzLSOckSJzw9KoFFyGePd2o';
final places = GoogleMapsPlaces(apiKey: googleApiKey);

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  LatLng? selectedLocation;
  PlacesDetailsResponse? placeDetails;
  Set<Marker> markers = {};
  final locationController = loc.Location();
  LatLng? currentPosition;

  @override
  void initState() {
    super.initState();
    fetchLocationUpdates();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _fetchNearbyPlaces();
  }

  Future<void> _fetchNearbyPlaces() async {
    if (currentPosition == null) return;

    final result = await places.searchNearbyWithRadius(
      Location(lat: currentPosition!.latitude, lng: currentPosition!.longitude),
      1000, // 1 km radius
    );

    if (result.results.isNotEmpty) {
      setState(() {
        markers = result.results.map((place) {
          return Marker(
            markerId: MarkerId(place.placeId),
            position: LatLng(place.geometry!.location.lat, place.geometry!.location.lng),
            infoWindow: InfoWindow(title: place.name),
            onTap: () async {
              final details = await places.getDetailsByPlaceId(place.placeId);
              setState(() {
                placeDetails = details;
              });
            },
          );
        }).toSet();
      });
    }
  }

  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      selectedLocation = position;
      markers.add(
        Marker(
          markerId: MarkerId("selected"),
          position: position,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.2,
                  minChildSize: 0.2,
                  maxChildSize: 1.0,
                  expand: false,
                  builder: (context, scrollController) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            margin: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          ListTile(
                            title: Text('Selected Location'),
                            subtitle: Text('Lat: ${position.latitude}, Lng: ${position.longitude}'),
                          ),
                          if (placeDetails != null) ...[
                            ListTile(
                              title: Text(placeDetails!.result.name),
                              subtitle: Text(placeDetails?.result.formattedAddress ?? "No address available"),
                            ),
                            if (placeDetails?.result.rating != null)
                              ListTile(
                                title: Text("Rating"),
                                subtitle: Text("${placeDetails?.result.rating} ⭐"),
                              ),
                            if (placeDetails?.result.formattedPhoneNumber != null)
                              ListTile(
                                title: Text("Phone"),
                                subtitle: Text(placeDetails!.result.formattedPhoneNumber!),
                              ),
                            if (placeDetails?.result.website != null)
                              ListTile(
                                title: Text("Website"),
                                subtitle: Text(placeDetails!.result.website!),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      );
    });
  }

  Future<void> fetchLocationUpdates() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionStatus;
    serviceEnabled = await locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationController.requestService();
    }

    permissionStatus = await locationController.hasPermission();
    if (permissionStatus == loc.PermissionStatus.denied) {
      permissionStatus = await locationController.requestPermission();
    }

    locationController.onLocationChanged.listen((loc.LocationData currentLocation) {
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        setState(() {
          currentPosition = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          _fetchNearbyPlaces();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Google Maps Example")),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: currentPosition ?? LatLng(41.3851, 2.1734), // Current position or Barcelona if user doesn't allow location
              zoom: 15,
            ),
            onTap: _onMapTapped,
            markers: markers,
          ),
          if (placeDetails != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placeDetails!.result.name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 5),
                      Text(placeDetails!.result.formattedAddress ?? "No address available"),
                      SizedBox(height: 5),
                      Text("Rating: ${placeDetails!.result.rating?.toString() ?? 'N/A'} ⭐"),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}