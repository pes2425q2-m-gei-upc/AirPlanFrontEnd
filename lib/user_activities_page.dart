import 'package:flutter/material.dart';

// Simulated backend call to fetch user activities
Future<List<Map<String, String>>> fetchUserActivities() async {
  // Replace this with your actual backend API call
  await Future.delayed(const Duration(seconds: 1)); // Simulate delay
  return [
    {"id": "1", "name": "Actividad A"},
    {"id": "2", "name": "Actividad B"},
  ];
}

class UserActivitiesPage extends StatefulWidget {
  const UserActivitiesPage({super.key});

  @override
  State<UserActivitiesPage> createState() => _UserActivitiesPageState();
}

class _UserActivitiesPageState extends State<UserActivitiesPage> {
  late Future<List<Map<String, String>>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = fetchUserActivities();
  }

  void _goToActivityDetails(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailsPage(activityId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Actividades"),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _activitiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("Error al cargar las actividades"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("No estás participando en ninguna actividad"),
            );
          }

          final activities = snapshot.data!;
          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ListTile(
                title: GestureDetector(
                  onTap: () => _goToActivityDetails(activity["id"]!),
                  child: Text(
                    activity["name"]!,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ActivityDetailsPage extends StatelessWidget {
  final String activityId;

  const ActivityDetailsPage({super.key, required this.activityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detalles de Actividad $activityId"),
      ),
      body: Center(
        child: Text("Detalles de la actividad con ID: $activityId"),
      ),
    );
  }
}