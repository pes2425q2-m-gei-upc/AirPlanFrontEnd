import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';

class Activity {
  String name;
  String description;
  String imageUrl;

  Activity({
    required this.name,
    required this.description,
    required this.imageUrl,
  });
}

class RecommendedActivitiesPage extends StatefulWidget {
  final LatLng userLocation;

  RecommendedActivitiesPage({
    super.key,
    required this.userLocation,
  });

  @override
  RecommendedActivitiesPageState createState() => RecommendedActivitiesPageState();
}

class RecommendedActivitiesPageState extends State<RecommendedActivitiesPage> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}